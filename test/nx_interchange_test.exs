defmodule Image.NxInterchangeTest do
  use ExUnit.Case, async: true

  # A non-square image makes axis-order mistakes visible: width 4, height 2.
  defp non_square, do: Image.new!(4, 2, color: [255, 0, 0])

  describe "to_nx/2" do
    test "returns {height, width, bands} with :hwc names by default" do
      {:ok, tensor} = Image.to_nx(non_square(), backend: Nx.BinaryBackend)

      assert Nx.shape(tensor) == {2, 4, 3}
      assert Nx.names(tensor) == [:height, :width, :bands]
    end

    test "shape: :whc transposes the data, not just the labels" do
      # Regression: :whc reshaped (relabelled) rather than transposed, so
      # the axis names did not describe the data layout.
      {:ok, image} = Image.Draw.point(non_square(), 3, 1, color: :blue)
      {:ok, tensor} = Image.to_nx(image, shape: :whc, backend: Nx.BinaryBackend)

      assert Nx.shape(tensor) == {4, 2, 3}
      assert Nx.names(tensor) == [:width, :height, :bands]
      assert Nx.to_flat_list(tensor[3][1]) == [0, 0, 255]
    end

    test "returns an error for an unknown shape" do
      assert {:error, %Image.Error{message: "Invalid shape" <> _}} =
               Image.to_nx(non_square(), shape: :bogus)
    end
  end

  describe "from_nx/1" do
    test "round trips the default :hwc tensor" do
      image = non_square()
      {:ok, tensor} = Image.to_nx(image, backend: Nx.BinaryBackend)
      {:ok, round_tripped} = Image.from_nx(tensor)

      assert Image.shape(round_tripped) == Image.shape(image)
    end

    test "round trips a :whc tensor by transposing it back" do
      image = non_square()
      {:ok, tensor} = Image.to_nx(image, shape: :whc, backend: Nx.BinaryBackend)
      {:ok, round_tripped} = Image.from_nx(tensor)

      assert Image.shape(round_tripped) == Image.shape(image)
    end

    test "interprets unnamed tensors as {height, width, bands}" do
      # Regression: unnamed tensors were interpreted as
      # {width, height, bands}, contradicting the documentation and
      # garbling standard HWC tensors from other libraries.
      unnamed = Nx.broadcast(Nx.tensor(128, type: :u8), {2, 4, 3})
      {:ok, image} = Image.from_nx(unnamed)

      assert Image.shape(image) == {4, 2, 3}
    end

    test "returns an error for a two-dimensional tensor" do
      assert {:error, %Image.Error{message: "The tensor must have the shape" <> _}} =
               Image.from_nx(Nx.iota({3, 3}, type: :u8))
    end
  end
end
