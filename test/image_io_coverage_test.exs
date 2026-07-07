defmodule Image.IoCoverageTest do
  use ExUnit.Case, async: true

  import Image.TestSupport
  alias Vix.Vips.Image, as: Vimage

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  describe "Image.open/2 from binaries" do
    test "opens a JPEG binary" do
      binary = File.read!(image_path("Kip_small.jpg"))
      assert {:ok, %Vimage{}} = Image.open(binary)
    end

    test "opens a PNG binary" do
      binary = File.read!(image_path("penguin_with_alpha.png"))
      assert {:ok, %Vimage{} = image} = Image.open(binary)
      assert Image.has_alpha?(image)
    end

    test "opens a WEBP binary" do
      binary = File.read!(image_path("animated.webp"))
      assert {:ok, %Vimage{}} = Image.open(binary)
    end

    test "opens a GIF binary" do
      binary = File.read!(image_path("animated.gif"))
      assert {:ok, %Vimage{}} = Image.open(binary)
    end

    test "opens a TIFF binary" do
      binary = File.read!(image_path("video_image.tif"))
      assert {:ok, %Vimage{}} = Image.open(binary)
    end

    test "opens an SVG binary" do
      svg = "<svg width=\"10\" height=\"10\"><rect width=\"10\" height=\"10\"/></svg>"
      assert {:ok, %Vimage{} = image} = Image.open(svg)
      assert Image.width(image) == 10
    end
  end

  describe "Image.open/2 from paths and streams" do
    test "opens a path with options" do
      assert {:ok, %Vimage{}} = Image.open(image_path("Kip_small.jpg"), access: :sequential)
    end

    test "returns an error for a non-existent path" do
      assert {:error, %Image.Error{reason: :enoent}} = Image.open("no/such/image.jpg")
    end

    test "open!/2 raises for a non-existent path" do
      assert_raise Image.Error, fn ->
        Image.open!("no/such/image.jpg")
      end
    end

    test "returns an error for invalid open options" do
      assert {:error, _reason} = Image.open(image_path("Kip_small.jpg"), access: :bogus)
    end

    test "opens a File.Stream created with a byte size" do
      assert {:ok, %Vimage{}} =
               image_path("Kip_small.jpg")
               |> File.stream!(2048)
               |> Image.open()
    end

    test "returns an error for a line-based File.Stream" do
      assert {:error, %Image.Error{message: message}} =
               image_path("Kip_small.jpg")
               |> File.stream!()
               |> Image.open()

      assert message =~ "must specify the number of bytes"
    end

    test "opens a plain enumerable stream" do
      stream =
        image_path("Kip_small.jpg")
        |> File.stream!(2048)
        |> Stream.map(& &1)

      assert {:ok, %Vimage{}} = Image.open(stream)
    end
  end

  describe "Image.from_binary/2 and from_svg/2" do
    test "from_binary/2 returns an image for valid image data" do
      binary = File.read!(image_path("Kip_small.jpg"))
      assert {:ok, %Vimage{}} = Image.from_binary(binary)
    end

    test "from_binary/2 returns an error for garbage data" do
      assert {:error, _reason} = Image.from_binary(<<1, 2, 3, 4>>)
    end

    test "from_binary!/2 returns an image" do
      binary = File.read!(image_path("penguin_with_alpha.png"))
      assert %Vimage{} = Image.from_binary!(binary)
    end

    test "from_binary!/2 raises for garbage data" do
      assert_raise Image.Error, fn ->
        Image.from_binary!(<<1, 2, 3, 4>>)
      end
    end

    test "from_svg/2 returns an image for a valid SVG string" do
      svg = "<svg width=\"12\" height=\"8\"><rect width=\"12\" height=\"8\"/></svg>"
      assert {:ok, %Vimage{} = image} = Image.from_svg(svg)
      assert Image.shape(image) == {12, 8, 4}
    end

    test "from_svg/2 returns an error for invalid SVG" do
      assert {:error, _reason} = Image.from_svg("this is not svg")
    end

    test "from_svg!/2 raises for invalid SVG" do
      assert_raise Image.Error, fn ->
        Image.from_svg!("this is not svg")
      end
    end
  end

  describe "Image.new/2 and Image.new/3" do
    test "creates a black image of the requested dimensions" do
      assert {:ok, %Vimage{} = image} = Image.new(10, 12)
      assert Image.shape(image) == {10, 12, 3}
      assert Image.get_pixel!(image, 5, 5) == [0, 0, 0]
    end

    test "creates an image with a named color" do
      assert {:ok, %Vimage{} = image} = Image.new(10, 10, color: :misty_rose)
      assert Image.get_pixel!(image, 5, 5) == [255, 228, 225]
    end

    test "creates an image with the requested bands" do
      assert {:ok, %Vimage{} = image} = Image.new(10, 10, color: [0, 255, 0, 255], bands: 4)
      assert Image.shape(image) == {10, 10, 4}
    end

    test "creates an image with a requested format" do
      assert {:ok, %Vimage{} = image} = Image.new(4, 4, format: {:f, 32})
      assert Image.band_format(image) == {:f, 32}
    end

    test "returns an error for an unknown color" do
      assert {:error, _reason} = Image.new(10, 10, color: :bogus_color)
    end

    test "new/1 creates a same-shaped black image from another image" do
      base = Image.new!(8, 9, color: :red, bands: 3)
      assert {:ok, %Vimage{} = image} = Image.new(base)
      assert Image.shape(image) == {8, 9, 3}
      assert Image.get_pixel!(image, 4, 4) == [0, 0, 0]
    end

    test "new/2 creates a same-shaped image with a color from another image" do
      base = Image.new!(8, 9)
      assert {:ok, %Vimage{} = image} = Image.new(base, color: :blue)
      assert Image.get_pixel!(image, 4, 4) == [0, 0, 255]
    end

    test "new!/1, new!/2 and new!/3 return images" do
      base = Image.new!(5, 5)
      assert %Vimage{} = Image.new!(base)
      assert %Vimage{} = Image.new!(base, color: :green)
      assert %Vimage{} = Image.new!(5, 5, color: :green)
    end
  end

  describe "Image.write/3 to paths" do
    setup do
      image = Image.open!(image_path("Kip_small.jpg"))
      {:ok, %{image: image}}
    end

    test "writes a jpeg with quality options", %{image: image, dir: dir} do
      path = Temp.path!(suffix: ".jpg", basedir: dir)

      assert {:ok, %Vimage{}} =
               Image.write(image, path, quality: 60, progressive: true, strip_metadata: true)

      assert File.exists?(path)
      assert {:ok, %Vimage{}} = Image.open(path)
    end

    test "writes a png with compression and effort options", %{image: image, dir: dir} do
      path = Temp.path!(suffix: ".png", basedir: dir)

      assert {:ok, %Vimage{}} = Image.write(image, path, compression: 9, effort: 3)
      assert File.exists?(path)
    end

    test "writes a webp with quality and effort options", %{image: image, dir: dir} do
      path = Temp.path!(suffix: ".webp", basedir: dir)

      assert {:ok, %Vimage{}} = Image.write(image, path, quality: 50, effort: 2)
      assert {:ok, %Vimage{}} = Image.open(path)
    end

    test "merges image-type grouped options", %{image: image, dir: dir} do
      path = Temp.path!(suffix: ".jpg", basedir: dir)

      assert {:ok, %Vimage{}} =
               Image.write(image, path, jpg: [quality: 40], png: [compression: 2])

      assert File.exists?(path)
    end

    test "returns an error for an unknown suffix", %{image: image, dir: dir} do
      path = Temp.path!(suffix: ".bogus", basedir: dir)

      assert {:error, %Image.Error{message: "Unknown image type \".bogus\""}} =
               Image.write(image, path)
    end

    test "returns an error for invalid write options", %{image: image, dir: dir} do
      path = Temp.path!(suffix: ".jpg", basedir: dir)
      assert {:error, _reason} = Image.write(image, path, quality: "high")
    end

    test "write!/3 returns the image", %{image: image, dir: dir} do
      path = Temp.path!(suffix: ".png", basedir: dir)
      assert %Vimage{} = Image.write!(image, path)
    end

    test "write!/3 raises for an unknown suffix", %{image: image, dir: dir} do
      path = Temp.path!(suffix: ".bogus", basedir: dir)

      assert_raise Image.Error, fn ->
        Image.write!(image, path)
      end
    end
  end

  describe "Image.write/3 to memory and streams" do
    setup do
      image = Image.open!(image_path("Kip_small.jpg"))
      {:ok, %{image: image}}
    end

    test "writes a jpeg to memory", %{image: image} do
      assert {:ok, <<0xFF, 0xD8, 0xFF, _::binary>>} =
               Image.write(image, :memory, suffix: ".jpg", quality: 50)
    end

    test "writes a png to memory", %{image: image} do
      assert {:ok, <<0x89, "PNG", _::binary>>} = Image.write(image, :memory, suffix: ".png")
    end

    test "writing to memory requires a suffix", %{image: image} do
      assert {:error, %Image.Error{message: message}} = Image.write(image, :memory, [])
      assert message =~ ":suffix must be provided"
    end

    test "writes to a File.Stream", %{image: image, dir: dir} do
      path = Temp.path!(suffix: ".png", basedir: dir)
      stream = File.stream!(path, 2048)

      assert {:ok, %Vimage{}} = Image.write(image, stream, suffix: ".png")
      assert {:ok, %Vimage{}} = Image.open(path)
    end

    test "writing to a stream with a path extension infers the suffix", %{
      image: image,
      dir: dir
    } do
      path = Temp.path!(suffix: ".png", basedir: dir)
      stream = File.stream!(path, 2048)

      assert {:ok, %Vimage{}} = Image.write(image, stream, [])
    end

    test "writing to an extensionless stream requires a suffix", %{image: image, dir: dir} do
      path = Temp.path!(basedir: dir)
      stream = File.stream!(path, 2048)

      assert {:error, %Image.Error{}} = Image.write(image, stream, [])
    end
  end

  describe "Image.stream!/2" do
    setup do
      image = Image.open!(image_path("Kip_small.jpg"))
      {:ok, %{image: image}}
    end

    test "streams an image as an enumerable", %{image: image} do
      binary =
        image
        |> Image.stream!(suffix: ".jpg")
        |> Enum.into(<<>>)

      assert <<0xFF, 0xD8, 0xFF, _::binary>> = binary
      assert {:ok, %Vimage{}} = Image.from_binary(binary)
    end

    # Note that :buffer_size must be larger than the natural chunk
    # size emitted by libvips (64KiB). Values smaller than the natural
    # chunk size raise a MatchError in Image.buffer!/2.
    test "rebuffers the stream into :buffer_size chunks" do
      buffer_size = 100_000
      image = Image.open!(image_path("Singapore-2016-09-5887.jpg"))

      chunks =
        image
        |> Image.stream!(suffix: ".jpg", quality: 95, buffer_size: buffer_size)
        |> Enum.to_list()

      assert length(chunks) > 1
      {all_but_last, [last]} = Enum.split(chunks, -1)

      for chunk <- all_but_last do
        assert byte_size(chunk) == buffer_size
      end

      assert byte_size(last) <= buffer_size
      assert {:ok, %Vimage{}} = Image.from_binary(IO.iodata_to_binary(chunks))
    end

    test "raises when no suffix is provided", %{image: image} do
      assert_raise Image.Error, fn ->
        Image.stream!(image, [])
      end
    end
  end
end
