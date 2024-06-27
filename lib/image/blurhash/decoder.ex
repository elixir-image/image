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
    with {:ok, encoded_flag, rest} <- Base83.decode_number(blurhash, 1) do
      x = rem(encoded_flag, 9) + 1
      y = floor(encoded_flag / 9) + 1
      {:ok, {x, y}, rest}
    end
  end

  defp max_ac(blurhash) do
    with {:ok, quantized_max, rest} <- Base83.decode_number(blurhash, 1) do
      {:ok, (quantized_max + 1) / 166, rest}
    end
  end

  defp average_color_and_dc(blurhash) do
    with {:ok, raw, rest} <- Base83.decode_number(blurhash, 4) do
      {r, g, b} = color = {bsr(raw, 16), band(bsr(raw, 8), 255), band(raw, 255)}
      dc = {srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b)}
      {:ok, {color, dc}, rest}
    end
  end

  def construct_matrix(encoded_ac, max_ac, x, y, dc) do
    size = x * y - 1

    try do
      # We start with 1 because {0, 0} is the DC
      {ac_values, rest} =
        Enum.map_reduce(1..size, encoded_ac, fn index, rest ->
          case Base83.decode_number(rest, 2) do
            {:ok, value, rest} ->
              # add matrix position with the color since we will need it for
              # inverse dct later
              matrix_pos = {rem(index, x), floor(index / x)}

              quantized_r = floor(value / (19 * 19))
              quantized_g = floor(rem(floor(value / 19), 19))
              quantized_b = rem(value, 19)

              r = unquantize_color(quantized_r, max_ac)
              g = unquantize_color(quantized_g, max_ac)
              b = unquantize_color(quantized_b, max_ac)

              {{matrix_pos, {r, g, b}}, rest}

            # Haven't found a more elegant solution to throwing in this case
            error ->
              throw(error)
          end
        end)

      if rest != "" do
        {:error, "Unexpected number of blurhash components"}
      else
        {r, g, b} = dc
        matrix = [{{0, 0}, {r, g, b}} | ac_values]
        {:ok, matrix}
      end
    catch
      {:error, _} -> {:error, "Invalid blurhash"}
    end
  end

  def construct_pixel_iodata(width, height, matrix) do
    Enum.reduce((height - 1)..0, [], fn y, acc ->
      pixel_row =
        Enum.reduce((width - 1)..0, [], fn x, acc ->
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
