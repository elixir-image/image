defmodule Image.Options.Embed do
  @moduledoc """
  Options and option validation for `Image.embed/4`.

  """
  alias Image.Color

  @typedoc """
  Options applicable to `Image.embed/4`.

  """
  @type embed_option ::
          {:background_color, Color.t() | :average}
          | {:background_transparency, Color.transparency()}
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
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, image, width, height, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        options =
          options
          |> Map.new()
          |> adjust_transparency(Image.bands(image), Image.has_alpha?(image))
          |> adjust_extend_mode()

        {:ok, options}
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
        {:halt, {:error, "Could not get the image average: #{inspect(reason)}"}}
    end
  end

  defp validate_option({:background_color, color} = option, _image, _width, _height, options) do
    case Color.validate_color(color) do
      {:ok, color} ->
        {:cont, Keyword.put(options, :background_color, color)}

      _other ->
        {:halt, invalid_option(option)}
    end
  end

  defp validate_option(
         {:background_transparency, transparency} = option,
         _image,
         _width,
         _height,
         options
       ) do
    case Color.validate_transparency(transparency) do
      {:ok, transparency} ->
        {:cont, Keyword.put(options, :background_transparency, transparency)}

      _other ->
        {:halt, invalid_option(option)}
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
    "Invalid option or option value: #{inspect(option)}"
  end

  defp adjust_transparency(%{extend_mode: :VIPS_EXTEND_BLACK} = options, _bands, true = _has_alpha?) do
    options
    |> Map.put(:extend_mode, :VIPS_EXTEND_BACKGROUND)
    |> Map.put(:background_color, [0, 0, 0, options.background_transparency])
    |> Map.delete(:background_transparency)
  end

  defp adjust_transparency(%{extend_mode: :VIPS_EXTEND_WHITE} = options, _bands, true = _has_alpha?) do
    options
    |> Map.put(:extend_mode, :VIPS_EXTEND_BACKGROUND)
    |> Map.put(:background_color, [255, 255, 255, options.background_transparency])
    |> Map.delete(:background_transparency)
  end

  defp adjust_transparency(
         %{extend_mode: :VIPS_EXTEND_BACKGROUND} = options,
         bands,
         true = _has_alpha?
       ) do
    if length(options.background) == bands do
      options
    else
      options
      |> Map.put(
        :background_color,
        List.insert_at(options.background, -1, options.background_transparency)
      )
    end
    |> Map.delete(:background_transparency)
  end

  defp adjust_transparency(%{extend_mode: :VIPS_EXTEND_BACKGROUND} = options, 1, _has_alpha?) do
    background_color =
      options.background
      |> hd()
      |> List.wrap()

    options
    |> Map.put(:background_color, background_color)
    |> Map.delete(:background_transparency)
  end

  defp adjust_transparency(options, _bands, _has_alpha?) do
    options
  end

  defp adjust_extend_mode(options) do
    if options.background_color != [0, 0, 0] do
      Map.put(options, :extend_mode, :VIPS_EXTEND_BACKGROUND)
    else
      options
    end
  end

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
    {:error, "The canvas image must be larger than the image being embedded in it"}
  end

  defp offset_error(dim, value) do
    {:error,
     "#{inspect(dim)} offset #{inspect(value)} cannot fit the image inside the embedded image"}
  end
end
