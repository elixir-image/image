defmodule Image.AverageTest do
  use ExUnit.Case, async: true

  describe "average/1" do
    test "averages integer images to rounded integers" do
      image = Image.new!(4, 4, color: [10, 20, 30])
      assert Image.average(image) == [10, 20, 30]
    end

    test "weights the average by the alpha band" do
      # Regression: hidden RGB values under transparent pixels skewed the
      # result. Only the visible (opaque white) pixels may contribute, so
      # the average must be white, not red-tinted.
      transparent_red = Image.new!(20, 20, color: [255, 0, 0, 0])
      white = Image.new!(10, 10, color: [255, 255, 255, 255])
      {:ok, composed} = Image.compose(transparent_red, white, x: 0, y: 0)

      assert Image.average(composed) == [255, 255, 255]
    end

    test "falls back to the unweighted color-band average for a fully transparent image" do
      transparent_red = Image.new!(20, 20, color: [255, 0, 0, 0])

      assert Image.average(transparent_red) == [255, 0, 0]
    end

    test "preserves float precision for float interpretations" do
      # Regression: rounding per band collapsed scRGB averages to 0 or 1.
      scrgb =
        Image.new!(4, 4, color: [10, 20, 30])
        |> Image.to_colorspace!(:scrgb)

      assert [r, g, b] = Image.average(scrgb)
      assert is_float(r) and is_float(g) and is_float(b)
      assert r > 0.0 and r < 1.0
      assert g > 0.0 and g < 1.0
      assert b > 0.0 and b < 1.0
    end

    test "preserves fractional LAB averages" do
      lab =
        Image.new!(4, 4, color: [120, 80, 40])
        |> Image.to_colorspace!(:lab)

      assert [l, a, b] = Image.average(lab)
      assert is_float(l) and is_float(a) and is_float(b)
    end
  end
end
