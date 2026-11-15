defmodule Image.PrivacyJpegTest do
  use ExUnit.Case, async: true
  import Image.TestSupport
  import Image.TestSupport.Metadata

  alias Image.Privacy.Finding

  describe "comment segments" do
    test "a comment in a real file is reported" do
      assert {:ok, findings} = Image.Privacy.scan(image_path("kodak-dc210.jpg"))

      assert %Finding{source: :jpeg, field: :comment, kind: :embedded_text, value: value} =
               Enum.find(findings, &(&1.field == :comment))

      assert value == "Lovely smoke effect here, of which I'm secretly very proud."
    end

    test "comment text is trimmed and read as Latin-1 when it is not UTF-8" do
      bytes = jpeg_with_segments([{0xFE, <<" caf", 0xE9, 0, 0>>}])

      assert {:ok, [%Finding{field: :comment, value: "café"}]} = Image.Privacy.scan(bytes)
    end

    test "a blank comment is not reported" do
      assert {:ok, []} = Image.Privacy.scan(jpeg_with_segments([{0xFE, "  "}]))
    end
  end

  describe "data after the end of the image" do
    test "unknown data is reported with its size" do
      bytes = jpeg_with_segments([], "tracking-data")

      assert {:ok, [%Finding{source: :jpeg, field: :trailer, kind: :hidden_data} = finding]} =
               Image.Privacy.scan(bytes)

      assert finding.value == %{format: :unknown, bytes: 13}
    end

    test "zero padding is not reported" do
      assert {:ok, []} = Image.Privacy.scan(jpeg_with_segments([], <<0, 0, 0, 0>>))
    end

    test "an appended video is reported as MP4" do
      video = <<0, 0, 0, 24, "ftypmp42", 0, 0, 0, 0, "mp42isom">>

      assert {:ok, [%Finding{value: %{format: :mp4, bytes: 24}}]} =
               Image.Privacy.scan(jpeg_with_segments([], video))
    end

    test "a Samsung trailer is recognised" do
      trailer = "\0\0SEFH" <> :binary.copy("x", 20) <> "SEFT"

      assert {:ok, [%Finding{value: %{format: :samsung}}]} =
               Image.Privacy.scan(jpeg_with_segments([], trailer))
    end

    test "an appended JPEG that no MPF index declares is reported" do
      bytes = jpeg_with_segments([], small_jpeg())

      assert {:ok, [%Finding{value: %{format: :jpeg}}]} = Image.Privacy.scan(bytes)
    end

    test "the images an MPF index declares are not reported" do
      assert {:ok, findings} = Image.Privacy.scan(image_path("gain_map_pixel_10_pro.jpg"))
      refute Enum.any?(findings, &(&1.source == :jpeg))

      assert {:ok, findings} = Image.Privacy.scan(image_path("gain_map.jpg"))
      refute Enum.any?(findings, &(&1.source == :jpeg))
    end

    test "data after the images an MPF index declares is reported" do
      bytes = File.read!(image_path("gain_map_pixel_10_pro.jpg")) <> "tracking"

      assert {:ok, findings} = Image.Privacy.scan(bytes)

      assert [%Finding{field: :trailer, value: %{format: :unknown, bytes: 8}}] =
               Enum.filter(findings, &(&1.source == :jpeg))
    end

    test "is found after a progressive scan with restart markers" do
      {:ok, jpeg} =
        Vix.Vips.Operation.jpegsave_buffer(Image.new!(64, 64, color: :red),
          interlace: true,
          "restart-interval": 1
        )

      bytes = jpeg_with_segments([], "tail", jpeg)

      assert {:ok, [%Finding{value: %{format: :unknown, bytes: 4}}]} = Image.Privacy.scan(bytes)
    end
  end

  describe "scan/1 inputs" do
    test "a path and the file's bytes give the same findings" do
      path = image_path("kodak-dc210.jpg")

      assert Image.Privacy.scan(path) == Image.Privacy.scan(File.read!(path))
    end

    test "an image is scanned through its metadata only" do
      assert {:ok, findings} = Image.Privacy.scan(Image.open!(image_path("kodak-dc210.jpg")))
      refute Enum.any?(findings, &(&1.source == :jpeg))
    end

    test "a path that does not exist is an error" do
      assert {:error, %Image.Error{reason: :enoent, path: "/no/such/file.jpg"}} =
               Image.Privacy.scan("/no/such/file.jpg")
    end

    test "metadata findings come before segment findings" do
      bytes = jpeg_with_segments([{0xFE, "a comment"}], "", File.read!(image_path("Kip_small.jpg")))

      assert {:ok, findings} = Image.Privacy.scan(bytes)
      assert List.last(findings).source == :jpeg
      assert hd(findings).source == :iptc
    end
  end

  describe "Image.Privacy.Jpeg.scan/1 on malformed data" do
    test "a truncated file returns what was found before the truncation" do
      bytes = jpeg_with_segments([{0xFE, "kept"}])
      truncated = binary_part(bytes, 0, div(byte_size(bytes), 2))

      assert [%Finding{field: :comment, value: "kept"}] = Image.Privacy.Jpeg.scan(truncated)
    end

    test "a segment length past the end is treated as truncation" do
      assert [] = Image.Privacy.Jpeg.scan(<<0xFF, 0xD8, 0xFF, 0xFE, 0xFF, 0xFF, "short">>)
    end

    test "data that is not a JPEG has no findings" do
      assert [] = Image.Privacy.Jpeg.scan("not a jpeg")
    end
  end
end
