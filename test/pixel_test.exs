defmodule Image.PixelTest do
  use ExUnit.Case, async: true

  doctest Image.Pixel

  alias Image.Pixel

  describe "to_pixel/3 against an sRGB image" do
    setup do
      {:ok, image} = Image.new(2, 2, color: :black)
      {:ok, image: image}
    end

    test "atom name", %{image: image} do
      assert {:ok, [255, 0, 0]} = Pixel.to_pixel(image, :red)
    end

    test "string name", %{image: image} do
      assert {:ok, [255, 0, 0]} = Pixel.to_pixel(image, "red")
    end

    test "hex string", %{image: image} do
      assert {:ok, [255, 0, 0]} = Pixel.to_pixel(image, "#ff0000")
    end

    test "short hex", %{image: image} do
      assert {:ok, [255, 0, 0]} = Pixel.to_pixel(image, "#f00")
    end

    test "integer list", %{image: image} do
      assert {:ok, [10, 20, 30]} = Pixel.to_pixel(image, [10, 20, 30])
    end

    test "float list", %{image: image} do
      assert {:ok, [255, 0, 0]} = Pixel.to_pixel(image, [1.0, 0.0, 0.0])
    end

    test "Color.SRGB struct", %{image: image} do
      assert {:ok, [255, 0, 0]} =
               Pixel.to_pixel(image, %Color.SRGB{r: 1.0, g: 0.0, b: 0.0})
    end

    test "color from another space is converted to sRGB", %{image: image} do
      lab_red = %Color.Lab{l: 53.24, a: 80.09, b: 67.20}
      assert {:ok, [r, g, b]} = Pixel.to_pixel(image, lab_red)
      assert_in_delta r, 255, 1
      assert_in_delta g, 0, 1
      assert_in_delta b, 0, 1
    end

    test "hex with alpha is dropped on a 3-band image", %{image: image} do
      assert {:ok, [255, 0, 0]} = Pixel.to_pixel(image, "#ff000080")
    end

    test "the color atoms collapse to black", %{image: image} do
      assert {:ok, [0, 0, 0]} = Pixel.to_pixel(image, :transparent)
      assert {:ok, [0, 0, 0]} = Pixel.to_pixel(image, :none)
      assert {:ok, [0, 0, 0]} = Pixel.to_pixel(image, :opaque)
    end
  end

  describe "to_pixel/3 against an sRGB image with alpha" do
    setup do
      {:ok, image} = Image.new(2, 2, color: [0, 0, 0, 255])
      {:ok, image: image}
    end

    test "named color gets full opacity", %{image: image} do
      assert {:ok, [255, 0, 0, 255]} = Pixel.to_pixel(image, :red)
    end

    test "explicit :opacity option overrides", %{image: image} do
      assert {:ok, [255, 0, 0, 128]} = Pixel.to_pixel(image, :red, opacity: 0.5)
      assert {:ok, [255, 0, 0, 0]} = Pixel.to_pixel(image, :red, opacity: :transparent)
      assert {:ok, [255, 0, 0, 255]} = Pixel.to_pixel(image, :red, opacity: :opaque)
      assert {:ok, [255, 0, 0, 100]} = Pixel.to_pixel(image, :red, opacity: 100)
    end

    test "hex with alpha is preserved", %{image: image} do
      assert {:ok, [255, 0, 0, 128]} = Pixel.to_pixel(image, "#ff000080")
    end

    test "transparent / none yield zero alpha", %{image: image} do
      assert {:ok, [0, 0, 0, 0]} = Pixel.to_pixel(image, :transparent)
      assert {:ok, [0, 0, 0, 0]} = Pixel.to_pixel(image, :none)
    end

    test "opaque yields full alpha", %{image: image} do
      assert {:ok, [0, 0, 0, 255]} = Pixel.to_pixel(image, :opaque)
    end

    test "a list one band short gains the missing alpha", %{image: image} do
      assert {:ok, [255, 0, 0, 255]} = Pixel.to_pixel(image, [255, 0, 0])
    end

    test ":opacity applies to a pre-encoded list color", %{image: image} do
      assert {:ok, [255, 0, 0, 128]} = Pixel.to_pixel(image, [255, 0, 0, 255], opacity: 0.5)
    end

    test ":opacity applies to a list color that needs resolving", %{image: image} do
      assert {:ok, [255, 0, 0, 128]} = Pixel.to_pixel(image, [1.0, 0.0, 0.0], opacity: 0.5)
    end
  end

  describe "put_alpha/3" do
    test "replaces the alpha component of a pixel" do
      image = Image.new!(2, 2, color: [0, 0, 0, 255])

      assert Pixel.put_alpha([255, 0, 0, 255], image, 0.5) == {:ok, [255, 0, 0, 128]}
      assert Pixel.put_alpha([255, 0, 0, 255], image, :transparent) == {:ok, [255, 0, 0, 0]}
    end

    test "scales the alpha to the image's band" do
      image = Image.to_colorspace!(Image.new!(2, 2, color: [0, 0, 0, 255]), :rgb16)

      assert Pixel.put_alpha([65_535, 0, 0, 65_535], image, 0.5) == {:ok, [65_535, 0, 0, 32_768]}
    end

    test "leaves a pixel alone when the image has no alpha band" do
      image = Image.new!(2, 2, color: [0, 0, 0])

      assert Pixel.put_alpha([255, 0, 0], image, 0.5) == {:ok, [255, 0, 0]}
    end
  end

  describe "to_pixel/3 fits a list color to the image band count" do
    test "a list one band over a non-alpha image loses the extra value" do
      {:ok, image} = Image.new(2, 2, color: [0, 0, 0])

      assert {:ok, [255, 0, 0]} = Pixel.to_pixel(image, [255, 0, 0, 255])
    end
  end

  describe "to_pixel/3 against a Lab image" do
    setup do
      {:ok, image} = Image.new(2, 2, color: :black)
      {:ok, image} = Image.to_colorspace(image, :lab)
      {:ok, image: image}
    end

    test "named red is converted to Lab red, not [255, 0, 0]", %{image: image} do
      assert {:ok, [l, a, b]} = Pixel.to_pixel(image, :red)
      assert_in_delta l, 53.24, 0.1
      assert_in_delta a, 80.09, 0.1
      assert_in_delta b, 67.20, 0.1
    end

    test "Color.Lab struct passes through", %{image: image} do
      lab_blue = %Color.Lab{l: 32.30, a: 79.20, b: -107.86}
      assert {:ok, [l, a, b]} = Pixel.to_pixel(image, lab_blue)
      assert_in_delta l, 32.30, 0.001
      assert_in_delta a, 79.20, 0.001
      assert_in_delta b, -107.86, 0.001
    end

    test "white is L≈100, a≈0, b≈0", %{image: image} do
      assert {:ok, [l, a, b]} = Pixel.to_pixel(image, :white)
      assert_in_delta l, 100.0, 0.5
      assert_in_delta a, 0.0, 0.5
      assert_in_delta b, 0.0, 0.5
    end
  end

  describe "to_pixel/3 alpha scale matches the interpretation's max alpha" do
    defp with_alpha(colorspace) do
      {:ok, srgba} = Image.new(2, 2, color: [10, 20, 30, 255])
      {:ok, image} = Image.to_colorspace(srgba, colorspace)
      image
    end

    test "opaque alpha resolves to 255 for every 0..255-scale interpretation" do
      for colorspace <- [:srgb, :cmyk, :hsv, :bw, :lab, :lch, :labs] do
        image = with_alpha(colorspace)
        {:ok, pixel} = Pixel.to_pixel(image, :red, opacity: :opaque)
        assert List.last(pixel) == 255, "#{colorspace} opaque alpha was #{List.last(pixel)}"
      end
    end

    test "scRGB opaque alpha stays 1.0" do
      image = with_alpha(:scrgb)
      assert {:ok, [_r, _g, _b, alpha]} = Pixel.to_pixel(image, :red, opacity: :opaque)
      assert alpha == 1.0
    end

    test "a plain color (no explicit :opacity) also synthesizes opaque 255 on Lab" do
      image = with_alpha(:lab)
      assert {:ok, [_l, _a, _b, 255]} = Pixel.to_pixel(image, :red)
    end

    test "alpha 0.5 resolves to 128 on Lab" do
      image = with_alpha(:lab)
      assert {:ok, [_l, _a, _b, alpha]} = Pixel.to_pixel(image, :red, opacity: 0.5)
      assert alpha == 128
    end

    # Rounding a float to a byte first would put 0.5 at 128/255.
    test "a float alpha scales directly to the encoder's alpha range" do
      {:ok, scrgb} = Pixel.to_pixel(with_alpha(:scrgb), :red, opacity: 0.5)
      assert List.last(scrgb) == 0.5

      {:ok, grey16} = Pixel.to_pixel(with_alpha(:grey16), :red, opacity: 0.5)
      assert List.last(grey16) == 32_768
    end
  end

  describe "to_pixel/3 against a CMYK image" do
    setup do
      {:ok, image} = Image.new(2, 2, color: :black)
      {:ok, image} = Image.to_colorspace(image, :cmyk)
      {:ok, image: image}
    end

    test "named red is converted to CMYK with 4 channels", %{image: image} do
      assert {:ok, [c, m, y, k]} = Pixel.to_pixel(image, :red)
      # Red in CMYK is roughly (0, 255, 255, 0)
      assert c == 0
      assert m == 255
      assert y == 255
      assert k == 0
    end

    test "white is (0, 0, 0, 0)", %{image: image} do
      assert {:ok, [0, 0, 0, 0]} = Pixel.to_pixel(image, :white)
    end
  end

  describe "to_pixel/3 against a B/W image" do
    setup do
      {:ok, image} = Image.new(2, 2, color: 0, bands: 1)
      {:ok, image: image}
    end

    test "named red collapses to a single luma channel", %{image: image} do
      assert {:ok, [gray]} = Pixel.to_pixel(image, :red)
      # Red has a Lab L* around 53, so the gray should be near 53/100 * 255 ≈ 135
      assert_in_delta gray, 135, 5
    end

    test "white is 255, black is 0", %{image: image} do
      assert {:ok, [white]} = Pixel.to_pixel(image, :white)
      assert white == 255
      assert {:ok, [0]} = Pixel.to_pixel(image, :black)
    end
  end

  describe "to_pixel/3 against an scRGB image" do
    setup do
      {:ok, image} = Image.new(2, 2, color: :black)
      {:ok, image} = Image.to_colorspace(image, :scrgb)
      {:ok, image: image}
    end

    test "round trips through libvips back to the requested sRGB color", %{image: image} do
      colors = [
        "#000000",
        "#010101",
        "#404040",
        "#808080",
        "#fefefe",
        "#ffffff",
        "#4080c0",
        "#663399"
      ]

      for color <- colors do
        {:ok, pixel} = Pixel.to_pixel(image, color)
        {:ok, drawn} = Image.Draw.rect(image, 0, 0, 2, 2, color: pixel)
        {:ok, srgb} = Image.to_colorspace(drawn, :srgb)

        assert {:ok, actual} = Image.get_pixel(srgb, 0, 0)
        assert {:ok, expected} = Pixel.to_srgb(color)
        assert actual == expected, "#{inspect(color)} round tripped to #{inspect(actual)}"
      end
    end

    test "a float list passes through unclamped", %{image: image} do
      assert Pixel.to_pixel(image, [2.5, 0.0, -0.1]) == {:ok, [2.5, 0.0, -0.1]}
    end
  end

  describe "to_pixel/3 against a single band scRGB image" do
    setup do
      {:ok, image} = Image.new(2, 2, color: :black)
      {:ok, scrgb} = Image.to_colorspace(image, :scrgb)
      {:ok, image: hd(Image.split_bands(scrgb))}
    end

    test "resolves to the color's CIE Y", %{image: image} do
      for color <- [:white, :black, "#808080", :red, :lime, :blue, "#663399"] do
        assert {:ok, [y]} = Pixel.to_pixel(image, color)
        assert {:ok, %Color.XYZ{y: expected}} = Color.convert(color, Color.XYZ)
        assert_in_delta y, expected, 0.0001, "#{inspect(color)} resolved to #{y}"
      end
    end
  end

  describe "strip_alpha/2" do
    test "drops the last band of a full pixel on an alpha image" do
      {:ok, image} = Image.new(2, 2, color: [0, 0, 0, 255])

      assert [255, 0, 0] == Pixel.strip_alpha([255, 0, 0, 128], image)
    end

    test "returns the pixel unchanged on an image without alpha" do
      {:ok, image} = Image.new(2, 2, color: [0, 0, 0])

      assert [255, 0, 0] == Pixel.strip_alpha([255, 0, 0], image)
    end

    test "returns a pixel shorter than the image's bands unchanged" do
      {:ok, image} = Image.new(2, 2, color: [0, 0, 0, 255])

      assert [255, 0, 0] == Pixel.strip_alpha([255, 0, 0], image)
    end
  end

  describe "alpha_for/2 on an 8-bit image" do
    defp srgb, do: Image.new!(2, 2, color: [0, 0, 0, 255])

    test "atoms" do
      assert {:ok, 0} = Pixel.alpha_for(srgb(), :transparent)
      assert {:ok, 255} = Pixel.alpha_for(srgb(), :opaque)
    end

    test "integers" do
      assert {:ok, 0} = Pixel.alpha_for(srgb(), 0)
      assert {:ok, 128} = Pixel.alpha_for(srgb(), 128)
      assert {:ok, 255} = Pixel.alpha_for(srgb(), 255)
    end

    test "floats" do
      assert {:ok, 0} = Pixel.alpha_for(srgb(), 0.0)
      assert {:ok, 128} = Pixel.alpha_for(srgb(), 0.5)
      assert {:ok, 255} = Pixel.alpha_for(srgb(), 1.0)
    end

    test "out of range" do
      assert {:error, _} = Pixel.alpha_for(srgb(), -1)
      assert {:error, _} = Pixel.alpha_for(srgb(), 256)
      assert {:error, _} = Pixel.alpha_for(srgb(), 2.0)
      assert {:error, _} = Pixel.alpha_for(srgb(), :blue)
    end
  end

  describe "alpha_for/2 on other interpretations" do
    test "a 16-bit image scales to 0..65535" do
      image = with_alpha(:rgb16)

      assert {:ok, 0} = Pixel.alpha_for(image, :transparent)
      assert {:ok, 65_535} = Pixel.alpha_for(image, :opaque)
      assert {:ok, 32_768} = Pixel.alpha_for(image, 0.5)
      assert {:ok, 32_896} = Pixel.alpha_for(image, 128)
    end

    test "an scRGB image scales to 0.0..1.0" do
      image = with_alpha(:scrgb)

      assert Pixel.alpha_for(image, :transparent) == {:ok, 0.0}
      assert Pixel.alpha_for(image, :opaque) == {:ok, 1.0}
      assert Pixel.alpha_for(image, 0.5) == {:ok, 0.5}
    end

    test "Lab and LCH keep a 0..255 alpha despite their float color bands" do
      assert {:ok, 255} = Pixel.alpha_for(with_alpha(:lab), :opaque)
      assert {:ok, 128} = Pixel.alpha_for(with_alpha(:lch), 0.5)
    end
  end
end
