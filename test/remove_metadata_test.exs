defmodule Image.RemoveMetadataTest do
  use ExUnit.Case, async: true
  import Image.TestSupport

  # Each test saves the image and reads the saved file back, because
  # libvips rebuilds EXIF from per-tag fields when it saves: checking the
  # image in memory alone misses what reaches the file.

  describe "remove_metadata/2 checked in the saved file" do
    test ":exif removes every EXIF tag, the GPS and the thumbnail" do
      image = Image.open!(image_path("gain_map.jpg"))
      {:ok, before} = Image.Privacy.scan(image)
      assert length(before) == 5

      {:ok, removed} = Image.remove_metadata(image, :exif)
      saved = save(removed)

      assert {:ok, []} = Image.Privacy.scan(saved)

      # libvips writes a minimal EXIF block of its own on save.
      assert {:ok, exif} = Image.exif(saved)
      refute Map.has_key?(exif, :artist)
      refute Map.has_key?(exif, :gps)
      refute Map.has_key?(exif, :thumbnail)
      refute Map.has_key?(exif.exif, :body_serial_number)
    end

    test ":exif keeps the orientation" do
      image = Image.open!(image_path("Kip_small_rotated.jpg"))
      assert {:ok, 3} = Vix.Vips.Image.header_value(image, "orientation")

      {:ok, removed} = Image.remove_metadata(image, :exif)

      assert {:ok, 3} = Vix.Vips.Image.header_value(save(removed), "orientation")
    end

    test ":iptc removes Facebook's identifiers" do
      image = Image.open!(image_path("facebook_fbmd.jpg"))
      {:ok, removed} = Image.remove_metadata(image, :iptc)

      assert {:error, %Image.Error{reason: :no_iptc}} = Image.iptc(save(removed))
    end

    test ":xmp removes the XMP" do
      image = Image.open!(image_path("Kip_small.jpg"))
      {:ok, removed} = Image.remove_metadata(image, :xmp)

      assert {:error, %Image.Error{reason: :no_xmp}} = Image.xmp(save(removed))
    end

    test "removing one kind leaves the others" do
      image = Image.open!(image_path("Kip_small.jpg"))
      {:ok, removed} = Image.remove_metadata(image, :exif)
      saved = save(removed)

      assert {:ok, %{by_line: ["Kip Cole"]}} = Image.iptc(saved)
      assert {:ok, %{artist: "Kip Cole"}} = Image.xmp(saved)
    end

    test "with no fields removes everything the scan reports" do
      {:ok, removed} = Image.remove_metadata(Image.open!(image_path("Kip_small.jpg")))

      assert {:ok, []} = Image.Privacy.scan(save(removed))
    end
  end

  describe "minimize_metadata/1 checked in the saved file" do
    test "keeps only the EXIF artist" do
      {:ok, minimized} = Image.minimize_metadata(Image.open!(image_path("Kip_small.jpg")))

      assert {:ok, [%Image.Privacy.Finding{source: :exif, field: :artist}]} =
               Image.Privacy.scan(save(minimized))
    end
  end

  defp save(image) do
    {:ok, binary} = Image.write(image, :memory, suffix: ".jpg")
    Image.open!(binary)
  end
end
