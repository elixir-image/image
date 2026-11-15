defmodule Image.TestSupport.Metadata do
  @moduledoc false

  # Builders for images that carry a chosen piece of metadata, so tests
  # can check metadata readers without a fixture file for every case.

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.MutableImage

  @doc "Builds IPTC IIM records from `{record, dataset, value}` tuples."
  def iim(datasets) do
    for {record, number, value} <- datasets, into: <<>> do
      <<0x1C, record, number, byte_size(value)::16, value::binary>>
    end
  end

  @doc """
  Builds Photoshop image resource blocks from `{id, name, data}`
  tuples, padding the name and the data to even lengths.
  """
  def irb(resources) do
    for {id, name, data} <- resources, into: <<>> do
      name_padding = :binary.copy(<<0>>, rem(byte_size(name) + 1, 2))
      data_padding = :binary.copy(<<0>>, rem(byte_size(data), 2))

      "8BIM" <>
        <<id::16, byte_size(name)>> <>
        name <> name_padding <> <<byte_size(data)::32>> <> data <> data_padding
    end
  end

  @doc """
  Writes a JPEG whose APP13 segment holds `payload`, wrapping bare IIM
  records in a Photoshop resource block, and returns its path.
  """
  def jpeg_with_app13(<<0x1C, _rest::binary>> = iim) do
    jpeg_with_app13(irb([{0x0404, "", iim}]))
  end

  def jpeg_with_app13(resources) do
    payload = "Photoshop 3.0" <> <<0>> <> resources
    path = Path.join(System.tmp_dir!(), "metadata_#{System.unique_integer([:positive])}.jpg")
    File.write!(path, jpeg_with_segments([{0xED, payload}]))
    path
  end

  @doc """
  Returns the bytes of a JPEG with `segments`, a list of `{marker,
  payload}` tuples, inserted after its start-of-image marker, and
  `trailer` appended after its end-of-image marker. `jpeg` is the JPEG
  to start from.
  """
  def jpeg_with_segments(segments, trailer \\ <<>>, jpeg \\ small_jpeg()) do
    <<0xFF, 0xD8, rest::binary>> = jpeg

    inserted =
      for {marker, payload} <- segments, into: <<>> do
        <<0xFF, marker, byte_size(payload) + 2::16, payload::binary>>
      end

    <<0xFF, 0xD8>> <> inserted <> rest <> trailer
  end

  @doc "Returns the bytes of a small JPEG with no metadata."
  def small_jpeg(options \\ []) do
    {:ok, jpeg} =
      Image.write(Image.new!(16, 16, color: :red), :memory, [suffix: ".jpg"] ++ options)

    jpeg
  end

  @doc """
  Returns an image with the given string header fields set, written to
  `suffix` and opened again so the fields go through a real save.
  libvips writes `exif-ifd*` fields into EXIF and `png-comment-*`
  fields into PNG text chunks.
  """
  def saved_with_fields(fields, suffix) do
    {:ok, image} =
      Vimage.mutate(Image.new!(16, 16, color: :red), fn mutable ->
        Enum.each(fields, fn {name, value} ->
          :ok = MutableImage.set(mutable, name, :gchararray, value)
        end)
      end)

    {:ok, binary} = Image.write(image, :memory, suffix: suffix)
    Image.open!(binary)
  end

  @doc "Returns an image whose XMP is `xml`."
  def with_xmp(xml) do
    {:ok, image} =
      Vimage.mutate(Image.new!(16, 16), fn mutable ->
        MutableImage.set(mutable, "xmp-data", :VipsBlob, xml)
      end)

    image
  end
end
