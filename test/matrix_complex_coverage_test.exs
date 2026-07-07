defmodule Image.MatrixComplexCoverage.Test do
  use ExUnit.Case, async: true

  alias Vix.Vips.Image, as: Vimage

  describe "Image.Matrix.image_from_matrix/1" do
    test "builds an image from an integer matrix" do
      assert {:ok, %Vimage{} = image} = Image.Matrix.image_from_matrix([[1, 2], [3, 4]])

      assert Image.width(image) == 2
      assert Image.height(image) == 2
      assert Image.bands(image) == 1
      assert Vimage.format(image) == :VIPS_FORMAT_INT
      assert Image.get_pixel!(image, 0, 0) == [1]
      assert Image.get_pixel!(image, 1, 1) == [4]
    end

    test "builds a float image from a float matrix" do
      assert {:ok, %Vimage{} = image} = Image.Matrix.image_from_matrix([[1.5, 2.5]])

      assert Image.width(image) == 2
      assert Image.height(image) == 1
      assert Vimage.format(image) == :VIPS_FORMAT_FLOAT
      assert Image.get_pixel!(image, 1, 0) == [2.5]
    end

    test "a mixed integer and float matrix is widened to float" do
      assert {:ok, %Vimage{} = image} =
               Image.Matrix.image_from_matrix([[1, 2.5], [3, 4]])

      assert Vimage.format(image) == :VIPS_FORMAT_FLOAT
    end

    test "returns an error for an empty matrix" do
      assert {:error, %Image.Error{message: "Cannot infer the type of an empty matrix"}} =
               Image.Matrix.image_from_matrix([])
    end

    test "returns an error for ragged rows" do
      assert {:error, %Image.Error{message: message}} =
               Image.Matrix.image_from_matrix([[1, 2], [3]])

      assert message ==
               "Cannot build image because lists have different shapes: " <>
                 "{2} at position 0 and {1} at position 1"
    end

    test "returns an error for a one-dimensional list" do
      assert {:error, %Image.Error{message: message}} = Image.Matrix.image_from_matrix([1, 2, 3])
      assert message =~ "must be a two-dimensional list"
      assert message =~ "[3]"
    end

    test "returns an error for a three-dimensional list" do
      assert {:error, %Image.Error{message: message}} =
               Image.Matrix.image_from_matrix([[[1, 2], [3, 4]], [[5, 6], [7, 8]]])

      assert message =~ "must be a two-dimensional list"
      assert message =~ "[2, 2, 2]"
    end

    test "returns an error for a non-numeric value" do
      assert {:error, %Image.Error{message: "Invalid matrix value: :a"}} =
               Image.Matrix.image_from_matrix([[:a]])
    end
  end

  describe "Image.Complex.polar/1 and rectangular/1" do
    test "polar of a four band image returns a float image" do
      rgba = Image.new!(4, 4, color: [10, 20, 30, 40])

      assert {:ok, %Vimage{} = polar} = Image.Complex.polar(rgba)
      assert Image.bands(polar) == 4
      assert Vimage.format(polar) == :VIPS_FORMAT_FLOAT

      [amplitude, angle, amplitude_2, angle_2] = Image.get_pixel!(polar, 0, 0)
      assert_in_delta amplitude, :math.sqrt(10 * 10 + 20 * 20), 0.001
      assert_in_delta angle, :math.atan2(20, 10) * 180 / :math.pi(), 0.001
      assert_in_delta amplitude_2, :math.sqrt(30 * 30 + 40 * 40), 0.001
      assert_in_delta angle_2, :math.atan2(40, 30) * 180 / :math.pi(), 0.001
    end

    test "rectangular reverses polar" do
      rgba = Image.new!(4, 4, color: [10, 20, 30, 40])

      assert {:ok, polar} = Image.Complex.polar(rgba)
      assert {:ok, rectangular} = Image.Complex.rectangular(polar)

      [b1, b2, b3, b4] = Image.get_pixel!(rectangular, 0, 0)
      assert_in_delta b1, 10.0, 0.001
      assert_in_delta b2, 20.0, 0.001
      assert_in_delta b3, 30.0, 0.001
      assert_in_delta b4, 40.0, 0.001
    end

    test "a double format image converts through the double complex format" do
      double =
        Image.new!(4, 4, color: [10, 20])
        |> Vix.Vips.Operation.cast!(:VIPS_FORMAT_DOUBLE)

      assert {:ok, %Vimage{} = polar} = Image.Complex.polar(double)
      assert Vimage.format(polar) == :VIPS_FORMAT_DOUBLE
      assert Image.bands(polar) == 2
    end

    test "polar of an image with an odd number of bands is an error" do
      rgb = Image.new!(4, 4, color: :white)

      assert {:error, %Image.Error{message: "Not an even number of bands. Found: 3"}} =
               Image.Complex.polar(rgb)
    end

    test "rectangular of an image with an odd number of bands is an error" do
      rgb = Image.new!(4, 4, color: :white)

      assert {:error, %Image.Error{message: "Not an even number of bands. Found: 3"}} =
               Image.Complex.rectangular(rgb)
    end

    test "polar!/1 returns the image or raises" do
      rgba = Image.new!(4, 4, color: [10, 20, 30, 40])
      assert %Vimage{} = Image.Complex.polar!(rgba)

      assert_raise Image.Error, fn ->
        Image.Complex.polar!(Image.new!(4, 4, color: :white))
      end
    end

    test "rectangular!/1 returns the image or raises" do
      rgba = Image.new!(4, 4, color: [10, 20, 30, 40])
      assert %Vimage{} = Image.Complex.rectangular!(rgba)

      assert_raise Image.Error, fn ->
        Image.Complex.rectangular!(Image.new!(4, 4, color: :white))
      end
    end
  end
end
