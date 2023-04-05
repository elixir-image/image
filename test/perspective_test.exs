defmodule Image.Perspective.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  @warp_from [
    {139, 125},
    {826, 74},
    {796, 559},
    {155, 483}
  ]

  @warp_to [
    {139, 125},
    {815, 125},
    {815, 528},
    {139, 528}
  ]

  test "warps an image to perspective" do
    image_path = image_path("warp_perspective.jpg")
    validate_path = validate_path("warp_perspective.jpg")

    {:ok, image} = Image.open(image_path)
    {:ok, result} = Image.warp_perspective(image, @warp_from, @warp_to)

    # Image.write! result, validate_path
    {:ok, result} = Vix.Vips.Image.write_to_buffer(result, ".jpg")

    assert_images_equal(result, validate_path)
  end

  test "post-crop of a warped image" do
    image_path = image_path("warp_perspective.jpg")
    validate_path = validate_path("warp_perspective_cropped.png")

    {:ok, image} = Image.open(image_path)
    {:ok, result} = Image.warp_perspective(image, @warp_from, @warp_to)

    {:ok, cropped} = Image.crop(result, @warp_to)

    # Image.write! cropped, validate_path
    assert_images_equal(cropped, validate_path)
  end
end
