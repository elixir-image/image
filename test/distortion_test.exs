defmodule Image.Distortion.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  @background {[10, 20, 30], alpha: 40}

  test "Image.distort/3" do
    image_file = "koala.gif"
    validate_file = "koala_distorted.png"

    image_path = image_path(image_file)
    validate_path = validate_path(validate_file)

    image = Image.open!(image_path)
    {:ok, distorted} = Image.distort(image, [{30, 11}, {48, 29}], [{20, 11}, {58, 29}])

    # {:ok, _image} = Image.write(distorted, validate_path)
    assert_images_equal(distorted, validate_path)
  end

  test "Image.distort/4 fills coordinates outside the source with background" do
    image = rgba_image()

    assert {:ok, background} =
             Image.distort(image, [{0, 0}], [{50, 0}], background: @background)

    assert Image.get_pixel!(background, 0, 50) == [10, 20, 30, 40]
  end

  test "Image.distort/4 can copy the interpolation fringe" do
    image = rgba_image()

    assert {:ok, copied} =
             Image.distort(image, [{0, 0}], [{1, 0}], extend_mode: :copy)

    assert Image.get_pixel!(copied, 0, 50) == [255, 0, 0, 255]
  end

  defp rgba_image do
    Image.new!(100, 100, color: [255, 0, 0, 255])
  end
end
