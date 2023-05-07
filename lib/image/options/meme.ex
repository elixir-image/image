defmodule Image.Options.Meme do
  @moduledoc """
  Options and option validation for `Image.meme/2`.

  """

  alias Image.Color

  @typedoc "Valid font weights"
  @type font_weight :: :ultralight | :light | :normal | :bold | :ultrabold | :heavy

  @typedoc "Valid type transforms"
  @type text_transform :: :capitalize | :upcase | :downcase | :none

  @typedoc "Options applicable to Image.meme/3"
  @type meme_options ::
          [
            {:text, String.t()}
            | {:font, String.t()}
            | {:weight, font_weight()}
            | {:color, Color.t()}
            | {:outline_color, Color.t()}
            | {:justify, boolean()}
            | {:transform, text_transform()}
            | {:width, pos_integer()}
          ]
          | map()

  @doc """
  Validate the options for `Image.meme/3`.

  See `t:Image.Options.Meme.meme_options/0`.

  """
  def validate_options(image, options) when is_list(options) do
    options = Keyword.merge(default_options(image), options)

    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        options =
          cond do
            options[:font] == "Impact" && options[:fontfile] == :default ->
              Keyword.put(options, :fontfile, font_file("Impact"))

            options[:fontfile] == :default ->
              Keyword.delete(options, :fontfile)

            true ->
              options
          end

        {:ok, Map.new(options)}
    end
  end

  def validate_options(%{} = options) do
    {:ok, options}
  end

  defp validate_option({:font, font}, options) when is_binary(font) do
    {:cont, options}
  end

  defp validate_option({:font_file, font_file}, options) when is_binary(font_file) do
    font_file = font_file(font_file)

    if File.exists?(font_file) do
      options =
        options
        |> Keyword.delete(:font_file)
        |> Keyword.put(:fontfile, font_file)

      {:cont, options}
    else
      {:halt, {:error, no_such_font_file(font_file)}}
    end
  end

  defp validate_option({:font_file, :default}, options) do
    options =
      options
      |> Keyword.delete(:font_file)
      |> Keyword.put(:fontfile, :default)

    {:cont, options}
  end

  defp validate_option({:margin, margin}, options) when is_integer(margin) and margin > 0 do
    {:cont, options}
  end

  defp validate_option({:text, text}, options) when is_binary(text) do
    {:cont, options}
  end

  defp validate_option({:weight, weight}, options)
       when weight in [:ultralight, :light, :normal, :bold, :ultrabold, :heavy] do
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
      {:ok, hex: _hex, rgb: color} -> {:cont, Keyword.put(options, key, color)}
      {:ok, color} -> {:cont, Keyword.put(options, key, color)}
      _other -> {:halt, invalid_option(option)}
    end
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    "Invalid option or option value: #{inspect(option)}"
  end

  def no_such_font_file(file) do
    "Font file #{inspect(file)} could not be found"
  end

  defp default_options(image) do
    height = Image.height(image)

    [
      text: "",
      font: "Impact",
      font_file: :default,
      weight: :bold,
      color: :white,
      outline_color: :black,
      justify: false,
      transform: :upcase,
      headline_size: default_headline_size(height),
      text_size: default_text_size(height),
      margin: default_margin(image)
    ]
  end

  def default_margin(image) do
    div(Image.width(image), 20)
  end

  defp default_headline_size(height) do
    height_in_points(height) * 10
  end

  defp default_text_size(height) do
    height_in_points(height) * 6
  end

  defp height_in_points(height) do
    div(height, 72)
  end

  defp font_file("Impact") do
    Path.join(to_string(:code.priv_dir(:image)), "fonts/unicode.impact.ttf")
  end

  defp font_file(name) when is_binary(name) do
    name
  end
end
