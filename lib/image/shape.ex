defmodule Image.Shape do
  @moduledoc """
  Functions to render a shape as an image.

  The supported shapes match those defined in
  [Scalable Vector Graphics](https://developer.mozilla.org/en-US/docs/Web/SVG)
  including:

  * Rectangle
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
  Creates a image of a rectangle.

  * `width` is the number of pixels wide.

  * `height` is the number of pixels high.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:fill_color` is the color used to fill in the
    rectangle. The default is `:none`.

  * `:stroke_width` is the width of the line used
    to draw the rectangle. The default is `1px`.

  * `:stroke_color` is the color used for the outline
    of the rectangle. The default is `:black`.

  * `:opacity` is the opacity as a float between
    `0.0` and `1.0` where `0.0` is completely transparent
    and `1.0` is completely opaque. The default is `0.7`.

  * `:rotation` is the number of degrees to rotate the
    axis of a generated rectangle.

  ### Returns

  * `{:ok, rectangle_image}` or

  * `{:error, reason}`

  ### Example

        iex> {:ok, rectangle} = Image.Shape.rect(50, 100, fill_color: :red, stroke_color: :yellow)

  """
  @doc since: "1.27.0"

  @spec rect(width :: pos_integer(), height :: pos_integer(), options :: Keyword.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def rect(width, height, options \\ []) do
    with {:ok, options} <- Image.Options.Shape.validate_polygon_options(options) do
      svg = """
      <svg viewBox="0 0 #{width} #{height}">
        <style type="text/css">
          svg rect {
            fill: #{options.fill_color};
            stroke: #{options.stroke_color};
            stroke-width: #{options.stroke_width};
            opacity: #{options.opacity};
          }
        </style>
        <rect width="#{width}" height="#{height}" />
      </svg>
      """

      case Operation.svgload_buffer(svg) do
        {:ok, {polygon, _flags}} -> {:ok, polygon}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Creates a image of a rectangle or raises
  and exception.

  * `width` is the number of pixels wide.

  * `height` is the number of pixels high.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:fill_color` is the color used to fill in the
    rectangle. The default is `:none`.

  * `:stroke_width` is the width of the line used
    to draw the rectangle. The default is `1px`.

  * `:stroke_color` is the color used for the outline
    of the rectangle. The default is `:black`.

  * `:opacity` is the opacity as a float between
    `0.0` and `1.0` where `0.0` is completely transparent
    and `1.0` is completely opaque. The default is `0.7`.

  * `:rotation` is the number of degrees to rotate the
    axis of a generated rectangle.

  ### Returns

  * `rectangle_image` or

  * raises an exception.

  ### Examples

        iex> rectangle = Image.Shape.rect!(50, 100, fill_color: :red, stroke_color: :yellow)

  """
  @doc since: "1.27.0"

  @spec rect!(width :: pos_integer(), height :: pos_integer(), options :: Keyword.t()) ::
          Vimage.t() | no_return()

  def rect!(width, height, options \\ []) do
    case rect(width, height, options) do
      {:ok, rectangle} -> rectangle
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Creates an image of a polygon.

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
    polygon is drawn. The default is `500` pixels.

  * `:height` is the height of the canvas onto which the
    polygon is drawn. The default is `500` pixels.

  * `:fill_color` is the color used to fill in the
    polygon. The default is `:none`.

  * `:stroke_width` is the width of the line used
    to draw the polygon. The default is `1px`.

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
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`

  ### Examples

  """
  @spec polygon(points :: path(), options :: Keyword.t()) ::
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
    <svg width="#{width}" height="#{height}">
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

  @spec polygon(sides :: pos_integer(), options :: Keyword.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def polygon(sides, options) when is_integer(sides) and sides > 2 do
    {radius, options} = Keyword.pop(options, :radius, @default_radius)
    {rotation, options} = Keyword.pop(options, :rotation, @default_rotation)

    segment = :math.pi() * 2 / sides
    rotation = rotation * :math.pi() / 180

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
    polygon is drawn. The default is `500` pixels.

  * `:height` is the width of the canvas onto which the
    polygon is drawn. The default is `500` pixels.

  * `:fill_color` is the color used to fill in the
    polygon. The default is `:none`.

  * `:stroke_width` is the width of the line used
    to draw the polygon. The default is `1px`.

  * `:stroke_color` is the color used for the outline
    of the polygon. The default is `:black`.

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
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  ### Returns

  * `image` or

  * raises an exception

  ### Examples

  """
  @spec polygon!(points :: path(), options :: Keyword.t()) ::
          Vimage.t() | no_return()

  def polygon!(points, options \\ []) do
    case polygon(points, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Returns an image of an n-pointed star that
  can be composed over other images.

  ### Arguments

  * `points` is an integer number of points
    on the star. `points` must be >= 3. The default
    is `#{@default_star_points}`.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:inner_radius` is the size of the inner
    radius. The default is `#{@default_star_inner_radius}`.

  * `:outer_radius` is the size of the outer
    radius. The default is `#{@default_star_outer_radius}`.

  * `:rotation` is the angle in degrees of rotation
    applied to the points. The default is `#{@default_star_rotation}`.

  * Any remaining options are passed to `Image.Shape.polygon/2`.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`

  ### Examples

      iex> {:ok, star} = Image.Shape.star
      iex> {:ok, star} = Image.Shape.star(5, rotation: 90, fill_color: :red, stroke_color: :green)

  """
  @spec star(points :: pos_integer(), options :: Keyword.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def star(points \\ @default_star_points, options \\ []) when points > 3 do
    {inner_radius, options} = Keyword.pop(options, :inner_radius, @default_star_inner_radius)
    {outer_radius, options} = Keyword.pop(options, :outer_radius, @default_star_outer_radius)
    {rotation, options} = Keyword.pop(options, :rotation, @default_star_rotation)

    rotation = rotation * :math.pi() / 180

    Enum.reduce(1..points, [], fn point, polygon ->
      inner_angle = 2 * :math.pi() * point / points
      outer_angle = inner_angle + :math.pi() / points

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
  Returns an image of an n-pointed star that
  can be composed over other images.

  ### Arguments

  * `points` is an integer number of points
    on the star. `points` must be >= 3. The default
    is `#{@default_star_points}`.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:inner_radius` is the size of the inner
    radius. The default is `#{@default_star_inner_radius}`.

  * `:outer_radius` is the size of the outer
    radius. The default is `#{@default_star_outer_radius}`.

  * `:rotation` is the angle in degrees of rotation
    applied to the points. The default is `#{@default_star_rotation}`.

  * Any remaining options are passed to `Image.Shape.polygon/2`.

  ### Returns

  * `image` or

  * raises an exception.

  ### Examples

      iex> star = Image.Shape.star!
      iex> star = Image.Shape.star!(5, rotation: 90, fill_color: :red, stroke_color: :green)

  """
  @spec star!(points :: pos_integer(), options :: Keyword.t()) :: Vimage.t() | no_return()
  def star!(points \\ @default_star_points, options \\ []) do
    case star(points, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Creates an image of a circle.

  * `radius` is the radius of the circle in pixels.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:fill_color` is the color used to fill in the
    circle. The default is `:none`.

  * `:stroke_width` is the width of the line used
    to draw the circle. The default is `1px`.

  * `:stroke_color` is the color used for the outline
    of the circle. The default is `:black`.

  * `:opacity` is the opacity as a float between
    `0.0` and `1.0` where `0.0` is completely transparent
    and `1.0` is completely opaque. The default is `0.7`.

  ### Returns

  * `{:ok, circle_image}` or

  * `{:error, reason}`

  ### Example

        iex> {:ok, circle} = Image.Shape.circle(50, fill_color: :green, stroke_color: :blue)

  """
  @doc since: "1.38.0"

  @spec circle(radius :: pos_integer(), options :: Keyword.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def circle(radius, options \\ []) when is_integer(radius) and radius > 0 do
    with {:ok, options} <- Image.Options.Shape.validate_polygon_options(options) do
      diameter = 2 * radius
      cx = cy = radius

      svg = """
      <svg viewBox="0 0 #{diameter} #{diameter}">
        <style type="text/css">
          svg circle {
            fill: #{options.fill_color};
            stroke: #{options.stroke_color};
            stroke-width: #{options.stroke_width};
            opacity: #{options.opacity};
          }
        </style>
        <circle cx="#{cx}" cy="#{cy}" r="#{radius}" />
      </svg>
      """

      case Operation.svgload_buffer(svg) do
        {:ok, {circle, _flags}} -> {:ok, circle}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Creates an image of a circle or raises an exception.

  * `radius` is the radius of the circle in pixels.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:fill_color` is the color used to fill in the
    circle. The default is `:none`.

  * `:stroke_width` is the width of the line used
    to draw the circle. The default is `1px`.

  * `:stroke_color` is the color used for the outline
    of the circle. The default is `:black`.

  * `:opacity` is the opacity as a float between
    `0.0` and `1.0` where `0.0` is completely transparent
    and `1.0` is completely opaque. The default is `0.7`.

  ### Returns

  * `circle_image` or

  * raises an exception.

  ### Example

        iex> circle = Image.Shape.circle!(50, fill_color: :green, stroke_color: :blue)

  """
  @doc since: "1.38.0"

  @spec circle!(radius :: pos_integer(), options :: Keyword.t()) ::
          Vimage.t() | no_return()

  def circle!(radius, options \\ []) when is_integer(radius) and radius > 0 do
    case circle(radius, options) do
      {:ok, circle} -> circle
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Creates an image of a ellipse.

  * `x_radius` is the radius of the x-aixs of the
    ellipse in pixels.

  * `y_radius` is the radius of the y-aixs of the
    ellipse in pixels.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:fill_color` is the color used to fill in the
    ellipse. The default is `:none`.

  * `:stroke_width` is the width of the line used
    to draw the ellipse. The default is `1px`.

  * `:stroke_color` is the color used for the outline
    of the ellipse. The default is `:black`.

  * `:opacity` is the opacity as a float between
    `0.0` and `1.0` where `0.0` is completely transparent
    and `1.0` is completely opaque. The default is `0.7`.

  ### Returns

  * `{:ok, ellipse_image}` or

  * `{:error, reason}`

  ### Examples

        iex> {:ok, ellipse} = Image.Shape.ellipse(50, 100, fill_color: :green, stroke_color: :none)

  """
  @doc since: "1.38.0"

  @spec ellipse(x_radius :: pos_integer(), y_radius :: pos_integer(), options :: Keyword.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def ellipse(x_radius, y_radius, options \\ [])
      when is_integer(x_radius) and x_radius > 0 and is_integer(y_radius) and y_radius > 0 do
    with {:ok, options} <- Image.Options.Shape.validate_polygon_options(options) do
      x_diameter = 2 * x_radius
      y_diameter = 2 * y_radius

      svg = """
      <svg viewBox="0 0 #{x_diameter} #{y_diameter}">
        <style type="text/css">
          svg ellipse {
            fill: #{options.fill_color};
            stroke: #{options.stroke_color};
            stroke-width: #{options.stroke_width};
            opacity: #{options.opacity};
          }
        </style>
        <ellipse cx="#{x_radius}" cy="#{y_radius}" rx="#{x_radius}" ry="#{y_radius}" />
      </svg>
      """

      case Operation.svgload_buffer(svg) do
        {:ok, {ellipse, _flags}} -> {:ok, ellipse}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Creates an image of a ellipse or raises an exception.

  * `x_radius` is the radius of the x-aixs of the
    ellipse in pixels.

  * `y_radius` is the radius of the y-aixs of the
    ellipse in pixels.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:fill_color` is the color used to fill in the
    ellipse. The default is `:none`.

  * `:stroke_width` is the width of the line used
    to draw the rectangle. The default is `1px`.

  * `:stroke_color` is the color used for the outline
    of the polygon. The default is `:black`

  * `:opacity` is the opacity as a float between
    `0.0` and `1.0` where `0.0` is completely transparent
    and `1.0` is completely opaque. The default is `0.7`.

  ### Returns

  * `ellipse_image` or

  * raises an exception.

  ### Example

        iex> ellipse = Image.Shape.ellipse!(50, 100, fill_color: :green, stroke_color: :none)

  """
  @doc since: "1.38.0"

  @spec ellipse!(x_radius :: pos_integer(), y_radius :: pos_integer(), options :: Keyword.t()) ::
          Vimage.t() | no_return()

  def ellipse!(x_radius, y_radius, options \\ []) do
    case ellipse(x_radius, y_radius, options) do
      {:ok, ellipse} -> ellipse
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Creates an image of a line.

  * `x1` Defines the x-axis coordinate of the line
    starting point in pixels.

  * `y1` Defines the y-axis coordinate of the line
    starting point in pixels.

  * `x2` Defines the x-axis coordinate of the line
    ending point in pixels.

  * `y2` Defines the y-axis coordinate of the line
    ending point in pixels.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:fill_color` is the color used to fill in the
    line. The default is `:none`.

  * `:stroke_width` is the width of the line used
    to draw the line. The default is `1px`.

  * `:stroke_color` is the color used for the outline
    of the line. The default is `:black`.

  * `:opacity` is the opacity as a float between
    `0.0` and `1.0` where `0.0` is completely transparent
    and `1.0` is completely opaque. The default is `0.7`.

  ### Returns

  * `{:ok, line_image}` or

  * `{:error, reason}`

  ### Examples

        iex> {:ok, line} = Image.Shape.line(5, 5, 50, 50, stroke_width: 10, stroke_color: :white)

  """
  @doc since: "1.38.0"

  @spec line(
          x1 :: pos_integer(),
          y1 :: pos_integer(),
          x2 :: pos_integer(),
          y2 :: pos_integer(),
          options :: Keyword.t()
        ) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def line(x1, y1, x2, y2, options \\ [])
      when is_integer(x1) and x1 >= 0 and is_integer(y1) and y1 >= 0 and is_integer(x2) and x2 >= 0 and
             is_integer(y2) and y2 >= 0 do
    with {:ok, options} <- Image.Options.Shape.validate_polygon_options(options) do
      width = max(x1, x2) + div(options.stroke_width, 2)
      height = max(y1, y2) + div(options.stroke_width, 2)

      svg = """
      <svg viewBox="0 0 #{width} #{height}">
        <style type="text/css">
          svg line {
            fill: #{options.fill_color};
            stroke: #{options.stroke_color};
            stroke-width: #{options.stroke_width};
            opacity: #{options.opacity};
          }
        </style>
        <line x1="#{x1}" y1="#{y1}" x2="#{y2}" y2="#{y2}" />
      </svg>
      """

      case Operation.svgload_buffer(svg) do
        {:ok, {line, _flags}} -> {:ok, line}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Creates a image of a line or raises an exception.

  * `x1` Defines the x-axis coordinate of the line
    starting point in pixels.

  * `y1` Defines the y-axis coordinate of the line
    starting point in pixels.

  * `x2` Defines the x-axis coordinate of the line
    ending point in pixels.

  * `y2` Defines the y-axis coordinate of the line
    ending point in pixels.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:stroke_width` is the width of the line used
    to draw the rectangle. The default is `1px`.

  * `:stroke_color` is the color used for the outline
    of the polygon. The default is `:black`

  * `:opacity` is the opacity as a float between
    `0.0` and `1.0` where `0.0` is completely transparent
    and `1.0` is completely opaque. The default is `0.7`.

  ### Returns

  * `line_image` or

  * raises an exception.

  ### Example

        iex> line = Image.Shape.line!(5, 5, 50, 50, stroke_width: 10, stroke_color: :white)

  """
  @doc since: "1.38.0"

  @spec line!(
          x1 :: pos_integer(),
          y1 :: pos_integer(),
          x2 :: pos_integer(),
          y2 :: pos_integer(),
          options :: Keyword.t()
        ) ::
          Vimage.t() | no_return()

  def line!(x1, y1, x2, y2, options \\ [])
      when is_integer(x1) and x1 >= 0 and is_integer(y1) and y1 >= 0 and is_integer(x2) and x2 >= 0 and
             is_integer(y2) and y2 >= 0 do
    case line(x1, y1, x2, y2, options) do
      {:ok, line} -> line
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
        rescale(y, from_y_min, from_y_max, y_min, y_max)
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

  @doc false
  def aspect_ratio(%Vimage{} = image) do
    Image.width(image) / Image.height(image)
  end

  def aspect_ratio(polygon) when is_list(polygon) do
    {from_x_min, from_x_max, from_y_min, from_y_max} = polygon_scale(polygon)
    (from_x_max - from_x_min) / (from_y_max - from_y_min)
  end

  defp polygon_scale(polygon) do
    Enum.reduce(polygon, {10_000_000, -10_000_000, 10_000_000, -10_000_000}, fn
      [x, y], {x_min, x_max, y_min, y_max} ->
        x_min = min(x, x_min)
        x_max = max(x, x_max)
        y_min = min(y, y_min)
        y_max = max(y, y_max)
        {x_min, x_max, y_min, y_max}
    end)
  end

  defp points_to_path(points) when is_binary(points) do
    points
    |> String.split([",", " ", "\n"], trim: true)
    |> Enum.map(&String.to_integer/1)
    |> Enum.chunk_every(2)
  end
end
