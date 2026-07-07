defmodule Image.DominantColorTest do
  use ExUnit.Case, async: true

  describe "dominant_color/2 with the histogram method" do
    test "reports black for an opaque black image with an alpha band" do
      # Regression: the black-bin correction subtracted the transparent-pixel
      # count with min/2 instead of max/2, so a genuinely black RGBA image
      # could never report black as its dominant color.
      image = Image.new!(10, 10, color: [0, 0, 0, 255])

      assert {:ok, [r, g, b]} = Image.dominant_color(image)
      assert r < 16 and g < 16 and b < 16
    end

    test "matches the non-alpha result for the same black image" do
      with_alpha = Image.new!(10, 10, color: [0, 0, 0, 255])
      without_alpha = Image.new!(10, 10, color: [0, 0, 0])

      assert Image.dominant_color(with_alpha) == Image.dominant_color(without_alpha)
    end

    test "excludes fully transparent pixels from the dominant color" do
      transparent = Image.new!(20, 20, color: [0, 0, 0, 0])
      red = Image.new!(10, 10, color: [255, 0, 0, 255])
      {:ok, composed} = Image.compose(transparent, red, x: 0, y: 0)

      assert {:ok, [r, g, b]} = Image.dominant_color(composed)
      assert r > 200 and g < 16 and b < 16
    end
  end
end
