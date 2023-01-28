defmodule Image.ErodeDilate.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  setup do
    image =
      "chroma_key/greenscreen.jpg"
      |> image_path()
      |> Image.open!(access: :random)
      |> Image.chroma_key!()

    {:ok, %{image: image}}
  end

  test "Image.erode/1", %{image: image} do
    validate_path = validate_path("dilate_erode/erode.png")
    {:ok, eroded} = Image.erode(image)
    assert_images_equal(eroded, validate_path)
  end

  test "Image.dilate/1", %{image: image} do
    validate_path = validate_path("dilate_erode/dilate.png")
    {:ok, dilated} = Image.dilate(image)
    assert_images_equal(dilated, validate_path)
  end
end
