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

  def field(:artist), do: @artist_header
  def field(:copyright), do: @copyright_header
  def field(other), do: to_string(other)

  @doc false
  def get_metadata(image, header) do
    case Vix.Vips.Image.header_value(image, field(header)) do
      {:ok, value} -> {:ok, value}
      {:error, "No such field"} -> {:ok, nil}
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

  """
  def extract_exif(exif) do
    <<byte_order::16, forty_two::binary-size(2), offset::binary-size(4), _rest::binary>> = exif

    endian =
      case byte_order do
        0x4949 -> :little
        0x4D4D -> :big
      end

    read_unsigned = &:binary.decode_unsigned(&1, endian)

    # sanity check
    with 42 <- read_unsigned.(forty_two) do
      offset = read_unsigned.(offset)
      reshape(read_ifd({exif, offset, read_unsigned}))
    end
  end

  @spec read_ifd(context :: context()) :: map()
  defp read_ifd({exif, offset, ru} = context) do
    case exif do
      <<_::binary-size(offset), tag_count::binary-size(2), tags::binary>> ->
        read_tags(ru.(tag_count), tags, context, :tiff, [])

      _ ->
        %{}
    end
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

  def read_exif(exif_offset, {exif, _offset, ru} = context) do
    <<_::binary-size(exif_offset), count::binary-size(2), tags::binary>> = exif
    count = ru.(count)
    read_tags(count, tags, context, :exif, [])
  end

  @spec read_gps(non_neg_integer(), context()) :: %Gps{}
  defp read_gps(gps_offset, {gps, _offset, ru} = context) do
    case gps do
      <<_::binary-size(gps_offset), count::binary-size(2), tags::binary>> ->
        struct(Gps, read_tags(ru.(count), tags, context, :gps, []))

      _ ->
        %Gps{}
    end
  end

  @spec reshape(%{exif: t()}) :: %{exif: t()}
  defp reshape(result), do: extract_thumbnail(result)

  @spec extract_thumbnail(%{exif: t()}) :: %{exif: t()}
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
