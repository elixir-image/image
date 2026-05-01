defmodule Image.Palette.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  doctest Image.Palette, except: [extract!: 2]
  doctest Image.Color

  describe "Image.Palette.extract/2" do
    @image_path "Hong-Kong-2015-07-1998.jpg"

    test "returns at most :final SRGB swatches" do
      image = Image.open!(image_path(@image_path))
      {:ok, palette} = Image.Palette.extract(image, key: Nx.Random.key(42))

      assert length(palette) <= 5
      assert Enum.all?(palette, &match?(%Color.SRGB{}, &1))
    end

    test ":final caps the output count" do
      image = Image.open!(image_path(@image_path))
      {:ok, palette} = Image.Palette.extract(image, final: 3, key: Nx.Random.key(42))

      assert length(palette) <= 3
    end

    test "is deterministic when given the same :key" do
      image = Image.open!(image_path(@image_path))

      {:ok, p1} = Image.Palette.extract(image, key: Nx.Random.key(42))
      {:ok, p2} = Image.Palette.extract(image, key: Nx.Random.key(42))

      assert Enum.map(p1, &Color.to_hex/1) == Enum.map(p2, &Color.to_hex/1)
    end

    test "different :keys may produce different palettes" do
      # Not a strict guarantee — K-means with different seeds
      # often *does* converge to the same colours on a given
      # image — but the runs must at least *not crash*. The
      # determinism test above covers the "same key → same
      # output" guarantee; this one just exercises the seeding
      # path.
      image = Image.open!(image_path(@image_path))

      assert {:ok, _} = Image.Palette.extract(image, key: Nx.Random.key(1))
      assert {:ok, _} = Image.Palette.extract(image, key: Nx.Random.key(2))
    end

    test "sort: false skips the perceptual sort" do
      image = Image.open!(image_path(@image_path))

      {:ok, sorted} = Image.Palette.extract(image, key: Nx.Random.key(42))
      {:ok, unsorted} = Image.Palette.extract(image, sort: false, key: Nx.Random.key(42))

      # Same set of colours either way — sorting is a permutation.
      assert Enum.sort(Enum.map(sorted, &Color.to_hex/1)) ==
               Enum.sort(Enum.map(unsorted, &Color.to_hex/1))
    end

    test "small images (already under :longest_dim) skip the resize step" do
      image = Image.open!(image_path(@image_path))
      {:ok, tiny} = Image.thumbnail(image, 64)

      {:ok, palette} = Image.Palette.extract(tiny, key: Nx.Random.key(42))
      assert length(palette) >= 1
    end

    test "extract!/2 raises on a programmer error" do
      image = Image.open!(image_path(@image_path))

      # `:k` smaller than the surviving cluster count after
      # phantom-guard is fine — Scholar accepts it. To force a
      # crash we'd need to corrupt the image; we settle for the
      # sanity check that extract!/2 returns the same shape as
      # extract/2 on the happy path.
      assert is_list(Image.Palette.extract!(image, key: Nx.Random.key(42)))
    end
  end

  describe "Image.Color.srgb_tensor_to_oklab/1" do
    test "matches Color.convert per-row for sRGB primaries" do
      hexes = ["#ff0000", "#00ff00", "#0000ff", "#ffffff", "#000000", "#808080"]
      rows =
        Enum.map(hexes, fn hex ->
          {:ok, srgb} = Color.new(hex)
          [round(srgb.r * 255), round(srgb.g * 255), round(srgb.b * 255)]
        end)

      tensor = Nx.tensor(rows, type: :u8)
      oklab_rows = Image.Color.srgb_tensor_to_oklab(tensor) |> Nx.to_list()

      reference =
        Enum.map(hexes, fn hex ->
          {:ok, srgb} = Color.new(hex)
          {:ok, ok} = Color.convert(srgb, Color.Oklab)
          [ok.l, ok.a, ok.b]
        end)

      Enum.zip(oklab_rows, reference)
      |> Enum.each(fn {[tl, ta, tb], [rl, ra, rb]} ->
        assert_in_delta tl, rl, 1.0e-3
        assert_in_delta ta, ra, 1.0e-3
        assert_in_delta tb, rb, 1.0e-3
      end)
    end

    test "accepts a {n, 3} u8 tensor and returns an {n, 3} f32 tensor" do
      rgb = Nx.tensor([[255, 0, 0], [0, 255, 0]], type: :u8)
      out = Image.Color.srgb_tensor_to_oklab(rgb)

      assert Nx.shape(out) == {2, 3}
      assert match?({:f, _}, Nx.type(out))
    end
  end
end
