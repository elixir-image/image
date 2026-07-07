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

  test "Crop using percentages", %{image: image} do
    assert Image.shape(Image.crop!(image, 0.0, 0.0, 1.0, 1.0)) == Image.shape(image)
    assert Image.shape(Image.crop!(image, 0.0, 0.0, 0.5, 1.0)) == {500, 542, 3}
    assert Image.shape(Image.crop!(image, 0.0, 0.0, 1.0, 0.5)) == {1000, 271, 3}

    assert Image.shape(Image.crop!(image, 0.5, 0.5, 0.5, 0.5)) == {500, 271, 3}
    assert Image.shape(Image.crop!(image, -0.5, 0.5, 0.5, 0.5)) == {500, 271, 3}
    assert Image.shape(Image.crop!(image, 0.5, -0.5, 0.5, 0.5)) == {500, 271, 3}
  end

  test "Crop using invalid percentages", %{image: image} do
    # libvips errors are wrapped in Image.Error with the raw libvips
    # message preserved as the reason.
    assert {:error, %Image.Error{reason: "operation build:" <> _, operation: :extract_area}} =
             Image.crop(image, 0.5, 0.5, 0.6, 0.5)

    assert {:error, %Image.Error{reason: "operation build:" <> _, operation: :extract_area}} =
             Image.crop(image, 0.5, 0.5, 0.5, 0.6)

    assert {:error, %Image.Error{message: "width must be a percentage" <> _}} =
             Image.crop(image, 0.5, 0.5, -0.5, 0.6)

    assert {:error, %Image.Error{message: "height must be a percentage" <> _}} =
             Image.crop(image, 0.5, 0.5, 0.5, -0.6)
  end

  test "Cropping a multipage webp image" do
    image_path = image_path("animated.webp")
    validate_path = validate_path("crop/animated_cropped.webp")

    {:ok, image} = Image.open(image_path, pages: :all)
    {:ok, cropped} = Image.crop(image, 0, 100, 150, 150)

    # {:ok, _} = Image.write(cropped, validate_path)
    {:ok, validate_image} = Image.open(validate_path, pages: :all)
    assert_images_equal(cropped, validate_image, 160)
  end

  test "Cropping a multipage webp image via Image.map_pages/2" do
    image_path = image_path("animated.webp")
    validate_path = validate_path("crop/animated_cropped.webp")

    {:ok, image} = Image.open(image_path, pages: :all)
    {:ok, cropped} = Image.map_join_pages(image, &Image.crop(&1, 0, 100, 150, 150))

    # {:ok, _} = Image.write(cropped, validate_path)
    {:ok, validate_image} = Image.open(validate_path, pages: :all)

    assert_images_equal(cropped, validate_image, 160)
  end

  test "Cropping a multipage gif image" do
    image_path = image_path("animated.gif")
    validate_path = validate_path("crop/animated_cropped.gif")

    {:ok, image} = Image.open(image_path, pages: :all)
    {:ok, cropped} = Image.crop(image, 0, 100, 150, 150)

    # {:ok, _} = Image.write(cropped, validate_path)
    {:ok, validate_image} = Image.open(validate_path, pages: :all)
    assert_images_equal(cropped, validate_image)
  end
end
