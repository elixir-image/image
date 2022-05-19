defmodule Image.Crop.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  setup do
    image = image_path("Kamchatka-2019-8754.jpg")
    {:ok, image} = Image.open(image, access: :random)

    {:ok, %{image: image}}
  end

  test "Crop from top left", %{image: image} do
    validate_path = validate_path("crop/kamchatka_top_left.tif")

    {:ok, cropped} = Image.crop(image, 0, 0, 500, 200)

    assert_images_equal(cropped, validate_path)
  end

  test "Crop from bottom left", %{image: image} do
    validate_path = validate_path("crop/kamchatka_bottom_left.tif")

    {:ok, cropped} = Image.crop(image, 0, -1, 500, 200)

    assert_images_equal(cropped, validate_path)
  end

  test "Crop from top right", %{image: image} do
    validate_path = validate_path("crop/kamchatka_top_right.tif")

    {:ok, cropped} = Image.crop(image, -1, 0, 500, 200)

    assert_images_equal(cropped, validate_path)
  end

  test "Crop from bottom right", %{image: image} do
    validate_path = validate_path("crop/kamchatka_bottom_right.tif")

    {:ok, cropped} = Image.crop(image, -1, -1, 500, 200)

    assert_images_equal(cropped, validate_path)
  end
end
