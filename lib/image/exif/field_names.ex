defmodule Image.Exif.FieldNames do
  @moduledoc false

  # Defines the field names with mapping to the relevant
  # EXIF IFD.
  #
  # This is useful for mapping developer and user friendly
  # names to theinternal header names in `libvips`.

  @field_names [
    ["ifd3", "GPSDateStamp"],
    ["ifd3", "GPSMapDatum"],
    ["ifd3", "GPSDOP"],
    ["ifd3", "GPSMeasureMode"],
    ["ifd3", "GPSStatus"],
    ["ifd3", "GPSSatellites"],
    ["ifd3", "GPSTimeStamp"],
    ["ifd3", "GPSAltitude"],
    ["ifd3", "GPSAltitudeRef"],
    ["ifd3", "GPSLongitude"],
    ["ifd3", "GPSLongitudeRef"],
    ["ifd3", "GPSLatitude"],
    ["ifd3", "GPSLatitudeRef"],
    ["ifd3", "GPSVersionID"],
    ["ifd2", "FlashpixVersion"],
    ["ifd2", "LensSerialNumber"],
    ["ifd2", "LensModel"],
    ["ifd2", "LensSpecification"],
    ["ifd2", "BodySerialNumber"],
    ["ifd2", "SceneCaptureType"],
    ["ifd2", "WhiteBalance"],
    ["ifd2", "ExposureMode"],
    ["ifd2", "CustomRendered"],
    ["ifd2", "FocalPlaneResolutionUnit"],
    ["ifd2", "FocalPlaneYResolution"],
    ["ifd2", "FocalPlaneXResolution"],
    ["ifd2", "ColorSpace"],
    ["ifd2", "SubSecTimeDigitized"],
    ["ifd2", "SubSecTimeOriginal"],
    ["ifd2", "FocalLength"],
    ["ifd2", "Flash"],
    ["ifd2", "MeteringMode"],
    ["ifd2", "MaxApertureValue"],
    ["ifd2", "ExposureBiasValue"],
    ["ifd2", "ApertureValue"],
    ["ifd2", "ShutterSpeedValue"],
    ["ifd2", "OffsetTime"],
    ["ifd2", "DateTimeDigitized"],
    ["ifd2", "DateTimeOriginal"],
    ["ifd2", "ExifVersion"],
    ["ifd2", "RecommendedExposureIndex"],
    ["ifd2", "SensitivityType"],
    ["ifd2", "ISOSpeedRatings"],
    ["ifd2", "ExposureProgram"],
    ["ifd2", "FNumber"],
    ["ifd2", "ExposureTime"],
    ["ifd1", "ResolutionUnit"],
    ["ifd1", "YResolution"],
    ["ifd1", "XResolution"],
    ["ifd1", "Compression"],
    ["ifd0", "Copyright"],
    ["ifd0", "Artist"],
    ["ifd0", "DateTime"],
    ["ifd0", "Software"],
    ["ifd0", "ResolutionUnit"],
    ["ifd0", "YResolution"],
    ["ifd0", "XResolution"],
    ["ifd0", "Model"],
    ["ifd0", "Make"],
    ["ifd0", "ImageDescription"]
  ]

  @omit [
    ["ifd1", "YResolution"],
    ["ifd1", "XResolution"],
    ["ifd1", "ResolutionUnit"]
  ]

  for [ifd, name] <- @field_names, [ifd, name] not in @omit do
    vips_header_name = "exif-" <> ifd <> "-" <> name
    field = Macro.underscore(name) |> String.to_atom()

    def vips_header_name(unquote(field)), do: unquote(vips_header_name)
  end
end
