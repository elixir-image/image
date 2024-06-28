if match?({:module, _module}, Code.ensure_compiled(Scholar.Cluster.KMeans)) do
  defmodule Image.Scholar do
    import Nx

    alias Vix.Vips.Image, as: Vimage

    @square_256 256 ** 2
    @bands 3

    def unique_colors(%Vimage{} = image) do
      with {:ok, tensor} <- Image.to_nx(image) do
        bands = Image.bands(image)

        colors_base256 =
          tensor
          |> encode_colors(bands)
          |> Nx.flatten()
          |> Nx.sort()

        diff =
          diff(colors_base256)

        unique_indices_selector =
          Nx.concatenate([Nx.tensor([1]), Nx.not_equal(diff, 0)])

        marked_unique_indices =
          Nx.select(unique_indices_selector, Nx.iota(colors_base256.shape), -1)

        repeated_count =
          Nx.to_number(Nx.sum(Nx.logical_not(unique_indices_selector)))

        unique_indices =
          marked_unique_indices
          |> Nx.sort()
          |> Nx.slice_along_axis(repeated_count, Nx.size(marked_unique_indices) - repeated_count,
            axis: 0
          )

        unique_colors =
          Nx.take(colors_base256, unique_indices)
          |> decode_colors(bands)

        count = div(Nx.size(colors_base256), @bands)
        max = Nx.to_number(Nx.reduce_max(unique_indices))
        color_count = Nx.concatenate([diff(unique_indices), Nx.tensor([count - max])])

        {:ok, {color_count, unique_colors}}
      end
    end

    def k_means(%Vimage{} = image, options \\ []) do
      with {:ok, {_count, colors}} <- unique_colors(image) do
        Scholar.Cluster.KMeans.fit(colors, options)
      end
    end

    defp encode_colors(colors, 3) do
      colors
      |> Nx.multiply(Nx.tensor([[1, 256, @square_256]]))
      |> Nx.sum(axes: [2])
    end

    defp encode_colors(colors, 4) do
      colors
      |> Nx.multiply(Nx.tensor([[1, 256, @square_256, 256 * @square_256]]))
      |> Nx.sum(axes: [2])
    end

    defp decode_colors(encoded_colors, 3) do
      b = Nx.quotient(encoded_colors, @square_256)
      rem = Nx.remainder(encoded_colors, @square_256)
      g = Nx.quotient(rem, 256)
      r = Nx.remainder(rem, 256)

      Nx.stack([r, g, b], axis: 1)
    end

    defp decode_colors(encoded_colors, 4) do
      a = Nx.quotient(encoded_colors, 256 * @square_256)
      rem = Nx.remainder(encoded_colors, 256 * @square_256)
      b = Nx.quotient(rem, @square_256)
      rem = Nx.remainder(rem, @square_256)
      g = Nx.quotient(rem, 256)
      r = Nx.remainder(rem, 256)

      Nx.stack([r, g, b, a], axis: 1)
    end
  end
end
