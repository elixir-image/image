defmodule Image.Blurhash.Base83 do
  @moduledoc false

  alphabet =
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~"
    |> String.to_charlist()

  for {encoded, value} <- Enum.with_index(alphabet) do
    def encode_char(unquote(value)) do
      unquote(encoded)
    end

    def decode_char(unquote(encoded)) do
      unquote(value)
    end
  end

  def decode_number(string, length, acc \\ 0)

  def decode_number(rest, 0, acc) do
    {:ok, acc, rest}
  end

  def decode_number(<<>>, _, _) do
    {:error, :unexpected_end}
  end

  def decode_number(<<char, rest::binary>>, length, acc) do
    decode_number(rest, length - 1, acc * 83 + decode_char(char))
  end

  def encode_number(_, 0), do: ""

  def encode_number(number, length) do
    divisor = floor(:math.pow(83, length - 1))
    remainder = rem(number, divisor)
    quotient = floor(number / divisor)

    <<encode_char(quotient)>> <> encode_number(remainder, length - 1)
  end
end
