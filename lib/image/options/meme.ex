defmodule Image.Options.Meme do
  @moduledoc """
  Options and option validation for `Image.meme/2`.

  """

  alias Image.Pixel

  # The font Image.meme/3 uses by default, and the file it is loaded from.
  # Anton is a libre display face in the style of Impact, distributed
  # under the SIL Open Font License 1.1 (see LICENSE.md).
  @bundled_font "Anton"
  @bundled_font_file "priv/fonts/Anton-Regular.ttf"

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
            | {:color, Pixel.t()}
            | {:outline_color, Pixel.t()}
            | {:justify, boolean()}
            | {:transform, text_transform()}
          ]

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
            options[:font] == @bundled_font && options[:fontfile] == :default ->
              Keyword.put(options, :fontfile, bundled_font_file())

            options[:fontfile] == :default ->
              Keyword.delete(options, :fontfile)

            true ->
              options
          end

        {:ok, Map.new(options)}
    end
  end

  defp validate_option({:font, font}, options) when is_binary(font) do
    {:cont, options}
  end

  defp validate_option({:font_file, font_file}, options) when is_binary(font_file) do
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
    case Pixel.to_srgb(color) do
      {:ok, pixel} -> {:cont, Keyword.put(options, key, Enum.take(pixel, 3))}
      _other -> {:halt, {:error, invalid_option(option)}}
    end
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    %Image.Error{
      reason: :invalid_option,
      value: option,
      message: "Invalid option or option value: #{inspect(option)}"
    }
  end

  def no_such_font_file(file) do
    message = "Font file #{inspect(file)} could not be found"
    %Image.Error{message: message, reason: message, path: file}
  end

  defp default_options(image) do
    height = Image.height(image)

    [
      text: "",
      font: @bundled_font,
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

  defp bundled_font_file do
    Application.app_dir(:image, @bundled_font_file)
  end
end
