defmodule TextImage.Test do
  use ExUnit.Case, async: true

  import Image.TestSupport

  alias Image.{Text, Shape}

  @moduletag :text

  @points [[0, 0], [0, 100], [70, 100], [90, 0]]
  @polygon_color [116, 214, 245]

  setup do
    image = image_path("Singapore-2016-09-5887.jpg")
    {:ok, image} = Image.open(image, access: :random)

    {:ok, %{image: image}}
  end

  test "compositing several images in a pipeline", %{image: base_image} do
    validate_path = validate_path("compose/composition_1.tif")

    {:ok, polygon} =
      Shape.polygon(@points,
        fill_color: @polygon_color,
        stroke_color: "none",
        height: Image.height(base_image),
        opacity: 0.8
      )

    {:ok, explore_new} = Text.text("EXPLORE NEW", font_size: 70, font: "DIN Alternate")
    {:ok, places} = Text.text("PLACES", font_size: 70, font: "DIN Alternate")
    {:ok, blowout} = Text.text("BLOWOUT SINGAPORE SALE", font_size: 30, font: "DIN Alternate")

    {:ok, start_saving} =
      Text.text("START SAVING",
        font_size: 30,
        padding: 20,
        background_fill_color: "none",
        background_stroke_color: "white",
        background_stroke_width: 5
      )

    final_image =
      base_image
      |> Image.compose!(polygon, x: :middle, y: :top)
      |> Image.compose!(explore_new, x: 260, y: 200)
      |> Image.compose!(places, x: 260, y: 260)
      |> Image.compose!(blowout, x: 260, y: 340)
      |> Image.compose!(start_saving, x: 260, y: 400)
      # |> Image.preview()

    # Image.write(final_image, validate_path)
    assert_images_equal(final_image, validate_path)
  end

  test "Transparent text on a full image background", %{image: base_image} do
    validate_path = validate_path("compose/composition_2.png")

    {:ok, singapore} =
      Text.text("SINGAPORE",
        font_size: 160,
        font: "DIN Alternate",
        padding: base_image,
        text_fill_color: :transparent,
        background_fill_color: "black",
        background_fill_opacity: 0.6
      )

    {:ok, final_image} = Image.compose(base_image, singapore, x: :center, y: :middle)
    # Image.preview final_image

    # Image.write(final_image, validate_path)
    assert_images_equal(final_image, validate_path)
  end

  test "Black text trims correctly" do
    validate_path = validate_path("text/black_text.tif")

    {:ok, black_text} = Text.text("Some Black Text", text_stroke_color: :black, text_fill_color: :black)
    # Image.preview black_text

    # Image.write(black_text, validate_path)
    assert_images_equal(black_text, validate_path)
  end

  test "Text centered on a base image", %{image: base_image} do
    validate_path = validate_path("compose/composition_3.tif")

    {:ok, singapore} = Text.text("Singapore", font_size: 100, font: "DIN Alternate")
    final_image = Image.compose!(base_image, singapore, x: :center, y: :middle)
    # Image.preview final_image

    # Image.write(final_image, validate_path)
    assert_images_equal(final_image, validate_path)
  end

  test "compositing several images in a composition list", %{image: base_image} do
    validate_path = validate_path("compose/composition_4.tif")

    {:ok, polygon} =
      Shape.polygon(@points,
        fill_color: @polygon_color,
        stroke_color: "none",
        height: Image.height(base_image),
        opacity: 0.8
      )

    {:ok, explore_new} = Text.text("EXPLORE NEW", font_size: 70, font: "DIN Alternate")
    {:ok, places} = Text.text("PLACES", font_size: 70, font: "DIN Alternate")
    {:ok, blowout} = Text.text("BLOWOUT SINGAPORE SALE", font_size: 30, font: "DIN Alternate")

    {:ok, start_saving} =
      Text.text("START SAVING",
        font_size: 30,
        padding: 20,
        background_fill_color: "none",
        background_stroke_color: "white",
        background_stroke_width: 5
      )

    final_image =
      base_image
      |> Image.compose!([
        {polygon, x: :center, y: :top},
        {explore_new, y_baseline: :top, x_baseline: :left, dx: 20, dy: 200},
        {places, dy: 10},
        {blowout, dy: 20},
        {start_saving, dy: 50}
      ])
      # |> Image.preview

    # Image.write(final_image, validate_path)
    assert_images_equal(final_image, validate_path)
  end

  test "Autofit text default colors" do
    validate_path = validate_path("text/autofit_default.tif")

    {:ok, image} =
      Image.Text.text("This is some multiline text", height: 300, width: 300, autofit: true)

    assert {300, 300, 4} = Image.shape(image)
    assert_images_equal(image, validate_path)
  end

  test "Autofit text default colors and justification" do
    validate_path = validate_path("text/autofit_default_with_justify.tif")

    {:ok, image} =
      Image.Text.text("This is some multiline text",
        height: 300,
        width: 300,
        autofit: true,
        justify: true
      )

    # Image.write(image, validate_path)
    assert {300, 300, 4} = Image.shape(image)
    assert_images_equal(image, validate_path)
  end

  test "Autofit text alternate colors" do
    validate_path = validate_path("text/autofit_default_with_alternate_color.tif")

    {:ok, image} =
      Image.Text.text("This is some multiline text",
        height: 300,
        width: 300,
        autofit: true,
        text_fill_color: :green
      )

    # Image.write(image, validate_path)
    assert {300, 300, 4} = Image.shape(image)
    assert_images_equal(image, validate_path)
  end

  test "Autofit text composed over a base image", %{image: base_image} do
    validate_path = validate_path("text/autofit_default_composed_on_base_image.tif")

    {:ok, text_image} =
      Image.Text.text("Singapore skyline text in a 300x300 centred box",
        height: 300,
        width: 300,
        autofit: true,
        text_fill_color: :white
      )

    {:ok, final_image} = Image.compose(base_image, text_image, x: :middle, y: :center)

    # Image.write(final_image, validate_path)
    assert_images_equal(final_image, validate_path)
  end

  test "simple text generation" do
    assert Image.Text.simple_text("name",
             autofit: true,
             width: 290,
             height: 50,
             text_fill_color: "#A15B35"
           )
  end
end
