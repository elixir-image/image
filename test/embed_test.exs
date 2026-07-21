defmodule Image.Embed.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  test "Image.embed/4 with the default background gives a transparent border on an alpha image" do
    # The default `background: :transparent` fills the border. On an alpha image
    # that is transparent black, the same output as the explicit
    # `background: {:black, alpha: :transparent}`.
    image_file = "penguin_with_alpha.png"
    validate_file = "embed/penguin_with_alpha_embed_black_transparent.png"

    image_path = image_path(image_file)
    validate_path = validate_path(validate_file)

    image = Image.open!(image_path, access: :random)
    {width, height, _bands} = Image.shape(image)
    {:ok, embedded} = Image.embed(image, width, height + 50, x: 0, y: 0)

    # {:ok, _image} = Image.write(embedded, validate_path)
    assert_images_equal(embedded, validate_path)
  end

  test "Image.embed/4 with an explicit background: :black gives an opaque black border" do
    image_file = "penguin_with_alpha.png"
    validate_file = "embed/penguin_with_alpha_embed_black.png"

    image_path = image_path(image_file)
    validate_path = validate_path(validate_file)

    image = Image.open!(image_path, access: :random)
    {width, height, _bands} = Image.shape(image)
    {:ok, embedded} = Image.embed(image, width, height + 50, x: 0, y: 0, background: :black)

    # {:ok, _image} = Image.write(embedded, validate_path)
    assert_images_equal(embedded, validate_path)
  end

  test "Image.embed/4 with background: {:black, alpha: :transparent}" do
    image_file = "penguin_with_alpha.png"
    validate_file = "embed/penguin_with_alpha_embed_black_transparent.png"

    image_path = image_path(image_file)
    validate_path = validate_path(validate_file)

    image = Image.open!(image_path, access: :random)
    {width, height, _bands} = Image.shape(image)

    {:ok, embedded} =
      Image.embed(image, width, height + 50,
        x: 0,
        y: 0,
        background: {:black, alpha: :transparent}
      )

    # {:ok, _image} = Image.write(embedded, validate_path)
    assert_images_equal(embedded, validate_path)
  end

  test "Image.embed/4 with a background color" do
    image_file = "jose.png"
    validate_file = "embed/jose_with_border.png"

    image_path = image_path(image_file)
    validate_path = validate_path(validate_file)

    image = Image.open!(image_path, access: :random)

    {width, height, _bands} = Image.shape(image)
    {:ok, embedded} = Image.embed(image, width, height + 50, background: :blue)

    # {:ok, _image} = Image.write(embedded, validate_path)
    assert_images_equal(embedded, validate_path)
  end

  test "Image.embed/4 with an explicit opaque background on an image with an alpha band" do
    image_file = "penguin_with_alpha.png"
    validate_file = "embed/penguin_with_alpha_embed_background.png"

    image_path = image_path(image_file)
    validate_path = validate_path(validate_file)

    image = Image.open!(image_path, access: :random)
    assert Image.has_alpha?(image)

    {width, height, _bands} = Image.shape(image)
    {:ok, embedded} = Image.embed(image, width, height + 50, x: 0, y: 0, background: :black)

    # {:ok, _image} = Image.write(embedded, validate_path)
    assert_images_equal(embedded, validate_path)
  end

  test "Image.embed/4 with an explicit background on a single-band image" do
    validate_file = "embed/sydney_opera_house_bw_embed_background.png"
    validate_path = validate_path(validate_file)

    image =
      image_path("Sydney-Opera-House-BW.jpg")
      |> Image.open!(access: :random)
      |> Image.to_colorspace!(:bw)

    {width, height, bands} = Image.shape(image)
    assert bands == 1
    refute Image.has_alpha?(image)

    {:ok, embedded} = Image.embed(image, width, height + 50, x: 0, y: 0, background: :black)

    # {:ok, _image} = Image.write(embedded, validate_path)
    assert_images_equal(embedded, validate_path)
  end
end
