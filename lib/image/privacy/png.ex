defmodule Image.Privacy.Png do
  @moduledoc false

  # Walks a PNG file's chunks to its IEND chunk and reports any data
  # after it. libvips already exposes the text chunks (tEXt, zTXt and
  # iTXt), so they are left to the metadata scan.

  alias Image.Privacy.{Finding, Trailer}

  @signature <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A>>

  @spec scan(binary()) :: [Finding.t()]
  def scan(<<@signature, chunks::binary>>) do
    case end_of_image(chunks) do
      {:ok, trailer} -> Trailer.findings(:png, trailer)
      :truncated -> []
    end
  end

  def scan(_binary) do
    []
  end

  # A chunk is a 32-bit length, a four-byte type, the data and a 32-bit
  # CRC.
  defp end_of_image(<<length::32, "IEND", rest::binary>>) when byte_size(rest) >= length + 4 do
    {_data_and_crc, trailer} = :erlang.split_binary(rest, length + 4)
    {:ok, trailer}
  end

  defp end_of_image(<<length::32, _type::binary-size(4), rest::binary>>)
       when byte_size(rest) >= length + 4 do
    {_data_and_crc, rest} = :erlang.split_binary(rest, length + 4)
    end_of_image(rest)
  end

  defp end_of_image(_rest) do
    :truncated
  end
end
