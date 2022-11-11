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
  end