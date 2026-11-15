defmodule Image.Privacy.Jpeg do
  @moduledoc false

  # Reads a JPEG file's segments for data libvips does not expose:
  # comment segments and data after the end of the image. A file whose
  # APP2 segment carries a Multi-Picture Format (MPF) index holds more
  # images after the first, such as an UltraHDR gain map; those are
  # declared, so they are walked past rather than reported.

  alias Image.Privacy.{Finding, Trailer}

  @start_of_image 0xD8
  @end_of_image 0xD9
  @start_of_scan 0xDA
  @comment 0xFE
  @app2 0xE2

  # Markers with no length or payload: TEM and the restart markers.
  @standalone_markers [0x01 | Enum.to_list(0xD0..0xD7)]

  @spec scan(binary()) :: [Finding.t()]
  def scan(<<0xFF, @start_of_image, rest::binary>>) do
    case segments(rest, %{findings: [], mpf?: false}) do
      {:ok, state, trailer} -> Enum.reverse(state.findings) ++ trailer_findings(trailer, state.mpf?)
      {:truncated, state} -> Enum.reverse(state.findings)
    end
  end

  def scan(_binary) do
    []
  end

  # Fill bytes may precede a marker.
  defp segments(<<0xFF, 0xFF, rest::binary>>, state) do
    segments(<<0xFF, rest::binary>>, state)
  end

  defp segments(<<0xFF, @end_of_image, rest::binary>>, state) do
    {:ok, state, rest}
  end

  defp segments(<<0xFF, marker, rest::binary>>, state)
       when marker in @standalone_markers or marker == @start_of_image do
    segments(rest, state)
  end

  defp segments(<<0xFF, marker, length::16, rest::binary>>, state)
       when length >= 2 and byte_size(rest) >= length - 2 do
    {payload, rest} = :erlang.split_binary(rest, length - 2)
    state = segment(marker, payload, state)

    if marker == @start_of_scan do
      entropy_coded(rest, state)
    else
      segments(rest, state)
    end
  end

  defp segments(_rest, state) do
    {:truncated, state}
  end

  defp segment(@comment, payload, state) do
    text = clean_text(payload)

    if text == "" do
      state
    else
      finding = %Finding{source: :jpeg, field: :comment, value: text, kind: :embedded_text}
      %{state | findings: [finding | state.findings]}
    end
  end

  defp segment(@app2, <<"MPF", 0, _rest::binary>>, state) do
    %{state | mpf?: true}
  end

  defp segment(_marker, _payload, state) do
    state
  end

  # Entropy-coded data runs to the next marker. In it 0xFF is followed by
  # a stuffed zero byte or a restart marker, neither of which ends it.
  defp entropy_coded(binary, state) do
    case next_marker(binary, 0) do
      {:ok, position} ->
        segments(binary_part(binary, position, byte_size(binary) - position), state)

      :error ->
        {:truncated, state}
    end
  end

  defp next_marker(binary, from) do
    case :binary.match(binary, <<0xFF>>, scope: {from, byte_size(binary) - from}) do
      {position, 1} -> marker_at(binary, position)
      :nomatch -> :error
    end
  end

  defp marker_at(binary, position) when position + 1 < byte_size(binary) do
    case :binary.at(binary, position + 1) do
      0x00 -> next_marker(binary, position + 2)
      0xFF -> next_marker(binary, position + 1)
      byte when byte in 0xD0..0xD7 -> next_marker(binary, position + 2)
      _marker -> {:ok, position}
    end
  end

  defp marker_at(_binary, _position) do
    :error
  end

  defp trailer_findings(trailer, mpf?) do
    Trailer.findings(:jpeg, skip_declared_images(trailer, mpf?))
  end

  # With an MPF index, each JPEG after the first is a declared image.
  defp skip_declared_images(<<0xFF, @start_of_image, rest::binary>> = trailer, true) do
    case segments(rest, %{findings: [], mpf?: true}) do
      {:ok, _state, rest} -> skip_declared_images(rest, true)
      {:truncated, _state} -> trailer
    end
  end

  defp skip_declared_images(trailer, _mpf?) do
    trailer
  end

  # Removes trailing zero bytes and surrounding white space. Text that is
  # not UTF-8 is read as Latin-1.
  defp clean_text(payload) do
    text = String.trim_trailing(payload, <<0>>)

    text =
      if String.valid?(text) do
        text
      else
        :unicode.characters_to_binary(text, :latin1)
      end

    String.trim(text)
  end
end
