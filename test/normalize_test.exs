defmodule Image.Normalize.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  test "Image.normalize/1" do
    image_file = "dark.jpeg"

    image_path = image_path(image_file)
    validate_path = validate_path(image_file)

    image = Image.open!(image_path, access: :random)
    {:ok, normalized} = Image.normalize(image)

    {:ok, _image} = Image.write(normalized, validate_path)
    assert_images_equal(normalized, validate_path)
  end
end
