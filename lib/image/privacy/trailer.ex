defmodule Image.Privacy.Trailer do
  @moduledoc false

  # Reports data found after the end of an image file: bytes a viewer
  # never shows, such as an appended video, an archive or a maker's
  # private index.

  alias Image.Privacy.Finding

  @doc """
  Returns a `:hidden_data` finding for `trailer`, or an empty list when
  it is empty or only zero padding.
  """
  @spec findings(Finding.source(), binary()) :: [Finding.t()]
  def findings(source, trailer) do
    if padding?(trailer) do
      []
    else
      value = %{format: format(trailer), bytes: byte_size(trailer)}
      [%Finding{source: source, field: :trailer, value: value, kind: :hidden_data}]
    end
  end

  # Samsung's trailer can start with an MP4 video and ends with its
  # "SEFT" index, so it is recognised first.
  defp format(trailer) do
    if String.ends_with?(trailer, "SEFT") do
      :samsung
    else
      signature(trailer)
    end
  end

  defp signature(<<0xFF, 0xD8, _rest::binary>>) do
    :jpeg
  end

  defp signature(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _rest::binary>>) do
    :png
  end

  defp signature(<<"PK", 0x03, 0x04, _rest::binary>>) do
    :zip
  end

  defp signature(<<_size::binary-size(4), "ftyp", _rest::binary>>) do
    :mp4
  end

  defp signature(_trailer) do
    :unknown
  end

  defp padding?(binary) do
    binary == :binary.copy(<<0>>, byte_size(binary))
  end
end
