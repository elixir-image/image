defmodule Image.Draw do
  @moduledoc """
  Functions to draw directly on a mutable image.

  **Note** that while the functions in this module
  mutate an image, the mutations are performed on
  a copy of the image so no harm will come to other
  functions maintaining a reference to the original
  image.

  """

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.{MutableImage, MutableOperation}
  alias Image.Color
  alias Image.Options

  import Image, only: :macros

  @doc "Validates acceptable circle dimensions"
  defguard is_circle(cx, cy, radius)
           when is_integer(cx) and is_integer(cy) and cx >= 0 and cy >= 0 and is_integer(radius) and
                  radius > 0

  @doc "Validate a point location on an image"
  defguard is_point(left, top) when is_integer(left) and is_integer(top) and left >= 0 and top >= 0

  @doc """
  Draw a point on a mutable image.

  ### Arguments

  * `image` is any `t:Vimage.t/0` or a
    `t:MutableImage.t/0` upon which the rectangle
    will be drawn. If `image` is a `t:MutableImage.t/0`
    it will be mutated directly. If `image` is a
    `t:Vimage.t/0` it will be copied to a `t:MutableImage.t/0`
    and then mutated.

  * `left` is the 0-based offset from the
    left edge of the image where the point
    will be drawn.

  * `top` is the 0-based offset from the
    top edge of the image where the point
    will be drawn.

  * `options` is a keyword list of options.
    The default is `color: :black`.

  ### Options

  * `:color` defines the color of the point. This
    can be specified as a single integer which will
    be applied to all bands, or a list of
    integers representing the color for each
    band. The color can also be supplied as a CSS color
    name as a string or atom. For example: `:misty_rose`.
    Lastly, it can also be supplied as a hex string of
    the form `#rrggbb`. See `Image.Color.color_map/0` and
    `Image.Color.rgb_color/1`.

  ### Returns

  * `{:ok, image}` where `image` is the same
    type as that passed as an argument to the
    function.

  * or `{:error, reason}`

  """
  @doc since: "0.7.0"

  @spec point(
          Vimage.t() | MutableImage.t(),
          non_neg_integer(),
          non_neg_integer(),
          Options.Draw.point()
        ) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def point(image, left, top, options \\ [])

  def point(%Vimage{} = image, left, top, options)
      when is_integer(left) and is_integer(top) and left >= 0 and top >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:point, options) do
      color = maybe_add_alpha(image, options.color)

      Vimage.mutate(image, fn mut_img ->
        MutableOperation.draw_rect(mut_img, color, left, top, 1, 1)
      end)
    end
  end

  def point(%MutableImage{} = image, left, top, options) when is_point(left, top) do
    with {:ok, options} <- Options.Draw.validate_options(:point, options) do
      color = maybe_add_alpha(image, options.color)
      MutableOperation.draw_rect(image, color, left, top, 1, 1)
    end
    |> maybe_wrap()
  end

  @doc """
  Draw a point on a mutable image returning
  the mutated image or raising an exception.

  ### Arguments

  * `image` is any `t:Vimage.t/0` or a
    `t:MutableImage.t/0` upon which the rectangle
    will be drawn. If `image` is a `t:MutableImage.t/0`
    it will be mutated directly. If `image` is a
    `t:Vimage.t/0` it will be copied to a `t:MutableImage.t/0`
    and then mutated.

  * `left` is the 0-based offset from the
    left edge of the image where the point
    will be drawn.

  * `top` is the 0-based offset from the
    top edge of the image where the point
    will be drawn.

  * `options` is a keyword list of options.
    The default is `color: :black`.  See
    the options for `Image.Draw.point/4`.

  ### Returns

  * `image` where `image` is the same
    type as that passed as an argument to the
    function or

  * raises an exception.

  """

  @doc since: "0.17.0"

  @spec point!(
          Vimage.t() | MutableImage.t(),
          non_neg_integer(),
          non_neg_integer(),
          Options.Draw.point()
        ) ::
          Vimage.t() | MutableImage.t() | no_return()

  def point!(image, left, top, options) do
    case point(image, left, top, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Draw a rectangle on a mutable image.

  ### Arguments

  * `image` is any `t:Vimage.t/0` or a
    `t:MutableImage.t/0` upon which the rectangle
    will be drawn. If `image` is a `t:MutableImage.t/0`
    it will be mutated directly. If `image` is a
    `t:Vimage.t/0` it will be copied to a `t:MutableImage.t/0`
    and then mutated.

  * `left` is the 0-based offset from the
    left edge of the image where the rectangle
    will be drawn.

  * `top` is the 0-based offset from the
    top edge of the image where the rectangle
    will be drawn.

  * `width` is the width of the rectangle

  * `height` is the height of the rectangle

  * `options` is a keyword list of options.
    The default is `color: :black`.

  ### Options

  * `:color` defines the color of the point. This
    can be specified as a single integer which will
    be applied to all bands, or a list of
    integers representing the color for each
    band. The color can also be supplied as a CSS color
    name as a string or atom. For example: `:misty_rose`.
    Lastly, it can also be supplied as a hex string of
    the form `#rrggbb`. See `Image.Color.color_map/0` and
    `Image.Color.rgb_color/1`.

  * `:fill` is a boolean indicating whether the
    rectangle is to be filled with `:color`. The
    default is `true`.

  * `:stroke_width` indicates the width in pixels
    of the stroke that forms the rectangle. The
    default is `1`. Values greater than `1` will
    have a negative performance impact since the
    rectangle will be draw as 4 filled rectangles
    forming each of the four sides. If `fill: true`
    is set then this options is ignored.

  ### Returns

  * `{:ok, image}` where `image` is the same
    type as that passed as an argument to the
    function or

  * `{:error, reason}`.

  """
  @doc since: "0.7.0"

  @spec rect(
          Vimage.t() | MutableImage.t(),
          non_neg_integer(),
          non_neg_integer(),
          pos_integer(),
          pos_integer(),
          Options.Draw.rect()
        ) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def rect(image, left, top, width, height, options \\ [])

  def rect(%image_type{} = image, left, top, width, height, options)
      when is_image(image_type) and is_box(left, top, width, height) do
    with {:ok, options} <- Options.Draw.validate_options(:rect, options) do
      %{stroke_width: stroke_width, fill: fill} = options
      color = maybe_add_alpha(image, options.color)
      rect(image, left, top, width, height, color, stroke_width, fill)
    end
    |> maybe_wrap()
  end

  # If the stroke width is 1 then use the underlying Vips call.
  # If the stroke width is > 1 then form the rectangle by drawing
  # one filled rectangle for each of the four sides.

  defp rect(%Vimage{} = image, left, top, width, height, color, stroke_width, fill) do
    Image.mutate(image, fn image ->
      do_rect(image, left, top, width, height, color, stroke_width, fill)
    end)
  end

  defp rect(%MutableImage{} = image, left, top, width, height, color, stroke_width, fill) do
    :ok = do_rect(image, left, top, width, height, color, stroke_width, fill)
    {:ok, image}
  end

  # do_rect/8 operates within the mutation closure. Its results are
  # ignored, just return the expected :ok.

  defp do_rect(%MutableImage{} = image, left, top, width, height, color, stroke_width, fill)
       when fill == true or stroke_width == 1 do
    :ok = MutableOperation.draw_rect(image, color, left, top, width, height, fill: fill)
  end

  defp do_rect(%MutableImage{} = image, left, top, width, height, color, stroke_width, _fill) do
    with :ok <- do_rect(image, left, top, stroke_width, height, color, 1, true),
         :ok <- do_rect(image, left, top, width, stroke_width, color, 1, true),
         :ok <-
           do_rect(image, left + width - stroke_width, top, stroke_width, height, color, 1, true) do
      do_rect(image, left, top + height - stroke_width, width, stroke_width, color, 1, true)
    end
  end

  @doc """
  Draw a rectangle on a mutable image and
  returns the mutated image or raises an
  exception.

  ### Arguments

  * `image` is any `t:Vimage.t/0` or a
    `t:MutableImage.t/0` upon which the rectangle
    will be drawn. If `image` is a `t:MutableImage.t/0`
    it will be mutated directly. If `image` is a
    `t:Vimage.t/0` it will be copied to a `t:MutableImage.t/0`
    and then mutated.

  * `left` is the 0-based offset from the
    left edge of the image where the rectangle
    will be drawn.

  * `top` is the 0-based offset from the
    top edge of the image where the rectangle
    will be drawn.

  * `width` is the width of the rectangle

  * `height` is the height of the rectangle

  * `options` is a keyword list of options.
    The default is `color: :black`.

  ### Options

  * `:color` defines the color of the point. This
    can be specified as a single integer which will
    be applied to all bands, or a list of
    integers representing the color for each
    band. The color can also be supplied as a CSS color
    name as a string or atom. For example: `:misty_rose`.
    Lastly, it can also be supplied as a hex string of
    the form `#rrggbb`. See `Image.Color.color_map/0` and
    `Image.Color.rgb_color/1`.

  * `:fill` is a boolean indicating whether the
    rectangle is to be filled with `:color`. The
    default is `true`.

  * `:stroke_width` indicates the width in pixels
    of the stroke that forms the rectangle. The
    default is `1`. Values greater than `1` will
    have a negative performance impact since the
    rectangle will be draw as 4 filled rectangles
    forming each of the four sides. If `fill: true`
    is set then this options is ignored.

  ### Returns

  * `image` where `image` is the same
    type as that passed as an argument to the
    function or

  * raises an exception.

  """

  @doc since: "0.17.0"

  @spec rect!(
          Vimage.t() | MutableImage.t(),
          non_neg_integer(),
          non_neg_integer(),
          pos_integer(),
          pos_integer(),
          Options.Draw.rect()
        ) ::
          Vimage.t() | MutableImage.t() | no_return()

  def rect!(image, left, top, width, height, options \\ []) do
    case rect(image, left, top, width, height, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Draw a circle on a mutable image.

  ### Arguments

  * `image` is any `t:Vimage.t/0` or a
    `t:MutableImage.t/0` upon which the rectangle
    will be drawn. If `image` is a `t:MutableImage.t/0`
    it will be mutated directly. If `image` is a
    `t:Vimage.t/0` it will be copied to a `t:MutableImage.t/0`
    and then mutated.

  * `cx` is the 0-based offset from the
    left edge of the image indicating where
    the center of the circle will be localed.

  * `cy` is the 0-based offset from the
    top edge of the image indicating where
    the center of the circle will be localed.

  * `radius` is the radius of the drawn circle.

  * `options` is a keyword list of options.
    The default is `color: :black`.

  ### Options

  * `:color` defines the color of the point. This
    can be specified as a single integer which will
    be applied to all bands, or a list of
    integers representing the color for each
    band. The color can also be supplied as a CSS color
    name as a string or atom. For example: `:misty_rose`.
    Lastly, it can also be supplied as a hex string of
    the form `#rrggbb`. See `Image.Color.color_map/0` and
    `Image.Color.rgb_color/1`.

  * `:fill` is a boolean indicating whether the
    rectangle is to be filled with `:color`. The
    default is `true`.

  * `:stroke_width` indicates the width in pixels
    of the stroke that forms the rectangle. The
    default is `1`. Values greater than `1` will
    have a negative performance impact since the
    rectangle will be draw as 4 filled rectangles
    forming each of the four sides. If `fill: true`
    is set then this options is ignored.

  ### Returns

  * `{:ok, image}` where `image` is the same
    type as that passed as an argument to the
    function.

  * or `{:error, reason}`

  """
  @doc since: "0.7.0"

  @spec circle(
          Vimage.t() | MutableImage.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          Options.Draw.circle()
        ) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def circle(%image_type{} = image, cx, cy, radius, options \\ [])
      when is_image(image_type) and is_circle(cx, cy, radius) do
    with {:ok, options} <- Options.Draw.validate_options(:circle, options) do
      %{stroke_width: stroke_width, fill: fill, color: color} = options
      color = maybe_add_alpha(image, color)
      circle(image, cx, cy, radius, color, stroke_width, fill)
    end
    |> maybe_wrap()
  end

  # When drawing a circle with a stroke_wiodth of > 1 then
  # we draw two circles and flood fill between then to simulate
  # wider stroke width.

  defp circle(%Vimage{} = image, cx, cy, radius, color, stroke_width, fill) do
    Image.mutate(image, fn image ->
      do_circle(image, cx, cy, radius, color, stroke_width, fill)
    end)
  end

  defp circle(%MutableImage{} = image, cx, cy, radius, color, stroke_width, fill) do
    :ok = do_circle(image, cx, cy, radius, color, stroke_width, fill)
    {:ok, image}
  end

  defp do_circle(%MutableImage{} = image, cx, cy, radius, color, stroke_width, fill)
       when stroke_width == 1 or fill == true do
    MutableOperation.draw_circle(image, color, cx, cy, radius, fill: fill)
  end

  defp do_circle(%MutableImage{} = image, cx, cy, radius, color, 2 = stroke_width, _fill) do
    with :ok <- do_circle(image, cx, cy, radius, color, 1, false) do
      do_circle(image, cx, cy, radius - stroke_width + 1, color, 1, false)
    end
  end

  defp do_circle(%MutableImage{} = image, cx, cy, radius, color, stroke_width, _fill) do
    with :ok <- do_circle(image, cx, cy, radius, color, 1, false),
         :ok <- do_circle(image, cx, cy, radius - stroke_width, color, 1, false),
         {:ok, {_image, _meta}} <- flood(image, cx - radius + 1, cy, color, false) do
      :ok
    end
  end

  @doc """
  Draw a circle on a mutable image returning
  the mutated image or raises an exception.

  ### Arguments

  * `image` is any `t:Vimage.t/0` or a
    `t:MutableImage.t/0` upon which the rectangle
    will be drawn. If `image` is a `t:MutableImage.t/0`
    it will be mutated directly. If `image` is a
    `t:Vimage.t/0` it will be copied to a `t:MutableImage.t/0`
    and then mutated.

  * `cx` is the 0-based offset from the
    left edge of the image indicating where
    the center of the circle will be localed.

  * `cy` is the 0-based offset from the
    top edge of the image indicating where
    the center of the circle will be localed.

  * `radius` is the radius of the drawn circle.

  * `options` is a keyword list of options.
    The default is `color: :black`.

  ### Options

  * `:color` defines the color of the point. This
    can be specified as a single integer which will
    be applied to all bands, or a list of
    integers representing the color for each
    band. The color can also be supplied as a CSS color
    name as a string or atom. For example: `:misty_rose`.
    Lastly, it can also be supplied as a hex string of
    the form `#rrggbb`. See `Image.Color.color_map/0` and
    `Image.Color.rgb_color/1`.

  * `:fill` is a boolean indicating whether the
    rectangle is to be filled with `:color`. The
    default is `true`.

  ### Returns

  * `image` where `image` is the same
    type as that passed as an argument to the
    function or

  * raises an exception.

  """
  @doc since: "0.17.0"

  @spec circle!(
          Vimage.t() | MutableImage.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          Options.Draw.circle()
        ) ::
          Vimage.t() | MutableImage.t() | no_return()

  def circle!(image, cx, cy, radius, options \\ []) do
    case circle(image, cx, cy, radius, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Draw a line on a mutable image.

  ### Arguments

  * `image` is any `t:Vimage.t/0` or a
    `t:MutableImage.t/0` upon which the rectangle
    will be drawn. If `image` is a `t:MutableImage.t/0`
    it will be mutated directly. If `image` is a
    `t:Vimage.t/0` it will be copied to a `t:MutableImage.t/0`
    and then mutated.

  * `x1`, `y1` are the 0-based offsets from the `left`
    and `top` accordingly indicating the point
    at the start of the line.

  * `x2`, `y2` are the 0-based offsets from the `left`
    and `top` accordingly indicating the point
    at the end of the line.

  * `options` is a keyword list of options.
    The default is `color: :black`.

  ### Options

  * `:color` defines the color of the point. This
    can be specified as a single integer which will
    be applied to all bands, or a list of
    integers representing the color for each
    band. The color can also be supplied as a CSS color
    name as a string or atom. For example: `:misty_rose`.
    Lastly, it can also be supplied as a hex string of
    the form `#rrggbb`. See `Image.Color.color_map/0` and
    `Image.Color.rgb_color/1`.

  ### Returns

  * `{:ok, image}` where `image` is the same
    type as that passed as an argument to the
    function.

  * or `{:error, reason}`

  """
  @doc since: "0.7.0"

  @spec line(
          Vimage.t() | MutableImage.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          Options.Draw.line()
        ) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def line(image, x1, y1, x2, y2, options \\ [])

  def line(%Vimage{} = image, x1, y1, x2, y2, options)
      when is_integer(x1) and is_integer(y1) and x1 >= 0 and y1 >= 0 and
             is_integer(x2) and is_integer(y2) and x2 >= 0 and y2 >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:line, options) do
      Image.mutate(image, fn mut_img ->
        line(mut_img, x1, y1, x2, y2, options)
      end)
    end
    |> maybe_wrap()
  end

  def line(%MutableImage{} = image, x1, y1, x2, y2, options)
      when is_integer(x1) and is_integer(y1) and x1 >= 0 and y1 >= 0 and
             is_integer(x2) and is_integer(y2) and x2 >= 0 and y2 >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:line, options) do
      color = maybe_add_alpha(image, options.color)
      :ok = MutableOperation.draw_line(image, color, x1, y1, x2, y2)
      {:ok, image}
    end
    |> maybe_wrap()
  end

  @doc """
  Draw a line on a mutable image returning
  the mutated image or raising an exception.

  ### Arguments

  * `image` is any `t:Vimage.t/0` or a
    `t:MutableImage.t/0` upon which the rectangle
    will be drawn. If `image` is a `t:MutableImage.t/0`
    it will be mutated directly. If `image` is a
    `t:Vimage.t/0` it will be copied to a `t:MutableImage.t/0`
    and then mutated.

  * `x1`, `y1` are the 0-based offsets from the `left`
    and `top` accordingly indicating the point
    at the start of the line.

  * `x2`, `y2` are the 0-based offsets from the `left`
    and `top` accordingly indicating the point
    at the end of the line.

  * `options` is a keyword list of options.
    The default is `color: :black`.

  ### Options

  * `:color` defines the color of the point. This
    can be specified as a single integer which will
    be applied to all bands, or a list of
    integers representing the color for each
    band. The color can also be supplied as a CSS color
    name as a string or atom. For example: `:misty_rose`.
    Lastly, it can also be supplied as a hex string of
    the form `#rrggbb`. See `Image.Color.color_map/0` and
    `Image.Color.rgb_color/1`.

  ### Returns

  * `image` where `image` is the same
    type as that passed as an argument to the
    function or

  * raises an exception.

  """
  @doc since: "0.17.0"

  @spec line!(
          Vimage.t() | MutableImage.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          Options.Draw.line()
        ) ::
          Vimage.t() | MutableImage.t() | no_return()

  def line!(image, x1, y1, x2, y2, options \\ []) do
    case line(image, x1, y1, x2, y2, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Draw one image over the top of a mutable
  image.

  ### Arguments

  * `image` is any `t:Vimage.t/0` or a
    `t:MutableImage.t/0` upon which the rectangle
    will be drawn. If `image` is a `t:MutableImage.t/0`
    it will be mutated directly. If `image` is a
    `t:Vimage.t/0` it will be copied to a `t:MutableImage.t/0`
    and then mutated.

  * `sub_image` is any `t:Vimage.t/0` that
    is drawn on top of `image`.

  * `left` is the 0-based offset from the
    left edge of the image where the sub-image
    will be drawn.

  * `top` is the 0-based offset from the
    top edge of the image where the sub-image
    will be drawn.

  * `options` is a keyword list of options.
    The default is `color: :black`.

  ### Options

  * `:color` defines the color of the point. This
    can be specified as a single integer which will
    be applied to all bands, or a list of
    integers representing the color for each
    band. The color can also be supplied as a CSS color
    name as a string or atom. For example: `:misty_rose`.
    Lastly, it can also be supplied as a hex string of
    the form `#rrggbb`. See `Image.Color.color_map/0` and
    `Image.Color.rgb_color/1`.

  ### Returns

  * `{:ok, image}` where `image` is the same
    type as that passed as an argument to the
    function.

  * or `{:error, reason}`

  """
  @doc since: "0.7.0"

  @spec image(
          Vimage.t() | MutableImage.t(),
          Vimage.t(),
          non_neg_integer(),
          non_neg_integer(),
          Options.Draw.image()
        ) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def image(image, sub_image, top, left, options \\ [])

  def image(%Vimage{} = image, %Vimage{} = sub_image, top, left, options)
      when is_integer(top) and is_integer(left) and left >= 0 and top >= 0 do
    Image.mutate(image, fn mut_img ->
      image(mut_img, sub_image, top, left, options)
    end)
    |> maybe_wrap()
  end

  def image(%MutableImage{} = image, %Vimage{} = sub_image, top, left, options)
      when is_integer(top) and is_integer(left) and top >= 0 and left >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:image, options) do
      :ok = MutableOperation.draw_image(image, sub_image, top, left, Map.to_list(options))
      {:ok, image}
    end
    |> maybe_wrap()
  end

  @doc """
  Draw one image over the top of a mutable
  image or raises an exception.

  ### Arguments

  * `image` is any `t:Vimage.t/0` or a
    `t:MutableImage.t/0` upon which the rectangle
    will be drawn. If `image` is a `t:MutableImage.t/0`
    it will be mutated directly. If `image` is a
    `t:Vimage.t/0` it will be copied to a `t:MutableImage.t/0`
    and then mutated.

  * `sub_image` is any `t:Vimage.t/0` that
    is drawn on top of `image`.

  * `left` is the 0-based offset from the
    left edge of the image where the sub-image
    will be drawn.

  * `top` is the 0-based offset from the
    top edge of the image where the sub-image
    will be drawn.

  * `options` is a keyword list of options.
    The default is `color: :black`.

  ### Options

  * `:color` defines the color of the point. This
    can be specified as a single integer which will
    be applied to all bands, or a list of
    integers representing the color for each
    band. The color can also be supplied as a CSS color
    name as a string or atom. For example: `:misty_rose`.
    Lastly, it can also be supplied as a hex string of
    the form `#rrggbb`. See `Image.Color.color_map/0` and
    `Image.Color.rgb_color/1`.

  ### Returns

  * `image` where `image` is the same
    type as that passed as an argument to the
    function.

  * raises an exception.

  """
  @doc since: "0.25.0"

  @spec image!(
          Vimage.t() | MutableImage.t(),
          Vimage.t(),
          non_neg_integer(),
          non_neg_integer(),
          Options.Draw.image()
        ) ::
          Vimage.t() | MutableImage.t() | no_return()

  def image!(%image_type{} = image, %Vimage{} = sub_image, top, left, options \\ [])
      when is_image(image_type) do
    case image(image, sub_image, top, left, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Flood-fill image with color, starting at position
  `top`, `left`.

  The filled area is bounded by pixels that are equal to
  the `:colour`. That is, it searches for pixels enclosed
  by an edge of `:color`.

  If `:equal` is `true`, it instead searches for pixels
  which are equal to the start point and fills them with
  `:color`.

  ### Arguments

  * `image` is any `t:Vimage.t/0` or a
    `t:MutableImage.t/0` upon which the rectangle
    will be drawn. If `image` is a `t:MutableImage.t/0`
    it will be mutated directly. If `image` is a
    `t:Vimage.t/0` it will be copied to a `t:MutableImage.t/0`
    and then mutated.

  * `left` is the 0-based offset from the
    left edge of the image where the flood
    will be drawn.

  * `top` is the 0-based offset from the
    top edge of the image where the flood will
    drawn.

  * `options` is a keyword list of options.
    The default is `color: :black`.

  ### Options

  * `:color` defines the color of the point. This
    can be specified as a single integer which will
    be applied to all bands, or a list of
    integers representing the color for each
    band. The color can also be supplied as a CSS color
    name as a string or atom. For example: `:misty_rose`.
    Lastly, it can also be supplied as a hex string of
    the form `#rrggbb`. See `Image.Color.color_map/0` and
    `Image.Color.rgb_color/1`.

  ### Returns

  * `{:ok, {image, height, width, top, left}` where `image`
    is the same type as that passed as an argument to the
    function. `height` and `width` represent the dimensions
    of the flood fill in pixels. `top` and `left` are the
    0-based offsets from the top and left location respectively
    of the flood area.

  * or `{:error, reason}`.

  """
  @doc since: "0.7.0"

  @spec flood(
          Vimage.t() | MutableImage.t(),
          non_neg_integer(),
          non_neg_integer(),
          Options.Draw.flood()
        ) ::
          {:ok,
           {Vimage.t(), %{height: integer(), width: integer(), top: integer(), left: integer()}}}
          | {:error, Image.error_message()}

  def flood(%image_type{} = image, left, top, options \\ [])
      when is_image(image_type) and is_point(left, top) do
    with {:ok, options} <- Options.Draw.validate_options(:flood, options) do
      color = maybe_add_alpha(image, options.color)
      flood(image, left, top, color, options.equal)
    end
    |> maybe_wrap()
  end

  defp flood(%Vimage{} = image, left, top, color, equal) do
    Image.mutate(image, fn image ->
      flood(image, left, top, color, equal)
    end)
  end

  defp flood(%MutableImage{} = image, left, top, color, equal) do
    case MutableOperation.draw_flood(image, color, left, top, equal: equal) do
      {:ok, {%{} = box}} -> {:ok, {image, box}}
      other -> other
    end
  end

  @doc """
  Flood-fill image with color, starting at position
  `top`, `left` or raise an exception.

  The filled area is bounded by pixels that are equal to
  the `:colour`. That is, it searches for pixels enclosed
  by an edge of `:color`.

  If `:equal` is `true`, it instead searches for pixels
  which are equal to the start point and fills them with
  `:color`.

  ### Arguments

  * `image` is any `t:Vimage.t/0` or a
    `t:MutableImage.t/0` upon which the rectangle
    will be drawn. If `image` is a `t:MutableImage.t/0`
    it will be mutated directly. If `image` is a
    `t:Vimage.t/0` it will be copied to a `t:MutableImage.t/0`
    and then mutated.

  * `left` is the 0-based offset from the
    left edge of the image where the flood
    will be drawn.

  * `top` is the 0-based offset from the
    top edge of the image where the flood will
    drawn.

  * `options` is a keyword list of options.
    The default is `color: :black`.

  ### Options

  * `:color` defines the color of the point. This
    can be specified as a single integer which will
    be applied to all bands, or a list of
    integers representing the color for each
    band. The color can also be supplied as a CSS color
    name as a string or atom. For example: `:misty_rose`.
    Lastly, it can also be supplied as a hex string of
    the form `#rrggbb`. See `Image.Color.color_map/0` and
    `Image.Color.rgb_color/1`.

  ### Returns

  * `image` where `image` is the same
    type as that passed as an argument to the
    function or

  * raises an exception.

  """
  @doc since: "0.24.0"

  @spec flood!(
          Vimage.t() | MutableImage.t(),
          non_neg_integer(),
          non_neg_integer(),
          Options.Draw.flood()
        ) ::
          Vimage.t() | no_return()

  def flood!(%Vimage{} = image, left, top, options \\ []) do
    case flood(image, left, top, options) do
      {:ok, {image, _location}} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Draw mask on the image.

  Mask is a monochrome 8-bit image with the values of `0` or `255` for transparent
  and any other value as a color to be blended into the base image.

  """
  @doc since: "0.7.0"

  @spec mask(
          Vimage.t() | MutableImage.t(),
          Vimage.t(),
          non_neg_integer(),
          non_neg_integer(),
          Options.Draw.mask()
        ) ::
          {:ok,
           {Vimage.t(), [height: integer(), width: integer(), top: integer(), left: integer()]}}
          | {:error, Image.error_message()}

  def mask(image, mask, x, y, options \\ [])

  def mask(%Vimage{} = image, %Vimage{} = mask, x, y, options)
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:mask, options) do
      color = maybe_add_alpha(image, options.color)

      Image.mutate(image, fn mut_img ->
        MutableOperation.draw_mask(mut_img, color, mask, x, y)
      end)
    end
    |> maybe_wrap()
  end

  def mask(%MutableImage{} = image, %Vimage{} = mask, x, y, options)
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:mask, options) do
      color = maybe_add_alpha(image, options.color)
      :ok = MutableOperation.draw_mask(image, color, mask, x, y)
      {:ok, image}
    end
    |> maybe_wrap()
  end

  @doc """
  Smudge a section of image .

  Each pixel in the area left , top , width , height is
  replaced by the average of the surrounding 3x3 pixels.

  """
  @doc since: "0.7.0"

  @spec smudge(
          Vimage.t() | MutableImage.t(),
          non_neg_integer(),
          non_neg_integer(),
          pos_integer(),
          pos_integer(),
          Options.Draw.smudge()
        ) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def smudge(image, left, top, width, height, options \\ [])

  def smudge(%Vimage{} = image, left, top, width, height, options)
      when is_integer(left) and is_integer(top) and left >= 0 and top >= 0
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    with {:ok, _options} <- Options.Draw.validate_options(:smudge, options) do
      Image.mutate(image, fn mut_img ->
        MutableOperation.draw_smudge(mut_img, left, top, width, height)
      end)
    end
    |> maybe_wrap()
  end

  def smudge(%MutableImage{} = image, left, top, width, height, options)
      when is_integer(left) and is_integer(top) and left >= 0 and top >= 0
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    with {:ok, _options} <- Options.Draw.validate_options(:smudge, options) do
      :ok = MutableOperation.draw_smudge(image, left, top, width, height)
      {:ok, image}
    end
    |> maybe_wrap()
  end

  ## Helpers

  @spec maybe_add_alpha(Vimage.t() | MutableImage.t(), Color.t()) :: Color.t()

  @doc false
  def maybe_add_alpha(image, color) when length(color) == 3 do
    if has_alpha?(image) do
      List.insert_at(color, -1, Color.max_opacity())
    else
      color
    end
  end

  def maybe_add_alpha(image, color) when length(color) == 4 do
    if has_alpha?(image) do
      color
    else
      List.delete_at(color, -1)
    end
  end

  defp has_alpha?(%MutableImage{} = image) do
    case MutableImage.has_alpha?(image) do
      {:ok, true} -> true
      {:ok, false} -> false
    end
  end

  defp has_alpha?(%Vimage{} = image) do
    Vimage.has_alpha?(image)
  end

  defp maybe_wrap({:ok, result}) do
    {:ok, result}
  end

  defp maybe_wrap(error) do
    error
  end
end
