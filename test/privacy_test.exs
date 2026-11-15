defmodule Image.PrivacyTest do
  use ExUnit.Case, async: true
  import Image.TestSupport
  import Image.TestSupport.Metadata

  alias Image.Privacy.Finding

  doctest Image.Privacy

  @rdf ~s(xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#")

  describe "IPTC" do
    test "reports Facebook's FBMD identifier and transmission reference" do
      path =
        jpeg_with_app13(
          iim([{2, 40, "FBMD01000a8f0300003b0c0000"}, {2, 103, "bF9xQkLmNoPqRsTuVwXy"}])
        )

      assert {:ok, findings} = Image.Privacy.scan(Image.open!(path))

      assert %Finding{source: :iptc, kind: :tracking_id, value: "FBMD01000a8f0300003b0c0000"} =
               find(findings, :special_instructions)

      assert %Finding{source: :iptc, kind: :tracking_id, value: "bF9xQkLmNoPqRsTuVwXy"} =
               find(findings, :original_transmission_reference)
    end

    test "reports exactly Facebook's two identifiers in a photo Facebook processed" do
      assert {:ok, findings} = Image.Privacy.scan(image_path("facebook_fbmd.jpg"))

      assert [
               %Finding{source: :iptc, field: :special_instructions, kind: :tracking_id},
               %Finding{source: :iptc, field: :original_transmission_reference, kind: :tracking_id}
             ] = findings
    end

    test "Facebook's identifiers survive a plain save and are removed by strip_metadata" do
      image = Image.open!(image_path("facebook_fbmd.jpg"))

      {:ok, saved} = Image.write(image, :memory, suffix: ".jpg")
      assert {:ok, [_fbmd, _transmission_reference]} = Image.Privacy.scan(saved)

      {:ok, stripped} = Image.write(image, :memory, suffix: ".jpg", strip_metadata: true)
      assert {:ok, []} = Image.Privacy.scan(stripped)
      assert {:error, %Image.Error{reason: :no_iptc}} = Image.iptc(Image.open!(stripped))
    end

    test "does not report other special instructions" do
      path = jpeg_with_app13(iim([{2, 40, "Embargoed until noon"}]))

      assert {:ok, []} = Image.Privacy.scan(Image.open!(path))
    end

    test "reports people and places" do
      assert {:ok, findings} = Image.Privacy.scan(Image.open!(image_path("Kip_small.jpg")))

      assert %Finding{source: :iptc, kind: :person, value: ["Kip Cole"]} = find(findings, :by_line)

      assert %Finding{source: :iptc, kind: :location, value: "Vietnam"} =
               find(findings, :iptc, :country_name)
    end

    test "reports an IPTC block it cannot read" do
      path = jpeg_with_app13(irb([{0x0404, "", <<0x1C, 2, 40, 0, 40, "short">>}]))

      assert {:ok, [%Finding{source: :iptc, field: nil, kind: :unreadable, value: :invalid_iptc}]} =
               Image.Privacy.scan(Image.open!(path))
    end
  end

  describe "EXIF" do
    test "reports the artist, serial numbers and GPS coordinates" do
      assert {:ok, findings} = Image.Privacy.scan(Image.open!(image_path("gain_map.jpg")))

      assert %Finding{source: :exif, kind: :person, value: "Kip Cole"} =
               find(findings, :exif, :artist)

      assert %Finding{kind: :device_id, value: "022021004036"} =
               find(findings, :body_serial_number)

      assert %Finding{kind: :device_id, value: "9600000789"} = find(findings, :lens_serial_number)

      assert %Finding{kind: :location, value: %{latitude_ref: "N", longitude_ref: "E"} = gps} =
               find(findings, :gps)

      assert gps.latitude == [55, 41.375, 0]
    end

    test "reports the image unique ID" do
      image = Image.open!(image_path("gain_map_pixel_10_pro.jpg"))

      assert {:ok, findings} = Image.Privacy.scan(image)

      assert %Finding{source: :exif, kind: :document_id} =
               finding = find(findings, :image_unique_id)

      assert finding.value == "4b505d41a9f4729e0000000000000000"
    end

    test "does not report a GPS block without coordinates" do
      image = Image.open!(image_path("gain_map_pixel_10_pro.jpg"))
      {:ok, exif} = Image.exif(image)

      assert exif.gps.gps_img_direction == 252
      assert {:ok, findings} = Image.Privacy.scan(image)
      refute find(findings, :gps)
    end

    test "reports Windows author and comment tags and the user comment" do
      image =
        saved_with_fields(
          [
            {"exif-ifd0-XPAuthor", "Jane Doe"},
            {"exif-ifd0-XPComment", "taken at home"},
            {"exif-ifd2-UserComment", "call me on 555"}
          ],
          ".jpg"
        )

      assert {:ok, findings} = Image.Privacy.scan(image)

      assert %Finding{source: :exif, kind: :person, value: "Jane Doe"} = find(findings, :xp_author)

      assert %Finding{kind: :embedded_text, value: "taken at home"} =
               find(findings, :xp_comment)

      assert %Finding{kind: :embedded_text, value: "call me on 555"} =
               find(findings, :user_comment)
    end

    test "reports GPS destination coordinates" do
      image =
        saved_with_fields(
          [{"exif-ifd3-GPSDestLatitude", "1/1 2/1 3/1"}, {"exif-ifd3-GPSDestLatitudeRef", "S"}],
          ".jpg"
        )

      assert {:ok, [%Finding{field: :gps_destination, kind: :location, value: value}]} =
               Image.Privacy.scan(image)

      assert %{latitude: [1, 2, 3], latitude_ref: "S", longitude: nil} = value
    end

    test "reports the camera owner" do
      image = saved_with_fields([{"exif-ifd2-CameraOwnerName", "Jane Doe"}], ".jpg")

      assert {:ok, [%Finding{source: :exif, field: :camera_owner_name, kind: :person}]} =
               Image.Privacy.scan(image)
    end
  end

  describe "EXIF thumbnail" do
    test "is reported with its size" do
      image = Image.open!(image_path("gain_map_pixel_10_pro.jpg"))

      assert {:ok, findings} = Image.Privacy.scan(image)

      assert %Finding{source: :exif, kind: :hidden_data, value: value} = find(findings, :thumbnail)
      assert value == %{format: :jpeg, bytes: 6578, width: 144, height: 160}
    end

    test "is reported for a WebP" do
      assert {:ok, findings} = Image.Privacy.scan(image_path("puppy.webp"))
      assert %Finding{value: %{width: 256, height: 171}} = find(findings, :thumbnail)
    end

    test "that is not a JPEG is reported without its dimensions" do
      image = with_blob("jpeg-thumbnail-data", "not a jpeg")

      assert {:ok, [%Finding{field: :thumbnail, value: value}]} = Image.Privacy.scan(image)
      assert value == %{format: :unknown, bytes: 10, width: nil, height: nil}
    end

    test "that cannot be decoded is reported without its dimensions" do
      image = with_blob("jpeg-thumbnail-data", <<0xFF, 0xD8, 0xFF, "broken">>)

      assert {:ok, [%Finding{value: %{format: :jpeg, width: nil, height: nil}}]} =
               Image.Privacy.scan(image)
    end
  end

  describe "XMP" do
    test "reports document identifiers" do
      image = Image.open!(image_path("puppy.webp"))

      assert {:ok, findings} = Image.Privacy.scan(image)

      assert %Finding{source: :xmp, kind: :document_id} = find(findings, :document_id)
      assert %Finding{kind: :document_id} = find(findings, :instance_id)

      assert %Finding{kind: :document_id, value: "5D903D5DFF6B5E302C70779408ABE193"} =
               find(findings, :original_document_id)
    end

    test "reports document ancestors and GPS coordinates" do
      image =
        with_xmp("""
        <rdf:RDF #{@rdf}>
          <rdf:Description
            xmlns:photoshop="http://ns.adobe.com/photoshop/1.0/"
            xmlns:exif="http://ns.adobe.com/exif/1.0/"
            exif:GPSLatitude="21,1.5N" exif:GPSLongitude="105,51.0E">
            <photoshop:DocumentAncestors>
              <rdf:Bag><rdf:li>xmp.did:one</rdf:li><rdf:li>xmp.did:two</rdf:li></rdf:Bag>
            </photoshop:DocumentAncestors>
          </rdf:Description>
        </rdf:RDF>
        """)

      assert {:ok, findings} = Image.Privacy.scan(image)

      assert %Finding{kind: :document_id, value: ["xmp.did:one", "xmp.did:two"]} =
               find(findings, :document_ancestors)

      assert %Finding{kind: :location, value: "21,1.5N"} = find(findings, :gps_latitude)
      assert %Finding{kind: :location, value: "105,51.0E"} = find(findings, :gps_longitude)
    end

    test "reports a generative AI source type as an AI label" do
      image = with_xmp(source_type_xmp("trainedAlgorithmicMedia"))

      assert {:ok, [%Finding{source: :xmp, field: :digital_source_type, kind: :ai_label}]} =
               Image.Privacy.scan(image)
    end

    test "reports another source type as provenance" do
      image = with_xmp(source_type_xmp("digitalCapture"))

      assert {:ok, [%Finding{field: :digital_source_type, kind: :provenance}]} =
               Image.Privacy.scan(image)
    end

    test "reports an XMP packet it cannot read" do
      assert {:ok, [%Finding{source: :xmp, kind: :unreadable, value: :invalid_xmp}]} =
               Image.Privacy.scan(with_xmp("<not xml"))
    end
  end

  describe "PNG text" do
    test "reports each text chunk by its keyword" do
      image =
        saved_with_fields(
          [{"png-comment-0-parameters", "a cat, seed 42"}, {"png-comment-1-Software", "Gen"}],
          ".png"
        )

      assert {:ok, findings} = Image.Privacy.scan(image)

      assert %Finding{source: :png_text, kind: :embedded_text, value: "a cat, seed 42"} =
               find(findings, "parameters")

      assert %Finding{source: :png_text, value: "Gen"} = find(findings, "Software")
    end
  end

  describe "scan/1" do
    test "returns findings in the order IPTC, EXIF, XMP" do
      assert {:ok, findings} = Image.Privacy.scan(Image.open!(image_path("Kip_small.jpg")))

      sources = Enum.map(findings, & &1.source)
      assert Enum.dedup(sources) == [:iptc, :exif, :xmp]
    end

    test "an image with no metadata has no findings" do
      assert {:ok, []} = Image.Privacy.scan(Image.new!(16, 16))
    end

    test "metadata removed with strip_metadata is no longer reported" do
      image = Image.open!(image_path("gain_map.jpg"))
      {:ok, binary} = Image.write(image, :memory, suffix: ".jpg", strip_metadata: true)

      assert {:ok, []} = Image.Privacy.scan(Image.open!(binary))
    end

    test "a value that is not an image, a path or a binary is an error" do
      assert {:error, %Image.Error{reason: :invalid_image, value: 42}} = Image.Privacy.scan(42)
    end

    test "a file that is not an image is an error" do
      path = Path.join(System.tmp_dir!(), "privacy_#{System.unique_integer([:positive])}.txt")
      File.write!(path, "plain text")

      assert {:error, %Image.Error{}} = Image.Privacy.scan(path)
    end
  end

  defp source_type_xmp(term) do
    """
    <rdf:RDF #{@rdf}>
      <rdf:Description xmlns:Iptc4xmpExt="http://iptc.org/std/Iptc4xmpExt/2008-02-29/">
        <Iptc4xmpExt:DigitalSourceType
          rdf:resource="http://cv.iptc.org/newscodes/digitalsourcetype/#{term}"/>
      </rdf:Description>
    </rdf:RDF>
    """
  end

  defp find(findings, field) do
    Enum.find(findings, &(&1.field == field))
  end

  defp find(findings, source, field) do
    Enum.find(findings, &(&1.source == source and &1.field == field))
  end
end
