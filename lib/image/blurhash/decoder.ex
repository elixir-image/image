defmodule Image.Blurhash.Decoder do
  @moduledoc false

  import Image.Blurhash.Utils
  alias Image.Blurhash.Base83

  import Bitwise

  def decode(blurhash, width, height) do
    with {:ok, {components_x, components_y}, rest} <- size_flag(blurhash),
         {:ok, max_ac, rest} <- max_ac(rest),
         {:ok, {average_color, dc}, rest} <- average_color_and_dc(rest),
         {:ok, matrix} <- construct_matrix(rest, max_ac, components_x, components_y, dc) do
      pixels = construct_pixel_iodata(width, height, matrix)

      {:ok, pixels, average_color}
    end
  end

  defp size_flag(blurhash) do
    with {:ok, encoded_flag, rest} <- decode_number(blurhash, 1) do
      x = rem(encoded_flag, 9) + 1
      y = floor(encoded_flag / 9) + 1
      {:ok, {x, y}, rest}
    end
  end

  defp max_ac(blurhash) do
    with {:ok, quantized_max, rest} <- decode_number(blurhash, 1) do
      {:ok, (quantized_max + 1) / 166, rest}
    end
  end

  defp average_color_and_dc(blurhash) do
    with {:ok, raw, rest} <- decode_number(blurhash, 4) do
      {r, g, b} = color = {bsr(raw, 16), band(bsr(raw, 8), 255), band(raw, 255)}
      dc = {srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b)}
      {:ok, {color, dc}, rest}
    end
  end

  def construct_matrix(encoded_ac, max_ac, x, y, dc) do
    size = x * y - 1

    # Index 0 is the DC component, so the AC components start at 1.
    1..size//1
    |> Enum.reduce_while({[], encoded_ac}, &decode_ac_component(&1, &2, x, max_ac))
    |> finish_matrix(dc)
  end

  defp decode_ac_component(index, {components, rest}, x, max_ac) do
    case decode_number(rest, 2) do
      {:ok, value, rest} ->
        {:cont, {[ac_component(index, value, x, max_ac) | components], rest}}

      error ->
        {:halt, error}
    end
  end

  # The matrix position is kept with the colour for the inverse DCT.
  defp ac_component(index, value, x, max_ac) do
    matrix_position = {rem(index, x), floor(index / x)}

    quantized_r = floor(value / (19 * 19))
    quantized_g = floor(rem(floor(value / 19), 19))
    quantized_b = rem(value, 19)

    r = unquantize_color(quantized_r, max_ac)
    g = unquantize_color(quantized_g, max_ac)
    b = unquantize_color(quantized_b, max_ac)

    {matrix_position, {r, g, b}}
  end

  defp finish_matrix({:error, _reason} = error, _dc) do
    error
  end

  defp finish_matrix({components, ""}, dc) do
    {:ok, [{{0, 0}, dc} | Enum.reverse(components)]}
  end

  defp finish_matrix({_components, _rest}, _dc) do
    {:error,
     %Image.Error{
       message: "Unexpected number of blurhash components",
       reason: "Unexpected number of blurhash components"
     }}
  end

  defp decode_number(string, length) do
    case Base83.decode_number(string, length) do
      {:ok, _value, _rest} = result -> result
      {:error, _reason} -> {:error, invalid_blurhash()}
    end
  end

  defp invalid_blurhash do
    %Image.Error{message: "Invalid blurhash", reason: "Invalid blurhash"}
  end

  def construct_pixel_iodata(width, height, matrix) do
    Enum.reduce((height - 1)..0//-1, [], fn y, acc ->
      pixel_row =
        Enum.reduce((width - 1)..0//-1, [], fn x, acc ->
          {linear_r, linear_g, linear_b} =
            Enum.reduce(matrix, {0, 0, 0}, fn {{component_x, component_y},
                                               {current_red, current_green, current_blue}},
                                              {red, green, blue} ->
              idct_basis =
                :math.cos(:math.pi() * x * component_x / width) *
                  :math.cos(:math.pi() * y * component_y / height)

              {red + current_red * idct_basis, green + current_green * idct_basis,
               blue + current_blue * idct_basis}
            end)

          r = linear_to_srgb(linear_r)
          g = linear_to_srgb(linear_g)
          b = linear_to_srgb(linear_b)

          [<<r::8, g::8, b::8>> | acc]
        end)

      [pixel_row | acc]
    end)
  end
end
