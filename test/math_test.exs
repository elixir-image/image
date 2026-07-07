defmodule Image.MathTest do
  use ExUnit.Case, async: true

  alias Image.Math

  describe "scalar arithmetic" do
    test "add/2 with two numbers" do
      assert Math.add(10, 2) == {:ok, 12}
    end

    test "subtract/2 with two numbers" do
      assert Math.subtract(10, 2) == {:ok, 8}
    end

    test "multiply/2 with two numbers" do
      assert Math.multiply(10, 2) == {:ok, 20}
    end

    test "divide/2 with two numbers divides (not subtracts)" do
      assert Math.divide(10, 2) == {:ok, 5.0}
    end

    test "pow/2 with two numbers" do
      assert Math.pow(10, 2) == {:ok, 100}
    end
  end

  describe "operator overloading with use Image.Math" do
    use Image.Math

    test "the / operator divides two numbers" do
      assert 10 / 2 == 5.0
    end

    test "the + operator adds two numbers" do
      assert 10 + 2 == 12
    end

    test "the - operator subtracts two numbers" do
      assert 10 - 2 == 8
    end

    test "the * operator multiplies two numbers" do
      assert 10 * 2 == 20
    end
  end
end
