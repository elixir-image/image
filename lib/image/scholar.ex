if match?({:module, _module}, Code.ensure_compiled(Scholar.Cluster.KMeans)) and
     match?({:module, _module}, Code.ensure_compiled(Nx)) do
  defmodule Image.Scholar do
    @moduledoc """
    Functions that analyse images using
    [Scholar](https://hex.pm/packages/scholar) machine-learning
    primitives.

    The public API is `unique_colors/1`, `unique_color_count/1` and
    `k_means/2`, which underpin `Image.k_means/2` and
    `Image.reduce_colors/2`.

    """

    import Nx

    alias Vix.Vips.Image, as: Vimage

    @square_256 256 ** 2

    @doc """
    Returns the unique colors in an image and the count of
    each color.

    ### Arguments

    * `image` is any 3- or 4-band `t:Vix.Vips.Image.t/0` with
      `{:u, 8}` band format.

    ### Returns

    * `{:ok, {color_count_tensor, unique_colors_tensor}}` or

    * `{:error, reason}`.

    """
    def unique_colors(%Vimage{} = image) do
      bands = Image.bands(image)

      cond do
        bands not in [3, 4] ->
          {:error,
           scholar_error("unique_colors/1 requires a 3- or 4-band image. Found #{bands} bands")}

        Image.band_format(image) != {:u, 8} ->
          {:error,
           scholar_error(
             "unique_colors/1 requires an 8-bit unsigned image. " <>
               "Found #{inspect(Image.band_format(image))}"
           )}

        true ->
          do_unique_colors(image, bands)
      end
    end

    defp do_unique_colors(image, bands) do
      with {:ok, tensor} <- Image.to_nx(image) do
        colors_base256 =
          tensor
          |> encode_colors(bands)
          |> Nx.flatten()
          |> Nx.sort()

        diff =
          diff(colors_base256)

        unique_indices_selector =
          Nx.concatenate([Nx.tensor([1]), Nx.not_equal(diff, 0)])

        marked_unique_indices =
          Nx.select(unique_indices_selector, Nx.iota(colors_base256.shape), -1)

        repeated_count =
          Nx.to_number(Nx.sum(Nx.logical_not(unique_indices_selector)))

        unique_indices =
          marked_unique_indices
          |> Nx.sort()
          |> Nx.slice_along_axis(repeated_count, Nx.size(marked_unique_indices) - repeated_count,
            axis: 0
          )

        unique_colors =
          Nx.take(colors_base256, unique_indices)
          |> decode_colors(bands)

        # colors_base256 holds one encoded value per pixel so its size
        # is the pixel count.
        count = Nx.size(colors_base256)

        # Nx.diff/1 requires at least two elements so a single unique
        # color (a solid-color image) is handled directly.
        color_count =
          if Nx.size(unique_indices) == 1 do
            Nx.tensor([count])
          else
            max = Nx.to_number(Nx.reduce_max(unique_indices))
            Nx.concatenate([diff(unique_indices), Nx.tensor([count - max])])
          end

        {:ok, {color_count, unique_colors}}
      end
    end

    @doc """
    Returns the number of unique colors in an image.

    Prefer this over `unique_colors/1` when only the count is
    needed.

    ### Arguments

    * `image_or_tensor` is any 3- or 4-band `t:Vix.Vips.Image.t/0` with
      `{:u, 8}` band format, or the `{height, width, bands}` tensor of
      such an image as returned by `Image.to_nx/2`. Pass the tensor when
      one is already to hand, to avoid converting the image twice.

    ### Returns

    * `{:ok, count}` or

    * `{:error, reason}`.

    ### Example

        iex> Image.Scholar.unique_color_count(Image.new!(4, 4, color: :red))
        {:ok, 1}

    """
    @spec unique_color_count(image_or_tensor :: Vimage.t() | Nx.Tensor.t()) ::
            {:ok, non_neg_integer()} | {:error, Image.Error.t()}

    def unique_color_count(image_or_tensor)

    def unique_color_count(%Vimage{} = image) do
      with {:ok, tensor} <- Image.to_nx(image) do
        unique_color_count(tensor)
      end
    end

    # The rank is checked first so the band lookup below cannot raise.
    def unique_color_count(%Nx.Tensor{} = tensor) do
      cond do
        Nx.rank(tensor) != 3 ->
          {:error,
           scholar_error(
             "unique_color_count requires a {height, width, bands} tensor. " <>
               "Found rank #{Nx.rank(tensor)}"
           )}

        Nx.axis_size(tensor, 2) not in [3, 4] ->
          {:error,
           scholar_error(
             "unique_color_count requires a 3- or 4-band image. " <>
               "Found #{Nx.axis_size(tensor, 2)} bands"
           )}

        Nx.type(tensor) != {:u, 8} ->
          {:error,
           scholar_error(
             "unique_color_count requires an 8-bit unsigned image. " <>
               "Found #{inspect(Nx.type(tensor))}"
           )}

        true ->
          {:ok, do_unique_color_count(tensor, Nx.axis_size(tensor, 2))}
      end
    end

    defp do_unique_color_count(tensor, bands) do
      encoded =
        tensor
        |> encode_colors(bands)
        |> Nx.flatten()
        |> Nx.sort()

      # Nx.diff/1 needs at least two elements, so a single pixel is counted
      # directly. Otherwise the distinct count is one more than the number
      # of adjacent unequal pairs.
      if Nx.size(encoded) < 2 do
        Nx.size(encoded)
      else
        Nx.to_number(Nx.sum(Nx.not_equal(diff(encoded), 0))) + 1
      end
    end

    defp scholar_error(message) do
      %Image.Error{message: message, reason: message}
    end

    # Scholar.Cluster.KMeans.fit/2 raises rather than returning an error:
    # NimbleOptions.ValidationError for an invalid or unknown option, and
    # ArgumentError for the checks it makes outside its schema. Both are
    # translated to {:error, %Image.Error{}} here at the boundary.
    #
    # `max_clusters` bounds `:num_clusters`, which cannot exceed the
    # number of distinct samples to cluster.
    @doc false
    def fit(samples, options, max_clusters \\ nil) do
      # Scholar raises ArithmeticError for a lone sample rather than
      # validating it, so it is checked here to keep the message useful.
      if Nx.axis_size(samples, 0) < 2 do
        {:error,
         scholar_error(
           "K-means requires at least 2 samples to cluster. " <>
             "Found #{Nx.axis_size(samples, 0)}"
         )}
      else
        {:ok, Scholar.Cluster.KMeans.fit(samples, clamp_clusters(options, max_clusters))}
      end
    rescue
      exception in NimbleOptions.ValidationError ->
        {:error, invalid_option(exception)}

      exception in ArgumentError ->
        {:error, %Image.Error{reason: :invalid_option, message: Exception.message(exception)}}
    end

    defp clamp_clusters(options, nil), do: options

    defp clamp_clusters(options, max_clusters) do
      case Keyword.fetch(options, :num_clusters) do
        {:ok, num_clusters} when is_integer(num_clusters) ->
          Keyword.put(options, :num_clusters, Kernel.min(num_clusters, max_clusters))

        _other ->
          options
      end
    end

    # An unknown option sets :key to the list of unknown keys and leaves
    # :value nil. An invalid value sets both.
    defp invalid_option(%NimbleOptions.ValidationError{key: keys} = exception)
         when is_list(keys) do
      %Image.Error{
        reason: :invalid_option,
        value: keys,
        message: Exception.message(exception)
      }
    end

    defp invalid_option(exception) do
      %Image.Error{
        reason: :invalid_option,
        value: {exception.key, exception.value},
        message: Exception.message(exception)
      }
    end

    @doc """
    Clusters the unique colors of an image using the K-means
    algorithm.

    ### Arguments

    * `image` is any 3- or 4-band `t:Vix.Vips.Image.t/0` with
      `{:u, 8}` band format.

    * `options` is a keyword list of options passed to
      `Scholar.Cluster.KMeans.fit/2`.

    ### Returns

    * `{:ok, model}` where `model` is a fitted
      `Scholar.Cluster.KMeans` or

    * `{:error, reason}`.

    """
    def k_means(%Vimage{} = image, options \\ []) do
      with {:ok, {_count, colors}} <- unique_colors(image) do
        # A single unique color (solid image) is duplicated because
        # the random centroid initialisation needs at least 2 samples.
        unique_count = Nx.axis_size(colors, 0)

        colors =
          if unique_count == 1, do: Nx.concatenate([colors, colors]), else: colors

        fit(colors, options, unique_count)
      end
    end

    # The multipliers are 64-bit so that 4-band encoding
    # (255 * 256 ** 3) does not overflow the default 32-bit
    # integer tensor type.
    defp encode_colors(colors, 3) do
      colors
      |> Nx.multiply(Nx.tensor([[1, 256, @square_256]], type: :s64))
      |> Nx.sum(axes: [2])
    end

    defp encode_colors(colors, 4) do
      colors
      |> Nx.multiply(Nx.tensor([[1, 256, @square_256, 256 * @square_256]], type: :s64))
      |> Nx.sum(axes: [2])
    end

    defp decode_colors(encoded_colors, 3) do
      b = Nx.quotient(encoded_colors, @square_256)
      rem = Nx.remainder(encoded_colors, @square_256)
      g = Nx.quotient(rem, 256)
      r = Nx.remainder(rem, 256)

      Nx.stack([r, g, b], axis: 1)
    end

    defp decode_colors(encoded_colors, 4) do
      a = Nx.quotient(encoded_colors, 256 * @square_256)
      rem = Nx.remainder(encoded_colors, 256 * @square_256)
      b = Nx.quotient(rem, @square_256)
      rem = Nx.remainder(rem, @square_256)
      g = Nx.quotient(rem, 256)
      r = Nx.remainder(rem, 256)

      Nx.stack([r, g, b, a], axis: 1)
    end
  end
end
