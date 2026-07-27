defmodule Image.AverageTest do
  use ExUnit.Case, async: true

  import Image.TestSupport

  describe "average/1" do
    test "averages integer images to rounded integers" do
      image = Image.new!(4, 4, color: [10, 20, 30])
      assert Image.average(image) == {:ok, [10, 20, 30]}
    end

    test "weights the average by the alpha band" do
      # Regression: hidden RGB values under transparent pixels skewed the
      # result. Only the visible (opaque white) pixels may contribute, so
      # the average must be white, not red-tinted.
      transparent_red = Image.new!(20, 20, color: [255, 0, 0, 0])
      white = Image.new!(10, 10, color: [255, 255, 255, 255])
      {:ok, composed} = Image.compose(transparent_red, white, x: 0, y: 0)

      assert Image.average(composed) == {:ok, [255, 255, 255]}
    end

    test "falls back to the unweighted color-band average for a fully transparent image" do
      transparent_red = Image.new!(20, 20, color: [255, 0, 0, 0])

      assert Image.average(transparent_red) == {:ok, [255, 0, 0]}
    end

    test "preserves float precision for float interpretations" do
      # Regression: rounding per band collapsed scRGB averages to 0 or 1.
      scrgb =
        Image.new!(4, 4, color: [10, 20, 30])
        |> Image.to_colorspace!(:scrgb)

      assert {:ok, [r, g, b]} = Image.average(scrgb)
      assert is_float(r) and is_float(g) and is_float(b)
      assert r > 0.0 and r < 1.0
      assert g > 0.0 and g < 1.0
      assert b > 0.0 and b < 1.0
    end

    test "preserves fractional LAB averages" do
      lab =
        Image.new!(4, 4, color: [120, 80, 40])
        |> Image.to_colorspace!(:lab)

      assert {:ok, [l, a, b]} = Image.average(lab)
      assert is_float(l) and is_float(a) and is_float(b)
    end

    test "wraps a libvips failure as an Image.Error tagged with the operation" do
      # JPEG with a readable header, but truncated so opening it
      # succeeds, but reading pixels fails
      whole = File.read!(image_path("Hong-Kong-2015-07-1998.jpg"))
      image = Image.from_binary!(binary_part(whole, 0, div(byte_size(whole), 2)))

      assert {:error, %Image.Error{operation: :average, reason: reason}} = Image.average(image)
      assert is_binary(reason)
    end
  end
end
