defmodule Image.Shape do
  @moduledoc """
  Functions to render a shape as an image. The supported shapes match
  those defined in [Scalable Vector Graphics](https://developer.mozilla.org/en-US/docs/Web/SVG)
  including:

  * Polygon
  * Circle
  * Ellipse
  * Line

  """

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Operation

  @typedoc """
  A point is a list of two integers
  representing the `x` and `y` coordinates

  """
  @type point :: [integer()]

  @typedoc """
  A path is a list of points representing
  a path, open polygon or closed polygon.

  """
  @type path :: String.t() | [point(), ...]

  @default_width 500
  @default_radius 100
  @default_rotation 180

  @default_star_points 5
  @default_star_inner_radius 60
  @default_star_outer_radius 150
  @default_star_rotation 0

  @doc """
  Creates an image of a polygon as a single
  band image on a transparent background.

  ### Arguments

  * `points` defines the points of the polygon. The
    origin is the top left of the image with a positive
    `x` value moving from right to left and a positive
    `y` value moving from top to bottom.  The points can
    be an [SVG point string](https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/points)
    or a "list of lists" of the form
    `[[x1, y1], [x2, y2], ...]` where `x1` and `y1`
    are integers.  `points` can also be a positive
    integer >= 3 which indicates that an `n` sided
    polygon will be generated. In this case the options
    `:rotation` and `:radius` are also applicable.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:width` is the width of the canvas onto which the
    pologon is drawn. The default is `500` pixels.

  * `:height` is the width of the canvas onto which the
    pologon is drawn. The default is `500` pixels.

  * `:fill_color` is the color used to fill in the
    polygon. The default is `:none`.

  * `:stroke_color` is the color used for the outline
    of the polygon. The default is `:black`

  * `:opacity` is the opacity as a float between
    `0.0` and `1.0` where `0.0` is completely transparent
    and `1.0` is completely opaque. The default is `0.7`.

  * `:rotation` is the number of degrees to rotate the
    axis of a generated n-sided polygon. This option is
    only valid if `points` is an integer >= 3.
    The default is `#{@default_rotation}`.

  * `:radius` indicates the radius in pixels of a generated
    n-sided polygon. The default is `#{@default_radius}`.

  ### Notes

  * The polygon points are scaled to fit the canvas size
    defined by `:width` and `:height` This means that the
    resulting image will fill the canvas. This is useful
    for composing images. Define the canvas to be the size
    intended to be composed into a base image and the
    polygon will be scaled to fit.

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexidecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuschia".

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`

  ### Examples

  """
  @spec polygon(points::path(), options::Keyword.t()) ::
    {:ok, Vimage.t()} | {:error, Image.error_message()}

  def polygon(points, options \\ [])

  def polygon(points, options) when is_binary(points) do
    points
    |> points_to_path()
    |> polygon(options)
  end

  def polygon(points, options) when is_list(points) and is_list(options) do
    with {:ok, options} <- Image.Options.Shape.validate_polygon_options(options) do
      polygon(points, options)
    end
  end

  def polygon(points, %{} = options) when is_list(points) do
    {width, height} = dimensions_from(points, options[:width], options[:height])

    points =
      points
      |> rescale(0, width, 0, height)
      |> format_points()

    svg = """
    <svg width="#{width}px" height="#{height}px">
      <style type="text/css">
        svg polygon {
          fill: #{options.fill_color};
          stroke: #{options.stroke_color};
          stroke-width: #{options.stroke_width};
          opacity: #{options.opacity};
        }
      </style>
      <polygon points="#{points}" />
    </svg>
    """

    case Operation.svgload_buffer(svg) do
      {:ok, {polygon, _flags}} -> {:ok, polygon}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec polygon(sides::pos_integer(), options::Keyword.t()) ::
    {:ok, Vimage.t()} | {:error, Image.error_message()}

  def polygon(sides, options) when is_integer(sides) and sides > 2 do
    {radius, options} = Keyword.pop(options, :radius, @default_radius)
    {rotation, options} = Keyword.pop(options, :rotation, @default_rotation)

    segment = :math.pi * 2 / sides
    rotation = rotation * :math.pi / 180

    for side <- 1..sides do
      [
        :math.sin(segment * side + rotation) * radius,
        :math.cos(segment * side + rotation) * radius
      ]
    end
    |> polygon(options)
  end

  defp dimensions_from(points, nil, nil) do
    aspect_ratio = aspect_ratio(points)
    {@default_width, round(@default_width / aspect_ratio)}
  end

  defp dimensions_from(_points, width, height) when is_integer(width) and is_integer(height) do
    {width, height}
  end

  defp dimensions_from(points, width, nil) when is_integer(width) do
    aspect_ratio = aspect_ratio(points)
    {width, round(width / aspect_ratio)}
  end

  defp dimensions_from(points, nil, height) when is_integer(height) do
    aspect_ratio = aspect_ratio(points)
    {round(height * aspect_ratio), height}
  end

  @doc """
  Creates an image of a polygon as a single
  band image on a transparent background.

  ### Arguments

  * `points` defines the points of the polygon. The
    origin is the top left of the image with a positive
    `x` value moving from right to left and a positive
    `y` value moving from top to bottom.  The points can
    be an [SVG point string](https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/points)
    or a "list of lists" of the form
    `[[x1, y1], [x2, y2], ...]` where `x1` and `y1`
    are integers.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:width` is the width of the canvas onto which the
    pologon is drawn. The default is `500` pixels.

  * `:height` is the width of the canvas onto which the
    pologon is drawn. The default is `500` pixels.

  * `:fill_color` is the color used to fill in the
    polygon. The default is `:none`.

  * `:stroke_color` is the color used for the outline
    of the polygon. The default is `:black`

  * `:opacity` is the opacity as a float between
    `0.0` and `1.0` where `0.0` is completely transparent
    and `1.0` is completely opaque. The default is `0.7`.

  ### Notes

  * The polygon points are scaled to fit the canvas size
    defined by `:width` and `:height` This means that the
    resulting image will fill the canvas. This is useful
    for composing images. Define the canvas to be the size
    intended to be composed into a base image and the
    polygon will be scaled to fit.

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexidecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuschia".

  ### Returns

  * `image` or

  * raises an exception

  ### Examples

  """
  @spec polygon!(points::path(), options::Keyword.t()) ::
    Vimage.t() | no_return()

  def polygon!(points, options \\ []) do
    case polygon(points, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Returns an image of a 5-pointed star that
  can be composed over other images.

  ### Arguments

  * `points` is an integer number of points
    on the star. `points` must be >= 3.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * See `Image.Shape.polygon/2` for the applicable
    options

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`

  ### Examples

  """
  @spec star(points :: pos_integer(), options::Keyword.t()) ::
    {:ok, Vimage.t()} | {:error, Image.error_message()}

  def star(points \\ @default_star_points, options \\ []) when points > 3 do
    {inner_radius, options} = Keyword.pop(options, :inner_radius, @default_star_inner_radius)
    {outer_radius, options} = Keyword.pop(options, :outer_radius, @default_star_outer_radius)
    {rotation, options} = Keyword.pop(options, :rotation, @default_star_rotation)

    rotation = (rotation * :math.pi / 180)

    Enum.reduce(1..points, [], fn point, polygon ->
      inner_angle = 2 * :math.pi * point / points
      outer_angle = inner_angle + :math.pi / points

      inner_angle = inner_angle + rotation
      outer_angle = outer_angle + rotation

      inner = [
        inner_radius * :math.cos(inner_angle),
        inner_radius * :math.sin(inner_angle)
      ]


      outer = [
        outer_radius * :math.cos(outer_angle),
        outer_radius * :math.sin(outer_angle)
      ]

      [outer, inner | polygon]
    end)
    |> polygon(options)
  end

  @doc """
  Returns an image of a 5-pointed star that
  can be composed over other images.

  ### Arguments

  * `points` is an integer number of points
    on the star. `points` must be >= 3.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * See `Image.Shape.polygon/2` for the applicable
    options

  ### Returns

  * `image` or

  * raises an exception

  ### Examples

  """
  @spec star!(points :: pos_integer(), options::Keyword.t()) :: Vimage.t() | no_return()
  def star!(points \\ @default_star_points, options \\ []) do
    case star(points, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  ### Helpers

  defp format_points(points) do
    points
    |> List.flatten()
    |> Enum.join(" ")
  end

  @doc false
  def rescale(unscaled, from_min, from_max, to_min, to_max) when is_number(unscaled) do
    round((to_max - to_min) * (unscaled - from_min) / (from_max - from_min) + to_min)
  end

  @doc false
  def rescale(polygon, x_min, x_max, y_min, y_max, scale \\ nil) when is_list(polygon) do
    {from_x_min, from_x_max, from_y_min, from_y_max} = scale || polygon_scale(polygon)

    for [x, y] <- polygon do
      [
        rescale(x, from_x_min, from_x_max, x_min, x_max),
        rescale(y, from_y_min, from_y_max, y_min, y_max),
      ]
    end
  end

  @doc false
  def rescale(polygon, %Vimage{} = image) when is_list(polygon) do
    {from_x_min, from_x_max, from_y_min, from_y_max} = polygon_scale(polygon)
    aspect_ratio = (from_x_max - from_x_min) / (from_y_max - from_y_min)

    width = Image.width(image)
    height = round(width * aspect_ratio)
    min = 0

    rescale(polygon, min, width, min, height, {from_x_min, from_x_max, from_y_min, from_y_max})
  end

  def aspect_ratio(%Vimage{} = image) do
    Image.width(image) / Image.height(image)
  end

  def aspect_ratio(polygon) when is_list(polygon) do
    {from_x_min, from_x_max, from_y_min, from_y_max} = polygon_scale(polygon)
    (from_x_max - from_x_min) / (from_y_max - from_y_min)
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

  defp points_to_path(points) when is_binary(points) do
    points
    |> String.split([",", " ", "\n"], trim: true)
    |> Enum.map(&String.to_integer/1)
    |> Enum.chunk_every(2)
  end

end