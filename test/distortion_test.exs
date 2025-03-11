defmodule Image.Distortion.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

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
end
