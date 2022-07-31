defmodule Image.Options.Text do
  @moduledoc false

  alias Image.Color
  alias Vix.Vips.Image, as: Vimage

  @type t :: [
    {:font, String.t()},
    {:font_size, pos_integer()},
    {:text_fill_color, Color.t()},
    {:text_stroke_color, Color.t()},
    {:text_stroke_width, pos_integer()},
    {:font_weigtht, atom()},
    {:background_fill_color, Color.t()},
    {:background_stroke_color, Color.t()},
    {:background_stroke_width, pos_integer()},
    {:background_stroke_opacity, float()},
    {:background_fill_opacity, float()},
    {:padding, [non_neg_integer(), ...]},
    {:x, :center | :left | :right},
    {:y, :middle | :top | :bottom}
  ]

  def default_options do
    [
      font: "Helvetica",
      font_size: 50,
      text_fill_color: :white,
      text_stroke_color: :none,
      text_stroke_width: 1,
      font_weight: :normal,
      background_fill_color: :none,
      background_stroke_color: :none,
      background_stroke_width: 1,
      background_stroke_opacity: 0.7,
      background_fill_opacity: 0.7,
      padding: [0, 0],
      x: :center,
      y: :middle
    ]
  end

  @doc """
  Validate the options for `Image.Text.render/3`.

  """
  def validate_options(options) do
    options =
      Keyword.merge(default_options(), options)

    options =
      case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
        {:error, value} ->
          {:error, value}

        options ->
          {:ok, options}
      end

    case options do
      {:ok, options} ->
        options
        |> Map.new()
        |> ensure_background_color_if_transparent_text()
        |> wrap(:ok)

      other -> other
    end
  end

  defp validate_option({:x, x}, options) when is_integer(x) and x >= 0 do
    {:cont, options}
  end

  defp validate_option({:y, y}, options) when is_integer(y) and y >= 0 do
    {:cont, options}
  end

  defp validate_option({:x, x}, options) when x in [:left, :center, :right] do
    {:cont, options}
  end

  defp validate_option({:y, y}, options) when y in [:top, :middle, :bottom] do
    {:cont, options}
  end

  defp validate_option({:font, font}, options) when is_binary(font) do
    {:cont, options}
  end

  defp validate_option({:font_weight, font_weight}, options)
      when is_binary(font_weight) or is_atom(font_weight) do
    {:cont, options}
  end

  defp validate_option({:font_weight, font_weight}, options)
      when is_integer(font_weight) and font_weight in 1..1000 do
    {:cont, options}
  end

  defp validate_option({:font_size, font_size}, options)
     when is_integer(font_size) and font_size >= 0 do
    {:cont, options}
  end

  defp validate_option({:background_fill_color = option, color}, options) do
    validate_color(option, color, options)
  end

  defp validate_option({:background_stroke_color = option, color}, options) do
    validate_color(option, color, options)
  end

  defp validate_option({:text_fill_color = option, color}, options) do
    validate_color(option, color, options)
  end

  defp validate_option({:text_stroke_color = option, color}, options) do
    validate_color(option, color, options)
  end

  defp validate_option({:background_fill_opacity = option, opacity}, options) do
    validate_opacity(option, opacity, options)
  end

  defp validate_option({:background_stroke_opacity = option, opacity}, options) do
    validate_opacity(option, opacity, options)
  end

  defp validate_option({:text_stroke_width = option, width}, options) do
    validate_stroke_width(option, width, options)
  end

  defp validate_option({:background_stroke_width = option, width}, options) do
    validate_stroke_width(option, width, options)
  end

  defp validate_option({:padding, [left, right]}, options)
      when is_integer(left) and is_integer(right) and left >= 0 and right >= 0 do
    {:cont, options}
  end

  defp validate_option({:padding = option, padding}, options)
      when is_integer(padding) and padding > 0 do
    {:cont, Keyword.put(options, option, [padding, padding])}
  end

  defp validate_option({:padding = option, %Vimage{} = image}, options) do
    padding_left = div(Image.width(image), 2)
    padding_top = div(Image.height(image), 2)

    {:cont, Keyword.put(options, option, [padding_left, padding_top])}
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  @doc false
  def validate_color(option, color, options) do
    cond do
      (is_binary(color) or is_atom(color)) && Map.get(Color.color_map(), Color.normalize(color)) ->
        {:cont, options}

      match?(<<"#", _rest::bytes-6>>, color) ->
        {:cont, options}

      match?([_r, _g, _b], color) ->
        [r, g, b] = color

        hex_color =
          ["#", convert_color(r), convert_color(g), convert_color(b)]
          |> :erlang.iolist_to_binary()

        {:cont, Keyword.put(options, option, hex_color)}

      color in [:none, "none"] ->
        {:cont, Keyword.put(options, option, :transparent)}

      color in [:transparent, "transparent"] ->
        {:cont, Keyword.put(options, option, :transparent)}

      (is_binary(color) or is_atom(color)) && String.downcase(to_string(color)) in ["none", ""] ->
        {:cont, Keyword.put(options, option, :none)}

      true ->
        {:halt, {:error, invalid_option(option, color)}}
    end
  end

  @doc false
  def validate_opacity(_option, opacity, options)
      when is_float(opacity) and opacity >= 0.0 and opacity <= 1.0 do
    {:cont, options}
  end

  def validate_opacity(option, opacity, _options) do
    {:halt, {:error, invalid_option(option, opacity)}}
  end

  @doc false
  def validate_stroke_width(_option, width, options) when is_integer(width) and width > 0 do
    {:cont, options}
  end

  def validate_stroke_width(option, width, _options) do
    {:halt, {:error, invalid_option(option, width)}}
  end

  @doc false
  def invalid_option(option) do
    "Invalid option or option value: #{inspect(option)}"
  end

  @doc false
  def invalid_option(option, value) do
    "Invalid option or option value: #{option}: #{inspect value}"
  end

  defp ensure_background_color_if_transparent_text(options) do
    case options do
      %{text_fill_color: :transparent, background_color: :none} ->
        Map.put(options, :background_color, "black")

      _other ->
        options
    end
  end

  defp convert_color(c) do
    c
    |> round()
    |> Integer.to_string(16)
    |> String.pad_leading(2, "0")
  end

  @doc false
  def wrap(term, atom) do
    {atom, term}
  end
end