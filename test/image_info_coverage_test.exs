defmodule Image.InfoCoverageTest do
  use ExUnit.Case, async: true

  import Image.TestSupport

  alias Vix.Vips.Image, as: Vimage

  describe "width/1 and height/1" do
    test "returns dimensions of a synthetic image" do
      image = Image.new!(20, 30, color: :white)

      assert Image.width(image) == 20
      assert Image.height(image) == 30
    end

    test "returns dimensions of a file image" do
      image = Image.open!(image_path("Kip_small.jpg"))

      assert Image.width(image) == 300
      assert Image.height(image) == 328
    end
  end

  describe "shape/1" do
    test "returns {width, height, bands}" do
      image = Image.new!(20, 30, color: :white)

      assert Image.shape(image) == {20, 30, 3}
    end

    test "includes the alpha band in the band count" do
      image = Image.open!(image_path("penguin_with_alpha.png"))

      {width, height, bands} = Image.shape(image)

      assert width == Image.width(image)
      assert height == Image.height(image)
      assert bands == 4
    end
  end

  describe "bands/1" do
    test "returns 3 for an RGB image" do
      image = Image.new!(10, 10, color: :red)

      assert Image.bands(image) == 3
    end

    test "returns 4 for an image with alpha" do
      image = Image.open!(image_path("penguin_with_alpha.png"))

      assert Image.bands(image) == 4
    end

    test "returns 1 for a single band image" do
      image = Image.new!(10, 10, color: 128, bands: 1)

      assert Image.bands(image) == 1
    end
  end

  describe "band_format/1 and range/1" do
    test "unsigned 8-bit image" do
      image = Image.new!(10, 10, color: :white)

      assert Image.band_format(image) == {:u, 8}
      assert Image.range(image) == {0, 255}
    end

    test "float image has a nominal range of 0.0 to 1.0" do
      image = Image.new!(10, 10, color: :white)
      {:ok, float_image} = Image.cast(image, {:f, 32})

      assert Image.band_format(float_image) == {:f, 32}
      assert Image.range(float_image) == {0.0, 1.0}
    end

    test "signed 16-bit image range" do
      image = Image.new!(10, 10, color: :white)
      {:ok, signed_image} = Image.cast(image, {:s, 16})

      assert Image.band_format(signed_image) == {:s, 16}
      assert Image.range(signed_image) == {-32_768.0, 32_767.0}
    end

    test "unsigned 16-bit image range" do
      image = Image.new!(10, 10, color: :white)
      {:ok, u16_image} = Image.cast(image, {:u, 16})

      assert Image.range(u16_image) == {0, 65_535}
    end
  end

  describe "colorspace/1" do
    test "returns :srgb for a standard image" do
      image = Image.new!(10, 10, color: :white)

      assert Image.colorspace(image) == :srgb
    end

    test "returns :bw for a black and white image" do
      image = Image.new!(10, 10, color: :white)
      {:ok, bw} = Image.to_colorspace(image, :bw)

      assert Image.colorspace(bw) == :bw
    end
  end

  describe "has_alpha?/1 and alpha_band/1" do
    test "false and nil for an image without alpha" do
      image = Image.new!(10, 10, color: :white)

      refute Image.has_alpha?(image)
      assert Image.alpha_band(image) == nil
    end

    test "true and band index for an image with alpha" do
      image = Image.open!(image_path("penguin_with_alpha.png"))

      assert Image.has_alpha?(image)
      assert Image.alpha_band(image) == 3
    end

    test "alpha added with add_alpha/2 is detected" do
      image = Image.new!(10, 10, color: :white)
      {:ok, with_alpha} = Image.add_alpha(image, :opaque)

      assert Image.has_alpha?(with_alpha)
      assert Image.alpha_band(with_alpha) == 3
    end
  end

  describe "filename/1" do
    test "returns the path for an image opened from a file" do
      path = image_path("Kip_small.jpg")
      image = Image.open!(path)

      assert Image.filename(image) == path
    end

    test "returns nil for an image opened from a binary" do
      binary = File.read!(image_path("Kip_small.jpg"))
      {:ok, image} = Image.open(binary)

      assert Image.filename(image) == nil
    end
  end

  describe "pages/1" do
    test "returns the number of pages for an animated image" do
      image = Image.open!(image_path("animated.webp"))

      assert Image.pages(image) == 12
    end

    test "returns 1 for a normal image" do
      image = Image.open!(image_path("Kip_small.jpg"))

      assert Image.pages(image) == 1
    end

    test "returns 1 for a synthetic image" do
      image = Image.new!(10, 10, color: :white)

      assert Image.pages(image) == 1
    end

    test "animated image opened with pages: :all has combined height" do
      {:ok, image} = Image.open(image_path("animated.webp"), pages: :all)
      {:ok, single} = Image.open(image_path("animated.webp"))

      assert Image.pages(image) == 12
      assert Image.height(image) == Image.height(single) * 12
    end
  end

  describe "aspect/2" do
    test "landscape, portrait and square" do
      assert Image.aspect(Image.new!(20, 10, color: :white)) == :landscape
      assert Image.aspect(Image.new!(10, 20, color: :white)) == :portrait
      assert Image.aspect(Image.new!(10, 10, color: :white)) == :square
    end

    test "square_ratio option widens the square band" do
      image = Image.new!(101, 100, color: :white)

      assert Image.aspect(image) == :landscape
      assert Image.aspect(image, square_ratio: 0.05) == :square
    end
  end

  describe "vips_version/0" do
    test "returns a parsed version" do
      assert {:ok, %Version{}} = Image.vips_version()
    end
  end

  describe "get_concurrency/0 and put_concurrency/1" do
    test "returns a positive integer" do
      concurrency = Image.get_concurrency()

      assert is_integer(concurrency)
      assert concurrency > 0
    end

    test "put_concurrency/1 sets and returns the concurrency" do
      original = Image.get_concurrency()

      try do
        assert Image.put_concurrency(2) == 2
        assert Image.get_concurrency() == 2
      after
        Image.put_concurrency(original)
      end
    end
  end

  describe "exif/1" do
    test "returns exif data for an image with exif" do
      image = Image.open!(image_path("Kip_small.jpg"))

      assert {:ok, exif} = Image.exif(image)
      assert is_map(exif)
      assert map_size(exif) > 0
    end

    test "returns an error for an image without exif" do
      image = Image.new!(10, 10, color: :white)

      assert {:error, %Image.Error{}} = Image.exif(image)
    end
  end

  describe "get_pixel/3 and get_pixel!/3" do
    test "returns the pixel at a location" do
      image = Image.new!(10, 10, color: [255, 0, 0])

      assert {:ok, [255, 0, 0]} = Image.get_pixel(image, 5, 5)
    end

    test "unsigned band format values are rounded to integers" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert {:ok, [10, 20, 30]} = Image.get_pixel(image, 0, 0)
    end

    test "float image pixels are returned as floats" do
      image = Image.new!(10, 10, color: [255, 0, 0])
      {:ok, float_image} = Image.cast(image, {:f, 32})

      assert {:ok, [red, green, blue]} = Image.get_pixel(float_image, 5, 5)
      assert is_float(red) and is_float(green) and is_float(blue)
    end

    test "returns an error for an out of bounds location" do
      image = Image.new!(10, 10, color: :white)

      assert {:error, %Image.Error{}} = Image.get_pixel(image, 100, 100)
    end

    test "get_pixel!/3 returns the pixel" do
      image = Image.new!(10, 10, color: [0, 255, 0])

      assert Image.get_pixel!(image, 3, 3) == [0, 255, 0]
    end

    test "get_pixel!/3 raises for an out of bounds location" do
      image = Image.new!(10, 10, color: :white)

      assert_raise Image.Error, fn ->
        Image.get_pixel!(image, 100, 100)
      end
    end
  end

  describe "mutate/2" do
    test "returns a mutated image" do
      image = Image.new!(20, 20, color: :white)

      assert {:ok, %Vimage{} = mutated} =
               Image.mutate(image, fn mutable ->
                 {:ok, _} = Image.Draw.rect(mutable, 0, 0, 10, 10, color: :black)
               end)

      assert Image.shape(mutated) == {20, 20, 3}
      assert Image.get_pixel!(mutated, 5, 5) == [0, 0, 0]
      assert Image.get_pixel!(mutated, 15, 15) == [255, 255, 255]
    end
  end

  describe "dominant_color/2" do
    test "histogram bins strategy on a synthetic image" do
      image = Image.new!(20, 20, color: [250, 5, 5])

      assert {:ok, [red, green, blue]} = Image.dominant_color(image)
      assert red > 200
      assert green < 50
      assert blue < 50
    end

    test "histogram strategy with a custom bin count" do
      image = Image.new!(20, 20, color: [5, 250, 5])

      assert {:ok, [red, green, blue]} = Image.dominant_color(image, bins: 64)
      assert green > 200
      assert red < 50
      assert blue < 50
    end

    test "dominant_color!/2 returns a color" do
      image = Image.new!(20, 20, color: [5, 5, 250])

      assert [_red, _green, blue] = Image.dominant_color!(image)
      assert blue > 200
    end
  end
end
