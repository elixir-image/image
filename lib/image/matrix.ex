defmodule Image.Matrix do
  @moduledoc false

  # Adapted from [Nx.tensor/2](https://hexdocs.pm/nx/Nx.html#tensor/2)

  def image_from_matrix(list) when is_list(list) do
    type = infer_type(list)
    [width, height] = dimensions(list)

    with {:ok, format} <- Image.BandFormat.image_format_from_nx(type),
         {:ok, image} = Vix.Vips.Image.new_matrix_from_array(width, height, list) do
      Vix.Vips.Operation.cast(image, format)
    end
  end

  ### Helpers

  defp dimensions(list) do
    dimensions(list, [])
  end

  defp dimensions([], dimensions) do
    [0 | dimensions]
  end

  defp dimensions([head | rest], parent_dimensions) when is_list(head) do
    child_dimensions = dimensions(head, [])

    n =
      Enum.reduce(rest, 1, fn list, count ->
        case dimensions(list, []) do
          ^child_dimensions ->
            count + 1

          other_dimensions ->
            raise ArgumentError,
                  "cannot build image because lists have different shapes, got " <>
                    inspect(List.to_tuple(child_dimensions)) <>
                    " at position 0 and " <>
                    inspect(List.to_tuple(other_dimensions)) <> " at position #{count + 1}"
        end
      end)

    child_dimensions ++ [n | parent_dimensions]
  end

  defp dimensions(list, dimensions) do
    [length(list) | dimensions]
  end

  defp infer_type([head | tail]) when is_list(tail) do
    Enum.reduce(tail, infer_type(head), &merge(infer_type(&1), &2))
  end

  defp infer_type(number) when is_number(number) do
    infer(number)
  end

  defp infer_type(value) do
    raise ArgumentError,
          "invalid value given to Image.Matrix.binary_from_list/1, got: #{inspect(value)}"
  end

  defp infer(value) when is_integer(value), do: {:s, 64}
  defp infer(value) when is_float(value), do: {:f, 32}

  defp merge({type, left_size}, {type, right_size}) do
    {type, max(left_size, right_size)}
  end

  defp merge(left, right) do
    case sort(left, right) do
      {{:u, size1}, {:s, size2}} -> {:s, max(min(size1 * 2, 64), size2)}
      {_, type2} -> type2
    end
  end

  defp sort({left_type, _} = left, {right_type, _} = right) do
    if type_to_int(left_type) < type_to_int(right_type) do
      {left, right}
    else
      {right, left}
    end
  end

  defp type_to_int(:c), do: 4
  defp type_to_int(:f), do: 3
  defp type_to_int(:bf), do: 2
  defp type_to_int(:s), do: 1
  defp type_to_int(:u), do: 0
end
