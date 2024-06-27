defmodule Image.ExitTest do
  use ExUnit.Case, async: true
  import Image.TestSupport

  test "Exif extract when exif blob but no exif tags" do
    image = image_path("description_no_exif.jpg")
    {:ok, image} = Image.open(image, access: :random)

    assert Image.exif(image) ==
             {:ok,
              %{
                YCbCr_positioning: "Centered",
                image_description: "a descriptive white pixel",
                resolution_units: "Pixels/in",
                x_resolution: 97,
                y_resolution: 97
              }}
  end

  test "Exif with zero length data for a tag" do
    image = image_path("kodak-dc210.jpg")
    {:ok, image} = Image.open(image, access: :random)

    assert {:ok, %{copyright: "", image_description: ""}} = Image.exif(image)
  end
end
