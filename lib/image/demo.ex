defmodule Image.Demo do
  alias Image.{Text, Shape}
  alias Vix.Vips.Image, as: Vimage

  @points [[0, 0], [0, 100], [70, 100], [90, 0]]
  @polygon_color  [116, 214, 245]

  def demo1 do
    {:ok, base_image} = Image.open("test/support/images/Singapore-2016-09-5887.jpg")
    {:ok, polygon} = Shape.polygon(@points, fill_color:  @polygon_color, stroke_color: "none", height: Image.height(base_image), opacity: 0.8)
    {:ok, explore_new} = Text.new_from_string("EXPLORE NEW", font_size: 95, font: "DIN Alternate")
    {:ok, places} = Text.new_from_string("PLACES", font_size: 95, font: "DIN Alternate")
    {:ok, blowout} = Text.new_from_string("BLOWOUT SINGAPORE SALE", font_size: 40, font: "DIN Alternate")
    {:ok, start_saving} = Text.new_from_string("START SAVING", font_size: 30, padding: 20, background_fill_color: "none", background_stroke_color: "white", background_stroke_width: 5)

    base_image
    |> Image.compose!(polygon, x: :middle, y: :top)
    |> Image.compose!(explore_new, x: 260, y: 200)
    |> Image.compose!(places, x: 260, y: 260)
    |> Image.compose!(blowout, x: 260, y: 340)
    |> Image.compose!(start_saving, x: 260, y: 400)
    |> Image.write!("/Users/kip/Desktop/polygon.png")
  end

  def demo2 do
    {:ok, base_image} = Image.open("test/support/images/Singapore-2016-09-5887.jpg")
    {:ok, singapore} = Text.new_from_string("SINGAPORE", font_size: 250, font: "DIN Alternate", padding: base_image, text_fill_color: :transparent, background_fill_color: "black", background_fill_opacity: 0.6)

    base_image
    |> Image.compose!(singapore)
    |> Image.write!("/Users/kip/Desktop/overlay.png")
  end

  def demo3 do
    {:ok, base_image} = Image.open("test/support/images/Singapore-2016-09-5887.jpg")
    {:ok, singapore} = Text.new_from_string("Singapore", font_size: 100, font: "DIN Alternate")

    base_image
    |> Image.compose!(singapore, x: :center, y: :middle)
    |> Image.write!("/Users/kip/Desktop/center_text.png")
  end

  def demo4 do
    {:ok, base_image} = Image.open("test/support/images/Singapore-2016-09-5887.jpg")
    {:ok, polygon} = Shape.polygon(@points, fill_color:  @polygon_color, stroke_color: "none", height: Image.height(base_image), opacity: 0.8)
    {:ok, explore_new} = Text.new_from_string("EXPLORE NEW", font_size: 95, font: "DIN Alternate")
    {:ok, places} = Text.new_from_string("PLACES", font_size: 95, font: "DIN Alternate")
    {:ok, blowout} = Text.new_from_string("BLOWOUT SINGAPORE SALE", font_size: 40, font: "DIN Alternate")
    {:ok, start_saving} = Text.new_from_string("START SAVING", font_size: 30, padding: 20, background_fill_color: "none", background_stroke_color: "white", background_stroke_width: 5)

    base_image
    |> compose!([
      {polygon, x: 250, y: 0},
      {explore_new, y_baseline: :top, x_baseline: :left, dx: 20, dy: 200},
      {places, dy: 10},
      {blowout, dy: 20},
      {start_saving, dy: 50}
    ])
    |> Image.write!("/Users/kip/Desktop/polygon_2.png")
  end

  # x, y are absolute coordinates on the base image, which is the first image
  # dx, dx are relative coordinates, relative to the last placed image
  # x_baseline, x_baseline indicates where dx, dy are relative to:
  #   x_baseline: :left | :right with a default of :right
  #   y_baseline: :top | :bottom with a default of :bottom

  # x, y, dx and dy can also be function captures which will receive the coordinates
  # and size of the prior image as well as the canvas size (ie the size of the base image)

  # An image is just an image or a tuple of the form
  # {image, options} where options are the parameters above

  def compose(%Vimage{} = base_image, list) when is_list(list) do
    zipped =
      Enum.reduce_while list, {0, 0, 0, 0, []}, fn
        %Vimage{} = image, {prev_x, prev_y, prev_width, prev_height, acc} ->
          image
          |> composit(prev_x, prev_y, prev_width, prev_height, Map.new())
          |> update_composits(image, acc)

        {%Vimage{} = image, options}, {prev_x, prev_y, prev_width, prev_height, acc} ->
          image
          |> composit(prev_x, prev_y, prev_width, prev_height, Map.new(options))
          |> update_composits(image, acc)
      end

    case zipped do
      {:error, reason} ->
        {:error, reason}

      {_x, _y, _height, _width, list} ->
        {overlay_images, xs, ys, blend_modes} = unzip_composition_params(list)
        |> IO.inspect(label: "Compose")

        Vix.Vips.Operation.composite([base_image | overlay_images], blend_modes, x: xs, y: ys)
    end
  end

  def compose!(%Vimage{} = base_image, list) do
    case compose(base_image, list) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  def unzip_composition_params(list) do
    Enum.reduce list, {[], [], [], []}, fn
      [image, x, y, blend_mode], {images, xs, ys, blend_modes} ->
        blend_mode = Vix.Vips.Enum.VipsBlendMode.to_nif_term(blend_mode, nil)
        {[image | images], [x | xs], [y | ys], [blend_mode | blend_modes]}
    end
  end

  def update_composits(composition, image, acc) do
    case composition do
      {:ok, composition} ->
        [_image, x, y | _rest] = composition
        {:cont, {x, y, Image.width(image), Image.height(image), [composition | acc]}}

      {:error, reason} ->
        {:halt, reason}
    end
  end

  # Specifying x and y is the highest precedence
  def composit(image, _prev_x, _prev_y, _prev_width, _prev_height, %{x: x, y: y} = options)
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    blend_mode = Map.get(options, :blend_mode, Image.BlendMode.default_blend_mode())

    with {:ok, blend_mode} <- Image.BlendMode.validate_blend_mode(blend_mode) do
      {:ok, [image, x, y, blend_mode]}
    end
  end

  def composit(image, _prev_x, prev_y, _prev_width, prev_height, %{x: x, dy: dy} = options)
      when is_integer(x) and is_integer(dy) and x >= 0 do
    blend_mode = Map.get(options, :blend_mode, Image.BlendMode.default_blend_mode())
    baseline = Map.get(options, :y_baseline, :bottom)

    with {:ok, blend_mode} <- Image.BlendMode.validate_blend_mode(blend_mode) do
      {:ok, [image, x, y(prev_y, prev_height, dy, baseline), blend_mode]}
    end
  end

  def composit(image, prev_x, _prev_y, prev_width, _prev_height, %{dx: dx, y: y} = options)
      when is_integer(y) and is_integer(dx) and y >= 0 do
    blend_mode = Map.get(options, :blend_mode, Image.BlendMode.default_blend_mode())
    baseline = Map.get(options, :x_baseline, :right)

    with {:ok, blend_mode} <- Image.BlendMode.validate_blend_mode(blend_mode) do
      {:ok, [image, x(prev_x, prev_width, dx, baseline), y, blend_mode]}
    end
  end

  def composit(image, prev_x, prev_y, prev_width, prev_height, %{dx: dx, dy: dy} = options)
      when is_integer(dx) and is_integer(dy) do
    blend_mode = Map.get(options, :blend_mode, Image.BlendMode.default_blend_mode())
    x_baseline = Map.get(options, :x_baseline, :right)
    y_baseline = Map.get(options, :y_baseline, :bottom)

    with {:ok, blend_mode} <- Image.BlendMode.validate_blend_mode(blend_mode) do
      x = x(prev_x, prev_width, dx, x_baseline)
      y = y(prev_y, prev_height, dy, y_baseline)

      {:ok, [image, x, y, blend_mode]}
    end
  end

  def composit(image, _prev_x, prev_y, _prev_width, _prev_height, %{x: x} = options)
      when is_integer(x) and x >= 0 do
    blend_mode = Map.get(options, :blend_mode, Image.BlendMode.default_blend_mode())

    with {:ok, blend_mode} <- Image.BlendMode.validate_blend_mode(blend_mode) do
      {:ok, [image, x, prev_y, blend_mode]}
    end
  end

  def composit(image, prev_x, _prev_y, _prev_width, _prev_height, %{y: y} = options)
      when is_integer(y) and y >= 0 do
    blend_mode = Map.get(options, :blend_mode, Image.BlendMode.default_blend_mode())

    with {:ok, blend_mode} <- Image.BlendMode.validate_blend_mode(blend_mode) do
      {:ok, [image, prev_x, y, blend_mode]}
    end
  end

  def composit(image, prev_x, prev_y, prev_width, _prev_height, %{dx: dx} = options)
      when is_integer(dx) do
    blend_mode = Map.get(options, :blend_mode, Image.BlendMode.default_blend_mode())
    x_baseline = Map.get(options, :x_baseline, :right)
    x = x(prev_x, prev_width, dx, x_baseline)

    with {:ok, blend_mode} <- Image.BlendMode.validate_blend_mode(blend_mode) do
      {:ok, [image, x, prev_y, blend_mode]}
    end
  end

  def composit(image, prev_x, prev_y, _prev_width, prev_height, %{dy: dy} = options)
      when is_integer(dy) do
    blend_mode = Map.get(options, :blend_mode, Image.BlendMode.default_blend_mode())
    y_baseline = Map.get(options, :y_baseline, :bottom)
    y = y(prev_y, prev_height, dy, y_baseline)

    with {:ok, blend_mode} <- Image.BlendMode.validate_blend_mode(blend_mode) do
      {:ok, [image, prev_x, y, blend_mode]}
    end
  end

  def composit(image, prev_x, prev_y, _prev_width, prev_height, %{} = options) do
    blend_mode = Map.get(options, :blend_mode, Image.BlendMode.default_blend_mode())
    x = prev_x
    y = prev_y + prev_height

    with {:ok, blend_mode} <- Image.BlendMode.validate_blend_mode(blend_mode) do
      {:ok, [image, x, y, blend_mode]}
    end
  end

  def y(prev_y, prev_height, dy, :bottom) do
    prev_y + prev_height + dy
  end

  def y(prev_y, _prev_height, dy, :top) do
    prev_y + dy
  end

  def x(prev_x, prev_width, dx, :right) do
    prev_x + prev_width + dx
  end

  def x(prev_x, _prev_width, dx, :left) do
    prev_x + dx
  end

end