if Code.ensure_loaded?(Nx) do
  defmodule Image.Nx.Test do
    use ExUnit.Case, async: true
    import Image.TestSupport

    test "An image can be used in Nx as a tensor" do
      {:ok, image} = Vix.Vips.Operation.black(3, 3)
      {:ok, tensor} = Vix.Vips.Image.write_to_tensor(image)

      %Vix.Tensor{data: binary, names: names, shape: shape, type: type} = tensor

      assert Nx.tensor(
               [
                 [
                   [0],
                   [0],
                   [0]
                 ],
                 [
                   [0],
                   [0],
                   [0]
                 ],
                 [
                   [0],
                   [0],
                   [0]
                 ]
               ],
               type: {:u, 8},
               names: names,
               backend: Nx.BinaryBackend
             ) ==
               binary
               |> Nx.from_binary(type, backend: Nx.BinaryBackend)
               |> Nx.reshape(shape, names: names)
    end

    test "That an image round trips to Nx and back" do
      image = image_path("Kamchatka-2019-8754.jpg")

      {:ok, image} = Image.open(image, access: :random)

      {:ok, tensor} = Image.to_nx(image)
      {:ok, image2} = Image.from_nx(tensor)

      assert_images_equal image, image2

      {:ok, tensor} = Image.to_nx(image, shape: :hwc)
      {:ok, image2} = Image.from_nx(tensor)

      assert_images_equal image, image2

      {:ok, tensor} = Image.to_nx(image, shape: :whc)
      {:ok, image2} = Image.from_nx(tensor)

      assert_images_equal image, image2
    end
  end
end
