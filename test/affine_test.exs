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

    test "accepts the :extend_mode and :output_area options" do
      image = white_dot(20, 20, 2, 3)
      assert {:ok, %Vimage{}} = Image.affine(image, [1, 0, 0, 1], extend_mode: :mirror)

      {:ok, cropped} = Image.affine(image, [1, 0, 0, 1], output_area: [0, 0, 10, 10])
      assert Image.shape(cropped) == {10, 10, 3}
    end

    test "rejects an invalid :extend_mode with a structured error" do
      image = white_dot(20, 20, 2, 3)

      assert {:error, %Image.Error{reason: :invalid_extend_mode, value: :bogus}} =
               Image.affine(image, [1, 0, 0, 1], extend_mode: :bogus)
    end

    test "rejects a non-atom/binary :extend_mode without crashing" do
      image = white_dot(20, 20, 2, 3)

      assert {:error, %Image.Error{reason: :invalid_option, value: {:extend_mode, 123}}} =
               Image.affine(image, [1, 0, 0, 1], extend_mode: 123)
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

    test "applies the documented default :extend_mode, :background and :interpolate" do
      image = white_dot(20, 20, 2, 3)
      {:ok, options} = Image.Options.Affine.validate_options(image, [])

      assert Keyword.get(options, :extend) == :VIPS_EXTEND_BACKGROUND
      assert Keyword.get(options, :background) == [0, 0, 0]
      assert %Vix.Vips.Interpolate{} = Keyword.get(options, :interpolate)
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

      {:ok, result} =
        Image.translate(image, 5, 0, background: [100, 100, 100], extend_mode: :background)

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
