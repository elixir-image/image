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

  describe "thumbnail" do
    test "is read from IFD1, and its bytes are the thumbnail libvips reads" do
      image = Image.open!(image_path("Kamchatka-2019-8754.jpg"))

      assert {:ok, %{thumbnail: %Image.Exif.Thumbnail{} = thumbnail}} = Image.exif(image)
      assert thumbnail.thumbnail_size == 12_512

      {:ok, <<"Exif", 0, 0, tiff::binary>>} = Vix.Vips.Image.header_value(image, "exif-data")
      {:ok, expected} = Vix.Vips.Image.header_value(image, "jpeg-thumbnail-data")

      assert binary_part(tiff, thumbnail.thumbnail_offset, thumbnail.thumbnail_size) == expected
    end

    test "is read when IFD1 comes before IFD0" do
      image = Image.open!(image_path("Kip_small.jpg"))

      assert {:ok, %{thumbnail: %Image.Exif.Thumbnail{thumbnail_size: 3940}}} = Image.exif(image)
    end

    test "is absent when there is no IFD1" do
      exif = Image.Exif.extract_exif(tiff(0, []))

      assert is_map(exif)
      refute Map.has_key?(exif, :thumbnail)
    end

    test "is read from hand-built EXIF data" do
      exif = tiff(14, [{0x0201, 100}, {0x0202, 20}])

      assert %{thumbnail: %Image.Exif.Thumbnail{thumbnail_offset: 100, thumbnail_size: 20}} =
               Image.Exif.extract_exif(exif)
    end

    test "an IFD1 offset into the header, at IFD0 or past the end is ignored" do
      for offset <- [4, 8, 10_000] do
        exif = Image.Exif.extract_exif(tiff(offset, [{0x0201, 100}, {0x0202, 20}]))

        assert is_map(exif)
        refute Map.has_key?(exif, :thumbnail)
      end
    end

    test "an IFD1 without both thumbnail tags has no thumbnail" do
      exif = Image.Exif.extract_exif(tiff(14, [{0x0201, 100}]))

      refute Map.has_key?(exif, :thumbnail)
    end
  end

  test "No exif data" do
    image = Image.new!(10, 10)
    assert {:error, %Image.Error{reason: :no_exif}} = Image.exif(image)
  end

  test "Minimizing metadata on an image with no exif" do
    image = Image.new!(10, 10)
    assert {:ok, _image} = Image.minimize_metadata(image)
  end

  # Big-endian EXIF TIFF data with an empty IFD0 at offset 8, whose next
  # IFD offset is `ifd1_offset`, followed at offset 14 by an IFD1 holding
  # `entries`, each a LONG tag and its value.
  defp tiff(ifd1_offset, entries) do
    ifd1 =
      for {tag, value} <- entries, into: <<length(entries)::16>> do
        <<tag::16, 4::16, 1::32, value::32>>
      end

    <<"MM", 0, 42, 8::32, 0::16, ifd1_offset::32>> <> ifd1 <> <<0::32>>
  end
end
