defmodule Image.BackgroundColorTest do
  use ExUnit.Case, async: true

  alias Image.BackgroundColor

  defp solid(color), do: Image.new!(4, 4, color: color)

  defp solid_in(color, colorspace),
    do: Image.to_colorspace!(solid(color), colorspace)

  describe "resolve/2 with :average" do
    test "resolves to the image's average color" do
      image = solid([10, 20, 30])
      assert BackgroundColor.resolve(image, :average) == {:ok, [10, 20, 30]}
    end

    test "matches a non-alpha image's band count" do
      image = solid([10, 20, 30])
      assert {:ok, pixel} = BackgroundColor.resolve(image, :average)
      assert length(pixel) == Image.bands(image)
    end

    test "appends an opaque alpha band for an image with alpha" do
      image = solid([10, 20, 30, 255])
      assert {:ok, pixel} = BackgroundColor.resolve(image, :average)

      # The average is computed on the flattened image, so the alpha band is
      # re-appended as fully opaque to match the image's band layout exactly.
      assert pixel == [10, 20, 30, 255]
      assert length(pixel) == Image.bands(image)
      assert List.last(pixel) == 255
    end
  end

  describe "resolve/2 with :average in a non-sRGB interpretation" do
    test "preserves LAB color bands verbatim (no sRGB re-interpretation)" do
      image = solid_in([120, 80, 40], :lab)
      raw = Image.average!(image)

      assert BackgroundColor.resolve(image, :average) == {:ok, raw}
    end

    test "LAB with alpha keeps the raw average and appends a 0..255 opaque alpha" do
      # Float LAB color bands do not imply a float alpha: libvips stores the
      # alpha band of a LAB image in the 0..255 range (see
      # `vips_interpretation_max_alpha/1`), so opaque is 255, not 1.0.
      image = solid_in([120, 80, 40, 255], :lab)
      raw = Image.average!(image)

      assert {:ok, pixel} = BackgroundColor.resolve(image, :average)
      assert pixel == raw ++ [255]
      assert length(pixel) == Image.bands(image)
    end

    test "CMYK with alpha keeps the raw average and appends a uchar opaque alpha" do
      image = solid_in([120, 80, 40, 255], :cmyk)
      raw = Image.average!(image)

      assert {:ok, pixel} = BackgroundColor.resolve(image, :average)
      assert pixel == raw ++ [255]
      assert length(pixel) == Image.bands(image)
    end

    test "16-bit RGB with alpha appends a ushort opaque alpha" do
      image = solid_in([120, 80, 40, 255], :rgb16)
      raw = Image.average!(image)

      assert {:ok, pixel} = BackgroundColor.resolve(image, :average)
      assert pixel == raw ++ [65_535]
      assert length(pixel) == Image.bands(image)
    end

    test "signed-short LAB (labs) with alpha uses libvips' 0..255 opaque alpha" do
      # `:labs` bands are signed shorts ({:s, 16}), but libvips'
      # `vips_interpretation_max_alpha/1` returns 255 for LABS (65_535 is
      # reserved for RGB16/GREY16). The opaque alpha therefore follows the
      # interpretation (255), matching what `Image.Pixel.to_pixel/3` does.
      image = solid_in([120, 80, 40, 255], :labs)
      raw = Image.average!(image)

      assert {:ok, pixel} = BackgroundColor.resolve(image, :average)
      assert pixel == raw ++ [255]
      assert length(pixel) == Image.bands(image)
    end
  end

  describe "resolve/2 with a color spec" do
    test "resolves a named color into the image's band layout" do
      image = solid([0, 0, 0])
      assert BackgroundColor.resolve(image, :red) == {:ok, [255, 0, 0]}
    end

    test "appends an opaque alpha band when the image has alpha" do
      image = solid([0, 0, 0, 255])
      assert {:ok, pixel} = BackgroundColor.resolve(image, :red)

      assert pixel == [255, 0, 0, 255]
      assert length(pixel) == Image.bands(image)
    end

    test "forwards other spec forms (hex string) to Image.Pixel" do
      image = solid([0, 0, 0])
      assert BackgroundColor.resolve(image, "#00ff00") == {:ok, [0, 255, 0]}
    end
  end

  describe "resolve/2 error handling" do
    test "wraps an invalid color in an Image.Error" do
      image = solid([0, 0, 0])

      assert {:error, %Image.Error{} = error} =
               BackgroundColor.resolve(image, :definitely_not_a_color)

      assert error.message =~ "Invalid background color :definitely_not_a_color"
    end

    test "preserves the underlying reason from Image.Pixel" do
      image = solid([0, 0, 0])

      assert {:error, %Image.Error{reason: reason}} =
               BackgroundColor.resolve(image, "not-a-hex")

      assert reason == %Color.UnknownColorNameError{name: "not-a-hex"}
    end
  end
end
