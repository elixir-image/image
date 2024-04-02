defmodule Image.Exif.Tag do
  @moduledoc false
  # Parse the different tag type values (strings, unsigned shorts, etc...)

  @max_signed_32_bit_int 2_147_483_647

  @type value :: binary()
  @type context :: {value(), non_neg_integer(), (any() -> non_neg_integer())}

  # unsigned byte, size = 1
  @spec value(non_neg_integer(), non_neg_integer(), value(), context()) :: any()
  def value(1, count, value, context),
    do: decode_numeric(value, count, 2, context)

  # ascii string, size = 1
  def value(2, count, value, {exif, _offset, ru}) do
    # ignore null-byte at end
    length = count - 1

    cond do
      count > 4 ->
        # + offset
        offset = ru.(value)
        <<_::binary-size(offset), string::binary-size(length), _::binary>> = exif
        string

      count == 0 ->
        ""

      true ->
        <<string::binary-size(length), _::binary>> = value
        string
    end
  end

  # unsigned short, size = 2
  def value(3, count, value, context),
    do: decode_numeric(value, count, 2, context)

  # unsigned long, size = 4
  def value(4, count, value, context),
    do: decode_numeric(value, count, 4, context)

  # unsigned rational, size = 8
  def value(5, count, value, context),
    do: decode_ratio(value, count, context, :unsigned)

  # undefined, size = 1
  def value(7, count, value, context),
    do: decode_numeric(value, count, 1, context)

  # signed rational, size = 8
  def value(10, count, value, context),
    do: decode_ratio(value, count, context, :signed)

  # Handle malformed tags
  def value(_, _, _, _), do: nil

  @spec decode_numeric(
          value :: value(),
          non_neg_integer(),
          non_neg_integer(),
          context()
        ) :: any()
  defp decode_numeric(value, count, size, {exif, _offset, ru}) do
    length = count * size

    values =
      if length > 4 do
        case exif do
          <<_::binary-size(value), data::binary-size(length), _::binary>> -> data
          # probably a maker_note or user_comment
          _ -> nil
        end
      else
        <<data::binary-size(length), _::binary>> = value
        data
      end

    if values do
      if count == 1 do
        ru.(values)
      else
        read_unsigned_many(values, size, ru)
      end
    end
  end

  @spec decode_ratio(
          value(),
          non_neg_integer(),
          context(),
          :unsigned | :signed
        ) :: any()
  defp decode_ratio(value_offset, count, {exif, _offset, ru}, signed) do
    exif
    |> decode_ratios(count, ru.(value_offset), ru, signed)
    |> do_decode_ratio(count)
  end

  @spec do_decode_ratio(list(), non_neg_integer()) :: any()
  defp do_decode_ratio([result | _], 1), do: result
  defp do_decode_ratio(result, _), do: result

  @spec decode_ratios(
          value :: value(),
          non_neg_integer(),
          non_neg_integer(),
          (any() -> non_neg_integer()),
          :unsigned | :signed
        ) :: list()
  defp decode_ratios(_data, 0, _offset, _ru, _signed), do: []

  defp decode_ratios(data, count, offset, ru, signed) do
    case data do
      <<_::binary-size(offset), numerator::binary-size(4), denominator::binary-size(4),
        rest::binary>> ->
        d = maybe_signed_int(ru.(denominator), signed)
        n = maybe_signed_int(ru.(numerator), signed)

        result =
          case {d, n} do
            {1, n} -> n
            {d, 1} -> "1/#{d}"
            {0, _} -> :infinity
            {d, n} -> round(n * 1000 / d) / 1000
          end

        [result | decode_ratios(rest, count - 1, 0, ru, signed)]

      _ ->
        []
    end
  end

  @spec read_unsigned_many(binary(), non_neg_integer(), ([any()] -> binary())) :: any()
  defp read_unsigned_many(<<>>, _size, _ru), do: []

  defp read_unsigned_many(data, size, ru) do
    <<number::binary-size(size), rest::binary>> = data
    [ru.(number) | read_unsigned_many(rest, size, ru)]
  end

  @spec maybe_signed_int(non_neg_integer(), :signed | :unsigned) :: non_neg_integer()
  defp maybe_signed_int(x, :signed) when x > @max_signed_32_bit_int,
    do: x - (@max_signed_32_bit_int + 1) * 2

  # +ve or unsigned
  defp maybe_signed_int(x, _), do: x
end
