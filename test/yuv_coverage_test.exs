defmodule Image.YUVCoverageTest do
  use ExUnit.Case, async: true

  # An 8x6 image means all encodings subsample evenly:
  # :C444 planes are 48 bytes each, :C422 U/V planes are
  # 24 bytes and :C420 U/V planes are 12 bytes.
  @width 8
  @height 6
  @y_bytes @width * @height

  setup do
    Temp.track!()
    dir = Temp.mkdir!()

    image = Image.new!(@width, @height, color: [200, 30, 90])
    {:ok, %{dir: dir, image: image}}
  end

  describe "valid_encodings/0 and valid_colorspaces/0" do
    test "returns the supported encodings" do
      assert Image.YUV.valid_encodings() == [:C444, :C422, :C420]
    end

    test "returns the supported colorspaces" do
      assert Image.YUV.valid_colorspaces() == [:bt601, :bt709]
    end
  end

  describe "write_to_binary/3" do
    test "writes :C444 with the full plane sizes", %{image: image} do
      assert {:ok, binary} = Image.YUV.write_to_binary(image, :C444, :bt601)
      assert byte_size(binary) == @y_bytes * 3
    end

    test "writes :C422 with half-width U/V planes", %{image: image} do
      assert {:ok, binary} = Image.YUV.write_to_binary(image, :C422, :bt601)
      assert byte_size(binary) == @y_bytes + 2 * div(@width, 2) * @height
    end

    test "writes :C420 with half-width, half-height U/V planes", %{image: image} do
      assert {:ok, binary} = Image.YUV.write_to_binary(image, :C420, :bt601)
      assert byte_size(binary) == @y_bytes + 2 * div(@width, 2) * div(@height, 2)
    end

    test "supports the :bt709 colorspace", %{image: image} do
      assert {:ok, bt601} = Image.YUV.write_to_binary(image, :C444, :bt601)
      assert {:ok, bt709} = Image.YUV.write_to_binary(image, :C444, :bt709)
      assert byte_size(bt601) == byte_size(bt709)
      refute bt601 == bt709
    end
  end

  describe "new_from_binary/5 round trips" do
    for encoding <- [:C444, :C422, :C420], colorspace <- [:bt601, :bt709] do
      test "round trips #{inspect(encoding)} in #{inspect(colorspace)}", %{image: image} do
        encoding = unquote(encoding)
        colorspace = unquote(colorspace)

        assert {:ok, binary} = Image.YUV.write_to_binary(image, encoding, colorspace)

        assert {:ok, round_tripped} =
                 Image.YUV.new_from_binary(binary, @width, @height, encoding, colorspace)

        assert Image.shape(round_tripped) == {@width, @height, 3}
        assert Image.colorspace(round_tripped) == :srgb
      end
    end

    test "decoding is deterministic", %{image: image} do
      assert {:ok, binary} = Image.YUV.write_to_binary(image, :C444, :bt601)
      assert {:ok, image_1} = Image.YUV.new_from_binary(binary, @width, @height, :C444, :bt601)
      assert {:ok, image_2} = Image.YUV.new_from_binary(binary, @width, @height, :C444, :bt601)

      assert Image.get_pixel!(image_1, 4, 3) == Image.get_pixel!(image_2, 4, 3)
    end
  end

  describe "new_from_binary/5 error cases" do
    test "returns an error for a short :C444 binary" do
      binary = :binary.copy(<<128>>, @y_bytes)

      assert {:error, %Image.Error{message: "Could not decode raw YUV data as 4:4:4"}} =
               Image.YUV.new_from_binary(binary, @width, @height, :C444, :bt601)
    end

    test "returns an error for a short :C422 binary" do
      binary = :binary.copy(<<128>>, @y_bytes)

      assert {:error, %Image.Error{message: "Could not decode raw YUV data as 4:2:2"}} =
               Image.YUV.new_from_binary(binary, @width, @height, :C422, :bt601)
    end

    test "returns an error for a short :C420 binary" do
      binary = :binary.copy(<<128>>, 10)

      assert {:error, %Image.Error{message: "Could not decode raw YUV data as 4:2:0"}} =
               Image.YUV.new_from_binary(binary, @width, @height, :C420, :bt601)
    end

    test "returns an error for an over-long binary" do
      binary = :binary.copy(<<128>>, @y_bytes * 3 + 1)

      assert {:error, %Image.Error{}} =
               Image.YUV.new_from_binary(binary, @width, @height, :C444, :bt601)
    end
  end

  describe "write_to_file/4 and new_from_file/5" do
    test "round trips via the file system", %{image: image, dir: dir} do
      path = Temp.path!(suffix: ".yuv", basedir: dir)

      assert :ok = Image.YUV.write_to_file(image, path, :C420, :bt601)
      assert File.stat!(path).size == @y_bytes + 2 * div(@width, 2) * div(@height, 2)

      assert {:ok, read_back} = Image.YUV.new_from_file(path, @width, @height, :C420, :bt601)
      assert Image.shape(read_back) == {@width, @height, 3}
    end

    test "returns a posix error for a missing file" do
      assert {:error, :enoent} =
               Image.YUV.new_from_file("no/such/file.yuv", @width, @height, :C444, :bt601)
    end
  end

  describe "to_yuv/3 and encode/2" do
    test "returns three planes of the correct size for :C444", %{image: image} do
      assert {:ok, [y, u, v]} = Image.YUV.to_yuv(image, :C444, :bt601)
      assert byte_size(y) == @y_bytes
      assert byte_size(u) == @y_bytes
      assert byte_size(v) == @y_bytes
    end

    test "returns subsampled planes for :C422", %{image: image} do
      assert {:ok, [y, u, v]} = Image.YUV.to_yuv(image, :C422, :bt709)
      assert byte_size(y) == @y_bytes
      assert byte_size(u) == div(@width, 2) * @height
      assert byte_size(v) == div(@width, 2) * @height
    end

    test "returns subsampled planes for :C420", %{image: image} do
      assert {:ok, [y, u, v]} = Image.YUV.to_yuv(image, :C420, :bt601)
      assert byte_size(y) == @y_bytes
      assert byte_size(u) == div(@width, 2) * div(@height, 2)
      assert byte_size(v) == div(@width, 2) * div(@height, 2)
    end
  end

  describe "decode/4 and to_rgb/5" do
    test "decodes planes and converts them to an RGB image", %{image: image} do
      assert {:ok, binary} = Image.YUV.write_to_binary(image, :C422, :bt601)
      assert {:ok, [_y, _u, _v] = planes} = Image.YUV.decode(binary, @width, @height, :C422)

      assert {:ok, rgb} = Image.YUV.to_rgb(planes, @width, @height, :C422, :bt601)
      assert Image.shape(rgb) == {@width, @height, 3}
      assert Image.colorspace(rgb) == :srgb
    end

    test "returns an error tuple for a truncated binary" do
      assert {:error, %Image.Error{}} = Image.YUV.decode(<<0, 1, 2>>, @width, @height, :C444)
    end
  end
end
