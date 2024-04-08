defmodule Image.Blurhash.Utils do
  @moduledoc false

  def srgb_to_linear(srgb_color) do
    value = srgb_color / 255

    if value <= 0.04045,
      do: value / 12.92,
      else: :math.pow((value + 0.055) / 1.055, 2.4)
  end

  def linear_to_srgb(linear_color) do
    value = max(0, min(1, linear_color))

    if value <= 0.0031308,
      do: round(value * 12.92 * 255 + 0.5),
      else: round((1.055 * :math.pow(value, 1 / 2.4) - 0.055) * 255 + 0.5)
  end

  defp sign_pow(value, exponent) do
    sign =
      if value < 0,
        do: -1,
        else: 1

    sign * :math.pow(abs(value), exponent)
  end

  def unquantize_color(quantized_color, max_ac),
    do: sign_pow((quantized_color - 9) / 9, 2) * max_ac

  def quantize_color(color, max_ac) do
    value = floor(sign_pow(color / max_ac, 0.5) * 9 + 9.5)

    cond do
      value > 18 -> 18
      value < 0 -> 0
      true -> value
    end
  end
end
