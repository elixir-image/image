if Code.ensure_loaded?(Nx) do
  defmodule Image.Nx do
    @moduledoc false

    import Nx

    @doc """
    Returns a new 1-D tensor which indexes the input
    tensor according to the mask.

    The mask values are interpreted as `0` being `false`
    and any other value being `true`.

    """
    def masked_select(tensor, mask) do
      n = sum(mask) |> to_number()
      rank = rank(tensor)
      indices = argsort(mask, axis: rank - 1, direction: :desc)
      slice_along_axis(indices, 0, n, axis: rank - 1)
    end

    @doc """
    Find the unique elements of a tensor.

    Returns the sorted unique elements of a tensor and
    optionally also return the count of each unique
    value.

    """
    def unique(tensor, options \\ []) do
      return_counts? = options[:return_counts]

      sorted_tensor =
        tensor
        |> flatten()
        |> sort()

      not_equal =
        not_equal(sorted_tensor[1..-1//1], sorted_tensor[0..-2//1])

      mask =
        concatenate([tensor([1]), not_equal])

      indices = masked_select(sorted_tensor, mask)
      values = take(sorted_tensor, indices)

      if return_counts? do
        indicies = concatenate([nonzero(mask), tensor([size(mask)])])
        counts = diff(indicies)
        {values, counts}
      else
        {values, nil}
      end
    end

    @doc """
    Return the indices of the elements that are non-zero.

    """
    def nonzero(tensor) do
      mask = logical_or(tensor, tensor)
      masked_select(tensor, mask)
    end
  end
end
