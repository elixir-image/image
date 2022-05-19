defmodule Image.Resize.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  @moduletag :full

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  test "Resize to fit", %{dir: dir} do
    image = image_path("Kamchatka-2019-8754.jpg")
    {:ok, image} = Image.open(image, access: :random)

    {:ok, resized} = Image.resize(image, 200)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    validate_path = validate_path("resize/kamchatka_fit.png")

    assert {:ok, _image} = Image.write(resized, out_path)
    assert_images_equal resized, validate_path
  end

  test "Resize to fill with attention crop", %{dir: dir} do
    image = image_path("Kamchatka-2019-8754.jpg")
    {:ok, image} = Image.open(image, access: :random)

    {:ok, resized} = Image.resize(image, 200, height: 50, crop: :attention)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    validate_path = validate_path("resize/kamchatka_fill.png")

    assert {:ok, _image} = Image.write(resized, out_path, quality: 50)

    assert_images_equal(out_path, validate_path)
  end

  test "Resize to fill with low crop", %{dir: dir} do
    image = image_path("Kamchatka-2019-8754.jpg")
    {:ok, image} = Image.open(image, access: :random)

    {:ok, resized} = Image.resize(image, 200, height: 50, crop: :low)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    validate_path = validate_path("resize/kamchatka_fill_low.png")

    assert {:ok, _image} = Image.write(resized, out_path)

    assert_images_equal(out_path, validate_path)
  end

  test "Resize to fill with high crop", %{dir: dir} do
    image = image_path("Kamchatka-2019-8754.jpg")
    {:ok, image} = Image.open(image, access: :random)

    {:ok, resized} = Image.resize(image, 200, height: 50, crop: :high)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    validate_path = validate_path("resize/kamchatka_fill_high.png")

    assert {:ok, _image} = Image.write(resized, out_path)

    assert_images_equal(out_path, validate_path)
  end

  test "Resize to fill with center crop", %{dir: dir} do
    image = image_path("Kamchatka-2019-8754.jpg")
    {:ok, image} = Image.open(image, access: :random)

    {:ok, resized} = Image.resize(image, 200, height: 50, crop: :center)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    validate_path = validate_path("resize/kamchatka_fill_center.png")

    assert {:ok, _image} = Image.write(resized, out_path)

    assert_images_equal(out_path, validate_path)
  end

  test "Resize to fill with none crop", %{dir: dir} do
    image = image_path("Kamchatka-2019-8754.jpg")
    {:ok, image} = Image.open(image, access: :random)

    {:ok, resized} = Image.resize(image, 200, height: 50, crop: :none)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    validate_path = validate_path("resize/kamchatka_fill_none.png")

    assert {:ok, _image} = Image.write(resized, out_path)

    assert_images_equal(out_path, validate_path)
  end
end

