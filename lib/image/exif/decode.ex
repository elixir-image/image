defmodule Image.Exif.Decode do
  @moduledoc false

  # Decode tags and (in some cases) their parameters.
  # Reference for tags: https://exiftool.org/TagNames/EXIF.html

  alias Image.Exif.Gps

  @doc "Returns the decoded and humanized tag out of raw exif representation."

  @spec tag(atom(), non_neg_integer(), value) :: {atom | <<_::64, _::_*8>>, value}
        when value: binary() | float() | non_neg_integer()

  def tag(:tiff, 0x0100, value), do: {:image_width, value}
  def tag(:tiff, 0x0101, value), do: {:image_height, value}
  def tag(:tiff, 0x010D, value), do: {:document_name, value}
  def tag(:tiff, 0x010E, value), do: {:image_description, trim(value)}
  def tag(:tiff, 0x010F, value), do: {:make, trim(value)}
  def tag(:tiff, 0x0110, value), do: {:model, trim(value)}
  def tag(:tiff, 0x0112, value), do: {:orientation, orientation(value)}
  def tag(:tiff, 0x011A, value), do: {:x_resolution, value}
  def tag(:tiff, 0x011B, value), do: {:y_resolution, value}
  def tag(:tiff, 0x0128, value), do: {:resolution_units, resolution(value)}
  def tag(:tiff, 0x0131, value), do: {:software, trim(value)}
  def tag(:tiff, 0x0132, value), do: {:modify_date, date_time(value)}
  def tag(:tiff, 0x0213, value), do: {:YCbCr_positioning, ycbcr_positioning(value)}

  def tag(:tiff, 0x8769, value), do: {:exif, value}
  def tag(:tiff, 0x8825, value), do: {:gps, value}

  def tag(:tiff, 0xC4A5, value), do: {:print_image_matching, value}
  def tag(:tiff, 0xC7A1, value), do: {:camera_label, value}

  def tag(:exif, 0x0201, value), do: {:thumbnail_offset, value}
  def tag(:exif, 0x0202, value), do: {:thumbnail_size, value}

  def tag(_, 0x013B, value), do: {:artist, trim(value)}
  def tag(_, 0x8298, value), do: {:copyright, trim(value)}
  def tag(_, 0x829A, value), do: {:exposure_time, value}
  def tag(_, 0x829D, value), do: {:f_number, value}
  def tag(_, 0x8822, value), do: {:exposure_program, exposure_program(value)}
  def tag(_, 0x8824, value), do: {:spectral_sensitivity, value}
  def tag(_, 0x8827, value), do: {:iso_speed_ratings, value}
  def tag(_, 0x8828, value), do: {:oecf, value}
  def tag(_, 0x8830, value), do: {:sensitivity_type, sensitivity_type(value)}
  def tag(_, 0x8831, value), do: {:standard_output_sensitivity, value}
  def tag(_, 0x8832, value), do: {:recommended_exposure, value}
  def tag(_, 0x9000, value), do: {:exif_version, version(value)}
  def tag(_, 0x9003, value), do: {:datetime_original, date_time(value)}
  def tag(_, 0x9004, value), do: {:datetime_digitized, date_time(value)}
  def tag(_, 0x9010, value), do: {:time_offset, value}
  def tag(_, 0x9011, value), do: {:datetime_original_offset, value}
  def tag(_, 0x9012, value), do: {:datetime_digitized_offset, value}
  def tag(_, 0x9101, value), do: {:component_configuration, component_configuration(value)}
  def tag(_, 0x9102, value), do: {:compressed_bits_per_pixel, value}
  def tag(_, 0x9201, value), do: {:shutter_speed_value, value}
  def tag(_, 0x9202, value), do: {:aperture_value, value}
  def tag(_, 0x9203, value), do: {:brightness_value, value}
  def tag(_, 0x9204, value), do: {:exposure_bias_value, value}
  def tag(_, 0x9205, value), do: {:max_aperture_value, value}
  def tag(_, 0x9206, value), do: {:subject_distance, value}
  def tag(_, 0x9207, value), do: {:metering_mode, metering_mode(value)}
  def tag(_, 0x9208, value), do: {:light_source, value}
  def tag(_, 0x9209, value), do: {:flash, flash(value)}
  def tag(_, 0x920A, value), do: {:focal_length, value}
  def tag(_, 0x9211, value), do: {:image_number, value}
  def tag(_, 0x9214, value), do: {:subject_area, value}
  def tag(_, 0x927C, value), do: {:maker_note, value}
  def tag(_, 0x9286, value), do: {:user_comment, value}
  def tag(_, 0x9290, value), do: {:subsec_time, value}
  def tag(_, 0x9291, value), do: {:subsec_time_original, value}
  def tag(_, 0x9292, value), do: {:subsec_time_digitized, value}
  def tag(_, 0xA000, value), do: {:flash_pix_version, version(value)}
  def tag(_, 0xA001, value), do: {:color_space, color_space(value)}
  def tag(_, 0xA002, value), do: {:exif_image_width, value}
  def tag(_, 0xA003, value), do: {:exif_image_height, value}
  def tag(_, 0xA004, value), do: {:related_sound_file, value}
  def tag(_, 0xA005, value), do: {:interopt_offset, value}
  def tag(_, 0xA20B, value), do: {:flash_energy, value}
  def tag(_, 0xA20C, value), do: {:spatial_frequency_response, value}
  def tag(_, 0xA20E, value), do: {:focal_plane_x_resolution, value}
  def tag(_, 0xA20F, value), do: {:focal_plane_y_resolution, value}

  def tag(_, 0xA210, value),
    do: {:focal_plane_resolution_unit, focal_plane_resolution_unit(value)}

  def tag(_, 0xA214, value), do: {:subject_location, value}
  def tag(_, 0xA215, value), do: {:exposure_index, value}
  def tag(_, 0xA217, value), do: {:sensing_method, sensing_method(value)}
  def tag(_, 0xA300, value), do: {:file_source, file_source(value)}
  def tag(_, 0xA301, value), do: {:scene_type, scene_type(value)}
  def tag(_, 0xA302, value), do: {:cfa_pattern, value}
  def tag(_, 0xA401, value), do: {:custom_rendered, custom_rendered(value)}
  def tag(_, 0xA402, value), do: {:exposure_mode, exposure_mode(value)}
  def tag(_, 0xA403, value), do: {:white_balance, white_balance(value)}
  def tag(_, 0xA404, value), do: {:digital_zoom_ratio, value}
  def tag(_, 0xA405, value), do: {:focal_length_in_35mm_film, value}
  def tag(_, 0xA406, value), do: {:scene_capture_type, scene_capture_type(value)}
  def tag(_, 0xA407, value), do: {:gain_control, gain_control(value)}
  def tag(_, 0xA408, value), do: {:contrast, contrast(value)}
  def tag(_, 0xA409, value), do: {:saturation, saturation(value)}
  def tag(_, 0xA40A, value), do: {:sharpness, sharpness(value)}
  def tag(_, 0xA40B, value), do: {:device_setting_description, value}
  def tag(_, 0xA40C, value), do: {:subject_distance_range, subject_distance_range(value)}
  def tag(_, 0xA420, value), do: {:image_unique_id, value}
  def tag(_, 0xA431, value), do: {:body_serial_number, value}
  def tag(_, 0xA432, value), do: {:lens_info, value}
  def tag(_, 0xA433, value), do: {:lens_make, value}
  def tag(_, 0xA434, value), do: {:lens_model, value}
  def tag(_, 0xA435, value), do: {:lens_serial_number, value}
  def tag(_, 0xA436, value), do: {:image_title, value}

  def tag(_, 0xFDEA, value), do: {:lens, value}

  # http://www.sno.phy.queensu.ca/~phil/exiftool/TagNames/GPS.html
  Gps.fields()
  |> Enum.with_index()
  |> Enum.each(fn {e, i} ->
    def tag(:gps, unquote(i), value), do: {unquote(e), value}
  end)

  def tag(type, tag, value) do
    {~s[#{type} tag(0x#{:io_lib.format("~.16B", [tag])})], inspect(value)}
  end

  # Value decodes

  @spec date_time(binary()) :: NaiveDateTime.t()
  defp date_time(date_time) do
    # Some devices produce datetimes with appended null bytes.
    # We trim those before decoding.
    date_time = String.trim_trailing(date_time, "\x00")

    case String.split(date_time, [":", "-", "T", " "]) do
      [y, m, d, h, mm, s] ->
        case NaiveDateTime.new(int(y), int(m), int(d), int(h), int(mm), int(s)) do
          {:ok, naive_datetime} -> naive_datetime
          {:error, _} -> date_time
        end

      _other ->
        date_time
    end
  end

  def trim(value) do
    cond do
      <<0::size(byte_size(value) * 8)>> == value ->
        nil

      true ->
        String.trim(value)
    end
  end

  @compile {:inline, int: 1}
  defp int(string), do: String.to_integer(string)

  @spec orientation(non_neg_integer()) :: binary()
  defp orientation(1), do: "Horizontal (normal)"
  defp orientation(2), do: "Mirror horizontal"
  defp orientation(3), do: "Rotate 180"
  defp orientation(4), do: "Mirror vertical"
  defp orientation(5), do: "Mirror horizontal and rotate 270 CW"
  defp orientation(6), do: "Rotate 90 CW"
  defp orientation(7), do: "Mirror horizontal and rotate 90 CW"
  defp orientation(8), do: "Rotate 270 CW"
  defp orientation(other), do: "Unknown (#{other})"

  @spec resolution(non_neg_integer()) :: binary()
  defp resolution(1), do: "None"
  defp resolution(2), do: "Pixels/in"
  defp resolution(3), do: "Pixels/cm"
  defp resolution(other), do: "Unknown (#{other})"

  @spec exposure_program(non_neg_integer()) :: binary()
  defp exposure_program(1), do: "Manual"
  defp exposure_program(2), do: "Program AE"
  defp exposure_program(3), do: "Aperture-priority AE"
  defp exposure_program(4), do: "Shutter speed priority AE"
  defp exposure_program(5), do: "Creative (Slow speed)"
  defp exposure_program(6), do: "Action (High speed)"
  defp exposure_program(7), do: "Portrait"
  defp exposure_program(8), do: "Landscape"
  defp exposure_program(9), do: "Bulb"
  defp exposure_program(other), do: "Unknown (#{other})"

  @spec sensitivity_type(non_neg_integer()) :: binary()
  defp sensitivity_type(1), do: "Standard Output Sensitivity"
  defp sensitivity_type(2), do: "Recommended Exposure Index"
  defp sensitivity_type(3), do: "ISO Speed"
  defp sensitivity_type(4), do: "Standard Output Sensitivity and Recommended Exposure Index"
  defp sensitivity_type(5), do: "Standard Output Sensitivity and ISO Speed"
  defp sensitivity_type(6), do: "Recommended Exposure Index and ISO Speed"

  defp sensitivity_type(7),
    do: "Standard Output Sensitivity, Recommended Exposure Index and ISO Speed"

  defp sensitivity_type(other), do: "Unknown (#{other})"

  @comp_conf {"-", "Y", "Cb", "Cr", "R", "G", "B"}

  @spec component_configuration([non_neg_integer()]) :: binary()
  defp component_configuration(components) when is_list(components) do
    components
    |> Enum.map(&elem(@comp_conf, &1))
    |> Enum.join(",")
  end

  defp component_configuration(components) do
    "Unknown #{inspect components}"
  end

  @spec metering_mode(non_neg_integer()) :: binary()
  defp metering_mode(1), do: "Average"
  defp metering_mode(2), do: "Center-weighted average"
  defp metering_mode(3), do: "Spot"
  defp metering_mode(4), do: "Multi-spot"
  defp metering_mode(5), do: "Multi-segment"
  defp metering_mode(6), do: "Partial"
  defp metering_mode(other), do: "Unknown (#{other})"

  @spec color_space(non_neg_integer()) :: binary()
  defp color_space(0x1), do: "sRGB"
  defp color_space(0x2), do: "Adobe RGB"
  defp color_space(0xFFFD), do: "Wide Gamut RGB"
  defp color_space(0xFFFE), do: "ICC Profile"
  defp color_space(0xFFFF), do: "Uncalibrated"
  defp color_space(other), do: "Unknown (#{other})"

  @spec focal_plane_resolution_unit(non_neg_integer()) :: binary()
  defp focal_plane_resolution_unit(1), do: "None"
  defp focal_plane_resolution_unit(2), do: "inches"
  defp focal_plane_resolution_unit(3), do: "cm"
  defp focal_plane_resolution_unit(4), do: "mm"
  defp focal_plane_resolution_unit(5), do: "um"
  defp focal_plane_resolution_unit(other), do: "Unknown (#{other})"

  @spec sensing_method(non_neg_integer()) :: binary()
  defp sensing_method(1), do: "Not defined"
  defp sensing_method(2), do: "One-chip color area"
  defp sensing_method(3), do: "Two-chip color area"
  defp sensing_method(4), do: "Three-chip color area"
  defp sensing_method(5), do: "Color sequential area"
  defp sensing_method(7), do: "Trilinear"
  defp sensing_method(8), do: "Color sequential linear"
  defp sensing_method(other), do: "Unknown (#{other})"

  @spec file_source(non_neg_integer()) :: binary()
  defp file_source(1), do: "Film Scanner"
  defp file_source(2), do: "Reflection Print Scanner"
  defp file_source(3), do: "Digital Camera"
  defp file_source(0x03000000), do: "Sigma Digital Camera"
  defp file_source(other), do: "Unknown (#{other})"

  @spec custom_rendered(non_neg_integer()) :: binary()
  defp custom_rendered(0), do: "Normal"
  defp custom_rendered(1), do: "Custom"
  defp custom_rendered(other), do: "Unknown (#{other})"

  @spec scene_type(non_neg_integer()) :: binary()
  defp scene_type(1), do: "Directly photographed"
  defp scene_type(other), do: "Unknown (#{other})"

  @spec exposure_mode(non_neg_integer()) :: binary()
  defp exposure_mode(0), do: "Auto"
  defp exposure_mode(1), do: "Manual"
  defp exposure_mode(2), do: "Auto bracket"
  defp exposure_mode(other), do: "Unknown (#{other})"

  @spec white_balance(non_neg_integer()) :: binary()
  defp white_balance(0), do: "Auto"
  defp white_balance(1), do: "Manual"
  defp white_balance(other), do: "Unknown (#{other})"

  @spec scene_capture_type(non_neg_integer()) :: binary()
  defp scene_capture_type(0), do: "Standard"
  defp scene_capture_type(1), do: "Landscape"
  defp scene_capture_type(2), do: "Portrait"
  defp scene_capture_type(3), do: "Night"
  defp scene_capture_type(other), do: "Unknown (#{other})"

  @spec gain_control(non_neg_integer()) :: binary()
  defp gain_control(0), do: "None"
  defp gain_control(1), do: "Low gain up"
  defp gain_control(2), do: "High gain up"
  defp gain_control(3), do: "Low gain down"
  defp gain_control(4), do: "High gain down"
  defp gain_control(other), do: "Unknown (#{other})"

  @spec contrast(non_neg_integer()) :: binary()
  defp contrast(0), do: "Normal"
  defp contrast(1), do: "Low"
  defp contrast(2), do: "High"
  defp contrast(other), do: "Unknown (#{other})"

  @spec saturation(non_neg_integer()) :: binary()
  defp saturation(0), do: "Normal"
  defp saturation(1), do: "Low"
  defp saturation(2), do: "High"
  defp saturation(other), do: "Unknown (#{other})"

  @spec sharpness(non_neg_integer()) :: binary()
  defp sharpness(0), do: "Normal"
  defp sharpness(1), do: "Soft"
  defp sharpness(2), do: "Hard"
  defp sharpness(other), do: "Unknown (#{other})"

  @spec subject_distance_range(non_neg_integer()) :: binary()
  defp subject_distance_range(0), do: "Unknown"
  defp subject_distance_range(1), do: "Macro"
  defp subject_distance_range(2), do: "Close"
  defp subject_distance_range(3), do: "Distant"
  defp subject_distance_range(other), do: "Unknown (#{other})"

  @spec flash(non_neg_integer()) :: binary()
  defp flash(0x0), do: "No Flash"
  defp flash(0x1), do: "Fired"
  defp flash(0x5), do: "Fired, Return not detected"
  defp flash(0x7), do: "Fired, Return detected"
  defp flash(0x8), do: "On, Did not fire"
  defp flash(0x9), do: "On, Fired"
  defp flash(0xD), do: "On, Return not detected"
  defp flash(0xF), do: "On, Return detected"
  defp flash(0x10), do: "Off, Did not fire"
  defp flash(0x14), do: "Off, Did not fire, Return not detected"
  defp flash(0x18), do: "Auto, Did not fire"
  defp flash(0x19), do: "Auto, Fired"
  defp flash(0x1D), do: "Auto, Fired, Return not detected"
  defp flash(0x1F), do: "Auto, Fired, Return detected"
  defp flash(0x20), do: "No flash function"
  defp flash(0x30), do: "Off, No flash function"
  defp flash(0x41), do: "Fired, Red-eye reduction"
  defp flash(0x45), do: "Fired, Red-eye reduction, Return not detected"
  defp flash(0x47), do: "Fired, Red-eye reduction, Return detected"
  defp flash(0x49), do: "On, Red-eye reduction"
  defp flash(0x4D), do: "On, Red-eye reduction, Return not detected"
  defp flash(0x4F), do: "On, Red-eye reduction, Return detected"
  defp flash(0x50), do: "Off, Red-eye reduction"
  defp flash(0x58), do: "Auto, Did not fire, Red-eye reduction"
  defp flash(0x59), do: "Auto, Fired, Red-eye reduction"
  defp flash(0x5D), do: "Auto, Fired, Red-eye reduction, Return not detected"
  defp flash(0x5F), do: "Auto, Fired, Red-eye reduction, Return detected"
  defp flash(other), do: "Unknown (#{other})"

  defp ycbcr_positioning(1), do: "Centered"
  defp ycbcr_positioning(2), do: "Co-sited"
  defp ycbcr_positioning(other), do: "Unknown (#{other})"

  @spec version(charlist() | binary()) :: binary()
  defp version([?0, major, minor1, minor2]) do
    <<major, ?., minor1, minor2>>
  end

  defp version([major1, major2, minor1, minor2]) do
    <<major1, major2, ?., minor1, minor2>>
  end

  defp version(<<?0, major, minor1, minor2>>) do
    <<major, ?., minor1, minor2>>
  end

  defp version(<<major1, major2, minor1, minor2>>) do
    <<major1, major2, ?., minor1, minor2>>
  end
end
