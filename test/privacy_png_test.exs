defmodule Image.PrivacyPngTest do
  use ExUnit.Case, async: true
  import Image.TestSupport
  import Image.TestSupport.Metadata

  alias Image.Privacy.Finding

  describe "data after IEND" do
    test "unknown data is reported with its size" do
      assert {:ok, [%Finding{source: :png, field: :trailer, kind: :hidden_data} = finding]} =
               Image.Privacy.scan(png_with_chunks([], "tracking-data"))

      assert finding.value == %{format: :unknown, bytes: 13}
    end

    test "an appended ZIP archive is recognised" do
      trailer = <<"PK", 3, 4>> <> :binary.copy(<<0>>, 26)

      assert {:ok, [%Finding{value: %{format: :zip, bytes: 30}}]} =
               Image.Privacy.scan(png_with_chunks([], trailer))
    end

    test "an appended PNG is recognised" do
      assert {:ok, [%Finding{value: %{format: :png}}]} =
               Image.Privacy.scan(png_with_chunks([], png_with_chunks([])))
    end

    test "zero padding is not reported" do
      assert {:ok, []} = Image.Privacy.scan(png_with_chunks([], <<0, 0, 0>>))
    end

    test "chunks before IEND are walked past" do
      bytes = png_with_chunks([{"prVt", "private data"}, {"tEXt", "Note" <> <<0>> <> "hi"}], "tail")

      assert {:ok, findings} = Image.Privacy.scan(bytes)
      assert [%Finding{value: %{bytes: 4}}] = Enum.filter(findings, &(&1.source == :png))
      assert %Finding{source: :png_text, value: "hi"} = Enum.find(findings, &(&1.field == "Note"))
    end

    test "PNG fixtures have no trailing data" do
      for name <- ["cat.png", "Kip_small.png", "image_with_alpha2.png", "jose.png"] do
        assert {:ok, findings} = Image.Privacy.scan(image_path(name))
        refute Enum.any?(findings, &(&1.source == :png)), name
      end
    end
  end

  describe "Image.Privacy.Png.scan/1 on malformed data" do
    test "a truncated file has no findings" do
      bytes = png_with_chunks([], "tail")
      truncated = binary_part(bytes, 0, byte_size(bytes) - 20)

      assert [] = Image.Privacy.Png.scan(truncated)
    end

    test "a chunk length past the end is treated as truncation" do
      bytes = <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, 0xFFFFFFFF::32, "IHDR", "short">>

      assert [] = Image.Privacy.Png.scan(bytes)
    end

    test "data that is not a PNG has no findings" do
      assert [] = Image.Privacy.Png.scan("not a png")
    end
  end

  describe "trailer formats" do
    test "each recognised format" do
      cases = [
        {<<0xFF, 0xD8, 0xFF>>, :jpeg},
        {<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A>>, :png},
        {<<"PK", 3, 4>>, :zip},
        {<<0, 0, 0, 24, "ftypmp42">>, :mp4},
        {<<0, 0, 0, 24, "ftypmp42", "SEFHxxxxSEFT">>, :samsung},
        {"anything else", :unknown}
      ]

      for {trailer, format} <- cases do
        assert [%Finding{value: %{format: ^format}}] = Image.Privacy.Trailer.findings(:png, trailer)
      end
    end

    test "empty data has no findings" do
      assert [] = Image.Privacy.Trailer.findings(:png, <<>>)
    end
  end
end
