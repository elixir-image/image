defmodule Image.PixelsCoverageTest do
  use ExUnit.Case, async: true

  alias Image.Pixels

  describe "pixels_from_binary/3 with unsigned integer types" do
    test "{:u, 8} for bands 1 to 4" do
      binary = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12>>

      assert Pixels.pixels_from_binary(binary, {:u, 8}, 1) ==
               {:ok, Enum.map(1..12, &[&1])}

      assert Pixels.pixels_from_binary(binary, {:u, 8}, 2) ==
               {:ok, [[1, 2], [3, 4], [5, 6], [7, 8], [9, 10], [11, 12]]}

      assert Pixels.pixels_from_binary(binary, {:u, 8}, 3) ==
               {:ok, [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]]}

      assert Pixels.pixels_from_binary(binary, {:u, 8}, 4) ==
               {:ok, [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12]]}
    end

    test "{:u, 16} for bands 1 to 4" do
      values = [1, 2, 3, 4, 65_535, 6, 7, 8, 9, 10, 11, 12]
      binary = for value <- values, into: <<>>, do: <<value::native-unsigned-16>>

      assert Pixels.pixels_from_binary(binary, {:u, 16}, 1) ==
               {:ok, Enum.map(values, &[&1])}

      assert Pixels.pixels_from_binary(binary, {:u, 16}, 2) ==
               {:ok, Enum.chunk_every(values, 2)}

      assert Pixels.pixels_from_binary(binary, {:u, 16}, 3) ==
               {:ok, Enum.chunk_every(values, 3)}

      assert Pixels.pixels_from_binary(binary, {:u, 16}, 4) ==
               {:ok, Enum.chunk_every(values, 4)}
    end

    test "{:u, 32} for bands 1 to 4" do
      values = [1, 2, 3, 4, 4_294_967_295, 6, 7, 8, 9, 10, 11, 12]
      binary = for value <- values, into: <<>>, do: <<value::native-unsigned-32>>

      assert Pixels.pixels_from_binary(binary, {:u, 32}, 1) ==
               {:ok, Enum.map(values, &[&1])}

      assert Pixels.pixels_from_binary(binary, {:u, 32}, 2) ==
               {:ok, Enum.chunk_every(values, 2)}

      assert Pixels.pixels_from_binary(binary, {:u, 32}, 3) ==
               {:ok, Enum.chunk_every(values, 3)}

      assert Pixels.pixels_from_binary(binary, {:u, 32}, 4) ==
               {:ok, Enum.chunk_every(values, 4)}
    end

    test "{:u, 64} for bands 1 to 4" do
      values = [1, 2, 3, 4, 18_446_744_073_709_551_615, 6, 7, 8, 9, 10, 11, 12]
      binary = for value <- values, into: <<>>, do: <<value::native-unsigned-64>>

      assert Pixels.pixels_from_binary(binary, {:u, 64}, 1) ==
               {:ok, Enum.map(values, &[&1])}

      assert Pixels.pixels_from_binary(binary, {:u, 64}, 2) ==
               {:ok, Enum.chunk_every(values, 2)}

      assert Pixels.pixels_from_binary(binary, {:u, 64}, 3) ==
               {:ok, Enum.chunk_every(values, 3)}

      assert Pixels.pixels_from_binary(binary, {:u, 64}, 4) ==
               {:ok, Enum.chunk_every(values, 4)}
    end
  end

  describe "pixels_from_binary/3 with signed integer types" do
    test "{:s, 8} for bands 1 to 4" do
      values = [-128, -1, 0, 1, 127, 6, 7, 8, 9, 10, 11, 12]
      binary = for value <- values, into: <<>>, do: <<value::native-signed-8>>

      assert Pixels.pixels_from_binary(binary, {:s, 8}, 1) ==
               {:ok, Enum.map(values, &[&1])}

      assert Pixels.pixels_from_binary(binary, {:s, 8}, 2) ==
               {:ok, Enum.chunk_every(values, 2)}

      assert Pixels.pixels_from_binary(binary, {:s, 8}, 3) ==
               {:ok, Enum.chunk_every(values, 3)}

      assert Pixels.pixels_from_binary(binary, {:s, 8}, 4) ==
               {:ok, Enum.chunk_every(values, 4)}
    end

    test "{:s, 16} for bands 1 to 4" do
      values = [-32_768, -1, 0, 1, 32_767, 6, 7, 8, 9, 10, 11, 12]
      binary = for value <- values, into: <<>>, do: <<value::native-signed-16>>

      assert Pixels.pixels_from_binary(binary, {:s, 16}, 1) ==
               {:ok, Enum.map(values, &[&1])}

      assert Pixels.pixels_from_binary(binary, {:s, 16}, 2) ==
               {:ok, Enum.chunk_every(values, 2)}

      assert Pixels.pixels_from_binary(binary, {:s, 16}, 3) ==
               {:ok, Enum.chunk_every(values, 3)}

      assert Pixels.pixels_from_binary(binary, {:s, 16}, 4) ==
               {:ok, Enum.chunk_every(values, 4)}
    end

    test "{:s, 32} for bands 1 to 4" do
      values = [-2_147_483_648, -1, 0, 1, 2_147_483_647, 6, 7, 8, 9, 10, 11, 12]
      binary = for value <- values, into: <<>>, do: <<value::native-signed-32>>

      assert Pixels.pixels_from_binary(binary, {:s, 32}, 1) ==
               {:ok, Enum.map(values, &[&1])}

      assert Pixels.pixels_from_binary(binary, {:s, 32}, 2) ==
               {:ok, Enum.chunk_every(values, 2)}

      assert Pixels.pixels_from_binary(binary, {:s, 32}, 3) ==
               {:ok, Enum.chunk_every(values, 3)}

      assert Pixels.pixels_from_binary(binary, {:s, 32}, 4) ==
               {:ok, Enum.chunk_every(values, 4)}
    end

    test "{:s, 64} for bands 1 to 4" do
      values = [
        -9_223_372_036_854_775_808,
        -1,
        0,
        1,
        9_223_372_036_854_775_807,
        6,
        7,
        8,
        9,
        10,
        11,
        12
      ]

      binary = for value <- values, into: <<>>, do: <<value::native-signed-64>>

      assert Pixels.pixels_from_binary(binary, {:s, 64}, 1) ==
               {:ok, Enum.map(values, &[&1])}

      assert Pixels.pixels_from_binary(binary, {:s, 64}, 2) ==
               {:ok, Enum.chunk_every(values, 2)}

      assert Pixels.pixels_from_binary(binary, {:s, 64}, 3) ==
               {:ok, Enum.chunk_every(values, 3)}

      assert Pixels.pixels_from_binary(binary, {:s, 64}, 4) ==
               {:ok, Enum.chunk_every(values, 4)}
    end
  end

  describe "pixels_from_binary/3 with float types" do
    test "{:f, 32} for bands 1 to 4" do
      values = [-1.5, 0.0, 0.25, 1.0, 2.5, 3.75, 100.0, -0.5, 8.0, 9.5, 10.25, 12.0]
      binary = for value <- values, into: <<>>, do: <<value::native-float-32>>

      assert Pixels.pixels_from_binary(binary, {:f, 32}, 1) ==
               {:ok, Enum.map(values, &[&1])}

      assert Pixels.pixels_from_binary(binary, {:f, 32}, 2) ==
               {:ok, Enum.chunk_every(values, 2)}

      assert Pixels.pixels_from_binary(binary, {:f, 32}, 3) ==
               {:ok, Enum.chunk_every(values, 3)}

      assert Pixels.pixels_from_binary(binary, {:f, 32}, 4) ==
               {:ok, Enum.chunk_every(values, 4)}
    end

    test "{:f, 64} for bands 1 to 4" do
      values = [-1.5, 0.0, 0.25, 1.0, 2.5, 3.75, 100.0, -0.5, 8.0, 9.5, 10.25, 12.0]
      binary = for value <- values, into: <<>>, do: <<value::native-float-64>>

      assert Pixels.pixels_from_binary(binary, {:f, 64}, 1) ==
               {:ok, Enum.map(values, &[&1])}

      assert Pixels.pixels_from_binary(binary, {:f, 64}, 2) ==
               {:ok, Enum.chunk_every(values, 2)}

      assert Pixels.pixels_from_binary(binary, {:f, 64}, 3) ==
               {:ok, Enum.chunk_every(values, 3)}

      assert Pixels.pixels_from_binary(binary, {:f, 64}, 4) ==
               {:ok, Enum.chunk_every(values, 4)}
    end
  end

  describe "pixels_from_binary/3 error handling" do
    test "band counts outside 1..4 return an error" do
      for bands <- [0, 5, -1] do
        assert {:error, %Image.Error{} = error} =
                 Pixels.pixels_from_binary(<<0>>, {:u, 8}, bands)

        assert error.message == "Only images with 1..4 bands are supported. Found #{bands}"
      end
    end

    test "unsupported types return an error" do
      assert {:error, %Image.Error{} = error} =
               Pixels.pixels_from_binary(<<0, 0>>, {:c, 64}, 1)

      assert error.message == "Unsupported image type for pixels_from_binary/3. Found {:c, 64}"
    end
  end

  describe "Image.to_list/1 (built on Image.Pixels)" do
    test "three band image" do
      image = Image.new!(4, 4, color: [10, 20, 30])

      assert {:ok, rows} = Image.to_list(image)
      assert length(rows) == 4
      assert Enum.all?(rows, &(length(&1) == 4))
      assert Enum.all?(rows, fn row -> Enum.all?(row, &(&1 == [10, 20, 30])) end)
    end

    test "four band image with alpha" do
      image =
        Image.new!(3, 2, color: [10, 20, 30])
        |> Image.add_alpha!(:opaque)

      assert {:ok, rows} = Image.to_list(image)
      assert length(rows) == 2
      assert Enum.all?(rows, &(length(&1) == 3))
      assert Enum.all?(rows, fn row -> Enum.all?(row, &(&1 == [10, 20, 30, 255])) end)
    end

    test "single band image" do
      image =
        Image.new!(2, 2, color: [10, 20, 30])
        |> Image.to_colorspace!(:bw)

      assert {:ok, rows} = Image.to_list(image)
      assert length(rows) == 2

      for row <- rows, pixel <- row do
        assert [value] = pixel
        assert is_integer(value)
        assert value in 0..255
      end
    end
  end
end
