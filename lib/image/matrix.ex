defmodule Image.Matrix do
  @moduledoc false

  # Adapted from [Nx.tensor/2](https://hexdocs.pm/nx/Nx.html#tensor/2)

  def image_from_matrix(list) when is_list(list) do
    with {:ok, type} <- infer_type(list),
         {:ok, [width, height]} <- dimensions(list),
         {:ok, format} <- Image.BandFormat.image_format_from_nx(type),
         {:ok, image} <- Vix.Vips.Image.new_matrix_from_array(width, height, list) do
      Image.Vips.Operation.cast(image, format)
    end
  end

  ### Helpers

  defp dimensions(list) do
    case do_dimensions(list, []) do
      {:ok, [_width, _height] = dimensions} ->
        {:ok, dimensions}

      {:ok, other} ->
        {:error,
         matrix_error(
           "A matrix must be a two-dimensional list of lists of numbers. " <>
             "Found dimensions #{inspect(other)}"
         )}

      {:error, _reason} = error ->
        error
    end
  end

  defp do_dimensions([], dimensions) do
    {:ok, [0 | dimensions]}
  end

  defp do_dimensions([head | rest], parent_dimensions) when is_list(head) do
    with {:ok, child_dimensions} <- do_dimensions(head, []) do
      rest
      |> Enum.reduce_while({:ok, 1}, fn list, {:ok, count} ->
        case do_dimensions(list, []) do
          {:ok, ^child_dimensions} ->
            {:cont, {:ok, count + 1}}

          {:ok, other_dimensions} ->
            {:halt,
             {:error,
              matrix_error(
                "Cannot build image because lists have different shapes: " <>
                  inspect(List.to_tuple(child_dimensions)) <>
                  " at position 0 and " <>
                  inspect(List.to_tuple(other_dimensions)) <> " at position #{count}"
              )}}

          {:error, _reason} = error ->
            {:halt, error}
        end
      end)
      |> case do
        {:ok, count} -> {:ok, child_dimensions ++ [count | parent_dimensions]}
        {:error, _reason} = error -> error
      end
    end
  end

  defp do_dimensions(list, dimensions) when is_list(list) do
    {:ok, [length(list) | dimensions]}
  end

  defp do_dimensions(_scalar, dimensions) do
    {:ok, dimensions}
  end

  defp infer_type(list) when is_list(list) do
    list
    |> Enum.reduce_while({:ok, nil}, fn element, {:ok, acc} ->
      case infer_type(element) do
        {:ok, type} when is_nil(acc) -> {:cont, {:ok, type}}
        {:ok, type} -> {:cont, {:ok, merge(type, acc)}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, nil} -> {:error, matrix_error("Cannot infer the type of an empty matrix")}
      other -> other
    end
  end

  defp infer_type(number) when is_number(number) do
    {:ok, infer(number)}
  end

  defp infer_type(value) do
    {:error, matrix_error("Invalid matrix value: #{inspect(value)}")}
  end

  defp matrix_error(message) do
    %Image.Error{message: message, reason: message}
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
