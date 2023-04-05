defmodule Image.Perspective.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  test "warps an image to perspective" do
    original = image_path("warp_perspective.jpg")
    expected = validate_path("warp_perspective.jpg")

    {:ok, image} = Image.open(original, access: :random)

    {:ok, result} =
      Image.warp_perspective(
        image,
        [
          {139, 125},
          {826, 74},
          {796, 559},
          {155, 483}
        ],
        [
          {139, 125},
          {816, 125},
          {815, 528},
          {136, 528}
        ]
      )

    {:ok, result} = Vix.Vips.Image.write_to_buffer(result, ".jpg")

    assert_images_equal(result, expected)
  end
end
