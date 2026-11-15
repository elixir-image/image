defmodule Image.ExifDecodeGapTest do
  use ExUnit.Case, async: true

  alias Image.Exif.Decode

  describe "tag/3 pass-through tag table entries" do
    test "tiff tags that carry their value unchanged" do
      assert Decode.tag(:tiff, 0x0101, 480) == {:image_height, 480}
      assert Decode.tag(:tiff, 0x010D, "scan.tif") == {:document_name, "scan.tif"}
      assert Decode.tag(:tiff, 0xC4A5, "PIM") == {:print_image_matching, "PIM"}
      assert Decode.tag(:tiff, 0xC7A1, "Camera A") == {:camera_label, "Camera A"}
    end

    test "exif tags that carry their value unchanged" do
      assert Decode.tag(:exif, 0x8824, "sensitivity") == {:spectral_sensitivity, "sensitivity"}
      assert Decode.tag(:exif, 0x8828, "oecf") == {:oecf, "oecf"}
      assert Decode.tag(:exif, 0x8831, 200) == {:standard_output_sensitivity, 200}
      assert Decode.tag(:exif, 0x9011, "+10:00") == {:datetime_original_offset, "+10:00"}
      assert Decode.tag(:exif, 0x9012, "+10:00") == {:datetime_digitized_offset, "+10:00"}
      assert Decode.tag(:exif, 0x9211, 42) == {:image_number, 42}
      assert Decode.tag(:exif, 0x9214, [1, 2, 3, 4]) == {:subject_area, [1, 2, 3, 4]}
      assert Decode.tag(:exif, 0x9286, "a comment") == {:user_comment, "a comment"}
      assert Decode.tag(:exif, 0x9290, "123") == {:subsec_time, "123"}
      assert Decode.tag(:exif, 0xA004, "SND00001.WAV") == {:related_sound_file, "SND00001.WAV"}
      assert Decode.tag(:exif, 0xA005, 1234) == {:interopt_offset, 1234}
      assert Decode.tag(:exif, 0xA20B, 5) == {:flash_energy, 5}
      assert Decode.tag(:exif, 0xA20C, 7) == {:spatial_frequency_response, 7}
      assert Decode.tag(:exif, 0xA214, [10, 20]) == {:subject_location, [10, 20]}
      assert Decode.tag(:exif, 0xA215, 100) == {:exposure_index, 100}
      assert Decode.tag(:exif, 0xA302, <<2, 2>>) == {:cfa_pattern, <<2, 2>>}
      assert Decode.tag(:exif, 0xA404, 2.0) == {:digital_zoom_ratio, 2.0}
      assert Decode.tag(:exif, 0xA405, 50) == {:focal_length_in_35mm_film, 50}
      assert Decode.tag(:exif, 0xA40B, "settings") == {:device_setting_description, "settings"}
      assert Decode.tag(:exif, 0xA420, "abc123") == {:image_unique_id, "abc123"}
      assert Decode.tag(:exif, 0xA433, "Zeiss") == {:lens_make, "Zeiss"}
      assert Decode.tag(:exif, 0xA436, "Title") == {:image_title, "Title"}
      assert Decode.tag(:exif, 0xFDEA, "50mm f/1.4") == {:lens, "50mm f/1.4"}
    end
  end

  describe "tag/3 with nil values from malformed offsets" do
    test "datetime tags decode nil to nil" do
      assert Decode.tag(:tiff, 0x0132, nil) == {:modify_date, nil}
    end

    test "string tags trim nil to nil" do
      assert Decode.tag(:tiff, 0x010E, nil) == {:image_description, nil}
      assert Decode.trim(nil) == nil
    end
  end

  describe "tag/3 enumeration decodes" do
    test "orientation values" do
      for {value, expected} <- [
            {2, "Mirror horizontal"},
            {4, "Mirror vertical"},
            {5, "Mirror horizontal and rotate 270 CW"},
            {7, "Mirror horizontal and rotate 90 CW"},
            {8, "Rotate 270 CW"}
          ] do
        assert Decode.tag(:tiff, 0x0112, value) == {:orientation, expected}
      end
    end

    test "resolution units" do
      assert Decode.tag(:tiff, 0x0128, 1) == {:resolution_units, "None"}
      assert Decode.tag(:tiff, 0x0128, 3) == {:resolution_units, "Pixels/cm"}
    end

    test "exposure programs" do
      for {value, expected} <- [
            {2, "Program AE"},
            {4, "Shutter speed priority AE"},
            {5, "Creative (Slow speed)"},
            {6, "Action (High speed)"},
            {7, "Portrait"},
            {8, "Landscape"},
            {9, "Bulb"}
          ] do
        assert Decode.tag(:exif, 0x8822, value) == {:exposure_program, expected}
      end
    end

    test "sensitivity types" do
      for {value, expected} <- [
            {1, "Standard Output Sensitivity"},
            {3, "ISO Speed"},
            {4, "Standard Output Sensitivity and Recommended Exposure Index"},
            {5, "Standard Output Sensitivity and ISO Speed"},
            {6, "Recommended Exposure Index and ISO Speed"},
            {7, "Standard Output Sensitivity, Recommended Exposure Index and ISO Speed"}
          ] do
        assert Decode.tag(:exif, 0x8830, value) == {:sensitivity_type, expected}
      end
    end

    test "metering modes" do
      assert Decode.tag(:exif, 0x9207, 1) == {:metering_mode, "Average"}
      assert Decode.tag(:exif, 0x9207, 3) == {:metering_mode, "Spot"}
      assert Decode.tag(:exif, 0x9207, 4) == {:metering_mode, "Multi-spot"}
    end

    test "color spaces" do
      assert Decode.tag(:exif, 0xA001, 0xFFFD) == {:color_space, "Wide Gamut RGB"}
      assert Decode.tag(:exif, 0xA001, 0xFFFE) == {:color_space, "ICC Profile"}
    end

    test "focal plane resolution units" do
      assert Decode.tag(:exif, 0xA210, 1) == {:focal_plane_resolution_unit, "None"}
      assert Decode.tag(:exif, 0xA210, 4) == {:focal_plane_resolution_unit, "mm"}
      assert Decode.tag(:exif, 0xA210, 5) == {:focal_plane_resolution_unit, "um"}
    end

    test "sensing methods" do
      for {value, expected} <- [
            {1, "Not defined"},
            {3, "Two-chip color area"},
            {4, "Three-chip color area"},
            {5, "Color sequential area"},
            {7, "Trilinear"},
            {8, "Color sequential linear"}
          ] do
        assert Decode.tag(:exif, 0xA217, value) == {:sensing_method, expected}
      end
    end

    test "file sources" do
      assert Decode.tag(:exif, 0xA300, 1) == {:file_source, "Film Scanner"}
      assert Decode.tag(:exif, 0xA300, 2) == {:file_source, "Reflection Print Scanner"}
    end

    test "custom rendered" do
      assert Decode.tag(:exif, 0xA401, 1) == {:custom_rendered, "Custom"}
    end

    test "exposure modes" do
      assert Decode.tag(:exif, 0xA402, 2) == {:exposure_mode, "Auto bracket"}
    end

    test "white balance" do
      assert Decode.tag(:exif, 0xA403, 1) == {:white_balance, "Manual"}
    end

    test "scene capture types" do
      assert Decode.tag(:exif, 0xA406, 1) == {:scene_capture_type, "Landscape"}
      assert Decode.tag(:exif, 0xA406, 3) == {:scene_capture_type, "Night"}
    end

    test "gain control" do
      for {value, expected} <- [
            {0, "None"},
            {2, "High gain up"},
            {3, "Low gain down"},
            {4, "High gain down"}
          ] do
        assert Decode.tag(:exif, 0xA407, value) == {:gain_control, expected}
      end
    end

    test "contrast, saturation and sharpness" do
      assert Decode.tag(:exif, 0xA408, 0) == {:contrast, "Normal"}
      assert Decode.tag(:exif, 0xA408, 1) == {:contrast, "Low"}
      assert Decode.tag(:exif, 0xA409, 0) == {:saturation, "Normal"}
      assert Decode.tag(:exif, 0xA409, 2) == {:saturation, "High"}
      assert Decode.tag(:exif, 0xA40A, 0) == {:sharpness, "Normal"}
      assert Decode.tag(:exif, 0xA40A, 1) == {:sharpness, "Soft"}
    end

    test "subject distance ranges" do
      assert Decode.tag(:exif, 0xA40C, 0) == {:subject_distance_range, "Unknown"}
      assert Decode.tag(:exif, 0xA40C, 1) == {:subject_distance_range, "Macro"}
      assert Decode.tag(:exif, 0xA40C, 2) == {:subject_distance_range, "Close"}
    end

    test "flash values" do
      for {value, expected} <- [
            {0x5, "Fired, Return not detected"},
            {0x7, "Fired, Return detected"},
            {0x8, "On, Did not fire"},
            {0x9, "On, Fired"},
            {0xD, "On, Return not detected"},
            {0xF, "On, Return detected"},
            {0x14, "Off, Did not fire, Return not detected"},
            {0x18, "Auto, Did not fire"},
            {0x1D, "Auto, Fired, Return not detected"},
            {0x1F, "Auto, Fired, Return detected"},
            {0x20, "No flash function"},
            {0x30, "Off, No flash function"},
            {0x41, "Fired, Red-eye reduction"},
            {0x45, "Fired, Red-eye reduction, Return not detected"},
            {0x47, "Fired, Red-eye reduction, Return detected"},
            {0x49, "On, Red-eye reduction"},
            {0x4D, "On, Red-eye reduction, Return not detected"},
            {0x4F, "On, Red-eye reduction, Return detected"},
            {0x50, "Off, Red-eye reduction"},
            {0x58, "Auto, Did not fire, Red-eye reduction"},
            {0x59, "Auto, Fired, Red-eye reduction"},
            {0x5D, "Auto, Fired, Red-eye reduction, Return not detected"},
            {0x5F, "Auto, Fired, Red-eye reduction, Return detected"}
          ] do
        assert Decode.tag(:exif, 0x9209, value) == {:flash, expected}
      end
    end

    test "YCbCr positioning" do
      assert Decode.tag(:tiff, 0x0213, 2) == {:YCbCr_positioning, "Co-sited"}
    end

    test "a binary version with a non-zero leading digit keeps both major digits" do
      assert Decode.tag(:exif, 0x9000, "1230") == {:exif_version, "12.30"}
      assert Decode.tag(:exif, 0x9000, [?1, ?2, ?3, ?0]) == {:exif_version, "12.30"}
    end
  end

  describe "tag/3 identifying text tags" do
    test "UserComment in ASCII drops its code and padding" do
      value = ~c"ASCII" ++ [0, 0, 0] ++ ~c"call me" ++ [0, 32, 0]
      assert Decode.tag(:exif, 0x9286, value) == {:user_comment, "call me"}
    end

    test "UserComment in UNICODE is read in either byte order" do
      big = ~c"UNICODE" ++ [0, 0, 72, 0, 105]
      little = ~c"UNICODE" ++ [0, 72, 0, 105, 0]

      assert Decode.tag(:exif, 0x9286, big) == {:user_comment, "Hi"}
      assert Decode.tag(:exif, 0x9286, little) == {:user_comment, "Hi"}
    end

    test "UserComment with an undefined code is read as text" do
      value = List.duplicate(0, 8) ++ ~c"note"
      assert Decode.tag(:exif, 0x9286, value) == {:user_comment, "note"}
    end

    test "UserComment that is only padding is nil" do
      value = List.duplicate(0, 8) ++ [32, 32, 0, 32, 0]
      assert Decode.tag(:exif, 0x9286, value) == {:user_comment, nil}
    end

    test "UserComment text that is not UTF-8 is read as Latin-1" do
      value = ~c"ASCII" ++ [0, 0, 0] ++ ~c"caf" ++ [0xE9]
      assert Decode.tag(:exif, 0x9286, value) == {:user_comment, "café"}
    end

    test "UserComment in JIS or with no code is kept as it is" do
      jis = ~c"JIS" ++ [0, 0, 0, 0, 0, 1, 2]

      assert Decode.tag(:exif, 0x9286, jis) == {:user_comment, <<"JIS", 0, 0, 0, 0, 0, 1, 2>>}
      assert Decode.tag(:exif, 0x9286, [1, 300]) == {:user_comment, [1, 300]}
      assert Decode.tag(:exif, 0x9286, nil) == {:user_comment, nil}
    end

    test "Windows XP tags are read as UTF-16LE" do
      author = [74, 0, 97, 0, 110, 0, 101, 0, 0, 0]

      assert Decode.tag(:tiff, 0x9C9D, author) == {:xp_author, "Jane"}
      assert Decode.tag(:tiff, 0x9C9C, [104, 0, 105, 0]) == {:xp_comment, "hi"}
      assert Decode.tag(:tiff, 0x9C9B, [84, 0]) == {:xp_title, "T"}
      assert Decode.tag(:tiff, 0x9C9E, [107, 0]) == {:xp_keywords, "k"}
      assert Decode.tag(:tiff, 0x9C9F, [115, 0]) == {:xp_subject, "s"}
    end

    test "a Windows XP tag with an incomplete code unit keeps the text before it" do
      assert Decode.tag(:tiff, 0x9C9D, [74, 0, 97]) == {:xp_author, "J"}
    end

    test "host computer, photographer, image editor and camera serial number" do
      assert Decode.tag(:tiff, 0x013C, "Janes-MacBook ") == {:host_computer, "Janes-MacBook"}
      assert Decode.tag(:exif, 0xA437, "Pat") == {:photographer, "Pat"}
      assert Decode.tag(:exif, 0xA438, "Sam") == {:image_editor, "Sam"}
      assert Decode.tag(:tiff, 0xC62F, "DNG123") == {:camera_serial_number, "DNG123"}
    end

    test "a text tag stored with another type does not raise" do
      assert Decode.tag(:tiff, 0x013B, 42) == {:artist, 42}
      assert Decode.tag(:tiff, 0x013B, [65, 110, 110, 0]) == {:artist, "Ann"}
      assert Decode.tag(:tiff, 0x013B, [1, 300]) == {:artist, [1, 300]}
    end
  end
end
