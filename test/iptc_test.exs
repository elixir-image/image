defmodule Image.IptcTest do
  use ExUnit.Case, async: true
  import Image.TestSupport

  doctest Image.Iptc

  # The ID strings are the shape Facebook writes; the values are made up.
  @fbmd "FBMD01000a8f0300003b0c0000"
  @transmission_reference "bF9xQkLmNoPqRsTuVwXy"

  describe "Image.iptc/1" do
    test "reads the IPTC of a JPEG" do
      image = Image.open!(image_path("Kip_small.jpg"))

      assert {:ok, iptc} = Image.iptc(image)
      assert iptc.by_line == ["Kip Cole"]
      assert iptc.country_name == "Vietnam"
      assert iptc.date_created == ~D[2004-08-18]
      assert iptc.record_version == 4
    end

    test "reads Facebook's identifiers from a JPEG APP13 segment" do
      path = jpeg_with_app13(iim([{2, 40, @fbmd}, {2, 103, @transmission_reference}]))
      image = Image.open!(path)

      assert {:ok, iptc} = Image.iptc(image)
      assert iptc.special_instructions == @fbmd
      assert iptc.original_transmission_reference == @transmission_reference
    end

    test "keeps the IPTC through a re-save" do
      path = jpeg_with_app13(iim([{2, 40, @fbmd}]))
      {:ok, binary} = Image.write(Image.open!(path), :memory, suffix: ".jpg")

      assert {:ok, %{special_instructions: @fbmd}} = Image.iptc(Image.open!(binary))
    end

    test "returns an error for an invalid IPTC block" do
      path = jpeg_with_app13(irb([{0x0404, "", <<0x1C, 2, 40, 0, 40, "short">>}]))

      assert {:error, %Image.Error{reason: :invalid_iptc}} = Image.iptc(Image.open!(path))
    end
  end

  describe "missing metadata" do
    test "exif/1, xmp/1 and iptc/1 report missing data the same way" do
      image = Image.new!(16, 16)

      assert {:error, %Image.Error{reason: :no_exif, operation: :exif}} = Image.exif(image)
      assert {:error, %Image.Error{reason: :no_xmp, operation: :xmp}} = Image.xmp(image)
      assert {:error, %Image.Error{reason: :no_iptc, operation: :iptc}} = Image.iptc(image)
    end
  end

  describe "extract_iptc/1 input forms" do
    test "a JPEG APP13 payload" do
      blob = "Photoshop 3.0" <> <<0>> <> irb([{0x0404, "", iim([{2, 5, "Title"}])}])

      assert {:ok, %{object_name: "Title"}} = Image.Iptc.extract_iptc(blob)
    end

    test "bare Photoshop image resource blocks" do
      blob = irb([{0x0404, "", iim([{2, 5, "Title"}])}])

      assert {:ok, %{object_name: "Title"}} = Image.Iptc.extract_iptc(blob)
    end

    test "bare IIM records" do
      assert {:ok, %{object_name: "Title"}} = Image.Iptc.extract_iptc(iim([{2, 5, "Title"}]))
    end

    test "an empty blob has no datasets" do
      assert {:ok, %{}} = Image.Iptc.extract_iptc(<<>>)
    end

    test "resource blocks with no IPTC block have no datasets" do
      assert {:ok, %{}} = Image.Iptc.extract_iptc(irb([{0x0409, "", <<1, 2, 3>>}]))
    end
  end

  describe "extract_iptc/1 resource blocks" do
    test "skips other resources, with odd and even name and data lengths" do
      blob =
        irb([
          {0x03ED, "a", <<1, 2, 3>>},
          {0x0409, "ab", <<1, 2>>},
          {0x0404, "abc", iim([{2, 5, "Title"}])},
          {0x0425, "", <<1>>}
        ])

      assert {:ok, %{object_name: "Title"}} = Image.Iptc.extract_iptc(blob)
    end

    test "accepts trailing zero padding" do
      blob = irb([{0x0404, "", iim([{2, 5, "Title"}])}]) <> <<0, 0, 0>>

      assert {:ok, %{object_name: "Title"}} = Image.Iptc.extract_iptc(blob)
    end

    test "a truncated resource block is an error" do
      blob = binary_part(irb([{0x0404, "", iim([{2, 5, "Title"}])}]), 0, 14)

      assert {:error, %Image.Error{reason: :invalid_iptc}} = Image.Iptc.extract_iptc(blob)
    end

    test "trailing data that is not a resource block is an error" do
      blob = irb([{0x0404, "", iim([{2, 5, "Title"}])}]) <> "garbage"

      assert {:error, %Image.Error{reason: :invalid_iptc}} = Image.Iptc.extract_iptc(blob)
    end
  end

  describe "extract_iptc/1 datasets" do
    test "repeatable datasets are lists in file order" do
      blob = iim([{2, 25, "sea"}, {2, 80, "Ann"}, {2, 25, "sky"}, {2, 80, "Bob"}])

      assert {:ok, %{keywords: ["sea", "sky"], by_line: ["Ann", "Bob"]}} =
               Image.Iptc.extract_iptc(blob)
    end

    test "a repeated non-repeatable dataset keeps its first value" do
      assert {:ok, %{object_name: "First"}} =
               Image.Iptc.extract_iptc(iim([{2, 5, "First"}, {2, 5, "Second"}]))
    end

    test "an extended length is read" do
      value = String.duplicate("x", 40)
      blob = <<0x1C, 2, 120, 0x80, 4, byte_size(value)::32>> <> value

      assert {:ok, %{caption_abstract: ^value}} = Image.Iptc.extract_iptc(blob)
    end

    test "dates are Dates when valid and text when not" do
      assert {:ok, %{date_created: ~D[2026-11-15], release_date: "20261341"}} =
               Image.Iptc.extract_iptc(iim([{2, 55, "20261115"}, {2, 30, "20261341"}]))
    end

    test "numeric datasets are integers" do
      assert {:ok, %{record_version: 4}} = Image.Iptc.extract_iptc(iim([{2, 0, <<0, 4>>}]))
    end

    test "text that is not UTF-8 is read as Latin-1" do
      assert {:ok, %{city: "Zürich"}} =
               Image.Iptc.extract_iptc(iim([{2, 90, <<"Z", 0xFC, "rich">>}]))
    end

    test "UTF-8 text is kept" do
      blob = iim([{1, 90, <<0x1B, 0x25, 0x47>>}, {2, 90, "Zürich"}])

      assert {:ok, %{city: "Zürich", coded_character_set: <<0x1B, 0x25, 0x47>>}} =
               Image.Iptc.extract_iptc(blob)
    end

    test "a trailing zero byte is removed from text" do
      assert {:ok, %{city: "Paris"}} = Image.Iptc.extract_iptc(iim([{2, 90, "Paris" <> <<0>>}]))
    end

    test "an unknown dataset is keyed by its numbers" do
      assert {:ok, %{{2, 199} => ["a", "b"]}} =
               Image.Iptc.extract_iptc(iim([{2, 199, "a"}, {2, 199, "b"}]))
    end

    test "a truncated dataset is an error" do
      assert {:error, %Image.Error{reason: :invalid_iptc}} =
               Image.Iptc.extract_iptc(<<0x1C, 2, 40, 0, 9, "FBMD">>)
    end

    test "a truncated extended length is an error" do
      assert {:error, %Image.Error{reason: :invalid_iptc}} =
               Image.Iptc.extract_iptc(<<0x1C, 2, 40, 0x80, 4, 0>>)
    end

    test "an extended length of more than four bytes is an error" do
      assert {:error, %Image.Error{reason: :invalid_iptc}} =
               Image.Iptc.extract_iptc(<<0x1C, 2, 40, 0x80, 9, 0, 0, 0, 0, 0, 0, 0, 0, 1, "x">>)
    end

    test "data that is not IPTC is an error" do
      assert {:error, %Image.Error{reason: :invalid_iptc}} = Image.Iptc.extract_iptc("not iptc")
    end

    test "a value that is not a binary is an error" do
      assert {:error, %Image.Error{reason: :invalid_iptc, value: :not_a_binary}} =
               Image.Iptc.extract_iptc(:not_a_binary)
    end
  end

  # Builds IIM records from {record, dataset, value} tuples.
  defp iim(datasets) do
    for {record, number, value} <- datasets, into: <<>> do
      <<0x1C, record, number, byte_size(value)::16, value::binary>>
    end
  end

  # Builds Photoshop image resource blocks from {id, name, data} tuples,
  # padding the name and the data to even lengths.
  defp irb(resources) do
    for {id, name, data} <- resources, into: <<>> do
      name_padding = :binary.copy(<<0>>, rem(byte_size(name) + 1, 2))
      data_padding = :binary.copy(<<0>>, rem(byte_size(data), 2))

      "8BIM" <>
        <<id::16, byte_size(name)>> <>
        name <> name_padding <> <<byte_size(data)::32>> <> data <> data_padding
    end
  end

  # Writes a JPEG whose APP13 segment holds `payload`, as Photoshop
  # resource blocks when it is bare IIM records.
  defp jpeg_with_app13(<<0x1C, _rest::binary>> = iim) do
    jpeg_with_app13(irb([{0x0404, "", iim}]))
  end

  defp jpeg_with_app13(resources) do
    payload = "Photoshop 3.0" <> <<0>> <> resources
    app13 = <<0xFF, 0xED, byte_size(payload) + 2::16>> <> payload

    {:ok, jpeg} = Image.write(Image.new!(16, 16, color: :red), :memory, suffix: ".jpg")
    <<0xFF, 0xD8, rest::binary>> = jpeg

    path = Path.join(System.tmp_dir!(), "iptc_test_#{System.unique_integer([:positive])}.jpg")
    File.write!(path, <<0xFF, 0xD8>> <> app13 <> rest)
    path
  end
end
