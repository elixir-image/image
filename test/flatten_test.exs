defmodule Image.FlattenTest do
  use ExUnit.Case, async: true
  import Image.TestSupport

  test "Image.flatten/2 with default background" do
    image_path = image_path("penguin_with_alpha.png")
    validate_path = validate_path("penguine_with_default_background.png")

    {:ok, image} = Image.open(image_path)
    {:ok, result} = Image.flatten(image)

    # Image.write! result, validate_path
    {:ok, result} = Vix.Vips.Image.write_to_buffer(result, ".png")

    assert_images_equal(result, validate_path)
  end

  test "Image.flatten/2 with green background" do
    image_path = image_path("penguin_with_alpha.png")
    validate_path = validate_path("penguine_with_green_background.png")

    {:ok, image} = Image.open(image_path)
    {:ok, result} = Image.flatten(image, background_color: :green)

    # Image.write! result, validate_path
    {:ok, result} = Vix.Vips.Image.write_to_buffer(result, ".png")

    assert_images_equal(result, validate_path)
  end
end
