defmodule Image.Privacy do
  @moduledoc """
  Finds tracking and identifying data in an image's metadata.

  `scan/1` reads an image's IPTC, EXIF, XMP and PNG text, a JPEG
  file's comment segments, and data hidden after the end of a JPEG or
  PNG file, and returns
  an `Image.Privacy.Finding` for each piece of data that could
  identify a person, a device, a place or the image itself, or that
  a platform added to follow the image: Facebook's `FBMD` identifier,
  camera serial numbers, GPS coordinates, the document identifiers
  editing software writes, AI labels and generator prompts. It also
  reports an EXIF thumbnail, a second copy of the picture that can
  show it before it was cropped or edited.

  `remove/2` removes the data that chosen findings describe and keeps
  the rest. `Image.remove_metadata/2`, or `strip_metadata: true` in
  `Image.write/3`, removes whole blocks. The
  [Privacy and tracking metadata](privacy.md) guide covers both.

  ### What the scan cannot find

  * **Invisible watermarks** embedded in the pixels, such as Google
    SynthID, Meta's Video Seal and Digimarc, can only be read with the
    vendor's own decoder. A scan with no findings is not evidence that
    an image carries no watermark.

  * **Maker notes**, the camera maker's own block in EXIF, can hold a
    body serial number or the owner's name. They are not read yet. They
    are removed with the rest of the EXIF by `strip_metadata: true` and
    `Image.remove_metadata(image, :exif)`.

  * **Data outside the decoded image** is not visible to libvips. For a
    JPEG or PNG given as a path or binary, the scan reads the file's
    segments or chunks for comment segments and data after the end of
    the image; given an image, it cannot. Other formats are not read
    this way. Any image `Image` writes leaves this data out.

  * **C2PA Content Credentials** are not reported. They record an
    image's authenticity rather than track it, and libvips has no API
    to read them. libvips does not carry a JPEG's credentials through
    a save either, so a JPEG `Image` writes has none.

  """

  alias Image.Exif.Gps
  alias Image.{Iptc, Xmp}
  alias Image.Privacy.{Finding, Jpeg, Png}
  alias Vix.Vips.MutableImage
  alias Vix.Vips.Image, as: Vimage

  # IPTC datasets that identify, with the kind of each.
  @iptc_fields [
    original_transmission_reference: :tracking_id,
    unique_name_of_object: :document_id,
    by_line: :person,
    contact: :person,
    writer_editor: :person,
    city: :location,
    sub_location: :location,
    province_state: :location,
    country_name: :location,
    country_code: :location,
    content_location_name: :location
  ]

  # EXIF fields that identify. IFD0 fields are at the top of the map
  # `Image.exif/1` returns and Exif IFD fields under its `:exif` key.
  @exif_ifd0_fields [
    artist: :person,
    xp_author: :person,
    xp_comment: :embedded_text,
    host_computer: :device_id,
    camera_serial_number: :device_id
  ]

  @exif_fields [
    camera_owner_name: :person,
    photographer: :person,
    image_editor: :person,
    body_serial_number: :device_id,
    lens_serial_number: :device_id,
    image_unique_id: :document_id,
    user_comment: :embedded_text
  ]

  # XMP properties that identify. Place names are under the `:location`
  # key of the map `Image.xmp/1` returns.
  @xmp_fields [
    artist: :person,
    gps_latitude: :location,
    gps_longitude: :location,
    document_id: :document_id,
    instance_id: :document_id,
    original_document_id: :document_id,
    document_ancestors: :document_id,
    document_history: :document_id,
    people_in_image: :person,
    region_names: :person,
    location_created: :location,
    locations_shown: :location
  ]

  @xmp_location_fields [
    city: :location,
    state: :location,
    territory: :location,
    territory_code: :location
  ]

  # IPTC digital source types that label an image as made with
  # generative AI.
  @ai_source_types ["trainedAlgorithmicMedia", "compositeWithTrainedAlgorithmicMedia"]

  # libvips names a PNG text chunk's field "png-comment-<index>-<keyword>".
  @png_text_prefix "png-comment-"

  # The libvips header field that holds each EXIF finding. libvips holds
  # every EXIF tag as its own field and drops a tag from the saved file
  # when its field is removed. libexif, which libvips uses for EXIF, does
  # not know the host computer, camera serial number, photographer and
  # image editor tags and drops them from every save, so they need no
  # field removed.
  @exif_removal_fields %{
    artist: ["exif-ifd0-Artist"],
    xp_author: ["exif-ifd0-XPAuthor"],
    xp_comment: ["exif-ifd0-XPComment"],
    camera_owner_name: ["exif-ifd2-CameraOwnerName"],
    body_serial_number: ["exif-ifd2-BodySerialNumber"],
    lens_serial_number: ["exif-ifd2-LensSerialNumber"],
    image_unique_id: ["exif-ifd2-ImageUniqueID"],
    user_comment: ["exif-ifd2-UserComment"],
    thumbnail: ["jpeg-thumbnail-data"],
    host_computer: [],
    camera_serial_number: [],
    photographer: [],
    image_editor: []
  }

  # GPS fields are named "exif-ifd3-<tag>"; the destination's tags start
  # with "GPSDest".
  @gps_prefix "exif-ifd3-"
  @gps_destination_prefix "exif-ifd3-GPSDest"

  # The prefix Facebook writes to IPTC Special Instructions.
  @facebook_prefix "FBMD"

  @doc """
  Scans an image for tracking and identifying data.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, the path to an image file,
    or an image file's bytes. A binary that starts with an image
    signature is treated as the file's bytes, as in `Image.open/2`.
    Given a path or bytes, a JPEG's segments and a PNG's chunks are
    read as well as its metadata.

  ### Returns

  * `{:ok, findings}` where `findings` is a list of
    `t:Image.Privacy.Finding.t/0`, in the order IPTC, EXIF, XMP, PNG
    text, JPEG segments and PNG chunks. An image with nothing to report returns an
    empty list, or

  * `{:error, %Image.Error{}}` if the file cannot be read or opened as
    an image, with reason `:invalid_image` if `image` is not an image,
    a path or a binary.

  ### Examples

      iex> image = Image.open!("./test/support/images/Kip_small.jpg")
      iex> {:ok, findings} = Image.Privacy.scan(image)
      iex> Enum.find(findings, &(&1.source == :iptc and &1.kind == :person))
      %Image.Privacy.Finding{source: :iptc, field: :by_line, value: ["Kip Cole"], kind: :person}

      iex> {:ok, findings} = Image.Privacy.scan("./test/support/images/kodak-dc210.jpg")
      iex> Enum.find(findings, &(&1.field == :comment)).value
      "Lovely smoke effect here, of which I'm secretly very proud."

      iex> Image.Privacy.scan(Image.new!(16, 16))
      {:ok, []}

  """
  @doc since: "0.74.0"

  @spec scan(Vimage.t() | Path.t() | binary()) :: {:ok, [Finding.t()]} | {:error, Image.Error.t()}
  def scan(%Vimage{} = image) do
    findings =
      iptc_findings(image) ++
        exif_findings(image) ++
        thumbnail_findings(image) ++ xmp_findings(image) ++ png_text_findings(image)

    {:ok, findings}
  end

  def scan(path_or_binary) when is_binary(path_or_binary) do
    with {:ok, bytes} <- read_bytes(path_or_binary),
         {:ok, image} <- Image.open(bytes),
         {:ok, metadata_findings} <- scan(image) do
      {:ok, metadata_findings ++ Jpeg.scan(bytes) ++ Png.scan(bytes)}
    end
  end

  def scan(other) do
    {:error,
     Image.Error.exception(
       reason: :invalid_image,
       operation: :scan,
       value: other,
       message: "Expected an image, got #{inspect(other)}"
     )}
  end

  @doc """
  Removes the data that findings from `scan/1` describe, keeping the
  rest of the image's metadata.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `findings` is a list of `t:Image.Privacy.Finding.t/0`, usually
    a selection of what `scan/1` returned for the same image.

  ### Returns

  * `{:ok, image}` with the data removed. The removal takes effect
    when the image is saved, or

  * `{:error, %Image.Error{reason: :invalid_finding}}` if a list
    element is not a finding, or

  * `{:error, %Image.Error{reason: :invalid_iptc}}` or
    `{:error, %Image.Error{reason: :invalid_xmp}}` if the image's IPTC
    or XMP cannot be read to remove a finding from it, or

  * `{:error, %Image.Error{reason: :unsupported_finding}}` for a
    finding this function does not know how to remove.

  ### Notes

  * A `:gps` finding removes the whole EXIF GPS block, including its
    timestamps and altitude. A `:gps_destination` finding removes only
    the destination.

  * An `:unreadable` finding removes the whole block it refers to.

  * IPTC findings are removed by rewriting the IPTC block without them.
    Its other datasets and Photoshop resources are kept, and the block
    is removed when no content is left.

  * XMP findings are removed from the XMP packet in place, keeping
    every other property byte for byte. `:region_names` removes the
    face regions whole, with their coordinates, and `:people_in_image`
    both IPTC lists of people. GPS inside an IPTC location structure
    describes that location and is kept when the image's GPS is
    removed.

  * Findings from a JPEG's or PNG's segments, such as comments and
    data after the end of the image, need nothing removed: libvips
    never reads them, so no image `Image` writes contains them. The
    EXIF host computer, camera serial number, photographer and image
    editor are likewise dropped by every save.

  ### Examples

      iex> image = Image.open!("./test/support/images/gain_map.jpg")
      iex> {:ok, findings} = Image.Privacy.scan(image)
      iex> remove = Enum.filter(findings, &(&1.kind in [:location, :device_id]))
      iex> {:ok, image} = Image.Privacy.remove(image, remove)
      iex> {:ok, jpeg} = Image.write(image, :memory, suffix: ".jpg")
      iex> {:ok, findings} = Image.Privacy.scan(jpeg)
      iex> Enum.map(findings, & &1.field)
      [:artist, :thumbnail]

  """
  @doc since: "0.74.0"

  @spec remove(Vimage.t(), [Finding.t()]) :: {:ok, Vimage.t()} | {:error, Image.Error.t()}
  def remove(%Vimage{} = image, findings) when is_list(findings) do
    with {:ok, fields} <- removal_fields(image, findings),
         {:ok, image} <- remove_fields(image, fields),
         {:ok, image} <- remove_iptc_datasets(image, block_fields(findings, :iptc)) do
      remove_xmp_properties(image, block_fields(findings, :xmp))
    end
  end

  def remove(image, findings) do
    {:error,
     Image.Error.exception(
       reason: :invalid_image,
       operation: :remove,
       value: {image, findings},
       message: "Expected an image and a list of findings"
     )}
  end

  # `Image.remove_metadata/2` removes every field when given none.
  defp remove_fields(image, []) do
    {:ok, image}
  end

  defp remove_fields(image, fields) do
    Image.remove_metadata(image, fields)
  end

  # IPTC and XMP are each one blob, so their fields are removed by
  # rewriting the blob.
  defp block_fields(findings, source) do
    for %Finding{source: ^source, field: field, kind: kind} <- findings, kind != :unreadable do
      field
    end
  end

  defp remove_iptc_datasets(image, []) do
    {:ok, image}
  end

  defp remove_iptc_datasets(image, datasets) do
    case Vimage.header_value(image, "iptc-data") do
      {:ok, iptc} -> rewrite_iptc(image, Iptc.remove_datasets(iptc, datasets))
      {:error, _no_iptc} -> {:ok, image}
    end
  end

  defp rewrite_iptc(image, {:ok, nil}) do
    Image.remove_metadata(image, :iptc)
  end

  defp rewrite_iptc(image, {:ok, iptc}) do
    case Vimage.mutate(image, &MutableImage.set(&1, "iptc-data", :VipsBlob, iptc)) do
      {:ok, image} -> {:ok, image}
      {:error, reason} -> {:error, Image.Error.wrap(reason, operation: :remove)}
    end
  end

  defp rewrite_iptc(_image, {:error, _reason} = error) do
    error
  end

  defp remove_xmp_properties(image, []) do
    {:ok, image}
  end

  defp remove_xmp_properties(image, fields) do
    case Vimage.header_value(image, "xmp-data") do
      {:ok, xmp} -> rewrite_xmp(image, Xmp.remove_properties(xmp, fields))
      {:error, _no_xmp} -> {:ok, image}
    end
  end

  defp rewrite_xmp(image, {:ok, xmp}) do
    case Vimage.mutate(image, &MutableImage.set(&1, "xmp-data", :VipsBlob, xmp)) do
      {:ok, image} -> {:ok, image}
      {:error, reason} -> {:error, Image.Error.wrap(reason, operation: :remove)}
    end
  end

  defp rewrite_xmp(_image, {:error, :invalid_xmp}) do
    {:error,
     Image.Error.exception(
       reason: :invalid_xmp,
       operation: :remove,
       message: "The image's XMP cannot be read to remove an XMP finding"
     )}
  end

  defp removal_fields(image, findings) do
    results = Enum.map(findings, &finding_fields(image, &1))

    case Enum.find(results, &match?({:error, _reason}, &1)) do
      nil -> {:ok, Enum.uniq(Enum.flat_map(results, fn {:ok, fields} -> fields end))}
      error -> error
    end
  end

  # `Image.remove_metadata/2` takes `:exif`, `:iptc` and `:xmp` for a
  # whole block, and libvips field names otherwise.
  defp finding_fields(_image, %Finding{kind: :unreadable, source: source})
       when source in [:exif, :iptc, :xmp] do
    {:ok, [source]}
  end

  defp finding_fields(image, %Finding{source: :exif, field: :gps}) do
    {:ok, fields_with_prefix(image, @gps_prefix)}
  end

  defp finding_fields(image, %Finding{source: :exif, field: :gps_destination}) do
    {:ok, fields_with_prefix(image, @gps_destination_prefix)}
  end

  defp finding_fields(_image, %Finding{source: :exif, field: field} = finding) do
    case Map.fetch(@exif_removal_fields, field) do
      {:ok, fields} -> {:ok, fields}
      :error -> unsupported(finding)
    end
  end

  defp finding_fields(_image, %Finding{source: source}) when source in [:iptc, :xmp] do
    {:ok, []}
  end

  defp finding_fields(image, %Finding{source: :png_text, field: keyword}) do
    {:ok, Enum.filter(header_fields(image), &png_text_field?(&1, keyword))}
  end

  defp finding_fields(_image, %Finding{source: source}) when source in [:jpeg, :png] do
    {:ok, []}
  end

  defp finding_fields(_image, %Finding{} = finding) do
    unsupported(finding)
  end

  defp finding_fields(_image, other) do
    {:error,
     Image.Error.exception(
       reason: :invalid_finding,
       operation: :remove,
       value: other,
       message: "Expected an Image.Privacy.Finding, got #{inspect(other)}"
     )}
  end

  defp unsupported(%Finding{source: source, field: field} = finding) do
    {:error,
     Image.Error.exception(
       reason: :unsupported_finding,
       operation: :remove,
       value: finding,
       message: "Removing the #{source} field #{inspect(field)} on its own is not supported"
     )}
  end

  defp fields_with_prefix(image, prefix) do
    Enum.filter(header_fields(image), &String.starts_with?(&1, prefix))
  end

  defp png_text_field?(name, keyword) do
    match?(["png", "comment", _index, ^keyword], String.split(name, "-", parts: 4))
  end

  defp header_fields(image) do
    case Vimage.header_field_names(image) do
      {:ok, fields} -> fields
      {:error, _reason} -> []
    end
  end

  # A binary that starts with an image signature is the image's bytes,
  # as in `Image.open/2`, and any other binary is a path.
  defp read_bytes(<<0xFF, 0xD8, 0xFF, _rest::binary>> = bytes), do: {:ok, bytes}
  defp read_bytes(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _rest::binary>> = bytes), do: {:ok, bytes}
  defp read_bytes(<<"RIFF", _size::32, "WEBP", _rest::binary>> = bytes), do: {:ok, bytes}
  defp read_bytes(<<"GIF8", _rest::binary>> = bytes), do: {:ok, bytes}
  defp read_bytes(<<"II", 0x2A, 0x00, _rest::binary>> = bytes), do: {:ok, bytes}
  defp read_bytes(<<"MM", 0x00, 0x2A, _rest::binary>> = bytes), do: {:ok, bytes}
  defp read_bytes(<<_size::binary-size(4), "ftyp", _rest::binary>> = bytes), do: {:ok, bytes}

  defp read_bytes(path) do
    case File.read(path) do
      {:ok, bytes} ->
        {:ok, bytes}

      {:error, reason} ->
        {:error, Image.Error.exception(reason: reason, operation: :scan, path: path)}
    end
  end

  defp iptc_findings(image) do
    case Image.iptc(image) do
      {:ok, iptc} -> facebook_finding(iptc) ++ field_findings(:iptc, iptc, @iptc_fields)
      {:error, %Image.Error{reason: :no_iptc}} -> []
      {:error, %Image.Error{reason: reason}} -> [unreadable(:iptc, reason)]
    end
  end

  defp facebook_finding(%{special_instructions: @facebook_prefix <> _id = value}) do
    [finding(:iptc, :special_instructions, value, :tracking_id)]
  end

  defp facebook_finding(_iptc) do
    []
  end

  defp exif_findings(image) do
    case Image.exif(image) do
      {:ok, exif} ->
        field_findings(:exif, exif, @exif_ifd0_fields) ++
          field_findings(:exif, Map.get(exif, :exif, %{}), @exif_fields) ++
          gps_findings(exif)

      {:error, %Image.Error{reason: :no_exif}} ->
        []

      {:error, %Image.Error{reason: reason}} ->
        [unreadable(:exif, reason)]
    end
  end

  # A GPS block can hold only a compass direction or a timestamp, which
  # do not locate the image, so only the coordinates of where it was
  # taken and of the destination it records are reported.
  defp gps_findings(%{gps: %Gps{} = gps}) do
    position =
      coordinates(
        :gps,
        gps.gps_latitude,
        gps.gps_latitude_ref,
        gps.gps_longitude,
        gps.gps_longitude_ref
      )

    destination =
      coordinates(
        :gps_destination,
        gps.gps_dest_latitude,
        gps.gps_dest_latitude_ref,
        gps.gps_dest_longitude,
        gps.gps_dest_longitude_ref
      )

    position ++ destination
  end

  defp gps_findings(_exif) do
    []
  end

  defp coordinates(_field, nil, _latitude_ref, nil, _longitude_ref) do
    []
  end

  defp coordinates(field, latitude, latitude_ref, longitude, longitude_ref) do
    value = %{
      latitude: latitude,
      latitude_ref: latitude_ref,
      longitude: longitude,
      longitude_ref: longitude_ref
    }

    [finding(:exif, field, value, :location)]
  end

  # An EXIF thumbnail is a second copy of the picture that not every
  # editor updates, so it can show the image before it was cropped or
  # retouched. libvips exposes a JPEG thumbnail's bytes.
  defp thumbnail_findings(image) do
    case Vimage.header_value(image, "jpeg-thumbnail-data") do
      {:ok, data} when is_binary(data) and byte_size(data) > 0 ->
        [finding(:exif, :thumbnail, thumbnail_value(data), :hidden_data)]

      _other ->
        []
    end
  end

  # Only data with a JPEG signature is opened, so the bytes can never be
  # taken for a path.
  defp thumbnail_value(<<0xFF, 0xD8, 0xFF, _rest::binary>> = data) do
    case Image.open(data) do
      {:ok, thumbnail} ->
        %{
          format: :jpeg,
          bytes: byte_size(data),
          width: Image.width(thumbnail),
          height: Image.height(thumbnail)
        }

      {:error, _reason} ->
        %{format: :jpeg, bytes: byte_size(data), width: nil, height: nil}
    end
  end

  defp thumbnail_value(data) do
    %{format: :unknown, bytes: byte_size(data), width: nil, height: nil}
  end

  defp xmp_findings(image) do
    case Image.xmp(image) do
      {:ok, xmp} ->
        field_findings(:xmp, xmp, @xmp_fields) ++
          field_findings(:xmp, xmp.location, @xmp_location_fields) ++
          contact_finding(xmp) ++
          source_type_finding(xmp)

      {:error, %Image.Error{reason: :no_xmp}} ->
        []

      {:error, %Image.Error{reason: reason}} ->
        [unreadable(:xmp, reason)]
    end
  end

  # The creator's contact details are reported as one finding holding the
  # details the XMP has.
  defp contact_finding(%{creator_contact: contact}) do
    details = Map.reject(contact, fn {_key, value} -> is_nil(value) end)

    if map_size(details) == 0 do
      []
    else
      [finding(:xmp, :creator_contact, details, :person)]
    end
  end

  defp source_type_finding(%{digital_source_type: source_type}) when is_binary(source_type) do
    [finding(:xmp, :digital_source_type, source_type, source_type_kind(source_type))]
  end

  defp source_type_finding(_xmp) do
    []
  end

  # A digital source type is a term from the IPTC vocabulary, usually
  # written as the term's URI.
  defp source_type_kind(source_type) do
    term = List.last(String.split(source_type, "/"))

    if term in @ai_source_types do
      :ai_label
    else
      :provenance
    end
  end

  defp png_text_findings(image) do
    case Vimage.header_field_names(image) do
      {:ok, fields} -> Enum.flat_map(fields, &png_text_finding(image, &1))
      {:error, _reason} -> []
    end
  end

  defp png_text_finding(image, @png_text_prefix <> _rest = field) do
    case String.split(field, "-", parts: 4) do
      ["png", "comment", _index, keyword] -> png_text(image, field, keyword)
      _other -> []
    end
  end

  defp png_text_finding(_image, _field) do
    []
  end

  defp png_text(image, field, keyword) do
    case Vimage.header_value(image, field) do
      {:ok, text} when is_binary(text) and text != "" ->
        [finding(:png_text, keyword, text, :embedded_text)]

      _other ->
        []
    end
  end

  # A finding for each field of `fields` that `metadata` holds a value
  # for, in the order of `fields`.
  defp field_findings(source, metadata, fields) do
    Enum.flat_map(fields, fn {field, kind} ->
      value = Map.get(metadata, field)

      if blank?(value) do
        []
      else
        [finding(source, field, value, kind)]
      end
    end)
  end

  defp blank?(value) do
    value in [nil, "", []]
  end

  defp finding(source, field, value, kind) do
    %Finding{source: source, field: field, value: value, kind: kind}
  end

  defp unreadable(source, reason) do
    finding(source, nil, reason, :unreadable)
  end
end
