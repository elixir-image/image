defmodule Image.Exif do
  @moduledoc """
  Functions to extract and interpret image EXIF
  data.

  """
  alias Image.Exif.{Decode, Tag}
  alias Image.Exif.{Gps, Thumbnail}

  @type t :: %{
          :brightness_value => float(),
          :color_space => binary(),
          :component_configuration => binary(),
          :compressed_bits_per_pixel => non_neg_integer(),
          :contrast => binary(),
          :custom_rendered => binary(),
          :datetime_digitized => binary(),
          :datetime_original => binary(),
          :digital_zoom_ratio => non_neg_integer(),
          :exif_image_height => non_neg_integer(),
          :exif_image_width => non_neg_integer(),
          :exif_version => binary(),
          :exposure_mode => binary(),
          :exposure_bias_value => non_neg_integer(),
          :exposure_program => binary(),
          :exposure_time => binary(),
          :f_number => non_neg_integer(),
          :file_source => binary(),
          :flash => binary(),
          :flash_pix_version => binary(),
          :focal_length_in_35mm_film => non_neg_integer(),
          :focal_length => float(),
          :iso_speed_ratings => non_neg_integer(),
          :lens_info => [float()],
          :light_source => non_neg_integer(),
          :max_aperture_value => float(),
          :metering_mode => binary(),
          :recommended_exposure => non_neg_integer(),
          :saturation => binary(),
          :scene_capture_type => binary(),
          :scene_type => binary(),
          :sensitivity_type => binary(),
          :sharpness => binary(),
          :white_balance => binary(),
          optional(binary()) => binary()
        }

  @type value :: binary()
  @type context :: {value(), non_neg_integer(), (any() -> non_neg_integer())}

  @copyright_header "exif-ifd0-Copyright"
  @artist_header "exif-ifd0-Artist"

  @doc """
  Returns the libvips header field name for a known EXIF field
  alias.

  ### Arguments

  * `field` is `:artist` or `:copyright`, the two aliases this
    library defines, or any other atom or string.

  ### Returns

  * the libvips header field name as a `t:String.t/0`. Anything
    other than a known alias is returned as a string unchanged,
    so a raw libvips field name passes straight through.

  ### Examples

      iex> Image.Exif.field(:artist)
      "exif-ifd0-Artist"

      iex> Image.Exif.field(:copyright)
      "exif-ifd0-Copyright"

      iex> Image.Exif.field("anything-else")
      "anything-else"

  """
  @spec field(:artist | :copyright | atom() | String.t()) :: String.t()
  def field(:artist), do: @artist_header
  def field(:copyright), do: @copyright_header
  def field(other), do: to_string(other)

  @doc false
  def get_metadata(image, header) do
    case Vix.Vips.Image.header_value(image, field(header)) do
      {:ok, value} -> {:ok, value}
      {:error, "No such field"} -> {:ok, nil}
      {:error, reason} -> {:error, Image.Error.wrap(reason, operation: :get_metadata)}
    end
  end

  @doc false
  def put_metadata(_mut_img, _field, nil), do: :ok
  def put_metadata(_mut_img, _field, ""), do: :ok

  def put_metadata(mut_img, field, value) do
    Vix.Vips.MutableImage.set(mut_img, field(field), :gchararray, value)
  end

  @doc """
  Extract EXIF data from a binary blob.

  ### Arguments

  * `exif` is a binary EXIF payload, such as the one returned by
    reading the `"exif-data"` header of an image.

  ### Returns

  * a map of EXIF fields, or

  * `{:error, :invalid_exif}` if the payload is truncated or
    malformed. EXIF payloads come from untrusted files, so a
    corrupt blob returns an error rather than raising.

  ### Examples

      iex> image = Image.open!("./test/support/images/Kip_small.jpg")
      iex> {:ok, <<"Exif", 0::16, blob::binary>>} = Vix.Vips.Image.header_value(image, "exif-data")
      iex> exif = Image.Exif.extract_exif(blob)
      iex> is_map(exif) and is_map_key(exif, :artist) and is_map_key(exif, :make)
      true

      iex> Image.Exif.extract_exif(<<1, 2, 3>>)
      {:error, :invalid_exif}

  """
  def extract_exif(exif) do
    # EXIF payloads come from untrusted image files so a truncated or
    # corrupt blob must produce an error, never a crash.
    with <<byte_order::16, forty_two::binary-size(2), offset::binary-size(4), _rest::binary>> <-
           exif,
         {:ok, read_unsigned} <- byte_order_decoder(byte_order),
         42 <- read_unsigned.(forty_two) do
      offset = read_unsigned.(offset)
      reshape(read_ifd({exif, offset, read_unsigned}))
    else
      _other -> {:error, :invalid_exif}
    end
  end

  defp byte_order_decoder(0x4949), do: {:ok, &:binary.decode_unsigned(&1, :little)}
  defp byte_order_decoder(0x4D4D), do: {:ok, &:binary.decode_unsigned(&1, :big)}
  defp byte_order_decoder(_other), do: {:error, :invalid_exif}

  @spec read_ifd(context :: context()) :: map()
  defp read_ifd({exif, offset, ru} = context) do
    case exif do
      <<_::binary-size(^offset), tag_count::binary-size(2), tags::binary>> ->
        count = ru.(tag_count)

        count
        |> read_tags(tags, context, :tiff, [])
        |> put_thumbnail(next_ifd(offset, count, context), context)

      _ ->
        %{}
    end
  end

  # An IFD is a 16-bit entry count, 12-byte entries and a 32-bit offset
  # to the next IFD, which is 0 when there is none. IFD1, after IFD0,
  # describes the thumbnail.
  defp next_ifd(offset, count, {exif, _offset, ru}) do
    position = offset + 2 + count * 12

    case exif do
      <<_::binary-size(^position), next::binary-size(4), _rest::binary>> -> ru.(next)
      _truncated -> 0
    end
  end

  # The thumbnail's offset counts from the start of the EXIF TIFF data,
  # like every other EXIF offset. IFD1 may come before IFD0, as it does
  # in files Photoshop writes; an offset into the 8-byte TIFF header or
  # back at IFD0 itself is malformed and ignored.
  defp put_thumbnail(result, ifd1_offset, {exif, ifd0_offset, ru} = context)
       when ifd1_offset >= 8 and ifd1_offset != ifd0_offset and ifd1_offset < byte_size(exif) do
    case exif do
      <<_::binary-size(^ifd1_offset), count::binary-size(2), tags::binary>> ->
        ifd1 = read_tags(ru.(count), tags, context, :exif, [])
        thumbnail(result, ifd1)

      _truncated ->
        result
    end
  end

  defp put_thumbnail(result, _ifd1_offset, _context) do
    result
  end

  defp thumbnail(result, %{thumbnail_offset: offset, thumbnail_size: size})
       when is_integer(offset) and is_integer(size) do
    Map.put(result, :thumbnail, %Thumbnail{thumbnail_offset: offset, thumbnail_size: size})
  end

  defp thumbnail(result, _ifd1) do
    result
  end

  @spec read_tags(non_neg_integer(), binary(), context(), any(), any()) :: map()
  defp read_tags(0, _tags, _context, _type, result), do: Map.new(result)

  defp read_tags(
         count,
         <<
           tag::binary-size(2),
           format::binary-size(2),
           component_count::binary-size(4),
           value::binary-size(4),
           rest::binary
         >>,
         {_exif, _offset, ru} = context,
         type,
         result
       ) do
    tag = ru.(tag)
    format = ru.(format)
    component_count = ru.(component_count)
    value = Tag.value(format, component_count, value, context)
    {name, description} = Decode.tag(type, tag, value)

    kv =
      case name do
        :exif -> {:exif, read_exif(value, context)}
        :gps -> {:gps, read_gps(value, context)}
        _ -> {name, description}
      end

    read_tags(count - 1, rest, context, type, [kv | result])
  end

  # Handle malformed data
  defp read_tags(_, _, _, _, result), do: Map.new(result)

  def read_exif(exif_offset, {exif, _offset, ru} = context)
      when is_integer(exif_offset) and exif_offset >= 0 do
    case exif do
      <<_::binary-size(^exif_offset), count::binary-size(2), tags::binary>> ->
        read_tags(ru.(count), tags, context, :exif, [])

      _ ->
        %{}
    end
  end

  def read_exif(_exif_offset, _context), do: %{}

  @spec read_gps(non_neg_integer(), context()) :: struct()
  defp read_gps(gps_offset, {gps, _offset, ru} = context)
       when is_integer(gps_offset) and gps_offset >= 0 do
    case gps do
      <<_::binary-size(^gps_offset), count::binary-size(2), tags::binary>> ->
        struct(Gps, read_tags(ru.(count), tags, context, :gps, []))

      _ ->
        %Gps{}
    end
  end

  defp read_gps(_gps_offset, _context), do: %Gps{}

  # The decoded IFD0 fields, with the Exif sub-IFD under `:exif` and the
  # GPS block under `:gps` when the image has them.
  @spec reshape(map()) :: map()
  defp reshape(result), do: extract_thumbnail(result)

  @spec extract_thumbnail(map()) :: map()
  defp extract_thumbnail(%{exif: exif} = result) do
    exif_keys = Map.keys(exif)

    result =
      if Enum.all?(Thumbnail.fields(), fn e -> Enum.any?(exif_keys, &(&1 == e)) end) do
        Map.put(
          result,
          :thumbnail,
          struct(
            Thumbnail,
            Thumbnail.fields()
            |> Enum.map(fn e -> {e, exif[e]} end)
            |> Enum.into(%{})
          )
        )
      else
        result
      end

    %{result | exif: Map.drop(result.exif, Thumbnail.fields())}
  end

  defp extract_thumbnail(result) do
    result
  end
end
