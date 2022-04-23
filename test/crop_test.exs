defmodule Image.Crop.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  alias Vix.Vips.Image, as: Vimage

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  test "Crop from top left", %{dir: dir} do
    image = image_path("Kamchatka-2019-8754.jpg")
    {:ok, image} = Vimage.new_from_file(image)

    {:ok, cropped} = Image.crop(image, 1, 1, 500, 200)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    validate_path = validate_path("crop/kamchatka_top_left.jpg")

    assert :ok = Vimage.write_to_file(cropped, out_path)

    assert_files_equal(out_path, validate_path)
  end

  test "Crop from bottom left", %{dir: dir} do
    image = image_path("Kamchatka-2019-8754.jpg")
    {:ok, image} = Vimage.new_from_file(image)

    {:ok, cropped} = Image.crop(image, 1, -250, 500, 200)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    validate_path = validate_path("crop/kamchatka_bottom_left.jpg")

    assert :ok = Vimage.write_to_file(cropped, out_path)

    assert_files_equal(out_path, validate_path)
  end

  test "Crop from top right", %{dir: dir} do
    image = image_path("Kamchatka-2019-8754.jpg")
    {:ok, image} = Vimage.new_from_file(image)

    {:ok, cropped} = Image.crop(image, -700, 1, 500, 200)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    validate_path = validate_path("crop/kamchatka_top_right.jpg")

    assert :ok = Vimage.write_to_file(cropped, out_path)
    Vimage.write_to_file(cropped, validate_path)
    assert_files_equal(out_path, validate_path)
  end

  test "Crop from bottom right", %{dir: dir} do
    image = image_path("Kamchatka-2019-8754.jpg")
    {:ok, image} = Vimage.new_from_file(image)

    {:ok, cropped} = Image.crop(image, -700, -250, 500, 200)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    validate_path = validate_path("crop/kamchatka_bottom_right.jpg")

    assert :ok = Vimage.write_to_file(cropped, out_path)

    assert_files_equal(out_path, validate_path)
  end
end
