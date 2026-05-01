defmodule Image.GroupA.Test do
  @moduledoc """
  Tests for the Group-A `image_plug`-driven additions:
  `Image.gamma/2`, `Image.sepia/2`, `Image.posterize/2`,
  `Image.opacity/2`, `Image.set_orientation/2`, and the
  `:lossy` / `:chroma_subsampling` write options.

  Also covers the `add_alpha/2` constant fix where `:opaque`
  used to write an alpha=0 band.
  """
  use ExUnit.Case, async: true
  import Image.TestSupport

  setup do
    %{
      cat: Image.open!(image_path("cat.png")),
      hk: Image.open!(image_path("Hong-Kong-2015-07-1998.jpg"))
    }
  end

  describe "Image.gamma/2" do
    test "is a no-op at exponent 1.0", %{cat: image} do
      orig_pixel = Image.get_pixel!(image, 270, 180)
      {:ok, same} = Image.gamma(image, 1.0)
      assert Image.get_pixel!(same, 270, 180) == orig_pixel
    end

    test "exponent > 1.0 brightens the image", %{cat: image} do
      [r, _, _, _] = Image.get_pixel!(image, 270, 180)
      {:ok, brighter} = Image.gamma(image, 1.5)
      [r2, _, _, _] = Image.get_pixel!(brighter, 270, 180)
      assert r2 > r
    end

    test "exponent < 1.0 darkens the image", %{cat: image} do
      [r, _, _, _] = Image.get_pixel!(image, 270, 180)
      {:ok, darker} = Image.gamma(image, 0.6)
      [r2, _, _, _] = Image.get_pixel!(darker, 270, 180)
      assert r2 < r
    end

    test "rejects non-positive exponents", %{cat: image} do
      assert_raise FunctionClauseError, fn -> Image.gamma(image, 0.0) end
      assert_raise FunctionClauseError, fn -> Image.gamma(image, -0.5) end
    end

    test "gamma! raises only on invalid input", %{cat: image} do
      assert %Vix.Vips.Image{} = Image.gamma!(image, 1.4)
    end
  end

  describe "Image.sepia/2" do
    test "strength 0.0 is the identity", %{cat: image} do
      pixel = Image.get_pixel!(image, 270, 180)
      {:ok, none} = Image.sepia(image, 0.0)
      [r1, g1, b1, _] = pixel
      [r2, g2, b2, _] = Image.get_pixel!(none, 270, 180)
      assert_in_delta r1, r2, 0.5
      assert_in_delta g1, g2, 0.5
      assert_in_delta b1, b2, 0.5
    end

    test "strength 1.0 produces classic sepia (red >= green >= blue)", %{cat: image} do
      {:ok, full} = Image.sepia(image)
      [r, g, b | _] = Image.get_pixel!(full, 270, 180)
      assert r >= g
      assert g >= b
    end

    test "intermediate strengths blend toward sepia", %{cat: image} do
      [r0, g0, b0 | _] = Image.get_pixel!(image, 270, 180)
      {:ok, half} = Image.sepia(image, 0.5)
      [r, g, b | _] = Image.get_pixel!(half, 270, 180)

      # The blended pixel sits between original and full sepia
      # along each channel.
      {:ok, full} = Image.sepia(image, 1.0)
      [rf, gf, bf | _] = Image.get_pixel!(full, 270, 180)

      assert (r >= min(r0, rf) and r <= max(r0, rf)) or abs(r - (r0 + rf) / 2) < 5
      assert (g >= min(g0, gf) and g <= max(g0, gf)) or abs(g - (g0 + gf) / 2) < 5
      assert (b >= min(b0, bf) and b <= max(b0, bf)) or abs(b - (b0 + bf) / 2) < 5
    end

    test "rejects out-of-range strengths", %{cat: image} do
      assert_raise FunctionClauseError, fn -> Image.sepia(image, 1.5) end
      assert_raise FunctionClauseError, fn -> Image.sepia(image, -0.1) end
    end
  end

  describe "Image.posterize/2" do
    test "with 2 levels produces only 2 distinct values per band", %{hk: image} do
      {:ok, p2} = Image.posterize(image, 2)

      values =
        for x <- 0..(Image.width(image) - 1)//200,
            y <- 0..(Image.height(image) - 1)//200,
            do: Image.get_pixel!(p2, x, y)

      r_values = values |> Enum.map(&hd/1) |> Enum.uniq()
      assert length(r_values) <= 2
    end

    test "with 256 levels is effectively a no-op", %{hk: image} do
      orig = Image.get_pixel!(image, 100, 100)
      {:ok, p} = Image.posterize(image, 256)
      assert Image.get_pixel!(p, 100, 100) == orig
    end

    test "rejects out-of-range levels", %{hk: image} do
      assert_raise FunctionClauseError, fn -> Image.posterize(image, 1) end
      assert_raise FunctionClauseError, fn -> Image.posterize(image, 257) end
    end
  end

  describe "Image.opacity/2" do
    test "halves the alpha band at factor 0.5", %{cat: image} do
      [_, _, _, a0] = Image.get_pixel!(image, 270, 180)
      {:ok, half} = Image.opacity(image, 0.5)
      [_, _, _, a] = Image.get_pixel!(half, 270, 180)
      assert_in_delta a, a0 * 0.5, 1.0
    end

    test "factor 0.0 produces alpha = 0 (fully transparent)", %{cat: image} do
      {:ok, gone} = Image.opacity(image, 0.0)
      [_, _, _, a] = Image.get_pixel!(gone, 270, 180)
      assert a == 0
    end

    test "adds an opaque alpha band when missing, then scales", %{hk: image} do
      refute Image.has_alpha?(image)
      {:ok, half} = Image.opacity(image, 0.5)
      assert Image.has_alpha?(half)
      [_, _, _, a] = Image.get_pixel!(half, 100, 100)
      assert_in_delta a, 127, 1
    end

    test "rejects factors outside [0, 1]", %{cat: image} do
      assert_raise FunctionClauseError, fn -> Image.opacity(image, 1.5) end
      assert_raise FunctionClauseError, fn -> Image.opacity(image, -0.5) end
    end
  end

  describe "Image.set_orientation/2" do
    test "writes the EXIF orientation header", %{hk: image} do
      {:ok, with_o} = Image.set_orientation(image, 6)
      assert Vix.Vips.Image.header_value(with_o, "orientation") == {:ok, 6}
    end

    test "leaves pixels untouched", %{hk: image} do
      orig = Image.get_pixel!(image, 100, 100)
      {:ok, with_o} = Image.set_orientation(image, 8)
      assert Image.get_pixel!(with_o, 100, 100) == orig
    end

    test "rejects out-of-range orientations", %{hk: image} do
      assert_raise FunctionClauseError, fn -> Image.set_orientation(image, 0) end
      assert_raise FunctionClauseError, fn -> Image.set_orientation(image, 9) end
    end
  end

  describe "add_alpha/2 with :opaque / :transparent" do
    test ":opaque produces alpha = 255 (standard RGBA)", %{hk: image} do
      {:ok, with_a} = Image.add_alpha(image, :opaque)
      [_, _, _, a] = Image.get_pixel!(with_a, 100, 100)
      assert a == 255
    end

    test ":transparent produces alpha = 0 (standard RGBA)", %{hk: image} do
      {:ok, with_a} = Image.add_alpha(image, :transparent)
      [_, _, _, a] = Image.get_pixel!(with_a, 100, 100)
      assert a == 0
    end

    test "integer values pass through unchanged", %{hk: image} do
      {:ok, with_a} = Image.add_alpha(image, 200)
      [_, _, _, a] = Image.get_pixel!(with_a, 100, 100)
      assert a == 200
    end
  end

  describe "Image.write/3 :lossy and :chroma_subsampling options" do
    test ":chroma_subsampling on JPEG controls chroma layout", %{hk: image} do
      {:ok, off} = Image.write(image, :memory, suffix: ".jpg", quality: 75, chroma_subsampling: :off)

      {:ok, default} = Image.write(image, :memory, suffix: ".jpg", quality: 75)

      # 4:4:4 (off) keeps full chroma resolution → file is larger
      # than the libvips default (which sub-samples at q=75).
      assert byte_size(off) > byte_size(default)
    end

    test ":chroma_subsampling :auto / :on / :off all valid on JPEG", %{hk: image} do
      for mode <- [:auto, :on, :off] do
        assert {:ok, _bytes} =
                 Image.write(image, :memory, suffix: ".jpg", chroma_subsampling: mode)
      end
    end

    test ":chroma_subsampling rejected on PNG", %{hk: image} do
      assert {:error, _} = Image.write(image, :memory, suffix: ".png", chroma_subsampling: :on)
    end

    test ":lossy true/false on WebP toggles lossless wire format", %{hk: image} do
      {:ok, lossy} = Image.write(image, :memory, suffix: ".webp", quality: 75, lossy: true)

      {:ok, lossless} = Image.write(image, :memory, suffix: ".webp", quality: 75, lossy: false)

      # Lossless is dramatically larger than lossy.
      assert byte_size(lossless) > byte_size(lossy) * 2
    end

    test ":lossy rejected on JPEG", %{hk: image} do
      assert {:error, _} = Image.write(image, :memory, suffix: ".jpg", lossy: true)
    end
  end
end
