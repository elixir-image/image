defmodule Image.Blurhash.Encoder do
  @moduledoc false

  import Image.Blurhash.Utils
  alias Image.Blurhash.Base83

  import Bitwise

  def encode(pixels, width, height, components_x, components_y) do
    components = calculate_components(pixels, components_x, components_y, width, height)
    {:ok, encode_blurhash(components, components_x, components_y)}
  end

  defp encode_blurhash([dc | ac], x, y) do
    size_flag = encode_size_flag(x, y)
    dc = encode_dc(dc)
    {max_ac, ac} = encode_ac(ac)

    size_flag <> max_ac <> dc <> ac
  end

  defp calculate_component(pixels, component_x, component_y, width, height, acc \\ {{0, 0, 0}, 0})

  defp calculate_component(
         <<r::8, g::8, b::8, rest::binary>>,
         component_x,
         component_y,
         width,
         height,
         {{acc_r, acc_g, acc_b}, index}
       ) do
    pixel_x = rem(index, width)
    pixel_y = floor(index / width)

    # DC
    normalization_factor =
      unless component_x == 0 and component_y == 0,
        do: 2,
        else: 1

    basis =
      normalization_factor * :math.cos(:math.pi() * pixel_x * component_x / width) *
        :math.cos(:math.pi() * pixel_y * component_y / height)

    linear_r = srgb_to_linear(r)
    linear_g = srgb_to_linear(g)
    linear_b = srgb_to_linear(b)

    acc_r = acc_r + basis * linear_r
    acc_g = acc_g + basis * linear_g
    acc_b = acc_b + basis * linear_b

    acc = {{acc_r, acc_g, acc_b}, index + 1}
    calculate_component(rest, component_x, component_y, width, height, acc)
  end

  defp calculate_component(_, _, _, width, height, {{r, g, b}, _}) do
    scale = 1 / (width * height)
    {r * scale, g * scale, b * scale}
  end

  defp calculate_components(pixels, x, y, width, height) do
    for y <- 0..(y - 1),
        x <- 0..(x - 1) do
      {{x, y}, calculate_component(pixels, x, y, width, height)}
    end
  end

  defp encode_size_flag(x, y) do
    Base83.encode_number(x - 1 + (y - 1) * 9, 1)
  end

  defp encode_dc({_, {linear_r, linear_g, linear_b}}) do
    r = linear_to_srgb(linear_r)
    g = linear_to_srgb(linear_g)
    b = linear_to_srgb(linear_b)

    Base83.encode_number(bsl(r, 16) + bsl(g, 8) + b, 4)
  end

  defp encode_ac([]) do
    {Base83.encode_number(0, 1), ""}
  end

  defp encode_ac(ac) do
    max_ac = Enum.reduce(ac, -2, fn {_, {r, g, b}}, max_ac -> Enum.max([max_ac, r, g, b]) end)

    quantized_max_ac = floor(max(0, min(82, floor(max_ac * 166 - 0.5))))
    max_ac_for_quantization = (quantized_max_ac + 1) / 166

    encoded_max_ac = Base83.encode_number(quantized_max_ac, 1)

    encoded_components =
      Enum.reduce(ac, "", fn {_, {r, g, b}}, hash ->
        r = quantize_color(r, max_ac_for_quantization)
        g = quantize_color(g, max_ac_for_quantization)
        b = quantize_color(b, max_ac_for_quantization)
        hash <> Base83.encode_number(r * 19 * 19 + g * 19 + b, 2)
      end)

    {encoded_max_ac, encoded_components}
  end
end
