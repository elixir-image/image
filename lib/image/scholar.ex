if match?({:module, _module}, Code.ensure_compiled(Scholar.Cluster.KMeans)) and
     match?({:module, _module}, Code.ensure_compiled(Nx)) do
  defmodule Image.Scholar do
    @moduledoc """
    Functions that analyse images using
    [Scholar](https://hex.pm/packages/scholar) machine-learning
    primitives.

    The primary public API is `unique_colors/1` and `k_means/2`
    which underpin `Image.k_means/2` and `Image.reduce_colors/2`.

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

    defp scholar_error(message) do
      %Image.Error{message: message, reason: message}
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

    * A fitted `Scholar.Cluster.KMeans` model or

    * `{:error, reason}`.

    """
    def k_means(%Vimage{} = image, options \\ []) do
      with {:ok, {_count, colors}} <- unique_colors(image) do
        # K-means requires at least as many samples as clusters, so
        # the cluster count is clamped to the number of unique colors.
        # A single unique color (solid image) is duplicated because
        # the random centroid initialisation needs at least 2 samples.
        unique_count = Nx.axis_size(colors, 0)

        colors =
          if unique_count == 1, do: Nx.concatenate([colors, colors]), else: colors

        options =
          case Keyword.fetch(options, :num_clusters) do
            {:ok, num_clusters} when is_integer(num_clusters) ->
              Keyword.put(options, :num_clusters, Kernel.min(num_clusters, unique_count))

            _other ->
              options
          end

        Scholar.Cluster.KMeans.fit(colors, options)
      end
    end

    defp encode_colors(colors, 3) do
      colors
      |> Nx.multiply(Nx.tensor([[1, 256, @square_256]]))
      |> Nx.sum(axes: [2])
    end

    defp encode_colors(colors, 4) do
      colors
      |> Nx.multiply(Nx.tensor([[1, 256, @square_256, 256 * @square_256]]))
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
