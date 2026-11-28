defmodule Image.IcoTest do
  use ExUnit.Case, async: true

  import Image.TestSupport

  # The directory of an ICO file: one `{width, height, bits_per_pixel,
  # png}` per entry, with each entry's bytes checked to lie where the
  # directory says.
  defp entries(ico) do
    <<0::little-16, 1::little-16, count::little-16, rest::binary>> = ico

    for index <- 0..(count - 1) do
      <<width, height, 0, 0, 1::little-16, bits::little-16, length::little-32, offset::little-32>> =
        binary_part(rest, index * 16, 16)

      {width, height, bits, binary_part(ico, offset, length)}
    end
  end

  defp decoded_shapes(ico) do
    for {_width, _height, _bits, png} <- entries(ico) do
      png
      |> Image.open!()
      |> Image.shape()
    end
  end

  setup do
    %{kip: Image.open!(image_path("Kip_small.jpg"))}
  end

  describe "Image.to_ico/2" do
    test "writes a PNG entry for each default size", %{kip: kip} do
      {:ok, ico} = Image.to_ico(kip)

      assert [{16, 16, 32, _}, {32, 32, 32, _}, {48, 48, 32, _}] = entries(ico)
      assert decoded_shapes(ico) == [{16, 16, 4}, {32, 32, 4}, {48, 48, 4}]
    end

    test "the entries follow the directory with no gap", %{kip: kip} do
      {:ok, ico} = Image.to_ico(kip, sizes: [16, 32])
      pngs = for {_width, _height, _bits, png} <- entries(ico), do: png

      assert byte_size(ico) == 6 + 16 * 2 + Enum.sum(Enum.map(pngs, &byte_size/1))
    end

    test "a 256 pixel entry is written with a size byte of 0", %{kip: kip} do
      {:ok, ico} = Image.to_ico(kip, sizes: [256])

      assert [{0, 0, 32, _png}] = entries(ico)
      assert decoded_shapes(ico) == [{256, 256, 4}]
    end

    test "sizes are deduplicated and sorted", %{kip: kip} do
      {:ok, ico} = Image.to_ico(kip, sizes: [32, 16, 32])

      assert [{16, 16, 32, _}, {32, 32, 32, _}] = entries(ico)
    end

    test "an image that is not square is fitted and padded with transparency" do
      {:ok, ico} = Image.to_ico(Image.new!(100, 40, color: :blue), sizes: [32])
      [{32, 32, 32, png}] = entries(ico)
      icon = Image.open!(png)

      assert Image.get_pixel!(icon, 0, 0) == [0, 0, 0, 0]
      assert Image.get_pixel!(icon, 16, 16) == [0, 0, 255, 255]
    end

    test "an animated image contributes its first frame" do
      path = image_path("animated.webp")
      {:ok, all_frames} = Image.to_ico(Image.open!(path, pages: :all), sizes: [16])
      {:ok, first_frame} = Image.to_ico(Image.open!(path), sizes: [16])

      assert all_frames == first_frame
    end

    test "a greyscale or 16-bit image is written as 8-bit sRGB with alpha" do
      for image <- [
            Image.new!(20, 20, bands: 1, color: 128),
            Image.to_colorspace!(Image.new!(20, 20), :rgb16)
          ] do
        {:ok, ico} = Image.to_ico(image, sizes: [16])
        [{16, 16, 32, png}] = entries(ico)
        icon = Image.open!(png)

        assert Image.shape(icon) == {16, 16, 4}
        assert Vix.Vips.Image.format(icon) == :VIPS_FORMAT_UCHAR
      end
    end

    test "rejects sizes outside 1..256 and sizes that are not a list", %{kip: kip} do
      for sizes <- [[], [0], [257], [16, "32"], 16, nil] do
        assert {:error, %Image.Error{reason: :invalid_option, value: {:sizes, ^sizes}}} =
                 Image.to_ico(kip, sizes: sizes)
      end
    end

    test "rejects an option other than :sizes", %{kip: kip} do
      assert {:error, %Image.Error{reason: :invalid_option, value: {:quality, 80}}} =
               Image.to_ico(kip, quality: 80)
    end

    test "rejects something that is not an image" do
      assert {:error, %Image.Error{reason: :invalid_image}} = Image.to_ico("not an image")
    end
  end

  describe "Image.to_ico!/2" do
    test "raises on an invalid option", %{kip: kip} do
      assert_raise Image.Error, fn -> Image.to_ico!(kip, sizes: [0]) end
    end
  end

  describe "Image.write/3 with an ICO destination" do
    setup do
      dir = Path.join(System.tmp_dir!(), "image_ico_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)
      %{dir: dir}
    end

    test "writes a path ending in .ico, in either case", %{kip: kip, dir: dir} do
      for name <- ["favicon.ico", "FAVICON.ICO"] do
        path = Path.join(dir, name)

        assert {:ok, ^kip} = Image.write(kip, path, sizes: [16, 32])
        assert decoded_shapes(File.read!(path)) == [{16, 16, 4}, {32, 32, 4}]
      end
    end

    test "writes to memory with suffix: \".ico\"", %{kip: kip} do
      assert {:ok, ico} = Image.write(kip, :memory, suffix: ".ico")
      assert {:ok, ico} == Image.to_ico(kip)
    end

    test "writes to a File.Stream whose path ends in .ico", %{kip: kip, dir: dir} do
      path = Path.join(dir, "streamed.ico")

      assert {:ok, ^kip} = Image.write(kip, File.stream!(path), sizes: [16])
      assert decoded_shapes(File.read!(path)) == [{16, 16, 4}]
    end

    test "rejects options that do not apply to an ICO file", %{kip: kip} do
      assert {:error, %Image.Error{reason: :invalid_option}} =
               Image.write(kip, :memory, suffix: ".ico", quality: 80)
    end

    test "other suffixes are written as before", %{kip: kip} do
      assert {:ok, <<0x89, "PNG", _rest::binary>>} = Image.write(kip, :memory, suffix: ".png")
    end
  end
end
