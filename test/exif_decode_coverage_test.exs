defmodule Image.ExifDecodeCoverageTest do
  use ExUnit.Case, async: true

  import Image.TestSupport

  alias Image.Exif
  alias Image.Exif.{Gps, Thumbnail}

  # Builds a big-endian TIFF blob with a top-level IFD and optional
  # EXIF and GPS sub-IFDs, laying out out-of-line values after each IFD.

  defp blob(tiff_entries_fun, exif_entries \\ [], gps_entries \\ []) do
    header = <<0x4D, 0x4D, 42::16, 8::32>>

    # Pass 1 sizes the top-level IFD (entry values do not change its size).
    tiff_size = byte_size(ifd(tiff_entries_fun.(0, 0), 8))

    exif_offset = 8 + tiff_size
    exif_ifd = if exif_entries == [], do: <<>>, else: ifd(exif_entries, exif_offset)

    gps_offset = exif_offset + byte_size(exif_ifd)
    gps_ifd = if gps_entries == [], do: <<>>, else: ifd(gps_entries, gps_offset)

    tiff_ifd = ifd(tiff_entries_fun.(exif_offset, gps_offset), 8)

    header <> tiff_ifd <> exif_ifd <> gps_ifd
  end

  # Entries are {tag, format, count, {:inline, binary}} for values that
  # fit in four bytes or {tag, format, count, {:data, binary}} for values
  # stored out-of-line at an offset.

  defp ifd(entries, ifd_offset) do
    entry_count = length(entries)
    data_start = ifd_offset + 2 + entry_count * 12

    {entry_binaries, data} =
      Enum.map_reduce(entries, <<>>, fn {tag, format, count, value}, data_acc ->
        case value do
          {:inline, binary} ->
            {<<tag::16, format::16, count::32, pad4(binary)::binary>>, data_acc}

          {:data, binary} ->
            offset = data_start + byte_size(data_acc)
            {<<tag::16, format::16, count::32, offset::32>>, data_acc <> binary}
        end
      end)

    <<entry_count::16>> <> IO.iodata_to_binary(entry_binaries) <> data
  end

  defp pad4(binary) when byte_size(binary) >= 4, do: binary_part(binary, 0, 4)
  defp pad4(binary), do: binary <> :binary.copy(<<0>>, 4 - byte_size(binary))

  describe "extract_exif/1 with a comprehensive synthetic blob" do
    setup do
      tiff = fn exif_offset, gps_offset ->
        [
          {0x0100, 3, 1, {:inline, <<640::16>>}},
          {0x010F, 2, 6, {:data, "Canon" <> <<0>>}},
          {0x0112, 3, 1, {:inline, <<6::16>>}},
          {0x011A, 5, 1, {:data, <<300::32, 1::32>>}},
          {0x0128, 3, 1, {:inline, <<2::16>>}},
          {0x0132, 2, 20, {:data, "2004:09:11 16:06:57" <> <<0>>}},
          {0x0213, 3, 1, {:inline, <<1::16>>}},
          {0x8769, 4, 1, {:inline, <<exif_offset::32>>}},
          {0x8825, 4, 1, {:inline, <<gps_offset::32>>}}
        ]
      end

      exif = [
        {0x829A, 5, 1, {:data, <<1::32, 125::32>>}},
        {0x829D, 5, 1, {:data, <<28::32, 10::32>>}},
        {0x8822, 3, 1, {:inline, <<3::16>>}},
        {0x8827, 3, 1, {:inline, <<100::16>>}},
        {0x8830, 3, 1, {:inline, <<2::16>>}},
        {0x9000, 7, 4, {:inline, "0230"}},
        {0x9003, 2, 20, {:data, "2016:09:20 19:17:18" <> <<0>>}},
        {0x9101, 7, 4, {:inline, <<1, 2, 3, 0>>}},
        {0x9202, 5, 1, {:data, <<5::32, 0::32>>}},
        {0x9204, 10, 1, {:data, <<4_294_967_295::32, 3::32>>}},
        {0x9207, 3, 1, {:inline, <<5::16>>}},
        {0x9209, 3, 1, {:inline, <<0x19::16>>}},
        {0xA000, 2, 5, {:data, "0100" <> <<0>>}},
        {0xA001, 3, 1, {:inline, <<1::16>>}},
        {0xA002, 4, 1, {:inline, <<300::32>>}},
        {0xA210, 3, 1, {:inline, <<2::16>>}},
        {0xA217, 3, 1, {:inline, <<2::16>>}},
        {0xA300, 7, 1, {:inline, <<3>>}},
        {0xA301, 7, 1, {:inline, <<1>>}},
        {0xA401, 3, 1, {:inline, <<0::16>>}},
        {0xA402, 3, 1, {:inline, <<1::16>>}},
        {0xA403, 3, 1, {:inline, <<0::16>>}},
        {0xA406, 3, 1, {:inline, <<2::16>>}},
        {0xA407, 3, 1, {:inline, <<1::16>>}},
        {0xA408, 3, 1, {:inline, <<2::16>>}},
        {0xA409, 3, 1, {:inline, <<1::16>>}},
        {0xA40A, 3, 1, {:inline, <<2::16>>}},
        {0xA40C, 3, 1, {:inline, <<3::16>>}},
        {0xA432, 5, 2, {:data, <<24::32, 1::32, 70::32, 1::32>>}},
        {0x0201, 4, 1, {:inline, <<1000::32>>}},
        {0x0202, 4, 1, {:inline, <<2000::32>>}}
      ]

      gps = [
        {1, 2, 2, {:inline, "N" <> <<0>>}},
        {2, 5, 3, {:data, <<41::32, 1::32, 23::32, 1::32, 16_019::32, 1000::32>>}},
        {3, 2, 2, {:inline, "E" <> <<0>>}},
        {4, 5, 3, {:data, <<2::32, 1::32, 11::32, 1::32, 49_584::32, 1000::32>>}}
      ]

      {:ok, result: Exif.extract_exif(blob(tiff, exif, gps))}
    end

    test "decodes top-level tiff tags", %{result: result} do
      assert result.image_width == 640
      assert result.make == "Canon"
      assert result.orientation == "Rotate 90 CW"
      assert result.x_resolution == 300
      assert result.resolution_units == "Pixels/in"
      assert result.modify_date == ~N[2004-09-11 16:06:57]
      assert result."YCbCr_positioning" == "Centered"
    end

    test "decodes rational values in their several shapes", %{result: result} do
      assert result.exif.exposure_time == "1/125"
      assert result.exif.f_number == 2.8
      assert result.exif.aperture_value == :infinity
      assert result.exif.exposure_bias_value == -0.333
      assert result.exif.lens_info == [24, 70]
    end

    test "decodes enumerated exif tags to human readable strings", %{result: result} do
      assert result.exif.exposure_program == "Aperture-priority AE"
      assert result.exif.iso_speed_ratings == 100
      assert result.exif.sensitivity_type == "Recommended Exposure Index"
      assert result.exif.metering_mode == "Multi-segment"
      assert result.exif.flash == "Auto, Fired"
      assert result.exif.color_space == "sRGB"
      assert result.exif.exif_image_width == 300
      assert result.exif.focal_plane_resolution_unit == "inches"
      assert result.exif.sensing_method == "One-chip color area"
      assert result.exif.file_source == "Digital Camera"
      assert result.exif.scene_type == "Directly photographed"
      assert result.exif.custom_rendered == "Normal"
      assert result.exif.exposure_mode == "Manual"
      assert result.exif.white_balance == "Auto"
      assert result.exif.scene_capture_type == "Portrait"
      assert result.exif.gain_control == "Low gain up"
      assert result.exif.contrast == "High"
      assert result.exif.saturation == "Low"
      assert result.exif.sharpness == "Hard"
      assert result.exif.subject_distance_range == "Distant"
    end

    test "decodes version tags", %{result: result} do
      assert result.exif.exif_version == "2.30"
      assert result.exif.flash_pix_version == "1.00"
    end

    test "decodes the component configuration", %{result: result} do
      assert result.exif.component_configuration == "Y,Cb,Cr,-"
    end

    test "decodes datetimes", %{result: result} do
      assert result.exif.datetime_original == ~N[2016-09-20 19:17:18]
    end

    test "decodes the GPS sub-IFD into a Gps struct", %{result: result} do
      assert %Gps{} = result.gps
      assert result.gps.gps_latitude_ref == "N"
      assert result.gps.gps_latitude == [41, 23, 16.019]
      assert result.gps.gps_longitude_ref == "E"
      assert result.gps.gps_longitude == [2, 11, 49.584]
    end

    test "formats GPS coordinates as a human readable string", %{result: result} do
      assert to_string(result.gps) == "41°23´16˝N,2°11´50˝E"
      assert Gps.inspect(result.gps) == "41°23´16˝N,2°11´50˝E"
    end

    test "extracts the thumbnail fields into a Thumbnail struct", %{result: result} do
      assert result.thumbnail == %Thumbnail{thumbnail_offset: 1000, thumbnail_size: 2000}
      refute Map.has_key?(result.exif, :thumbnail_offset)
      refute Map.has_key?(result.exif, :thumbnail_size)
      assert to_string(result.thumbnail) == "Image Thumbnail of size 2000"
    end
  end

  describe "extract_exif/1 byte order and malformed structure handling" do
    test "decodes a little-endian blob" do
      little =
        <<0x49, 0x49, 42::little-16, 8::little-32, 1::little-16, 0x0112::little-16, 3::little-16,
          1::little-32, 3::little-16, 0::16>>

      assert Exif.extract_exif(little) == %{orientation: "Rotate 180"}
    end

    test "an unknown tag is reported with its hex id and inspected value" do
      tiff = fn _, _ -> [{0xEEEE, 3, 1, {:inline, <<7::16>>}}] end
      assert Exif.extract_exif(blob(tiff)) == %{"tiff tag(0xEEEE)" => "7"}
    end

    test "an unknown tag format produces a nil value" do
      tiff = fn _, _ -> [{0x0100, 99, 1, {:inline, <<7::16>>}}] end
      assert Exif.extract_exif(blob(tiff)) == %{image_width: nil}
    end

    test "a truncated IFD returns the tags read so far" do
      truncated =
        <<0x4D, 0x4D, 42::16, 8::32, 5::16, 0x0112::16, 3::16, 1::32, 3::16, 0::16>>

      assert Exif.extract_exif(truncated) == %{orientation: "Rotate 180"}
    end

    test "an exif pointer past the end of the blob yields an empty exif map" do
      tiff = fn _, _ -> [{0x8769, 4, 1, {:inline, <<0xFFFF::32>>}}] end
      assert Exif.extract_exif(blob(tiff)) == %{exif: %{}}
    end

    test "an exif pointer with an undecodable format yields an empty exif map" do
      tiff = fn _, _ -> [{0x8769, 99, 1, {:inline, <<0::32>>}}] end
      assert Exif.extract_exif(blob(tiff)) == %{exif: %{}}
    end

    test "a gps pointer past the end of the blob yields an empty Gps struct" do
      tiff = fn _, _ -> [{0x8825, 4, 1, {:inline, <<0xFFFF::32>>}}] end
      assert Exif.extract_exif(blob(tiff)) == %{gps: %Gps{}}
    end

    test "a gps pointer with an undecodable format yields an empty Gps struct" do
      tiff = fn _, _ -> [{0x8825, 99, 1, {:inline, <<0::32>>}}] end
      assert Exif.extract_exif(blob(tiff)) == %{gps: %Gps{}}
    end
  end

  describe "extract_exif/1 value decoding edge cases" do
    test "unknown enumeration values decode to Unknown" do
      tiff = fn _, _ ->
        [
          {0x0112, 3, 1, {:inline, <<9::16>>}},
          {0x0128, 3, 1, {:inline, <<9::16>>}},
          {0x0213, 3, 1, {:inline, <<9::16>>}}
        ]
      end

      exif = [
        {0x8822, 3, 1, {:inline, <<99::16>>}},
        {0x8830, 3, 1, {:inline, <<99::16>>}},
        {0x9207, 3, 1, {:inline, <<99::16>>}},
        {0x9209, 3, 1, {:inline, <<0x99::16>>}},
        {0xA001, 3, 1, {:inline, <<3::16>>}},
        {0xA210, 3, 1, {:inline, <<9::16>>}},
        {0xA217, 3, 1, {:inline, <<9::16>>}},
        {0xA300, 7, 1, {:inline, <<9>>}},
        {0xA301, 7, 1, {:inline, <<9>>}},
        {0xA401, 3, 1, {:inline, <<9::16>>}},
        {0xA402, 3, 1, {:inline, <<9::16>>}},
        {0xA403, 3, 1, {:inline, <<9::16>>}},
        {0xA406, 3, 1, {:inline, <<9::16>>}},
        {0xA407, 3, 1, {:inline, <<9::16>>}},
        {0xA408, 3, 1, {:inline, <<9::16>>}},
        {0xA409, 3, 1, {:inline, <<9::16>>}},
        {0xA40A, 3, 1, {:inline, <<9::16>>}},
        {0xA40C, 3, 1, {:inline, <<9::16>>}}
      ]

      tiff_with_exif = fn exif_offset, _ ->
        tiff.(0, 0) ++ [{0x8769, 4, 1, {:inline, <<exif_offset::32>>}}]
      end

      result = Exif.extract_exif(blob(tiff_with_exif, exif))

      assert result.orientation == "Unknown (9)"
      assert result.resolution_units == "Unknown (9)"
      assert result."YCbCr_positioning" == "Unknown (9)"
      assert result.exif.exposure_program == "Unknown (99)"
      assert result.exif.sensitivity_type == "Unknown (99)"
      assert result.exif.metering_mode == "Unknown (99)"
      assert result.exif.flash == "Unknown (153)"
      assert result.exif.color_space == "Unknown (3)"
      assert result.exif.focal_plane_resolution_unit == "Unknown (9)"
      assert result.exif.sensing_method == "Unknown (9)"
      assert result.exif.file_source == "Unknown (9)"
      assert result.exif.scene_type == "Unknown (9)"
      assert result.exif.custom_rendered == "Unknown (9)"
      assert result.exif.exposure_mode == "Unknown (9)"
      assert result.exif.white_balance == "Unknown (9)"
      assert result.exif.scene_capture_type == "Unknown (9)"
      assert result.exif.gain_control == "Unknown (9)"
      assert result.exif.contrast == "Unknown (9)"
      assert result.exif.saturation == "Unknown (9)"
      assert result.exif.sharpness == "Unknown (9)"
      assert result.exif.subject_distance_range == "Unknown (9)"
    end

    test "additional colour space and file source values" do
      exif = [
        {0xA001, 3, 1, {:inline, <<2::16>>}},
        {0xA300, 4, 1, {:inline, <<0x03000000::32>>}}
      ]

      tiff = fn exif_offset, _ -> [{0x8769, 4, 1, {:inline, <<exif_offset::32>>}}] end
      result = Exif.extract_exif(blob(tiff, exif))

      assert result.exif.color_space == "Adobe RGB"
      assert result.exif.file_source == "Sigma Digital Camera"
    end

    test "an all-null string value is trimmed to nil" do
      tiff = fn _, _ -> [{0x010E, 2, 4, {:inline, <<0, 0, 0, 0>>}}] end
      assert Exif.extract_exif(blob(tiff)) == %{image_description: nil}
    end

    test "an unparseable datetime is returned as a string" do
      tiff = fn _, _ -> [{0x0132, 2, 20, {:data, "2004:99:99 99:99:99" <> <<0>>}}] end
      assert Exif.extract_exif(blob(tiff)) == %{modify_date: "2004:99:99 99:99:99"}
    end

    test "a non-datetime string is returned as-is" do
      tiff = fn _, _ -> [{0x0132, 2, 11, {:data, "not a date" <> <<0>>}}] end
      assert Exif.extract_exif(blob(tiff)) == %{modify_date: "not a date"}
    end

    test "a malformed version value decodes to Unknown" do
      exif = [{0x9000, 7, 2, {:inline, <<1, 2>>}}]
      tiff = fn exif_offset, _ -> [{0x8769, 4, 1, {:inline, <<exif_offset::32>>}}] end

      result = Exif.extract_exif(blob(tiff, exif))
      assert result.exif.exif_version == "Unknown [1, 2]"
    end

    test "a version with a non-zero leading digit keeps both major digits" do
      exif = [{0x9000, 7, 4, {:inline, "1230"}}]
      tiff = fn exif_offset, _ -> [{0x8769, 4, 1, {:inline, <<exif_offset::32>>}}] end

      result = Exif.extract_exif(blob(tiff, exif))
      assert result.exif.exif_version == "12.30"
    end

    test "component configuration with out-of-range components is Unknown" do
      exif = [{0x9101, 7, 4, {:inline, <<9, 2, 3, 0>>}}]
      tiff = fn exif_offset, _ -> [{0x8769, 4, 1, {:inline, <<exif_offset::32>>}}] end

      result = Exif.extract_exif(blob(tiff, exif))
      assert result.exif.component_configuration == "Unknown [9, 2, 3, 0]"
    end

    test "component configuration with a non-list value is Unknown" do
      exif = [{0x9101, 3, 1, {:inline, <<1::16>>}}]
      tiff = fn exif_offset, _ -> [{0x8769, 4, 1, {:inline, <<exif_offset::32>>}}] end

      result = Exif.extract_exif(blob(tiff, exif))
      assert result.exif.component_configuration == "Unknown 1"
    end
  end

  describe "Gps struct formatting" do
    test "inspect of a Gps struct without a latitude is empty" do
      assert Gps.inspect(%Gps{}) == ""
      assert to_string(%Gps{}) == ""
    end

    test "inspect of a Gps struct without a longitude is empty" do
      assert Gps.inspect(%Gps{gps_latitude: [1, 2, 3.0]}) == ""
    end

    test "inspect defaults missing hemisphere references to N" do
      gps = %Gps{gps_latitude: [41, 23, 16.0], gps_longitude: [2, 11, 49.6]}
      assert Gps.inspect(gps) == "41°23´16˝N,2°11´50˝N"
    end
  end

  describe "Thumbnail extraction to a file" do
    test "returns an error when the thumbnail fields are missing" do
      assert Thumbnail.to_image("any.jpg", %Thumbnail{}) == {:error, :bad_thumbnail_data}

      assert Thumbnail.to_image("any.jpg", %Thumbnail{thumbnail_offset: 10}) ==
               {:error, :bad_thumbnail_data}

      assert Thumbnail.to_image("any.jpg", %Thumbnail{thumbnail_size: 10}) ==
               {:error, :bad_thumbnail_data}
    end

    test "writes the thumbnail bytes to a -thumb suffixed file" do
      Temp.track!()
      dir = Temp.mkdir!()
      source_path = Path.join(dir, "source.jpg")
      File.write!(source_path, "0123456789ABCDEF")

      thumbnail = %Thumbnail{thumbnail_offset: 4, thumbnail_size: 6}
      assert Thumbnail.to_image(source_path, thumbnail) == :ok

      thumb_path = Path.join(dir, "source-thumb.jpg")
      assert File.read!(thumb_path) == "456789"
    end
  end

  describe "EXIF from real images" do
    test "decodes camera metadata from Kip_small.jpg" do
      {:ok, image} = Image.open(image_path("Kip_small.jpg"))
      assert {:ok, exif} = Image.exif(image)

      assert exif.make == "Canon"
      assert exif.model == "Canon EOS-1DS"
      assert exif.orientation == "Horizontal (normal)"
      assert exif.artist == "Kip Cole"
      assert exif.copyright == "Copyright (c) Kip Cole 2012"
      assert exif.modify_date == ~N[2004-09-11 16:06:57]

      assert exif.exif.exposure_time == "1/125"
      assert exif.exif.f_number == 9
      assert exif.exif.iso_speed_ratings == 100
      assert exif.exif.exif_version == "2.21"
      assert exif.exif.flash == "No Flash"
      assert exif.exif.metering_mode == "Partial"
      assert exif.exif.exposure_program == "Manual"
    end

    test "decodes a GPS sub-IFD from Singapore-2016-09-5887.jpg" do
      {:ok, image} = Image.open(image_path("Singapore-2016-09-5887.jpg"))
      assert {:ok, exif} = Image.exif(image)

      assert %Gps{} = exif.gps
      assert exif.gps.gps_map_datum == "WGS-84"
      assert exif.gps.gps_status == "V"
      assert exif.exif.exif_version == "2.31"
    end

    test "returns an error for an image without EXIF data" do
      {:ok, image} = Image.open(image_path("dark.jpeg"))
      assert {:error, _reason} = Image.exif(image)
    end
  end

  describe "get_metadata/2 and put_metadata/3" do
    test "gets a known metadata header" do
      {:ok, image} = Image.open(image_path("Kip_small.jpg"))
      assert {:ok, artist} = Exif.get_metadata(image, :artist)
      assert artist =~ "Kip Cole"

      assert {:ok, copyright} = Exif.get_metadata(image, :copyright)
      assert copyright =~ "Copyright (c) Kip Cole 2012"
    end

    test "gets nil for a missing metadata header" do
      {:ok, image} = Image.open(image_path("Kip_small.jpg"))
      assert Exif.get_metadata(image, "no-such-header") == {:ok, nil}
    end

    test "put_metadata is a no-op for nil and empty values" do
      assert Exif.put_metadata(:not_used, :artist, nil) == :ok
      assert Exif.put_metadata(:not_used, :artist, "") == :ok
    end

    test "put_metadata sets a header on a mutable image" do
      {:ok, image} = Image.open(image_path("Kip_small.jpg"))

      assert {:ok, updated} =
               Image.mutate(image, fn mutable ->
                 Exif.put_metadata(mutable, :artist, "New Artist")
               end)

      assert Exif.get_metadata(updated, :artist) == {:ok, "New Artist"}
    end
  end

  describe "field/1" do
    test "maps known aliases to libvips header names" do
      assert Exif.field(:artist) == "exif-ifd0-Artist"
      assert Exif.field(:copyright) == "exif-ifd0-Copyright"
      assert Exif.field("custom-header") == "custom-header"
      assert Exif.field(:other) == "other"
    end
  end
end
