defmodule Image.Options.Meme do
  @moduledoc """
  Options and option validation for `Image.blur/2`.

  """

  alias Image.Color

  @typedoc """
  Options applicable to Image.blur/2

  """
  @type blur_options :: [
          {:text, String.t()} |
          {:color, Color.t()} |
          {:outline_color, Color.t()} |
          {:justify, boolean()} |
          {:transform, :capitalize | :upcase | :downcase | :none}
          ] | map()

  @default_blur_sigma 5

  @doc false
  def default_blur_sigma do
    @default_blur_sigma
  end

  @doc """
  Validate the options for `Image.blur/2`.

  See `t:Image.Options.Resize.resize_options/0`.

  """
  def validate_options(image, options) when is_list(options) do
    options = Keyword.merge(default_options(image), options)

    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, Map.new(options)}
    end
  end

  def validate_options(%{} = options) do
    {:ok, options}
  end

  defp validate_option({:text, text}, options) when is_binary(text) do
    {:cont, options}
  end

  defp validate_option({:transform, transform}, options)
      when transform in [:upcase, :downcase, :capitalize, :none] do
    {:cont, options}
  end

  defp validate_option({:justify, justify}, options) when is_boolean(justify) do
    {:cont, options}
  end

  defp validate_option({key, size}, options)
      when key in [:headline_size, :text_size] and is_integer(size) and size > 0 do
    {:cont, options}
  end

  defp validate_option({key, color} = option, options) when key in [:color, :outline_color] do
    case Color.rgb_color(color) do
      {:ok, hex: _hex, rgb: color}  -> {:cont, Keyword.put(options, key, color)}
      {:ok, color}  -> {:cont, Keyword.put(options, key, color)}
      _other -> {:halt, invalid_option(option)}
    end
  end

  defp validate_option({:font, font}, options) when is_binary(font) do
    {:cont, options}
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    "Invalid option or option value: #{inspect(option)}"
  end

  defp default_options(image) do
    width = Image.width(image)

    [
      text: "",
      font: "Impact",
      color: :white,
      outline_color: :black,
      justify: true,
      transform: :upcase,
      headline_size: div(width, 10),
      text_size: div(width, 20)
    ]
  end
end
