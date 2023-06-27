defmodule Image.Options.WarpPerspective do
  @moduledoc """
  Options and option validation for `Image.warp_perspective/4`.

  """
  alias Vix.Vips.Image, as: Vimage
  alias Image.Color

  @typedoc """
  Options for Image.warp_perspective/4.

  """
  @type t :: [warp_perspective_option()]

  @typedoc """
  Options applicable to `Image.embed/4`.

  """
  @type warp_perspective_option :: [
          {:background, Color.t() | :average}
          | {:extend_mode, extend_mode()}
        ]

  @typedoc """
  When extending the canvas the generated
  pixels are determined by this option.

  """
  @type extend_mode :: [
          :black
          | :white
          | :copy
          | :repeat
          | :mirror
          | :background
        ]

  @doc """
  Validate the options for `Image.warp_perspective/4`.

  """
  @spec validate_options(Vimage.t(), Keyword.t()) ::
          {:ok, Keyword.t()} | {:error, Image.error_message()}
  def validate_options(image, options) when is_list(options) do
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, image, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, options}
    end
  end

  defp validate_option({:background, :average}, image, options) do
    case Image.average(image) do
      color when is_list(color) ->
        options = Keyword.put(options, :background, color)
        {:cont, options}

      {:error, reason} ->
        {:halt, {:error, "Could not get the image average: #{inspect(reason)}"}}
    end
  end

  defp validate_option({:background, color} = option, _image, options) do
    case Color.rgb_color(color) do
      {:ok, hex: _hex, rgb: color} -> {:cont, Keyword.put(options, :background, color)}
      {:ok, color} -> {:cont, Keyword.put(options, :backgrouond, color)}
      _other -> {:halt, invalid_option(option)}
    end
  end

  defp validate_option({:extend_mode, extend}, _image, options) do
    case Image.ExtendMode.validate_extend(extend) do
      {:ok, extend_mode} ->
        options = Keyword.put(options, :extend_mode, extend_mode)
        {:cont, options}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp validate_option(option, _image, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    "Invalid option or option value: #{inspect(option)}"
  end

  defp default_options do
    [
      extend_mode: :black,
      background: :black
    ]
  end
end
