defmodule Image.PrivacyRemoveTest do
  use ExUnit.Case, async: true
  import Image.TestSupport
  import Image.TestSupport.Metadata

  alias Image.Privacy.Finding

  # Every test saves the image and scans the saved file, because removal
  # takes effect when libvips writes the metadata.

  describe "EXIF findings" do
    setup do
      image = Image.open!(image_path("gain_map.jpg"))
      {:ok, findings} = Image.Privacy.scan(image)
      {:ok, image: image, findings: findings}
    end

    test "removing the serial numbers keeps everything else", %{image: image, findings: findings} do
      assert fields(removed(image, findings, &(&1.kind == :device_id))) ==
               [:artist, :gps, :thumbnail]
    end

    test "removing the GPS keeps the rest of the EXIF", %{image: image, findings: findings} do
      saved = removed(image, findings, &(&1.field == :gps))

      assert fields(saved) == [:artist, :body_serial_number, :lens_serial_number, :thumbnail]
      assert {:ok, %{make: "Canon", copyright: "Copyright (c) Kip Cole 2018"}} = Image.exif(saved)
    end

    test "removing the thumbnail or the artist removes only that", %{
      image: image,
      findings: findings
    } do
      refute :thumbnail in fields(removed(image, findings, &(&1.field == :thumbnail)))

      saved = removed(image, findings, &(&1.field == :artist))
      refute :artist in fields(saved)
      assert {:ok, %{copyright: "Copyright (c) Kip Cole 2018"}} = Image.exif(saved)
    end

    test "Windows author and comment, the user comment and the camera owner" do
      image =
        saved_with_fields(
          [
            {"exif-ifd0-XPAuthor", "Jane Doe"},
            {"exif-ifd0-XPComment", "at home"},
            {"exif-ifd2-UserComment", "call me"},
            {"exif-ifd2-CameraOwnerName", "Jane Doe"}
          ],
          ".jpg"
        )

      {:ok, findings} = Image.Privacy.scan(image)

      for field <- [:xp_author, :xp_comment, :user_comment, :camera_owner_name] do
        saved = removed(image, findings, &(&1.field == field))

        refute field in fields(saved)
        assert length(fields(saved)) == 3
      end
    end

    test "removing the GPS destination keeps the position" do
      image =
        saved_with_fields(
          [
            {"exif-ifd3-GPSLatitudeRef", "N"},
            {"exif-ifd3-GPSLatitude", "21/1 1/1 30/1"},
            {"exif-ifd3-GPSDestLatitudeRef", "S"},
            {"exif-ifd3-GPSDestLatitude", "1/1 2/1 3/1"}
          ],
          ".jpg"
        )

      {:ok, findings} = Image.Privacy.scan(image)
      assert fields(save(image)) == [:gps, :gps_destination]

      assert fields(removed(image, findings, &(&1.field == :gps_destination))) == [:gps]
    end

    test "a tag libvips drops from every save needs nothing removed" do
      image = Image.open!(image_path("gain_map.jpg"))
      finding = %Finding{source: :exif, field: :host_computer, value: "Mac", kind: :device_id}

      assert {:ok, ^image} = Image.Privacy.remove(image, [finding])
    end
  end

  describe "other findings" do
    test "a PNG text chunk is removed by its keyword" do
      image =
        saved_with_fields(
          [{"png-comment-0-parameters", "a prompt"}, {"png-comment-1-Software", "Gen"}],
          ".png"
        )

      {:ok, findings} = Image.Privacy.scan(image)

      {:ok, cleaned} =
        Image.Privacy.remove(image, Enum.filter(findings, &(&1.field == "parameters")))

      {:ok, png} = Image.write(cleaned, :memory, suffix: ".png")

      assert {:ok, [%Finding{field: "Software"}]} = Image.Privacy.scan(png)
    end

    test "an unreadable block is removed whole" do
      image = with_xmp("<not xml")
      {:ok, findings} = Image.Privacy.scan(image)
      {:ok, cleaned} = Image.Privacy.remove(image, findings)

      assert {:error, %Image.Error{reason: :no_xmp}} = Image.xmp(cleaned)
    end

    test "a JPEG comment needs nothing removed, as no written image has one" do
      path = image_path("kodak-dc210.jpg")
      {:ok, findings} = Image.Privacy.scan(path)
      image = Image.open!(path)

      assert {:ok, ^image} = Image.Privacy.remove(image, findings)
      assert {:ok, []} = Image.Privacy.scan(to_jpeg(image))
    end

    test "Facebook's two identifiers are removed with the IPTC block they leave empty" do
      image = Image.open!(image_path("facebook_fbmd.jpg"))
      {:ok, findings} = Image.Privacy.scan(image)
      {:ok, cleaned} = Image.Privacy.remove(image, findings)
      saved = save(cleaned)

      assert {:ok, []} = Image.Privacy.scan(saved)
      assert {:error, %Image.Error{reason: :no_iptc}} = Image.iptc(saved)
    end

    test "removing one IPTC dataset keeps the others" do
      image = Image.open!(image_path("facebook_fbmd.jpg"))
      {:ok, findings} = Image.Privacy.scan(image)
      saved = removed(image, findings, &(&1.field == :special_instructions))

      assert {:ok, %{original_transmission_reference: "lvYkyRMFdS9GAseo9eoP"} = iptc} =
               Image.iptc(saved)

      refute Map.has_key?(iptc, :special_instructions)
    end

    test "removing the IPTC by-line keeps the caption data and copyright" do
      image = Image.open!(image_path("Kip_small.jpg"))
      {:ok, findings} = Image.Privacy.scan(image)
      saved = removed(image, findings, &(&1.source == :iptc and &1.field == :by_line))

      assert {:ok, iptc} = Image.iptc(saved)
      refute Map.has_key?(iptc, :by_line)

      assert %{copyright_notice: "Copyright (c) Kip Cole 2012", country_name: "Vietnam"} = iptc
    end

    test "an XMP finding is not supported yet" do
      image = Image.open!(image_path("Kip_small.jpg"))
      {:ok, findings} = Image.Privacy.scan(image)

      assert {:error, %Image.Error{reason: :unsupported_finding}} =
               Image.Privacy.remove(image, Enum.filter(findings, &(&1.source == :xmp)))
    end
  end

  describe "remove/2 arguments" do
    test "no findings leaves every piece of metadata in place" do
      image = Image.open!(image_path("gain_map.jpg"))

      assert {:ok, ^image} = Image.Privacy.remove(image, [])
      assert length(fields(save(image))) == 5
    end

    test "a list element that is not a finding is an error" do
      image = Image.new!(4, 4)

      assert {:error, %Image.Error{reason: :invalid_finding, value: :gps}} =
               Image.Privacy.remove(image, [:gps])
    end

    test "a value that is not an image is an error" do
      assert {:error, %Image.Error{reason: :invalid_image}} = Image.Privacy.remove("x.jpg", [])
    end
  end

  defp removed(image, findings, selector) do
    {:ok, cleaned} = Image.Privacy.remove(image, Enum.filter(findings, selector))
    save(cleaned)
  end

  defp save(image) do
    {:ok, jpeg} = Image.write(image, :memory, suffix: ".jpg")
    Image.open!(jpeg)
  end

  defp to_jpeg(image) do
    {:ok, jpeg} = Image.write(image, :memory, suffix: ".jpg")
    jpeg
  end

  defp fields(image) do
    {:ok, findings} = Image.Privacy.scan(image)
    Enum.map(findings, & &1.field)
  end
end
