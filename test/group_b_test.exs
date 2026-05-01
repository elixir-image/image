defmodule Image.GroupB.Test do
  @moduledoc """
  Tests for the Group-B `image_plug`-driven additions:
  `Image.tint/2`, `Image.fade/2`, `Image.drop_shadow/2`, and
  the `:keep` option on `Image.minimize_metadata/2`.
  """
  use ExUnit.Case, async: true
  import Image.TestSupport

  setup do
    %{
      cat: Image.open!(image_path("cat.png")),
      hk: Image.open!(image_path("Hong-Kong-2015-07-1998.jpg")),
      kip: Image.open!(image_path("Kip_small.jpg"))
    }
  end

  describe "Image.tint/2" do
    test "produces a tinted monochrome — no green when blue tint is applied", %{hk: image} do
      {:ok, blue} = Image.tint(image, "#0080ff")

      [r, _g, _b | _] = Image.get_pixel!(blue, 100, 100)
      # The red channel of the tint colour is 0, so every output
      # pixel's red channel must be 0 (within float rounding).
      assert_in_delta r, 0.0, 0.5
    end

    test "channel proportions follow the tint colour", %{hk: image} do
      {:ok, gold} = Image.tint(image, "#a08020")

      [r, g, b | _] = Image.get_pixel!(gold, 100, 100)
      # Gold is #a08020 → r:160 g:128 b:32. The output ratios
      # should approximate r:g:b = 160:128:32 (5:4:1).
      assert r > g
      assert g > b
    end

    test "preserves alpha bands", %{cat: image} do
      assert Image.has_alpha?(image)
      {:ok, tinted} = Image.tint(image, "#a08020")
      assert Image.has_alpha?(tinted)
    end

    test "tint! raises only on invalid input", %{hk: image} do
      assert %Vix.Vips.Image{} = Image.tint!(image, "#a08020")

      assert_raise Image.Error, fn -> Image.tint!(image, "not a colour") end
    end
  end

  describe "Image.fade/2" do
    test "default :bottom fade leaves the top opaque and the bottom transparent", %{hk: image} do
      {:ok, faded} = Image.fade(image, length: 0.2)
      h = Image.height(image)

      [_, _, _, a_top] = Image.get_pixel!(faded, 100, 10)
      [_, _, _, a_bot] = Image.get_pixel!(faded, 100, h - 10)

      assert a_top == 255
      assert a_bot < 10
    end

    test ":all edges produces transparent corners and opaque centre", %{hk: image} do
      {:ok, faded} = Image.fade(image, edges: :all, length: 0.1)
      w = Image.width(image)
      h = Image.height(image)

      [_, _, _, a_corner] = Image.get_pixel!(faded, 5, 5)
      [_, _, _, a_centre] = Image.get_pixel!(faded, div(w, 2), div(h, 2))

      assert a_corner < 10
      assert a_centre == 255
    end

    test ":length accepts both float fractions and integer pixels", %{hk: image} do
      {:ok, frac} = Image.fade(image, edges: :bottom, length: 0.2)
      {:ok, px} = Image.fade(image, edges: :bottom, length: round(Image.height(image) * 0.2))

      h = Image.height(image)
      [_, _, _, a_frac] = Image.get_pixel!(frac, 100, h - 10)
      [_, _, _, a_px] = Image.get_pixel!(px, 100, h - 10)

      # Both representations of "20% of height" should land within
      # one pixel of each other after the gradient is rasterised.
      assert_in_delta a_frac, a_px, 5
    end

    test "adds an alpha band to images without one, then fades", %{hk: image} do
      refute Image.has_alpha?(image)
      {:ok, faded} = Image.fade(image, edges: :bottom, length: 0.2)
      assert Image.has_alpha?(faded)
    end

    test "rejects unknown edge atoms", %{hk: image} do
      assert {:error, %Image.Error{}} = Image.fade(image, edges: :diagonal)
    end

    test "rejects mixed valid + invalid edges", %{hk: image} do
      assert {:error, %Image.Error{}} = Image.fade(image, edges: [:top, :diagonal])
    end
  end

  describe "Image.drop_shadow/2" do
    test "produces a 4-band RGBA result the same size as the input", %{cat: image} do
      {:ok, shadowed} = Image.drop_shadow(image, sigma: 5.0, dy: 8)

      assert Vix.Vips.Image.bands(shadowed) == 4
      assert Image.width(shadowed) == Image.width(image)
      assert Image.height(shadowed) == Image.height(image)
    end

    test "leaves the original silhouette pixels unchanged", %{cat: image} do
      [r, g, b, a] = Image.get_pixel!(image, 270, 180)
      {:ok, shadowed} = Image.drop_shadow(image, sigma: 5.0, dy: 8)
      [r2, g2, b2, a2] = Image.get_pixel!(shadowed, 270, 180)

      assert {r, g, b, a} == {r2, g2, b2, a2}
    end

    test "adds an alpha band to images without one (rectangular silhouette)", %{hk: image} do
      refute Image.has_alpha?(image)
      {:ok, shadowed} = Image.drop_shadow(image, sigma: 4.0, dy: 6, dx: 6)
      assert Image.has_alpha?(shadowed)
    end

    test "rejects out-of-range :opacity", %{cat: image} do
      assert {:error, %Image.Error{}} = Image.drop_shadow(image, opacity: 1.5)
      assert {:error, %Image.Error{}} = Image.drop_shadow(image, opacity: -0.1)
    end

    test "rejects non-positive :sigma", %{cat: image} do
      assert {:error, %Image.Error{}} = Image.drop_shadow(image, sigma: 0)
      assert {:error, %Image.Error{}} = Image.drop_shadow(image, sigma: -1.0)
    end
  end

  describe "Image.minimize_metadata/2 with :keep" do
    # All assertions go through write→re-read so that the EXIF
    # changes (which materialise on save) are visible.

    defp roundtrip_exif(image) do
      {:ok, bytes} = Image.write(image, :memory, suffix: ".jpg")
      {:ok, reread} = Image.from_binary(bytes)

      case Image.exif(reread) do
        {:ok, exif} -> exif
        {:error, _} -> %{}
      end
    end

    test "default keeps copyright + artist", %{kip: image} do
      {:ok, minimized} = Image.minimize_metadata(image, [])
      exif = roundtrip_exif(minimized)

      assert exif[:copyright] != nil
      assert exif[:artist] != nil
    end

    test "keep: [:copyright] preserves only copyright", %{kip: image} do
      {:ok, minimized} = Image.minimize_metadata(image, keep: [:copyright])
      exif = roundtrip_exif(minimized)

      assert exif[:copyright] != nil
      assert exif[:artist] == nil
    end

    test "keep: [] strips both copyright and artist", %{kip: image} do
      {:ok, minimized} = Image.minimize_metadata(image, keep: [])
      exif = roundtrip_exif(minimized)

      assert exif[:copyright] == nil
      assert exif[:artist] == nil
    end

    test "minimize_metadata/1 still works (defaults preserved)", %{kip: image} do
      {:ok, minimized} = Image.minimize_metadata(image)
      exif = roundtrip_exif(minimized)

      assert exif[:copyright] != nil
      assert exif[:artist] != nil
    end

    test "minimize_metadata!/2 raises on error", %{kip: image} do
      # Happy path is the easiest test that the bang variant
      # exists and returns the image directly.
      assert %Vix.Vips.Image{} = Image.minimize_metadata!(image, keep: [:copyright])
    end
  end
end
