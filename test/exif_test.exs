defmodule Image.ExitTest do
  use ExUnit.Case, async: true
  import Image.TestSupport

  doctest Image.Exif

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

    assert {:ok, %{copyright: nil, image_description: nil}} = Image.exif(image)
  end

  test "EXIF from a PNG eXIf chunk, which has no Exif prefix" do
    image = Image.open!(image_path("jose.png"))
    {:ok, blob} = Vix.Vips.Image.header_value(image, "exif-data")

    assert <<"II", 42, 0, _rest::binary>> = blob
    assert {:ok, %{x_resolution: 72}} = Image.exif(image)
  end

  test "EXIF written to a PNG reads back" do
    {:ok, png} = Image.write(Image.new!(16, 16), :memory, suffix: ".png")

    assert {:ok, exif} = Image.exif(Image.open!(png))
    assert is_map(exif)
  end

  test "No exif data" do
    image = Image.new!(10, 10)
    assert {:error, %Image.Error{reason: :no_exif}} = Image.exif(image)
  end

  test "Minimizing metadata on an image with no exif" do
    image = Image.new!(10, 10)
    assert {:ok, _image} = Image.minimize_metadata(image)
  end
end
