defmodule Image.Options.Embed do
  @moduledoc """
  Options and option validation for `Image.embed/4`.

  """
  alias Image.Pixel

  @typedoc """
  Options applicable to `Image.embed/4`.

  """
  @type embed_option ::
          {:background_color, Pixel.t() | :average}
          | {:background_transparency, Pixel.transparency()}
          | {:extend_mode, extend_mode()}
          | {:x, non_neg_integer() | :center}
          | {:y, non_neg_integer() | :center}

  @typedoc """
  When extending the canvas the generated
  pixels are determined by this option.

  """
  @type extend_mode ::
          :black
          | :white
          | :copy
          | :repeat
          | :mirror
          | :background

  @typedoc """
  Options list for `Image.embed/4`.

  """
  @type embed_options :: [embed_option()]

  @doc """
  Validate the options for `Image.embed/4`.

  """
  def validate_options(image, width, height, options) when is_list(options) do
    user_supplied_keys = Keyword.keys(options)
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, image, width, height, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        options
        |> Map.new()
        |> adjust_background(image, user_supplied_keys)
    end
  end

  def validate_options(_image, _width, _height, %{} = options) do
    {:ok, options}
  end

  defp validate_option({:background_color, :average}, image, _width, _height, options) do
    case Image.average(image) do
      color when is_list(color) ->
        options = Keyword.put(options, :background_color, color)
        {:cont, options}

      {:error, reason} ->
        {:halt,
         {:error,
          %Image.Error{
            message: "Could not get the image average: #{inspect(reason)}",
            reason: "Could not get the image average: #{inspect(reason)}"
          }}}
    end
  end

  defp validate_option({:background_color, color} = option, image, _width, _height, options) do
    case Pixel.to_pixel(image, color) do
      {:ok, pixel} ->
        {:cont, Keyword.put(options, :background_color, pixel)}

      _other ->
        {:halt, {:error, invalid_option(option)}}
    end
  end

  defp validate_option(
         {:background_transparency, transparency} = option,
         _image,
         _width,
         _height,
         options
       ) do
    case Pixel.transparency(transparency) do
      {:ok, transparency} ->
        {:cont, Keyword.put(options, :background_transparency, transparency)}

      _other ->
        {:halt, {:error, invalid_option(option)}}
    end
  end

  defp validate_option({:extend_mode, extend}, _image, _width, _height, options) do
    case Image.ExtendMode.validate_extend(extend) do
      {:ok, extend_mode} ->
        options = Keyword.put(options, :extend_mode, extend_mode)
        {:cont, options}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp validate_option({:x, :center}, image, width, height, options) do
    x = trunc((width - Image.width(image)) / 2)
    validate_option({:x, x}, image, width, height, options)
  end

  defp validate_option({:y, :center}, image, width, height, options) do
    y = trunc((height - Image.height(image)) / 2)
    validate_option({:y, y}, image, width, height, options)
  end

  defp validate_option({:x, x}, image, width, _height, options) when is_integer(x) do
    x = normalize_dim(x, width)

    if x + width >= Image.width(image) do
      options = Keyword.put(options, :x, x)
      {:cont, options}
    else
      {:halt, offset_error(:x, x)}
    end
  end

  defp validate_option({:y, y}, image, _width, height, options) when is_integer(y) do
    y = normalize_dim(y, height)

    if y + height >= Image.height(image) do
      options = Keyword.put(options, :y, y)
      {:cont, options}
    else
      {:halt, offset_error(:y, y)}
    end
  end

  defp validate_option(option, _image, _width, _height, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    %Image.Error{
      reason: :invalid_option,
      value: option,
      message: "Invalid option or option value: #{inspect(option)}"
    }
  end

  @geometric_extend_modes [:VIPS_EXTEND_COPY, :VIPS_EXTEND_REPEAT, :VIPS_EXTEND_MIRROR]

  # Resolves the interaction between :extend_mode, :background_color and
  # :background_transparency.
  #
  # * A geometric extend mode (:copy, :repeat, :mirror) is always honored
  #   as given.
  #
  # * An explicit :background_color (or extend_mode: :background) extends
  #   with that color, with the alpha band (when present) set from
  #   :background_transparency.
  #
  # * The :black and :white extend modes on an image with an alpha band
  #   are converted to a background extension so that the generated
  #   pixels carry the requested :background_transparency. The color and
  #   alpha are scaled to the image interpretation by Pixel.to_pixel/3.
  defp adjust_background(options, image, user_supplied_keys) do
    explicit_background? = :background_color in user_supplied_keys

    cond do
      options.extend_mode in @geometric_extend_modes ->
        {:ok, Map.delete(options, :background_transparency)}

      explicit_background? or options.extend_mode == :VIPS_EXTEND_BACKGROUND ->
        with {:ok, background} <- background_with_alpha(options, image) do
          {:ok,
           options
           |> Map.put(:extend_mode, :VIPS_EXTEND_BACKGROUND)
           |> Map.put(:background_color, background)
           |> Map.delete(:background_transparency)}
        end

      Image.has_alpha?(image) ->
        base_color = if options.extend_mode == :VIPS_EXTEND_WHITE, do: :white, else: :black

        with {:ok, pixel} <-
               Pixel.to_pixel(image, base_color, alpha: options.background_transparency) do
          {:ok,
           options
           |> Map.put(:extend_mode, :VIPS_EXTEND_BACKGROUND)
           |> Map.put(:background_color, pixel)
           |> Map.delete(:background_transparency)}
        end

      true ->
        {:ok, Map.delete(options, :background_transparency)}
    end
  end

  defp background_with_alpha(options, image) do
    color = options.background_color
    bands = Image.bands(image)

    cond do
      not Image.has_alpha?(image) ->
        {:ok, conform_single_band(color, bands)}

      length(color) == bands ->
        with {:ok, alpha} <- background_alpha(options, image) do
          {:ok, List.replace_at(color, -1, alpha)}
        end

      length(color) == bands - 1 ->
        with {:ok, alpha} <- background_alpha(options, image) do
          {:ok, color ++ [alpha]}
        end

      true ->
        {:ok, color}
    end
  end

  # The opaque alpha value in the scale of the image interpretation,
  # adjusted by the requested :background_transparency.
  defp background_alpha(options, image) do
    with {:ok, pixel} <-
           Pixel.to_pixel(image, :black, alpha: options.background_transparency) do
      {:ok, List.last(pixel)}
    end
  end

  defp conform_single_band(color, 1) when length(color) > 1, do: [hd(color)]
  defp conform_single_band(color, _bands), do: color

  @doc false
  def normalize_dim(a, _max) when a >= 0, do: a
  def normalize_dim(a, max) when a < 0, do: max + a

  defp default_options do
    [
      x: :center,
      y: :center,
      extend_mode: :black,
      background_color: :black,
      background_transparency: :opaque
    ]
  end

  defp offset_error(_dim, value) when value < 0 do
    {:error,
     %Image.Error{
       message: "The canvas image must be larger than the image being embedded in it",
       reason: "The canvas image must be larger than the image being embedded in it"
     }}
  end

  defp offset_error(dim, value) do
    {:error,
     "#{inspect(dim)} offset #{inspect(value)} cannot fit the image inside the embedded image"}
  end
end
