defmodule Image.AdjustmentsCoverageTest do
  use ExUnit.Case, async: true

  import Image.TestSupport

  alias Vix.Vips.Image, as: Vimage

  describe "brightness/2 and brightness!/2" do
    test "increases brightness" do
      image = Image.new!(10, 10, color: [100, 100, 100])

      assert {:ok, brightened} = Image.brightness(image, 1.5)
      [red, green, blue] = Image.get_pixel!(brightened, 5, 5)
      assert red > 100 and green > 100 and blue > 100
    end

    test "decreases brightness" do
      image = Image.new!(10, 10, color: [100, 100, 100])

      assert {:ok, darkened} = Image.brightness(image, 0.5)
      [red, green, blue] = Image.get_pixel!(darkened, 5, 5)
      assert red < 100 and green < 100 and blue < 100
    end

    test "brightness of 1.0 leaves the image close to unchanged" do
      image = Image.new!(10, 10, color: [100, 100, 100])

      assert {:ok, adjusted} = Image.brightness(image, 1.0)
      [red, _green, _blue] = Image.get_pixel!(adjusted, 5, 5)
      assert_in_delta red, 100, 2
    end

    test "brightness!/2 returns an image" do
      image = Image.new!(10, 10, color: [100, 100, 100])

      assert %Vimage{} = Image.brightness!(image, 1.5)
    end
  end

  describe "contrast/2 and contrast!/2" do
    test "increases contrast" do
      dark = Image.new!(10, 10, color: [50, 50, 50])

      assert {:ok, contrasted} = Image.contrast(dark, 1.5)
      [red, _green, _blue] = Image.get_pixel!(contrasted, 5, 5)
      # Dark tones get darker when contrast increases
      assert red < 50
    end

    test "decreases contrast" do
      dark = Image.new!(10, 10, color: [50, 50, 50])

      assert {:ok, contrasted} = Image.contrast(dark, 0.5)
      [red, _green, _blue] = Image.get_pixel!(contrasted, 5, 5)
      # Dark tones move towards the middle when contrast decreases
      assert red > 50
    end

    test "an invalid contrast value returns an error" do
      image = Image.new!(10, 10, color: :white)

      assert {:error, %Image.Error{message: message}} = Image.contrast(image, -1.0)
      assert message =~ "Invalid contrast"
    end

    test "contrast!/2 raises for an invalid contrast value" do
      image = Image.new!(10, 10, color: :white)

      assert_raise Image.Error, ~r/Invalid contrast/, fn ->
        Image.contrast!(image, -1.0)
      end
    end

    test "contrast!/2 returns an image" do
      image = Image.new!(10, 10, color: [50, 50, 50])

      assert %Vimage{} = Image.contrast!(image, 1.2)
    end
  end

  describe "saturation/2 and saturation!/2" do
    test "desaturating moves channels towards each other" do
      image = Image.new!(10, 10, color: [200, 50, 50])

      assert {:ok, desaturated} = Image.saturation(image, 0.1)
      [red, green, _blue] = Image.get_pixel!(desaturated, 5, 5)
      assert abs(red - green) < 150
    end

    test "increasing saturation preserves shape" do
      image = Image.new!(10, 10, color: [200, 50, 50])

      assert {:ok, saturated} = Image.saturation(image, 1.5)
      assert Image.shape(saturated) == {10, 10, 3}
    end

    test "saturation!/2 returns an image" do
      image = Image.new!(10, 10, color: [200, 50, 50])

      assert %Vimage{} = Image.saturation!(image, 1.5)
    end
  end

  describe "gamma/2 and gamma!/2" do
    test "gamma greater than 1.0 brightens midtones" do
      image = Image.new!(10, 10, color: [100, 100, 100])

      assert {:ok, adjusted} = Image.gamma(image, 2.2)
      [red, _green, _blue] = Image.get_pixel!(adjusted, 5, 5)
      assert red > 100
    end

    test "gamma less than 1.0 darkens midtones" do
      image = Image.new!(10, 10, color: [100, 100, 100])

      assert {:ok, adjusted} = Image.gamma(image, 0.5)
      [red, _green, _blue] = Image.get_pixel!(adjusted, 5, 5)
      assert red < 100
    end

    test "gamma!/2 returns an image" do
      image = Image.new!(10, 10, color: [100, 100, 100])

      assert %Vimage{} = Image.gamma!(image, 2.2)
    end
  end

  describe "sepia/2 and sepia!/2" do
    test "applies a sepia tone at full strength" do
      image = Image.new!(10, 10, color: [100, 100, 100])

      assert {:ok, sepia} = Image.sepia(image)
      [red, green, blue] = Image.get_pixel!(sepia, 5, 5)
      # Sepia gives warm tones: red >= green >= blue
      assert red >= green
      assert green >= blue
    end

    test "applies a partial-strength sepia tone" do
      image = Image.new!(10, 10, color: [100, 100, 100])

      assert {:ok, sepia} = Image.sepia(image, 0.5)
      assert Image.shape(sepia) == {10, 10, 3}
    end

    test "sepia!/2 returns an image" do
      image = Image.new!(10, 10, color: [100, 100, 100])

      assert %Vimage{} = Image.sepia!(image)
    end
  end

  describe "invert/1 and invert!/1" do
    test "inverts pixel values" do
      image = Image.new!(10, 10, color: [10, 100, 200])

      assert {:ok, inverted} = Image.invert(image)
      assert Image.get_pixel!(inverted, 5, 5) == [245, 155, 55]
    end

    test "inverting twice returns the original values" do
      image = Image.new!(10, 10, color: [10, 100, 200])

      {:ok, inverted} = Image.invert(image)
      {:ok, restored} = Image.invert(inverted)

      assert Image.get_pixel!(restored, 5, 5) == [10, 100, 200]
    end

    test "invert!/1 returns an image" do
      image = Image.new!(10, 10, color: [10, 100, 200])

      assert %Vimage{} = Image.invert!(image)
    end
  end

  describe "equalize/2 and equalize!/2" do
    test "equalizes all bands" do
      image = Image.open!(image_path("Kip_small.jpg"), access: :random)

      assert {:ok, equalized} = Image.equalize(image, :all)
      assert Image.shape(equalized) == Image.shape(image)
    end

    test "equalizes the luminance band" do
      image = Image.open!(image_path("Kip_small.jpg"), access: :random)

      assert {:ok, equalized} = Image.equalize(image, :luminance)
      assert Image.shape(equalized) == Image.shape(image)
      assert Image.colorspace(equalized) == Image.colorspace(image)
    end

    test "default is :all" do
      image = Image.open!(image_path("Kip_small.jpg"), access: :random)

      assert {:ok, %Vimage{}} = Image.equalize(image)
    end

    test "returns an error for invalid bands" do
      image = Image.new!(10, 10, color: :white)

      assert {:error, %Image.Error{message: message}} = Image.equalize(image, :invalid)
      assert message =~ "Invalid bands parameter"
    end

    test "equalize!/2 returns an image" do
      image = Image.open!(image_path("Kip_small.jpg"), access: :random)

      assert %Vimage{} = Image.equalize!(image, :all)
    end

    test "equalize!/2 raises for invalid bands" do
      image = Image.new!(10, 10, color: :white)

      # Constructed at runtime so the compiler's type checker does not
      # flag the deliberately invalid bands argument.
      invalid_bands = String.to_atom("invalid")

      assert_raise Image.Error, fn ->
        Image.equalize!(image, invalid_bands)
      end
    end
  end

  describe "to_colorspace/2 and to_colorspace!/2" do
    setup do
      {:ok, image: Image.new!(10, 10, color: [200, 50, 50])}
    end

    test "converts to :lab and back to :srgb", %{image: image} do
      assert {:ok, lab} = Image.to_colorspace(image, :lab)
      assert Image.colorspace(lab) == :lab

      assert {:ok, srgb} = Image.to_colorspace(lab, :srgb)
      assert Image.colorspace(srgb) == :srgb

      [red, green, blue] = Image.get_pixel!(srgb, 5, 5)
      assert_in_delta red, 200, 2
      assert_in_delta green, 50, 2
      assert_in_delta blue, 50, 2
    end

    test "converts to :lch", %{image: image} do
      assert {:ok, lch} = Image.to_colorspace(image, :lch)
      assert Image.colorspace(lch) == :lch
    end

    test "converts to :labs", %{image: image} do
      assert {:ok, labs} = Image.to_colorspace(image, :labs)
      assert Image.colorspace(labs) == :labs
    end

    test "converts to :scrgb", %{image: image} do
      assert {:ok, scrgb} = Image.to_colorspace(image, :scrgb)
      assert Image.colorspace(scrgb) == :scrgb
      assert {:f, _} = Image.band_format(scrgb)
    end

    test "converts to :rgb16", %{image: image} do
      assert {:ok, rgb16} = Image.to_colorspace(image, :rgb16)
      assert Image.colorspace(rgb16) == :rgb16
      assert Image.band_format(rgb16) == {:u, 16}
    end

    test "converts to :cmyk", %{image: image} do
      assert {:ok, cmyk} = Image.to_colorspace(image, :cmyk)
      assert Image.colorspace(cmyk) == :cmyk
      assert Image.bands(cmyk) == 4
    end

    test "converts to :bw", %{image: image} do
      assert {:ok, bw} = Image.to_colorspace(image, :bw)
      assert Image.colorspace(bw) == :bw
      assert Image.bands(bw) == 1
    end

    test "returns an error for an unknown colorspace", %{image: image} do
      assert {:error, %Image.Error{message: message}} =
               Image.to_colorspace(image, :not_a_colorspace)

      assert message =~ "Unknown interpretation"
    end

    test "to_colorspace!/2 returns an image", %{image: image} do
      bw = Image.to_colorspace!(image, :bw)
      assert Image.colorspace(bw) == :bw
    end

    test "to_colorspace!/2 raises for an unknown colorspace", %{image: image} do
      assert_raise Image.Error, fn ->
        Image.to_colorspace!(image, :not_a_colorspace)
      end
    end
  end

  describe "add_alpha/2 and add_alpha!/2" do
    test "adds an opaque alpha band" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert {:ok, with_alpha} = Image.add_alpha(image, :opaque)
      assert Image.bands(with_alpha) == 4
      assert Image.get_pixel!(with_alpha, 5, 5) == [10, 20, 30, 255]
    end

    test "adds a transparent alpha band" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert {:ok, with_alpha} = Image.add_alpha(image, :transparent)
      assert Image.get_pixel!(with_alpha, 5, 5) == [10, 20, 30, 0]
    end

    test "adds an alpha band with an integer transparency" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert {:ok, with_alpha} = Image.add_alpha(image, 128)
      assert Image.get_pixel!(with_alpha, 5, 5) == [10, 20, 30, 128]
    end

    test "adds an alpha band from a single-band image" do
      image = Image.new!(10, 10, color: [10, 20, 30])
      alpha = Image.new!(10, 10, color: 200, bands: 1)

      assert {:ok, with_alpha} = Image.add_alpha(image, alpha)
      assert Image.get_pixel!(with_alpha, 5, 5) == [10, 20, 30, 200]
    end

    test "returns an error when the image already has an alpha band" do
      image = Image.new!(10, 10, color: [10, 20, 30])
      {:ok, with_alpha} = Image.add_alpha(image, :opaque)

      assert {:error, %Image.Error{message: message}} = Image.add_alpha(with_alpha, :opaque)
      assert message =~ "already has an alpha band"
    end

    test "returns an error when the alpha image has more than one band" do
      image = Image.new!(10, 10, color: [10, 20, 30])
      not_alpha = Image.new!(10, 10, color: [1, 2, 3])

      assert {:error, %Image.Error{message: message}} = Image.add_alpha(image, not_alpha)
      assert message =~ "more than one band"
    end

    test "add_alpha!/2 returns an image" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      with_alpha = Image.add_alpha!(image, :opaque)
      assert Image.bands(with_alpha) == 4
    end

    test "add_alpha!/2 raises when the image already has an alpha band" do
      image = Image.new!(10, 10, color: [10, 20, 30])
      with_alpha = Image.add_alpha!(image, :opaque)

      assert_raise Image.Error, fn ->
        Image.add_alpha!(with_alpha, :opaque)
      end
    end
  end

  describe "split_alpha/1" do
    test "splits the alpha band from an image with alpha" do
      image = Image.new!(10, 10, color: [10, 20, 30])
      with_alpha = Image.add_alpha!(image, 128)

      {bands, alpha} = Image.split_alpha(with_alpha)

      assert Image.bands(bands) == 3
      assert Image.bands(alpha) == 1
      assert Image.get_pixel!(alpha, 5, 5) == [128]
    end

    test "returns nil alpha for an image without alpha" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      {bands, alpha} = Image.split_alpha(image)

      assert Image.bands(bands) == 3
      assert alpha == nil
    end
  end

  describe "flatten/2 and flatten!/2" do
    test "flattens an alpha band onto the default black background" do
      image = Image.new!(10, 10, color: [200, 100, 50])
      transparent = Image.add_alpha!(image, :transparent)

      assert {:ok, flattened} = Image.flatten(transparent)
      assert Image.bands(flattened) == 3
      refute Image.has_alpha?(flattened)
      assert Image.get_pixel!(flattened, 5, 5) == [0, 0, 0]
    end

    test "flattens onto a background color" do
      image = Image.new!(10, 10, color: [200, 100, 50])
      transparent = Image.add_alpha!(image, :transparent)

      assert {:ok, flattened} = Image.flatten(transparent, background_color: :white)
      assert Image.get_pixel!(flattened, 5, 5) == [255, 255, 255]
    end

    test "an image without alpha is returned unchanged" do
      image = Image.new!(10, 10, color: [200, 100, 50])

      assert {:ok, flattened} = Image.flatten(image)
      assert Image.get_pixel!(flattened, 5, 5) == [200, 100, 50]
    end

    test "flatten!/2 returns an image" do
      image = Image.new!(10, 10, color: [200, 100, 50])
      transparent = Image.add_alpha!(image, :transparent)

      flattened = Image.flatten!(transparent)
      refute Image.has_alpha?(flattened)
    end
  end

  describe "opacity/2 and opacity!/2" do
    test "scales the alpha band by the factor" do
      image = Image.new!(10, 10, color: [10, 20, 30])
      opaque = Image.add_alpha!(image, :opaque)

      assert {:ok, translucent} = Image.opacity(opaque, 0.5)
      [_red, _green, _blue, alpha] = Image.get_pixel!(translucent, 5, 5)
      assert_in_delta alpha, 128, 1
    end

    test "adds an alpha band to an image without one" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert {:ok, translucent} = Image.opacity(image, 0.25)
      assert Image.bands(translucent) == 4
      [_red, _green, _blue, alpha] = Image.get_pixel!(translucent, 5, 5)
      assert_in_delta alpha, 64, 1
    end

    test "a factor of 0.0 makes the image fully transparent" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert {:ok, transparent} = Image.opacity(image, 0.0)
      [_red, _green, _blue, alpha] = Image.get_pixel!(transparent, 5, 5)
      assert alpha == 0
    end

    test "opacity!/2 returns an image" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert %Vimage{} = Image.opacity!(image, 0.5)
    end
  end

  describe "sharpen/2 and sharpen!/2" do
    test "sharpens an image" do
      image = Image.open!(image_path("Kip_small.jpg"), access: :random)

      assert {:ok, sharpened} = Image.sharpen(image)
      assert Image.shape(sharpened) == Image.shape(image)
    end

    test "sharpens with a sigma option" do
      image = Image.open!(image_path("Kip_small.jpg"), access: :random)

      assert {:ok, %Vimage{}} = Image.sharpen(image, sigma: 2.0)
    end

    test "returns an error for an invalid option" do
      image = Image.new!(10, 10, color: :white)

      assert {:error, %Image.Error{}} = Image.sharpen(image, sigma: :invalid)
    end

    test "sharpen!/2 returns an image" do
      image = Image.open!(image_path("Kip_small.jpg"), access: :random)

      assert %Vimage{} = Image.sharpen!(image)
    end

    test "sharpen!/2 raises for an invalid option" do
      image = Image.new!(10, 10, color: :white)

      assert_raise Image.Error, fn ->
        Image.sharpen!(image, sigma: :invalid)
      end
    end
  end

  describe "cast/2 and cast!/2" do
    test "casts to another band format and back" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert {:ok, wider} = Image.cast(image, {:u, 16})
      assert Image.band_format(wider) == {:u, 16}

      assert {:ok, restored} = Image.cast(wider, {:u, 8})
      assert Image.band_format(restored) == {:u, 8}
      assert Image.get_pixel!(restored, 5, 5) == [10, 20, 30]
    end

    test "returns an error for an unknown band format" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert {:error, %Image.Error{}} = Image.cast(image, {:u, 3})
    end

    test "cast!/2 returns an image" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert %Vimage{} = Image.cast!(image, {:f, 32})
    end

    test "cast!/2 raises for an unknown band format" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert_raise Image.Error, fn ->
        Image.cast!(image, {:u, 3})
      end
    end
  end
end
