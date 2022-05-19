defmodule Image.Resize.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  @moduletag :full

  test "Resize to fit" do
    image = image_path("Kamchatka-2019-8754.jpg")
    validate_path = validate_path("resize/kamchatka_fit.png")

    {:ok, image} = Image.open(image, access: :random)
    {:ok, resized} = Image.resize(image, 200)

    assert_images_equal resized, validate_path
  end

  test "Resize to fill with attention crop" do
    image = image_path("Kamchatka-2019-8754.jpg")
    validate_path = validate_path("resize/kamchatka_fill.png")

    {:ok, image} = Image.open(image, access: :random)
    {:ok, resized} = Image.resize(image, 200, height: 50, crop: :attention)

    assert_images_equal(resized, validate_path)
  end

  test "Resize to fill with low crop" do
    image = image_path("Kamchatka-2019-8754.jpg")
    validate_path = validate_path("resize/kamchatka_fill_low.png")

    {:ok, image} = Image.open(image, access: :random)
    {:ok, resized} = Image.resize(image, 200, height: 50, crop: :low)

    assert_images_equal(resized, validate_path)
  end

  test "Resize to fill with high crop" do
    image = image_path("Kamchatka-2019-8754.jpg")
    validate_path = validate_path("resize/kamchatka_fill_high.png")

    {:ok, image} = Image.open(image, access: :random)
    {:ok, resized} = Image.resize(image, 200, height: 50, crop: :high)

    assert_images_equal(resized, validate_path)
  end

  test "Resize to fill with center crop" do
    image = image_path("Kamchatka-2019-8754.jpg")
    validate_path = validate_path("resize/kamchatka_fill_center.png")

    {:ok, image} = Image.open(image, access: :random)
    {:ok, resized} = Image.resize(image, 200, height: 50, crop: :center)

    assert_images_equal(resized, validate_path)
  end

  test "Resize to fill with none crop" do
    image = image_path("Kamchatka-2019-8754.jpg")
    validate_path = validate_path("resize/kamchatka_fill_none.png")

    {:ok, image} = Image.open(image, access: :random)
    {:ok, resized} = Image.resize(image, 200, height: 50, crop: :none)

    assert_images_equal(resized, validate_path)
  end
end

