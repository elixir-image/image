defmodule Image.Iptc do
  @moduledoc """
  Functions to extract and interpret image IPTC data.

  [IPTC IIM](https://iptc.org/standards/iim/) metadata is a sequence
  of datasets, each identified by a record number and a dataset
  number. Record 1 is the envelope and record 2 holds the application
  data: captions, keywords, credits, locations and the like. Platforms
  also use it to carry identifiers. Facebook, for example, writes an
  `FBMD…` string into dataset 2:40, Special Instructions, and an
  identifier into dataset 2:103, Original Transmission Reference.

  In a JPEG, IPTC is stored in an APP13 segment as a Photoshop image
  resource block, `0x0404`. libvips returns the whole APP13 payload,
  starting with the `Photoshop 3.0` header, as the image's
  `"iptc-data"` field. TIFF files carry the bare IIM records. Both
  forms are accepted.

  The primary API is `Image.iptc/1`, which reads the IPTC of an
  image, and `extract_iptc/1`, which parses an IPTC blob.

  """

  @photoshop_header "Photoshop 3.0" <> <<0>>
  @iptc_resource 0x0404

  # Photoshop keeps an MD5 digest of the IPTC data in this resource, and
  # treats the IPTC as edited elsewhere when it no longer matches.
  @iptc_digest_resource 0x0425
  @tag_marker 0x1C

  # Photoshop writes "8BIM"; the others appear in files from older
  # tools and use the same layout.
  @resource_signatures ["8BIM", "PHUT", "AgHg", "DCSR", "MeSa"]

  # Known datasets, keyed by {record, dataset}. The kind says how the
  # value is decoded: `:text`, `:text_list` for repeatable text,
  # `:date` for CCYYMMDD, `:unsigned` for a big-endian integer and
  # `:binary` for data kept as it is.
  @datasets %{
    {1, 0} => {:envelope_record_version, :unsigned},
    {1, 5} => {:destination, :text_list},
    {1, 20} => {:file_format, :unsigned},
    {1, 22} => {:file_format_version, :unsigned},
    {1, 30} => {:service_identifier, :text},
    {1, 40} => {:envelope_number, :text},
    {1, 50} => {:product_id, :text_list},
    {1, 60} => {:envelope_priority, :text},
    {1, 70} => {:date_sent, :date},
    {1, 80} => {:time_sent, :text},
    {1, 90} => {:coded_character_set, :binary},
    {1, 100} => {:unique_name_of_object, :text},
    {1, 120} => {:arm_identifier, :unsigned},
    {1, 122} => {:arm_version, :unsigned},
    {2, 0} => {:record_version, :unsigned},
    {2, 3} => {:object_type_reference, :text},
    {2, 4} => {:object_attribute_reference, :text_list},
    {2, 5} => {:object_name, :text},
    {2, 7} => {:edit_status, :text},
    {2, 8} => {:editorial_update, :text},
    {2, 10} => {:urgency, :text},
    {2, 12} => {:subject_reference, :text_list},
    {2, 15} => {:category, :text},
    {2, 20} => {:supplemental_category, :text_list},
    {2, 22} => {:fixture_identifier, :text},
    {2, 25} => {:keywords, :text_list},
    {2, 26} => {:content_location_code, :text_list},
    {2, 27} => {:content_location_name, :text_list},
    {2, 30} => {:release_date, :date},
    {2, 35} => {:release_time, :text},
    {2, 37} => {:expiration_date, :date},
    {2, 38} => {:expiration_time, :text},
    {2, 40} => {:special_instructions, :text},
    {2, 42} => {:action_advised, :text},
    {2, 45} => {:reference_service, :text_list},
    {2, 47} => {:reference_date, :text_list},
    {2, 50} => {:reference_number, :text_list},
    {2, 55} => {:date_created, :date},
    {2, 60} => {:time_created, :text},
    {2, 62} => {:digital_creation_date, :date},
    {2, 63} => {:digital_creation_time, :text},
    {2, 65} => {:originating_program, :text},
    {2, 70} => {:program_version, :text},
    {2, 75} => {:object_cycle, :text},
    {2, 80} => {:by_line, :text_list},
    {2, 85} => {:by_line_title, :text_list},
    {2, 90} => {:city, :text},
    {2, 92} => {:sub_location, :text},
    {2, 95} => {:province_state, :text},
    {2, 100} => {:country_code, :text},
    {2, 101} => {:country_name, :text},
    {2, 103} => {:original_transmission_reference, :text},
    {2, 105} => {:headline, :text},
    {2, 110} => {:credit, :text},
    {2, 115} => {:source, :text},
    {2, 116} => {:copyright_notice, :text},
    {2, 118} => {:contact, :text_list},
    {2, 120} => {:caption_abstract, :text},
    {2, 122} => {:writer_editor, :text_list},
    {2, 125} => {:rasterized_caption, :binary},
    {2, 130} => {:image_type, :text},
    {2, 131} => {:image_orientation, :text},
    {2, 135} => {:language_identifier, :text},
    {2, 200} => {:object_preview_file_format, :unsigned},
    {2, 201} => {:object_preview_file_format_version, :unsigned},
    {2, 202} => {:object_preview_data, :binary}
  }

  # Dataset names to their {record, dataset} numbers.
  @dataset_numbers Map.new(@datasets, fn {key, {name, _kind}} -> {name, key} end)

  # The envelope and application record versions and the coded character
  # set describe the record rather than hold content.
  @structural_datasets [{1, 0}, {1, 90}, {2, 0}]

  @doc """
  Extracts an IPTC metadata blob into an Elixir map.

  ### Arguments

  * `iptc` is the IPTC blob as a binary. It may be a JPEG APP13
    payload starting with the `Photoshop 3.0` header, which is the
    form libvips returns from
    `Vix.Vips.Image.header_value(image, "iptc-data")` for a JPEG, a
    sequence of Photoshop image resource blocks, or the bare IIM
    records.

  ### Returns

  * `{:ok, iptc_map}` where `iptc_map` maps each dataset name, such as
    `:keywords` or `:special_instructions`, to its value. Repeatable
    datasets, such as `:keywords` and `:by_line`, are lists in the
    order they appear. Dates are `t:Date.t/0` when valid. A dataset
    with no name is keyed by its `{record, dataset}` numbers and holds
    a list of its raw values. A blob with no IPTC records returns an
    empty map, or

  * `{:error, %Image.Error{reason: :invalid_iptc}}` if the blob is
    truncated or is not IPTC.

  ### Examples

      iex> Image.Iptc.extract_iptc(<<0x1C, 2, 25, 0, 3, "sea", 0x1C, 2, 25, 0, 3, "sky">>)
      {:ok, %{keywords: ["sea", "sky"]}}

      iex> {:error, %Image.Error{reason: :invalid_iptc}} = Image.Iptc.extract_iptc("not iptc")

  """
  @doc since: "0.74.0"

  @spec extract_iptc(binary()) :: {:ok, map()} | {:error, Image.Error.t()}
  def extract_iptc(<<@photoshop_header, resources::binary>>) do
    extract_resources(resources)
  end

  def extract_iptc(<<signature::binary-size(4), _rest::binary>> = resources)
      when signature in @resource_signatures do
    extract_resources(resources)
  end

  def extract_iptc(iptc) when is_binary(iptc) do
    with {:ok, datasets} <- datasets(iptc, []) do
      {:ok, decode(datasets)}
    end
  end

  def extract_iptc(other) do
    invalid("IPTC data must be a binary", other)
  end

  @doc false
  # Removes the datasets named in `names` (dataset names, or
  # `{record, dataset}` numbers for datasets with no name) and returns the
  # IPTC blob in the form it was given, or `nil` when no content is left.
  # Other datasets and Photoshop resources are kept byte for byte, and
  # Photoshop's IPTC digest is recomputed.
  @spec remove_datasets(binary(), [atom() | {byte(), byte()}]) ::
          {:ok, binary() | nil} | {:error, Image.Error.t()}
  def remove_datasets(<<@photoshop_header, resources::binary>>, names) do
    with {:ok, rewritten} <- remove_from_resources(resources, names) do
      {:ok, rewritten && @photoshop_header <> rewritten}
    end
  end

  def remove_datasets(<<signature::binary-size(4), _rest::binary>> = resources, names)
      when signature in @resource_signatures do
    remove_from_resources(resources, names)
  end

  def remove_datasets(iim, names) when is_binary(iim) do
    with {:ok, datasets} <- datasets(iim, []) do
      {:ok, encode_iim(drop_datasets(datasets, dataset_keys(names)))}
    end
  end

  defp remove_from_resources(resources, names) do
    with {:ok, blocks} <- resource_blocks(resources, []),
         {:ok, blocks} <- rewrite_iptc_blocks(blocks, dataset_keys(names)) do
      {:ok, encode_blocks(blocks)}
    end
  end

  defp rewrite_iptc_blocks(blocks, keys) do
    results = Enum.map(blocks, &rewrite_block(&1, keys))

    case Enum.find(results, &match?({:error, _reason}, &1)) do
      nil -> {:ok, update_digest(Enum.flat_map(results, fn {:ok, block} -> block end))}
      error -> error
    end
  end

  defp rewrite_block({signature, @iptc_resource, name, data}, keys) do
    with {:ok, datasets} <- datasets(data, []) do
      case encode_iim(drop_datasets(datasets, keys)) do
        nil -> {:ok, []}
        iim -> {:ok, [{signature, @iptc_resource, name, iim}]}
      end
    end
  end

  defp rewrite_block(block, _keys) do
    {:ok, [block]}
  end

  defp update_digest(blocks) do
    iim = iptc_data(blocks)

    Enum.flat_map(blocks, fn
      {_signature, @iptc_digest_resource, _name, _data} when iim == <<>> ->
        []

      {signature, @iptc_digest_resource, name, _data} ->
        [{signature, @iptc_digest_resource, name, :crypto.hash(:md5, iim)}]

      block ->
        [block]
    end)
  end

  defp dataset_keys(names) do
    Enum.flat_map(names, fn
      {_record, _number} = key -> [key]
      name -> List.wrap(Map.get(@dataset_numbers, name))
    end)
  end

  defp drop_datasets(datasets, keys) do
    Enum.reject(datasets, fn {record, number, _value} -> {record, number} in keys end)
  end

  # Datasets that only describe the record carry no content of their own.
  defp encode_iim(datasets) do
    if Enum.all?(datasets, fn {record, number, _value} ->
         {record, number} in @structural_datasets
       end) do
      nil
    else
      for {record, number, value} <- datasets, into: <<>> do
        <<@tag_marker, record, number>> <> encode_length(byte_size(value)) <> value
      end
    end
  end

  defp encode_length(length) when length < 0x8000 do
    <<length::16>>
  end

  defp encode_length(length) do
    <<1::1, 4::15, length::32>>
  end

  defp encode_blocks([]) do
    nil
  end

  defp encode_blocks(blocks) do
    for {signature, id, name, data} <- blocks, into: <<>> do
      name_padding = :binary.copy(<<0>>, rem(byte_size(name) + 1, 2))
      data_padding = :binary.copy(<<0>>, rem(byte_size(data), 2))

      signature <>
        <<id::16, byte_size(name)>> <>
        name <> name_padding <> <<byte_size(data)::32>> <> data <> data_padding
    end
  end

  defp extract_resources(resources) do
    with {:ok, blocks} <- resource_blocks(resources, []),
         {:ok, datasets} <- datasets(iptc_data(blocks), []) do
      {:ok, decode(datasets)}
    end
  end

  defp iptc_data(blocks) do
    for {_signature, @iptc_resource, _name, data} <- blocks, into: <<>> do
      data
    end
  end

  # Walks the Photoshop image resource blocks, returning each as
  # `{signature, id, name, data}`. A block is a signature, a 16-bit id,
  # a Pascal string name padded to an even length, a 32-bit size and the
  # data, padded to an even length.
  defp resource_blocks(<<signature::binary-size(4), id::16, name_length, rest::binary>>, acc)
       when signature in @resource_signatures do
    name_size = name_length + rem(name_length + 1, 2)

    with {:ok, name_and_padding, rest} <- take(rest, name_size),
         {:ok, <<size::32>>, rest} <- take(rest, 4),
         {:ok, data, rest} <- take(rest, size) do
      name = binary_part(name_and_padding, 0, name_length)

      rest
      |> drop_padding(size)
      |> resource_blocks([{signature, id, name, data} | acc])
    end
  end

  defp resource_blocks(rest, acc) do
    if padding?(rest) do
      {:ok, Enum.reverse(acc)}
    else
      invalid("Invalid Photoshop image resource block in IPTC data", rest)
    end
  end

  defp drop_padding(<<_padding, rest::binary>>, size) when rem(size, 2) == 1 do
    rest
  end

  defp drop_padding(rest, _size) do
    rest
  end

  # Walks the IIM datasets. Each is the tag marker, a record number, a
  # dataset number and a length. A length with its top bit set is
  # extended: its other 15 bits give the size in bytes of the length
  # that follows.
  defp datasets(<<@tag_marker, record, number, 0::1, length::15, rest::binary>>, acc) do
    dataset(rest, length, record, number, acc)
  end

  defp datasets(<<@tag_marker, record, number, 1::1, size::15, rest::binary>>, acc)
       when size in 1..4 do
    with {:ok, length, rest} <- take(rest, size) do
      dataset(rest, :binary.decode_unsigned(length), record, number, acc)
    end
  end

  defp datasets(rest, acc) do
    if padding?(rest) do
      {:ok, Enum.reverse(acc)}
    else
      invalid("Invalid IPTC dataset", rest)
    end
  end

  defp dataset(binary, length, record, number, acc) do
    with {:ok, value, rest} <- take(binary, length) do
      datasets(rest, [{record, number, value} | acc])
    end
  end

  defp take(binary, count) when byte_size(binary) >= count do
    {part, rest} = :erlang.split_binary(binary, count)
    {:ok, part, rest}
  end

  defp take(binary, _count) do
    invalid("Truncated IPTC data", binary)
  end

  # Writers pad the end of a block with zero bytes.
  defp padding?(binary) do
    binary == :binary.copy(<<0>>, byte_size(binary))
  end

  # Builds the map in reverse dataset order, so a repeatable dataset's
  # list ends up in file order and a non-repeatable dataset that appears
  # more than once keeps its first value.
  defp decode(datasets) do
    datasets
    |> Enum.reverse()
    |> Enum.reduce(%{}, fn {record, number, value}, iptc ->
      put_dataset(iptc, Map.get(@datasets, {record, number}), {record, number}, value)
    end)
  end

  defp put_dataset(iptc, nil, key, value) do
    Map.update(iptc, key, [value], &[value | &1])
  end

  defp put_dataset(iptc, {name, :text_list}, _key, value) do
    text = decode_value(:text, value)
    Map.update(iptc, name, [text], &[text | &1])
  end

  defp put_dataset(iptc, {name, kind}, _key, value) do
    Map.put(iptc, name, decode_value(kind, value))
  end

  defp decode_value(:text, value) do
    value
    |> trim_nulls()
    |> to_utf8()
  end

  defp decode_value(:date, <<year::binary-size(4), month::binary-size(2), day::binary-size(2)>>) do
    case Date.from_iso8601("#{year}-#{month}-#{day}") do
      {:ok, date} -> date
      {:error, _reason} -> decode_value(:text, year <> month <> day)
    end
  end

  defp decode_value(:date, value) do
    decode_value(:text, value)
  end

  defp decode_value(:unsigned, value) do
    :binary.decode_unsigned(value)
  end

  defp decode_value(:binary, value) do
    value
  end

  # Some writers terminate text with a zero byte.
  defp trim_nulls(value) do
    String.trim_trailing(value, <<0>>)
  end

  # Text that is valid UTF-8 is kept as it is, whatever dataset 1:90
  # declares, and anything else is read as Latin-1, which never fails.
  defp to_utf8(value) do
    if String.valid?(value) do
      value
    else
      :unicode.characters_to_binary(value, :latin1)
    end
  end

  # A binary is not kept in the error: an IPTC block can be large.
  defp invalid(message, value) when is_binary(value) do
    {:error, Image.Error.exception(reason: :invalid_iptc, message: message)}
  end

  defp invalid(message, value) do
    {:error, Image.Error.exception(reason: :invalid_iptc, message: message, value: value)}
  end
end
