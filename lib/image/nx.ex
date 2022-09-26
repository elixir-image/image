if match?({:module, _module}, Code.ensure_compiled(Nx)) do
  defmodule Image.Nx do
    @moduledoc false

    # Nx helpers

    # libvips expect the dimensions to be [width, height, bands]. In Nx
    # its common they are [height, width, bands]. So we transpose the
    # axes if required to conform to `libvips` requirements.

    def transpose(tensor, {_, _, bands}, [:height, :width, band]) when bands in 1..5 do
      {:ok, Nx.transpose(tensor, axes: [:width, :height, band])}
    end

    def transpose(tensor, {_, _, bands}, [:width, :height, _band]) when bands in 1..5 do
      {:ok, tensor}
    end

    def transpose(_tensor, {_, _, bands}, _names) when bands not in 1..5 do
      {:error, "Tensor must be in the range of 1 and 5 image bands. Found #{inspect bands}."}
    end

    def transpose(_tensor, shape, _names) when tuple_size(shape) > 3 do
      {:error, "Tensor must have only three dimensions. Found #{inspect tuple_size(shape)}."}
    end

    def transpose(_tensor, _shape, names) do
      {:error,
        "Tensor must have dimension names of [:height, :width, :bands] or " <>
        "[:width, :height, :bands]. Found #{inspect names}."}
    end
  end
end