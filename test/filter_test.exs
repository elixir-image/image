defmodule Image.Filter.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  test "Image.reduce_noise/1" do
    image_file = "noise_in_rgb_image.png"
    validate_file = "denoise_in_rgb_image.png.tif"

    image_path = image_path(image_file)
    validate_path = validate_path(validate_file)

    image = Image.open!(image_path, access: :random)
    {:ok, reduced_noise} = Image.reduce_noise(image)

    # {:ok, _image} = Image.write(reduced_noise, validate_path)
    assert_images_equal(reduced_noise, validate_path)
  end
end