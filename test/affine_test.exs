defmodule Image.Affine.Test do
  use ExUnit.Case, async: true

  alias Vix.Vips.Image, as: Vimage

  # A black canvas with a single white pixel drawn at (x, y). Gives us a
  # deterministic feature to track through an affine transformation.
  defp white_dot(width, height, x, y) do
    Image.new!(width, height, color: [0, 0, 0])
    |> Image.Draw.rect!(x, y, 1, 1, color: [255, 255, 255])
  end

  describe "Image.affine/3" do
    test "the identity matrix is a no-op" do
      image = white_dot(20, 20, 2, 3)
      {:ok, result} = Image.affine(image, [1, 0, 0, 1])

      assert Image.shape(result) == {20, 20, 3}
      assert Image.get_pixel!(result, 2, 3) == [255, 255, 255]
    end

    test "a scaling matrix produces the expected geometry" do
      image = white_dot(20, 20, 2, 3)
      {:ok, result} = Image.affine(image, [2, 0, 0, 2])

      # The canvas is sized to the transformed bounding box and the input
      # point (2, 3) maps to (a*x + b*y, c*x + d*y) = (4, 6).
      assert Image.shape(result) == {40, 40, 3}
      assert Image.get_pixel!(result, 4, 6) == [255, 255, 255]
    end

    test ":interpolate selects an interpolator from the public vocabulary" do
      image = white_dot(20, 20, 2, 3)

      for interpolator <- [:nearest, :bilinear, :bicubic, :lbb, :nohalo, :vsqbs] do
        assert {:ok, %Vimage{}} = Image.affine(image, [2, 0, 0, 2], interpolate: interpolator)
      end
    end

    test "rejects an unknown :interpolate value" do
      image = white_dot(20, 20, 2, 3)

      assert {:error, %Image.Error{reason: :invalid_option, value: {:interpolate, :unknown}}} =
               Image.affine(image, [1, 0, 0, 1], interpolate: :unknown)
    end

    test "rejects an unknown option" do
      image = white_dot(20, 20, 2, 3)

      assert {:error, %Image.Error{reason: :invalid_option, value: {:not_an_option, 1}}} =
               Image.affine(image, [1, 0, 0, 1], not_an_option: 1)
    end

    test "accepts the :output_area option" do
      image = white_dot(20, 20, 2, 3)

      {:ok, cropped} = Image.affine(image, [1, 0, 0, 1], output_area: [0, 0, 10, 10])
      assert Image.shape(cropped) == {10, 10, 3}
    end

    test "applies output displacements :odx/:ody after the matrix" do
      image = white_dot(20, 20, 2, 3)
      {:ok, result} = Image.affine(image, [1, 0, 0, 1], odx: 4, ody: 1)

      assert Image.shape(result) == {20, 20, 3}
      assert Image.get_pixel!(result, 6, 4) == [255, 255, 255]
    end

    test "rejects a matrix that is not four numbers" do
      image = white_dot(20, 20, 2, 3)

      assert {:error, %Image.Error{reason: :invalid_affine_matrix, value: [1, 0, 0]}} =
               Image.affine(image, [1, 0, 0])

      assert {:error, %Image.Error{reason: :invalid_affine_matrix, value: [1, 0, 0, :x]}} =
               Image.affine(image, [1, 0, 0, :x])
    end

    test "affine!/3 returns an image on success" do
      image = white_dot(20, 20, 2, 3)
      assert %Vimage{} = Image.affine!(image, [1, 0, 0, 1])
    end

    test "affine!/3 raises on error" do
      image = white_dot(20, 20, 2, 3)

      assert_raise Image.Error, fn ->
        Image.affine!(image, [1, 0, 0, 1], interpolate: :unknown)
      end
    end

    test "defaults :extend to background, :interpolate to bilinear and no :background" do
      image = white_dot(20, 20, 2, 3)
      {:ok, options} = Image.Options.Affine.validate_options(image, [])

      assert Keyword.get(options, :extend) == :VIPS_EXTEND_BACKGROUND
      refute Keyword.has_key?(options, :extend_mode)
      assert %Vix.Vips.Interpolate{} = Keyword.get(options, :interpolate)
      # No :background is injected. libvips uses its native all-zeros fill.
      refute Keyword.has_key?(options, :background)
    end

    test "extend_mode: :copy is renamed to :extend for libvips" do
      image = white_dot(20, 20, 2, 3)
      {:ok, options} = Image.Options.Affine.validate_options(image, extend_mode: :copy)

      assert Keyword.get(options, :extend) == :VIPS_EXTEND_COPY
      refute Keyword.has_key?(options, :extend_mode)
    end

    test "extend_mode: :copy avoids the edge fringe on a full-canvas scale" do
      # A pure scale-up: the content covers the whole output canvas, so no
      # background should ever be visible. With the default :background
      # extend the outermost row/column still blends toward the (black)
      # fill. :copy clamps to the content instead.
      white = Image.new!(10, 10, color: [255, 255, 255])

      {:ok, blended} = Image.affine(white, [2, 0, 0, 2])
      assert Image.get_pixel!(blended, 19, 10) == [128, 128, 128]

      {:ok, clamped} = Image.affine(white, [2, 0, 0, 2], extend_mode: :copy)
      assert Image.get_pixel!(clamped, 19, 10) == [255, 255, 255]
    end

    test "only :background and :copy are valid extend modes" do
      image = white_dot(20, 20, 2, 3)

      for extend_mode <- [:repeat, :mirror, :black, :white] do
        assert {:error, %Image.Error{reason: :invalid_option}} =
                 Image.affine(image, [2, 0, 0, 2], extend_mode: extend_mode)
      end
    end

    test "the default fill is transparent for alpha images" do
      # A translation vacates a strip of canvas. On an alpha image the native
      # all-zeros default keeps those pixels transparent.
      image = Image.new!(20, 20, color: [0, 0, 0, 255])

      {:ok, translated} = Image.translate(image, 10, 0)
      assert Image.get_pixel!(translated, 2, 10) == [0, 0, 0, 0]
    end

    test "a nil :background is treated as unset and falls back to the default" do
      image = Image.new!(20, 20, color: [0, 0, 0, 255])

      {:ok, translated} = Image.translate(image, 10, 0, background: nil)
      # falls back to the native default -> transparent vacated strip
      assert Image.get_pixel!(translated, 2, 10) == [0, 0, 0, 0]
    end
  end

  describe "Image.affine/3 with a partially transparent :background" do
    # 45-degree rotation: the output corners are exposed canvas, the
    # center is source content.
    @angle :math.pi() / 4
    @rotation_45 [:math.cos(@angle), -:math.sin(@angle), :math.sin(@angle), :math.cos(@angle)]

    test "the fill is reproduced exactly" do
      image = Image.new!(20, 20, color: [255, 0, 0, 255])

      {:ok, result} = Image.affine(image, @rotation_45, background: [10, 20, 30, 40])

      assert Image.get_pixel!(result, 1, 1) == [10, 20, 30, 40]
    end

    test "content pixels, shape and band format are unchanged" do
      image = Image.new!(20, 20, color: [255, 0, 0, 255])

      {:ok, straight} = Image.affine(image, @rotation_45, background: [10, 20, 30, 255])
      {:ok, result} = Image.affine(image, @rotation_45, background: [10, 20, 30, 40])

      assert Image.shape(result) == Image.shape(straight)
      assert Image.band_format(result) == Image.band_format(image)

      {width, height, 4} = Image.shape(result)
      assert Image.get_pixel!(result, div(width, 2), div(height, 2)) == [255, 0, 0, 255]
    end

    test "the fill is exact for a :rgb16 image (alpha scale 65_535)" do
      image =
        Image.new!(20, 20, color: [255, 0, 0, 255])
        |> Image.to_colorspace!(:rgb16)

      {:ok, result} =
        Image.affine(image, @rotation_45, background: [4_000, 8_000, 12_000, 16_000])

      assert Image.get_pixel!(result, 1, 1) == [4_000, 8_000, 12_000, 16_000]
      assert Image.band_format(result) == {:u, 16}
    end
  end

  describe "Image.translate/4" do
    test "shifts content right and down without resizing the canvas" do
      image = white_dot(20, 20, 2, 3)
      {:ok, result} = Image.translate(image, 5, 4)

      assert Image.shape(result) == {20, 20, 3}
      assert Image.get_pixel!(result, 7, 7) == [255, 255, 255]
      assert Image.get_pixel!(result, 2, 3) == [0, 0, 0]
    end

    test "clips content shifted off the canvas" do
      # The dot is near the right edge. Shifting it further right pushes it
      # off the (unchanged) canvas entirely.
      image = white_dot(20, 20, 18, 10)
      {:ok, result} = Image.translate(image, 5, 0)

      assert Image.shape(result) == {20, 20, 3}
      # the dot ran off the right edge, so the canvas is entirely background
      assert Vix.Vips.Operation.avg!(result) == 0.0
    end

    test "fills the vacated area with the background colour" do
      image = white_dot(20, 20, 10, 10)

      {:ok, result} = Image.translate(image, 5, 0, background: [100, 100, 100])

      assert Image.get_pixel!(result, 0, 0) == [100, 100, 100]
    end

    test "accepts a CSS colour name as the :background fill" do
      image = white_dot(20, 20, 10, 10)
      {:ok, result} = Image.translate(image, 5, 0, background: :red)

      assert Image.get_pixel!(result, 0, 0) == [255, 0, 0]
    end

    test "accepts :average as the :background fill" do
      image = Image.new!(20, 20, color: [10, 20, 30])
      {:ok, result} = Image.translate(image, 5, 0, background: :average)

      assert Image.get_pixel!(result, 0, 0) == [10, 20, 30]
    end

    test "resolves :average against an image with an alpha band" do
      image = Image.new!(20, 20, color: [10, 20, 30, 255])

      assert {:ok, result} = Image.translate(image, 5, 0, background: :average)
      assert Image.bands(result) == 4
      assert Image.get_pixel!(result, 0, 0) == [10, 20, 30, 255]
    end

    test "rejects an invalid :background" do
      image = white_dot(20, 20, 10, 10)
      assert {:error, _reason} = Image.translate(image, 5, 0, background: :not_a_colour)
    end

    test "translate!/4 returns an image on success" do
      image = white_dot(20, 20, 2, 3)
      assert %Vimage{} = Image.translate!(image, 5, 4)
    end

    test "translate!/4 raises on error" do
      image = white_dot(20, 20, 2, 3)
      assert_raise Image.Error, fn -> Image.translate!(image, 5, 4, interpolate: :unknown) end
    end
  end

  describe "Image.shear/4" do
    test "horizontal shear (proportional to y) widens the canvas" do
      image = white_dot(20, 20, 2, 3)
      {:ok, result} = Image.shear(image, 0.5, 0)

      {width, height, _bands} = Image.shape(result)
      assert width == 30
      assert height == 20
    end

    test "vertical shear (proportional to x) heightens the canvas" do
      image = white_dot(20, 20, 2, 3)
      {:ok, result} = Image.shear(image, 0, 0.5)

      {width, height, _bands} = Image.shape(result)
      assert width == 20
      assert height == 30
    end

    test "shear!/4 returns an image on success" do
      image = white_dot(20, 20, 2, 3)
      assert %Vimage{} = Image.shear!(image, 0.5, 0)
    end

    test "shear!/4 raises on error" do
      image = white_dot(20, 20, 2, 3)
      assert_raise Image.Error, fn -> Image.shear!(image, 0.5, 0, interpolate: :unknown) end
    end
  end
end
