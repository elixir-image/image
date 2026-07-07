defmodule Image.ExifRobustnessTest do
  use ExUnit.Case, async: true

  alias Image.Exif

  describe "extract_exif/1 with malformed payloads" do
    # Regression: EXIF payloads come from untrusted image files. Truncated
    # or corrupt blobs raised MatchError / CaseClauseError, and a failed
    # TIFF "42" sanity check returned the bogus number as a success.

    test "returns an error for a blob shorter than a TIFF header" do
      assert Exif.extract_exif(<<1, 2, 3>>) == {:error, :invalid_exif}
    end

    test "returns an error for an empty blob" do
      assert Exif.extract_exif(<<>>) == {:error, :invalid_exif}
    end

    test "returns an error for an unknown byte order" do
      assert Exif.extract_exif(<<0xFF, 0xFF, 0, 42, 0, 0, 0, 8, 0, 0>>) ==
               {:error, :invalid_exif}
    end

    test "returns an error when the TIFF 42 sanity check fails" do
      assert Exif.extract_exif(<<0x4D, 0x4D, 0, 43, 0, 0, 0, 8, 0, 0>>) ==
               {:error, :invalid_exif}
    end

    test "returns an empty map for an out-of-range IFD offset" do
      # Valid header but the IFD offset points past the end of the blob.
      blob = <<0x4D, 0x4D, 0, 42, 0, 0, 255, 255>>
      assert Exif.extract_exif(blob) == %{}
    end
  end

  describe "extract_exif/1 with out-of-range tag value offsets" do
    # Regression: an ASCII string tag (format 2) whose count is > 4 stores
    # its value at an offset elsewhere in the blob. When that offset points
    # past the end of the blob, Image.Exif.Tag.value/4 decodes the tag to
    # nil; the string decoders in Image.Exif.Decode (trim/1 and date_time/1)
    # must pass the nil through rather than raising ArgumentError.

    test "returns a map with a nil value for a string tag (trim path)" do
      # Tag 0x010F (:make), format 2 (ASCII), count 10, value offset 0xFFFF.
      blob = <<0x4D, 0x4D, 42::16, 8::32, 1::16, 0x010F::16, 2::16, 10::32, 0xFFFF::32>>
      assert Exif.extract_exif(blob) == %{make: nil}
    end

    test "returns a map with a nil value for a datetime tag (date_time path)" do
      # Tag 0x0132 (:modify_date), format 2 (ASCII), count 20, offset 0xFFFF.
      blob = <<0x4D, 0x4D, 42::16, 8::32, 1::16, 0x0132::16, 2::16, 20::32, 0xFFFF::32>>
      assert Exif.extract_exif(blob) == %{modify_date: nil}
    end
  end

  describe "extract_exif/1 with a valid payload" do
    test "extracts EXIF from a real image" do
      {:ok, image} = Image.open("./test/support/images/Kip_small.jpg")
      assert {:ok, exif} = Image.exif(image)
      assert is_map(exif)
      assert map_size(exif) > 0
    end
  end
end
