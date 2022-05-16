defmodule Image.Shape do
  @moduledoc """
  Functions to render a shape as an image. The supported shapes match
  those defined in [Scalable Vector Graphics](https://developer.mozilla.org/en-US/docs/Web/SVG)
  including:

  * Circle
  * Ellipse
  * Line
  * Polygon

  """

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Operation

  def polygon(points, options \\ [])

  def polygon(points, options) when is_binary(points) do
    points
    |> String.split([",", " "])
    |> Enum.map(&String.to_integer/1)
    |> Enum.chunk_every(2)
    |> polygon(options)
  end

  def polygon(points, options) when is_list(points) do
    width = Keyword.get(options, :width, 500)
    height = Keyword.get(options, :height, 500)
    fill_color = Keyword.get(options, :fill_color, "black")
    opacity = Keyword.get(options, :opacity, 0.7)
    stroke_color = Keyword.get(options, :stroke_color, "green")

    points =
      points
      |> rescale(0, width, 0, height)
      |> format_points()

    svg = """
    <svg width="#{width}px" height="#{height}px">
      <style type="text/css">
        svg polygon {
          fill: #{fill_color};
          stroke: #{stroke_color};
          opacity: #{opacity};
        }
      </style>
      <polygon points="#{points}" />
    </svg>
    """

    Operation.svgload_buffer(svg)
  end

  @star_polygon "50,0 21,90 98,35 2,35 79,90"

  def star(options \\ []) do
    polygon(@star_polygon, options)
  end

  defp format_points(points) do
    points
    |> List.flatten()
    |> Enum.join(" ")
  end

  def rescale(unscaled, from_min, from_max, to_min, to_max) when is_number(unscaled) do
    round((to_max - to_min) * (unscaled - from_min) / (from_max - from_min) + to_min)
  end

  def rescale(polygon, x_min, x_max, y_min, y_max, scale \\ nil) when is_list(polygon) do
    {from_x_min, from_x_max, from_y_min, from_y_max} = scale || polygon_scale(polygon)

    for [x, y] <- polygon do
      [
        rescale(x, from_x_min, from_x_max, x_min, x_max),
        rescale(y, from_y_min, from_y_max, y_min, y_max),
      ]
    end
  end

  def rescale(polygon, %Vimage{} = image) when is_list(polygon) do
    {from_x_min, from_x_max, from_y_min, from_y_max} = polygon_scale(polygon)
    aspect_ratio = (from_x_max - from_x_min) / (from_y_max - from_y_min)

    width = Image.width(image)
    height = round(width * aspect_ratio)
    min = 0

    rescale(polygon, min, width, min, height, {from_x_min, from_x_max, from_y_min, from_y_max})
  end

  defp polygon_scale(polygon) do
    Enum.reduce polygon, {10_000_000, -10_000_000, 10_000_000, -10_000_000}, fn
      [x, y], {x_min, x_max, y_min, y_max} ->
        x_min = min(x, x_min)
        x_max = max(x, x_max)
        y_min = min(y, y_min)
        y_max = max(y, y_max)
        {x_min, x_max, y_min, y_max}
    end
  end

end