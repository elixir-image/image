defmodule Image.Options.Shape do
  @moduledoc false

  import Image.Options.Text

  def default_polygon_options do
    [
      opacity: 0.7,
      fill_color: "none",
      stroke_color: "white",
      stroke_width: 1
    ]
  end

  def validate_polygon_options(options) do
    validate_options(options, default_polygon_options())
  end

  @doc """
  Validate the options for `Image.Shape functions`.

  """
  def validate_options(options, default_options) do
    options = Keyword.merge(default_options, options)

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
        |> wrap(:ok)

      other ->
        other
    end
  end

  defp validate_option({:height, height}, options) when is_integer(height) and height > 0 do
    {:cont, options}
  end

  defp validate_option({:width, width}, options) when is_integer(width) and width > 0 do
    {:cont, options}
  end

  defp validate_option({:fill_color = option, color}, options) do
    validate_color(option, color, options)
  end

  defp validate_option({:stroke_color = option, color}, options) do
    validate_color(option, color, options)
  end

  defp validate_option({:stroke_width = option, width}, options) do
    validate_stroke_width(option, width, options)
  end

  defp validate_option({:opacity = option, opacity}, options) do
    validate_opacity(option, opacity, options)
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end
end
