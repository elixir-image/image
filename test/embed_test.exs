defmodule Image.Embed.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  test "Image.embed/4 with extend_mode: :black" do
    image_file = "penguin_with_alpha.png"
    validate_file = "embed/penguin_with_alpha_embed_black.png"

    image_path = image_path(image_file)
    validate_path = validate_path(validate_file)

    image = Image.open!(image_path, access: :random)
    {width, height, _bands} = Image.shape(image)
    {:ok, embedded} = Image.embed(image, width, height + 50, x: 0, y: 0, extend_mode: :black)

    # {:ok, _image} = Image.write(embedded, validate_path)
    assert_images_equal(embedded, validate_path)
  end

  test "Image.embed/4 with extend_mode: :black, background_transparency: :transparent" do
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
        extend_mode: :black,
        background_transparency: :transparent
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
    {:ok, embedded} = Image.embed(image, width, height + 50, background_color: :blue)

    # {:ok, _image} = Image.write(embedded, validate_path)
    assert_images_equal(embedded, validate_path)
  end
end
