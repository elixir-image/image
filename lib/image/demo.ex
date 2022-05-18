defmodule Image.Demo do
  alias Image.{Text, Shape}

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
    |> Image.compose!([
      {polygon, x: :center, y: :top},
      {explore_new, y_baseline: :top, dx: 20, dy: 200},
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




end