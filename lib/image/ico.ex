defmodule Image.Ico do
  @moduledoc false

  # Encodes Windows ICO files for `Image.to_ico/2` and `Image.write/3`.
  #
  # libvips has no ICO saver, but an ICO whose entries are PNG images
  # needs none: it is a 6-byte header, a 16-byte directory entry per
  # image, then the PNG data of each. Every current browser, and
  # Windows since Vista, reads PNG entries. The older BMP entries are
  # not written.

  alias Vix.Vips.Image, as: Vimage
  alias Image.Vips.Operation

  @default_sizes [16, 32, 48]
  @max_size 256
  @header_size 6
  @entry_size 16
  @icon_type 1
  @bits_per_pixel 32

  @doc false
  def encode(%Vimage{} = image, options) when is_list(options) do
    with {:ok, sizes} <- validate_options(options),
         {:ok, frame} <- first_frame(image),
         {:ok, frame} <- to_srgb_with_alpha(frame),
         {:ok, entries} <- encode_entries(frame, sizes) do
      {:ok, assemble(entries)}
    end
  end

  def encode(image, _options) do
    {:error,
     %Image.Error{
       reason: :invalid_image,
       value: image,
       message: "Expected an image, got #{inspect(image)}"
     }}
  end

  defp validate_options(options) do
    case Keyword.split(options, [:sizes]) do
      {sizes_option, []} ->
        sizes_option
        |> Keyword.get(:sizes, @default_sizes)
        |> validate_sizes()

      {_sizes_option, [{key, value} | _rest]} ->
        invalid_option(key, value, "is not an option for writing an ICO file")
    end
  end

  defp validate_sizes([_ | _] = sizes) do
    if Enum.all?(sizes, &(is_integer(&1) and &1 in 1..@max_size)) do
      {:ok,
       sizes
       |> Enum.uniq()
       |> Enum.sort()}
    else
      invalid_option(:sizes, sizes, "must be a list of integers in 1..#{@max_size}")
    end
  end

  defp validate_sizes(sizes) do
    invalid_option(:sizes, sizes, "must be a list of integers in 1..#{@max_size}")
  end

  defp invalid_option(key, value, expected) do
    {:error,
     %Image.Error{
       reason: :invalid_option,
       value: {key, value},
       message: "Invalid option #{inspect(key)}: #{inspect(value)} #{expected}"
     }}
  end

  # An image opened with all its pages is a strip of frames; an icon is
  # made from the first. `Image.crop/5` crops every page of such an
  # image, so the first frame is extracted directly.
  defp first_frame(image) do
    height = Image.height(image)

    case Vimage.header_value(image, "page-height") do
      {:ok, page_height} when page_height > 0 and page_height < height ->
        Operation.extract_area(image, 0, 0, Image.width(image), page_height)

      _single_page ->
        {:ok, image}
    end
  end

  defp to_srgb_with_alpha(image) do
    with {:ok, srgb} <- Image.to_colorspace(image, :srgb),
         {:ok, eight_bit} <- Operation.cast(srgb, :VIPS_FORMAT_UCHAR) do
      if Image.has_alpha?(eight_bit) do
        {:ok, eight_bit}
      else
        Image.add_alpha(eight_bit, :opaque)
      end
    end
  end

  defp encode_entries(image, sizes) do
    Enum.reduce_while(sizes, {:ok, []}, fn size, {:ok, entries} ->
      case encode_entry(image, size) do
        {:ok, png} -> {:cont, {:ok, [{size, png} | entries]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> reverse_entries()
  end

  defp reverse_entries({:ok, entries}) do
    {:ok, Enum.reverse(entries)}
  end

  defp reverse_entries(error) do
    error
  end

  # The image is fitted inside a `size` square and centred on a
  # transparent background, so that nothing is cropped from a source
  # that is not square.
  defp encode_entry(image, size) do
    with {:ok, fitted} <- Image.thumbnail(image, size),
         {:ok, square} <- square(fitted, size) do
      Image.write(square, :memory, suffix: ".png", strip_metadata: true)
    end
  end

  defp square(image, size) do
    left = div(size - Image.width(image), 2)
    top = div(size - Image.height(image), 2)

    Operation.embed(image, left, top, size, size,
      extend: :VIPS_EXTEND_BACKGROUND,
      background: [0.0, 0.0, 0.0, 0.0]
    )
  end

  defp assemble(entries) do
    count = length(entries)
    first_offset = @header_size + @entry_size * count

    {directory, _offset} =
      Enum.map_reduce(entries, first_offset, fn {size, png}, offset ->
        {directory_entry(size, byte_size(png), offset), offset + byte_size(png)}
      end)

    header = <<0::little-16, @icon_type::little-16, count::little-16>>
    pngs = Enum.map(entries, fn {_size, png} -> png end)

    IO.iodata_to_binary([header, directory, pngs])
  end

  # A width or height of 256 is written as 0, since the field is a byte.
  defp directory_entry(size, length, offset) do
    dimension = rem(size, @max_size)

    <<dimension::8, dimension::8, 0::8, 0::8, 1::little-16, @bits_per_pixel::little-16,
      length::little-32, offset::little-32>>
  end
end
