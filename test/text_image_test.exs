defmodule TextImage.Test do
  use ExUnit.Case, async: true

  @moduletag :full

  import Image.TestSupport

  alias Image.{Text, Shape}

  @points [[0, 0], [0, 100], [70, 100], [90, 0]]
  @polygon_color  [116, 214, 245]

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  test "compositing several images in a pipeline", %{dir: dir} do
    image = image_path("Singapore-2016-09-5887.jpg")

    {:ok, base_image} = Image.open(image, access: :random)
    {:ok, polygon} = Shape.polygon(@points, fill_color:  @polygon_color, stroke_color: "none", height: Image.height(base_image), opacity: 0.8)
    {:ok, explore_new} = Text.text("EXPLORE NEW", font_size: 95, font: "DIN Alternate")
    {:ok, places} = Text.text("PLACES", font_size: 95, font: "DIN Alternate")
    {:ok, blowout} = Text.text("BLOWOUT SINGAPORE SALE", font_size: 40, font: "DIN Alternate")
    {:ok, start_saving} = Text.text("START SAVING", font_size: 30, padding: 20, background_fill_color: "none", background_stroke_color: "white", background_stroke_width: 5)

    final_image =
      base_image
      |> Image.compose!(polygon, x: :middle, y: :top)
      |> Image.compose!(explore_new, x: 260, y: 200)
      |> Image.compose!(places, x: 260, y: 260)
      |> Image.compose!(blowout, x: 260, y: 340)
      |> Image.compose!(start_saving, x: 260, y: 400)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    validate_path = validate_path("compose/composition_1.png")

    assert {:ok, _image} = Image.write(final_image, out_path, quality: 50)
    assert_images_equal(out_path, validate_path)
  end

  test "Transparent text on a full image background", %{dir: dir} do
    image = image_path("Singapore-2016-09-5887.jpg")

    {:ok, base_image} = Image.open(image, access: :random)
    {:ok, singapore} = Text.text("SINGAPORE", font_size: 250, font: "DIN Alternate", padding: base_image, text_fill_color: :transparent, background_fill_color: "black", background_fill_opacity: 0.6)

    final_image = Image.compose!(base_image, singapore, x: :center, y: :middle)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    validate_path = validate_path("compose/composition_2.png")

    assert {:ok, _image} = Image.write(final_image, out_path, quality: 50)
    assert_images_equal(out_path, validate_path)
  end

  test "Text centered on a base image", %{dir: dir} do
    image = image_path("Singapore-2016-09-5887.jpg")

    {:ok, base_image} = Image.open(image, access: :random)
    {:ok, singapore} = Text.text("Singapore", font_size: 100, font: "DIN Alternate")

    final_image = Image.compose!(base_image, singapore, x: :center, y: :middle)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    validate_path = validate_path("compose/composition_3.png")

    assert {:ok, _image} = Image.write(final_image, out_path, quality: 50)
    assert_images_equal(out_path, validate_path)
  end

  test "compositing several images in a composition list", %{dir: dir} do
    image = image_path("Singapore-2016-09-5887.jpg")

    {:ok, base_image} = Image.open(image, access: :random)
    {:ok, polygon} = Shape.polygon(@points, fill_color:  @polygon_color, stroke_color: "none", height: Image.height(base_image), opacity: 0.8)
    {:ok, explore_new} = Text.text("EXPLORE NEW", font_size: 95, font: "DIN Alternate")
    {:ok, places} = Text.text("PLACES", font_size: 95, font: "DIN Alternate")
    {:ok, blowout} = Text.text("BLOWOUT SINGAPORE SALE", font_size: 40, font: "DIN Alternate")
    {:ok, start_saving} = Text.text("START SAVING", font_size: 30, padding: 20, background_fill_color: "none", background_stroke_color: "white", background_stroke_width: 5)

    final_image =
      base_image
      |> Image.compose!([
        {polygon, x: :center, y: :top},
        {explore_new, y_baseline: :top, x_baseline: :left, dx: 20, dy: 200},
        {places, dy: 10},
        {blowout, dy: 20},
        {start_saving, dy: 50}
      ])

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    validate_path = validate_path("compose/composition_4.png")

    assert {:ok, _image} = Image.write(final_image, out_path, quality: 50)
    assert_images_equal(out_path, validate_path)
  end
end