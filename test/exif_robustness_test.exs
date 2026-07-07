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

  describe "extract_exif/1 with a valid payload" do
    test "extracts EXIF from a real image" do
      {:ok, image} = Image.open("./test/support/images/Kip_small.jpg")
      assert {:ok, exif} = Image.exif(image)
      assert is_map(exif)
      assert map_size(exif) > 0
    end
  end
end
