defmodule Image.MathCoverage.Test do
  use ExUnit.Case, async: true

  alias Image.Math
  alias Vix.Vips.Image, as: Vimage

  defp grey_image(value) do
    Image.new!(4, 4, color: [value, value, value])
  end

  defp band_image(value) when is_list(value) do
    Image.new!(4, 4, color: value)
  end

  describe "add/2" do
    test "image and image" do
      {:ok, sum} = Math.add(grey_image(100), grey_image(30))
      assert Image.get_pixel!(sum, 0, 0) == [130, 130, 130]
    end

    test "image and scalar" do
      {:ok, sum} = Math.add(grey_image(100), 10)
      assert Image.get_pixel!(sum, 0, 0) == [110.0, 110.0, 110.0]
    end

    test "image and list" do
      {:ok, sum} = Math.add(grey_image(100), [1, 2, 3])
      assert Image.get_pixel!(sum, 0, 0) == [101.0, 102.0, 103.0]
    end

    test "scalar and image" do
      {:ok, sum} = Math.add(10, grey_image(100))
      assert Image.get_pixel!(sum, 0, 0) == [110.0, 110.0, 110.0]
    end
  end

  describe "subtract/2" do
    test "image and image" do
      {:ok, difference} = Math.subtract(grey_image(100), grey_image(30))
      assert Image.get_pixel!(difference, 0, 0) == [70.0, 70.0, 70.0]
    end

    test "image and scalar" do
      {:ok, difference} = Math.subtract(grey_image(100), 30)
      assert Image.get_pixel!(difference, 0, 0) == [70.0, 70.0, 70.0]
    end

    test "image and list" do
      {:ok, difference} = Math.subtract(grey_image(100), [10, 20, 30])
      assert Image.get_pixel!(difference, 0, 0) == [90.0, 80.0, 70.0]
    end

    test "scalar and image" do
      {:ok, difference} = Math.subtract(200, grey_image(100))
      assert Image.get_pixel!(difference, 0, 0) == [100.0, 100.0, 100.0]
    end
  end

  describe "multiply/2" do
    test "image and image" do
      {:ok, product} = Math.multiply(grey_image(100), grey_image(30))
      assert Image.get_pixel!(product, 0, 0) == [3000, 3000, 3000]
    end

    test "image and scalar" do
      {:ok, product} = Math.multiply(grey_image(100), 2)
      assert Image.get_pixel!(product, 0, 0) == [200.0, 200.0, 200.0]
    end

    test "image and list" do
      {:ok, product} = Math.multiply(grey_image(100), [1, 2, 0.5])
      assert Image.get_pixel!(product, 0, 0) == [100.0, 200.0, 50.0]
    end

    test "scalar and image" do
      {:ok, product} = Math.multiply(2, grey_image(100))
      assert Image.get_pixel!(product, 0, 0) == [200.0, 200.0, 200.0]
    end
  end

  describe "divide/2" do
    test "image and image" do
      {:ok, quotient} = Math.divide(grey_image(100), grey_image(50))
      assert Image.get_pixel!(quotient, 0, 0) == [2.0, 2.0, 2.0]
    end

    test "image and scalar" do
      {:ok, quotient} = Math.divide(grey_image(100), 2)
      assert Image.get_pixel!(quotient, 0, 0) == [50.0, 50.0, 50.0]
    end

    test "image and list" do
      {:ok, quotient} = Math.divide(grey_image(100), [2, 4, 5])
      assert Image.get_pixel!(quotient, 0, 0) == [50.0, 25.0, 20.0]
    end

    test "scalar and image" do
      {:ok, quotient} = Math.divide(100, grey_image(100))
      assert Image.get_pixel!(quotient, 0, 0) == [1.0, 1.0, 1.0]
    end
  end

  describe "pow/2" do
    test "image and scalar" do
      {:ok, power} = Math.pow(grey_image(100), 2)
      assert Image.get_pixel!(power, 0, 0) == [10_000.0, 10_000.0, 10_000.0]
    end

    test "image and image" do
      {:ok, power} = Math.pow(grey_image(2), grey_image(3))
      assert Image.get_pixel!(power, 0, 0) == [8.0, 8.0, 8.0]
    end

    test "pow! with image and scalar" do
      power = Math.pow!(grey_image(10), 2)
      assert Image.get_pixel!(power, 0, 0) == [100.0, 100.0, 100.0]
    end

    test "pow! with two numbers" do
      assert Math.pow!(2, 10) == 1024
    end
  end

  describe "comparison operations" do
    test "less_than/2 with a pixel" do
      {:ok, comparison} = Math.less_than(grey_image(100), 128)
      assert Image.get_pixel!(comparison, 0, 0) == [255, 255, 255]
    end

    test "less_than/2 with an image" do
      {:ok, comparison} = Math.less_than(grey_image(100), grey_image(30))
      assert Image.get_pixel!(comparison, 0, 0) == [0, 0, 0]
    end

    test "less_than_or_equal/2 with a pixel" do
      {:ok, comparison} = Math.less_than_or_equal(grey_image(100), [100, 100, 100])
      assert Image.get_pixel!(comparison, 0, 0) == [255, 255, 255]
    end

    test "less_than_or_equal/2 with an image" do
      {:ok, comparison} = Math.less_than_or_equal(grey_image(100), grey_image(30))
      assert Image.get_pixel!(comparison, 0, 0) == [0, 0, 0]
    end

    test "greater_than/2 with a pixel" do
      {:ok, comparison} = Math.greater_than(grey_image(100), 128)
      assert Image.get_pixel!(comparison, 0, 0) == [0, 0, 0]
    end

    test "greater_than/2 with an image" do
      {:ok, comparison} = Math.greater_than(grey_image(100), grey_image(30))
      assert Image.get_pixel!(comparison, 0, 0) == [255, 255, 255]
    end

    test "greater_than_or_equal/2 with a pixel" do
      {:ok, comparison} = Math.greater_than_or_equal(grey_image(100), 100)
      assert Image.get_pixel!(comparison, 0, 0) == [255, 255, 255]
    end

    test "greater_than_or_equal/2 with an image" do
      {:ok, comparison} = Math.greater_than_or_equal(grey_image(100), grey_image(30))
      assert Image.get_pixel!(comparison, 0, 0) == [255, 255, 255]
    end

    test "equal/2 with a pixel" do
      {:ok, comparison} = Math.equal(grey_image(100), [100, 100, 100])
      assert Image.get_pixel!(comparison, 0, 0) == [255, 255, 255]
    end

    test "equal/2 with an image" do
      {:ok, comparison} = Math.equal(grey_image(100), grey_image(30))
      assert Image.get_pixel!(comparison, 0, 0) == [0, 0, 0]
    end

    test "not_equal/2 with a pixel" do
      {:ok, comparison} = Math.not_equal(grey_image(100), 100)
      assert Image.get_pixel!(comparison, 0, 0) == [0, 0, 0]
    end

    test "not_equal/2 with an image" do
      {:ok, comparison} = Math.not_equal(grey_image(100), grey_image(30))
      assert Image.get_pixel!(comparison, 0, 0) == [255, 255, 255]
    end
  end

  describe "comparison bang functions with numbers" do
    test "less_than!/2" do
      assert Math.less_than!(1, 2) == true
    end

    test "less_than_or_equal!/2" do
      assert Math.less_than_or_equal!(2, 2) == true
    end

    test "greater_than!/2" do
      assert Math.greater_than!(1, 2) == false
    end

    test "greater_than_or_equal!/2" do
      assert Math.greater_than_or_equal!(2, 2) == true
    end

    test "equal!/2" do
      assert Math.equal!(2, 2) == true
    end

    test "not_equal!/2" do
      assert Math.not_equal!(2, 2) == false
    end
  end

  describe "trigonometry, exponents and extrema" do
    test "cos/1 of an image" do
      {:ok, cosine} = Math.cos(band_image([0, 0, 0]))
      assert Image.get_pixel!(cosine, 0, 0) == [1.0, 1.0, 1.0]
    end

    test "cos/1 of a number" do
      assert Math.cos(0) == {:ok, 1.0}
    end

    test "cos!/1 of an image" do
      cosine = Math.cos!(band_image([0, 0, 0]))
      assert Image.get_pixel!(cosine, 0, 0) == [1.0, 1.0, 1.0]
    end

    test "sin/1 of an image" do
      {:ok, sine} = Math.sin(band_image([0, 0, 0]))
      assert Image.get_pixel!(sine, 0, 0) == [0.0, 0.0, 0.0]
    end

    test "sin/1 of a number" do
      assert Math.sin(0) == {:ok, 0.0}
    end

    test "sin!/1 of an image" do
      sine = Math.sin!(band_image([0, 0, 0]))
      assert Image.get_pixel!(sine, 0, 0) == [0.0, 0.0, 0.0]
    end

    test "exp/1 of an image" do
      {:ok, exponent} = Math.exp(band_image([0, 0, 0]))
      assert Image.get_pixel!(exponent, 0, 0) == [1.0, 1.0, 1.0]
    end

    test "exp!/1 of an image" do
      exponent = Math.exp!(band_image([0, 0, 0]))
      assert Image.get_pixel!(exponent, 0, 0) == [1.0, 1.0, 1.0]
    end

    test "abs/1 of an image" do
      negative = Math.subtract!(grey_image(30), 100)
      {:ok, absolute} = Math.abs(negative)
      assert Image.get_pixel!(absolute, 0, 0) == [70.0, 70.0, 70.0]
    end

    test "abs/1 of a number" do
      assert Math.abs(-5) == {:ok, 5}
    end

    test "abs!/1 of an image" do
      negative = Math.subtract!(grey_image(30), 100)
      absolute = Math.abs!(negative)
      assert Image.get_pixel!(absolute, 0, 0) == [70.0, 70.0, 70.0]
    end

    test "max/1 and max!/1" do
      assert Math.max(grey_image(100)) == {:ok, 100.0}
      assert Math.max!(grey_image(100)) == 100.0
    end

    test "min/1 and min!/1" do
      assert Math.min(grey_image(30)) == {:ok, 30.0}
      assert Math.min!(grey_image(30)) == 30.0
    end
  end

  describe "boolean operations" do
    defp bw_image(value) do
      Image.new!(4, 4, color: value) |> Image.to_colorspace!(:bw)
    end

    test "boolean_and/2 and boolean_and!/2" do
      assert {:ok, %Vimage{} = anded} = Math.boolean_and(bw_image(3), bw_image(2))
      assert Image.get_pixel!(anded, 0, 0) == [2]
      assert Image.get_pixel!(Math.boolean_and!(bw_image(3), bw_image(2)), 0, 0) == [2]
    end

    test "boolean_or/2 and boolean_or!/2" do
      assert {:ok, %Vimage{} = ored} = Math.boolean_or(bw_image(3), bw_image(2))
      assert Image.get_pixel!(ored, 0, 0) == [3]
      assert Image.get_pixel!(Math.boolean_or!(bw_image(3), bw_image(2)), 0, 0) == [3]
    end

    test "boolean_xor/2 and boolean_xor!/2" do
      assert {:ok, %Vimage{} = xored} = Math.boolean_xor(bw_image(3), bw_image(2))
      assert Image.get_pixel!(xored, 0, 0) == [1]
      assert Image.get_pixel!(Math.boolean_xor!(bw_image(3), bw_image(2)), 0, 0) == [1]
    end

    test "boolean_lshift/2 and boolean_lshift!/2" do
      assert {:ok, %Vimage{} = shifted} = Math.boolean_lshift(bw_image(3), bw_image(2))
      assert Image.get_pixel!(shifted, 0, 0) == [12]
      assert Image.get_pixel!(Math.boolean_lshift!(bw_image(3), bw_image(2)), 0, 0) == [12]
    end

    test "boolean_rshift/2 and boolean_rshift!/2" do
      assert {:ok, %Vimage{} = shifted} = Math.boolean_rshift(bw_image(3), bw_image(2))
      assert Image.get_pixel!(shifted, 0, 0) == [0]
      assert Image.get_pixel!(Math.boolean_rshift!(bw_image(3), bw_image(2)), 0, 0) == [0]
    end
  end

  describe "extrema coordinates" do
    test "top_n/2" do
      image = Image.new!(4, 4, color: 3) |> Image.to_colorspace!(:bw)
      assert {3.0, x, y, coordinates} = Math.top_n(image, 2)
      assert is_integer(x) and is_integer(y)
      assert length(coordinates) == 2
    end

    test "bottom_n/2" do
      image = Image.new!(4, 4, color: 3) |> Image.to_colorspace!(:bw)
      assert {3.0, x, y, coordinates} = Math.bottom_n(image, 2)
      assert is_integer(x) and is_integer(y)
      assert length(coordinates) == 2
    end

    test "maxpos/2 finds the single maximum" do
      {:ok, image} =
        Image.new!(5, 5, color: :red)
        |> Image.mutate(fn mutable ->
          Image.Draw.point!(mutable, 2, 2, color: [0, 255, 0])
        end)

      mask = image |> Math.equal!([0, 255, 0]) |> Image.band_and!()
      assert Math.maxpos(mask) == {255, [{2, 2}], nil}
    end

    test "maxpos/2 signals a possible overflow" do
      mask =
        Image.new!(2, 2, color: :red)
        |> Math.equal!([255, 0, 0])
        |> Image.band_and!()

      assert {255, coordinates, :maybe_overflow} = Math.maxpos(mask, 3)
      assert length(coordinates) == 3
    end

    test "minpos/2 finds the single minimum" do
      {:ok, image} =
        Image.new!(5, 5, color: 200)
        |> Image.to_colorspace!(:bw)
        |> Image.mutate(fn mutable ->
          Image.Draw.point!(mutable, 2, 2, color: 10)
        end)

      assert {minimum, [{2, 2}], nil} = Math.minpos(image)
      assert minimum == trunc(Math.min!(image))
    end
  end

  describe "list helpers" do
    test "list_height/1" do
      assert Math.list_height([[1, 2], [3, 4]]) == 2
      assert Math.list_height([1, 2]) == 0
    end

    test "list_width/1" do
      assert Math.list_width([[1, 2, 3], [4, 5, 6]]) == 3
      assert Math.list_width([1, 2, 3]) == 3
    end
  end

  describe "operators on images via use Image.Math" do
    use Image.Math

    test "unary minus of an image" do
      negated = -Image.new!(4, 4, color: [100, 100, 100])
      assert Image.get_pixel!(negated, 0, 0) == [-100.0, -100.0, -100.0]
    end

    test "unary minus of a number" do
      assert -5 == Kernel.-(5)
    end

    test "+ operator with an image and a scalar" do
      sum = Image.new!(4, 4, color: [100, 100, 100]) + 10
      assert Image.get_pixel!(sum, 0, 0) == [110.0, 110.0, 110.0]
    end

    test "- operator with two images" do
      difference =
        Image.new!(4, 4, color: [100, 100, 100]) - Image.new!(4, 4, color: [30, 30, 30])

      assert Image.get_pixel!(difference, 0, 0) == [70.0, 70.0, 70.0]
    end

    test "* operator with an image and a list" do
      product = Image.new!(4, 4, color: [100, 100, 100]) * [1, 2, 0.5]
      assert Image.get_pixel!(product, 0, 0) == [100.0, 200.0, 50.0]
    end

    test "/ operator with an image and a scalar" do
      quotient = Image.new!(4, 4, color: [100, 100, 100]) / 2
      assert Image.get_pixel!(quotient, 0, 0) == [50.0, 50.0, 50.0]
    end

    test "** operator with an image and a scalar" do
      power = Image.new!(4, 4, color: [10, 10, 10]) ** 2
      assert Image.get_pixel!(power, 0, 0) == [100.0, 100.0, 100.0]
    end

    test "< operator with an image and a scalar" do
      comparison = Image.new!(4, 4, color: [100, 100, 100]) < 128
      assert Image.get_pixel!(comparison, 0, 0) == [255, 255, 255]
    end

    test "<= operator with an image and a scalar" do
      comparison = Image.new!(4, 4, color: [100, 100, 100]) <= 100
      assert Image.get_pixel!(comparison, 0, 0) == [255, 255, 255]
    end

    test "> operator with an image and a scalar" do
      comparison = Image.new!(4, 4, color: [100, 100, 100]) > 128
      assert Image.get_pixel!(comparison, 0, 0) == [0, 0, 0]
    end

    test ">= operator with an image and a scalar" do
      comparison = Image.new!(4, 4, color: [100, 100, 100]) >= 100
      assert Image.get_pixel!(comparison, 0, 0) == [255, 255, 255]
    end

    test "== operator with an image and a pixel" do
      comparison = Image.new!(4, 4, color: [100, 100, 100]) == [100, 100, 100]
      assert Image.get_pixel!(comparison, 0, 0) == [255, 255, 255]
    end

    # The != operator cannot be exercised under `use Image.Math` because
    # the __using__ macro does not exclude Kernel.!=/2, so the imports
    # conflict at any != call site. Call the operator function directly.
    test "!= operator function with an image and a pixel" do
      comparison = Image.Math.!=(Image.new!(4, 4, color: [100, 100, 100]), [100, 100, 100])
      assert Image.get_pixel!(comparison, 0, 0) == [0, 0, 0]
    end

    test "&&& operator with two images" do
      left = Image.new!(4, 4, color: 3) |> Image.to_colorspace!(:bw)
      right = Image.new!(4, 4, color: 2) |> Image.to_colorspace!(:bw)
      assert Image.get_pixel!(left &&& right, 0, 0) == [2]
    end

    test "||| operator with two images" do
      left = Image.new!(4, 4, color: 3) |> Image.to_colorspace!(:bw)
      right = Image.new!(4, 4, color: 2) |> Image.to_colorspace!(:bw)
      assert Image.get_pixel!(left ||| right, 0, 0) == [3]
    end

    test "<<< operator with two images" do
      left = Image.new!(4, 4, color: 3) |> Image.to_colorspace!(:bw)
      right = Image.new!(4, 4, color: 2) |> Image.to_colorspace!(:bw)
      assert Image.get_pixel!(left <<< right, 0, 0) == [12]
    end

    test ">>> operator with two images" do
      left = Image.new!(4, 4, color: 3) |> Image.to_colorspace!(:bw)
      right = Image.new!(4, 4, color: 2) |> Image.to_colorspace!(:bw)
      assert Image.get_pixel!(left >>> right, 0, 0) == [0]
    end
  end

  describe "bang function argument permutations" do
    test "add!/2 with value then image" do
      sum = Math.add!(10, grey_image(100))
      assert Image.get_pixel!(sum, 0, 0) == [110.0, 110.0, 110.0]
    end

    test "subtract!/2 with value then image" do
      difference = Math.subtract!(200, grey_image(100))
      assert Image.get_pixel!(difference, 0, 0) == [100.0, 100.0, 100.0]
    end

    test "multiply!/2 with value then image" do
      product = Math.multiply!(2, grey_image(100))
      assert Image.get_pixel!(product, 0, 0) == [200.0, 200.0, 200.0]
    end

    test "divide!/2 with value then image" do
      quotient = Math.divide!(100, grey_image(100))
      assert Image.get_pixel!(quotient, 0, 0) == [1.0, 1.0, 1.0]
    end
  end
end
