defmodule Image.Trim.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  test "trimming to alpha" do
    image_path = image_path("penguin_with_alpha.png")
    validate_path = validate_path("penguin_trimmed_to_alpha.png")

    {:ok, image} = Image.open(image_path)
    {:ok, trimmed} = Image.trim(image, background: :alpha)

    # Image.write! trimmed, validate_path

    assert Image.shape(trimmed) == {386, 385, 4}
    assert_images_equal(trimmed, validate_path)
  end
end
