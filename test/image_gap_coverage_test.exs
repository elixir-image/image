defmodule ImageGapCoverageTest do
  use ExUnit.Case, async: true

  import Image.TestSupport

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Operation

  require Image

  setup_all do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  describe "guards" do
    test "is_image/1" do
      assert Image.is_image(Vix.Vips.Image)
      assert Image.is_image(Vix.Vips.MutableImage)
      refute Image.is_image(Kernel)
    end

    test "is_box/4" do
      assert Image.is_box(0, 0, 10, 10)
      refute Image.is_box(0, 0, 0, 10)
    end

    test "is_rectangle/4" do
      assert Image.is_rectangle({0, 0}, {10, 0}, {10, 10}, {0, 10})
      refute Image.is_rectangle({0, 0}, {10, 1}, {10, 10}, {0, 10})
    end

    test "is_size/1" do
      assert Image.is_size(10)
      refute Image.is_size(0)
    end

    test "is_pixel/1" do
      assert Image.is_pixel(:red)
      assert Image.is_pixel([1, 2, 3])
      refute Image.is_pixel(nil)
    end

    test "is_percent/1, is_positive_percent/1 and is_multiplier/1" do
      assert Image.is_percent(0.5)
      refute Image.is_percent(2.0)
      assert Image.is_positive_percent(0.5)
      refute Image.is_positive_percent(-0.5)
      assert Image.is_multiplier(1.5)
      refute Image.is_multiplier(-1)
    end
  end

  describe "new!/2 and new!/3 error paths" do
    test "new!/2 with an invalid color raises" do
      image = Image.new!(5, 5, color: :white)

      assert_raise Image.Error, fn ->
        Image.new!(image, color: :not_a_color_name)
      end
    end

    test "new!/3 with an invalid color raises" do
      assert_raise Image.Error, fn ->
        Image.new!(5, 5, color: :not_a_color_name)
      end
    end
  end

  describe "open/2 binary signatures" do
    test "opens a GIF89a binary" do
      image = Image.new!(4, 4, color: :red)
      {:ok, binary} = Image.write(image, :memory, suffix: ".gif")
      assert <<"GIF89a", _::binary>> = binary
      assert {:ok, %Vimage{}} = Image.open(binary)
    end

    test "opens a GIF87a binary" do
      image = Image.new!(4, 4, color: :red)
      {:ok, <<"GIF89a", rest::binary>>} = Image.write(image, :memory, suffix: ".gif")
      assert {:ok, %Vimage{}} = Image.open(<<"GIF87a", rest::binary>>)
    end

    test "opens an SVG binary with an <?xml prefix" do
      svg = """
      <?xml version="1.0" encoding="UTF-8"?>
      <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
        <rect width="10" height="10" fill="blue"/>
      </svg>
      """

      assert {:ok, %Vimage{}} = Image.open(svg)
    end

    test "from_svg!/1 returns an image" do
      svg = """
      <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10">
        <rect width="10" height="10" fill="green"/>
      </svg>
      """

      assert %Vimage{} = Image.from_svg!(svg)
    end
  end

  describe "open/2 path handling" do
    test "opens a path with embedded loader options" do
      path = image_path("Kip_small.jpg") <> "[shrink=2]"
      assert {:ok, %Vimage{}} = Image.open(path)
    end

    test "opening a non-image file returns a wrapped error" do
      assert {:error, %Image.Error{}} = Image.open("mix.exs")
    end
  end

  describe "write/3 destinations" do
    test "writes to a File.Stream", %{dir: dir} do
      image = Image.new!(4, 4, color: :blue)
      path = Path.join(dir, "gap_write_stream.png")
      stream = File.stream!(path, 2048)
      assert {:ok, %Vimage{}} = Image.write(image, stream, suffix: ".png")
      assert File.exists?(path)
    end

    test "writing an unsupported band count to a stream returns an error", %{dir: dir} do
      {:ok, image} = Operation.black(4, 4, bands: 5)
      path = Path.join(dir, "gap_write_stream_error.jpg")
      stream = File.stream!(path, 2048)
      assert {:error, _reason} = Image.write(image, stream, suffix: ".jpg")
    end
  end

  describe "stream!/2" do
    test "buffer_size that evenly divides the binary" do
      image = Image.new!(4, 4, color: :red)

      chunks =
        image
        |> Image.stream!(suffix: ".png", buffer_size: 1)
        |> Enum.to_list()

      refute Enum.empty?(chunks)
      assert Enum.all?(chunks, &(byte_size(&1) == 1))
    end
  end

  describe "if_then_else!/4" do
    test "returns an image on success" do
      condition = Image.new!(4, 4, color: [255, 255, 255])
      assert %Vimage{} = Image.if_then_else!(condition, :red, :blue)
    end

    test "raises on an invalid color" do
      condition = Image.new!(4, 4, color: [255, 255, 255])

      assert_raise Image.Error, fn ->
        Image.if_then_else!(condition, :not_a_color_name, :blue)
      end
    end
  end

  describe "mask and blur bang variants" do
    test "chroma_mask!/2 with default options" do
      image = Image.open!(image_path("chroma_key/greenscreen.jpg"))
      assert %Vimage{} = Image.chroma_mask!(image)
    end

    test "blur!/2 with default options" do
      image = Image.new!(8, 8, color: :red)
      assert %Vimage{} = Image.blur!(image)
    end

    test "feather!/2 with default options" do
      image = Image.open!(image_path("dice_transparent.png"))
      assert %Vimage{} = Image.feather!(image)
    end
  end

  describe "compose offsets" do
    test "numeric x with atom y" do
      base = Image.new!(20, 20, color: :white)
      overlay = Image.new!(5, 5, color: :red)
      assert {:ok, %Vimage{}} = Image.compose(base, overlay, x: 2, y: :middle)
    end

    test "atom x with numeric y" do
      base = Image.new!(20, 20, color: :white)
      overlay = Image.new!(5, 5, color: :red)
      assert {:ok, %Vimage{}} = Image.compose(base, overlay, x: :center, y: 2)
    end

    test "invalid offset atom raises ArgumentError" do
      base = Image.new!(20, 20, color: :white)
      overlay = Image.new!(5, 5, color: :red)

      assert_raise ArgumentError, fn ->
        Image.compose(base, overlay, x: :bogus, y: :bogus)
      end
    end
  end

  describe "join!/2" do
    test "joins a list of images" do
      image_1 = Image.new!(5, 5, color: :red)
      image_2 = Image.new!(5, 5, color: :blue)
      assert %Vimage{} = Image.join!([image_1, image_2])
    end

    test "raises on invalid options" do
      image_1 = Image.new!(5, 5, color: :red)
      image_2 = Image.new!(5, 5, color: :blue)

      assert_raise Image.Error, fn ->
        Image.join!([image_1, image_2], across: 0)
      end
    end
  end

  describe "meme text transforms" do
    test "meme!/3 with transform: :capitalize" do
      image = Image.open!(image_path("meme.jpg"))
      assert %Vimage{} = Image.meme!(image, "hello world", transform: :capitalize)
    end

    test "meme!/3 with transform: :downcase" do
      image = Image.open!(image_path("meme.jpg"))
      assert %Vimage{} = Image.meme!(image, "HELLO WORLD", transform: :downcase)
    end
  end

  describe "pixelate/2 and pixelate!/2" do
    test "pixelate/1 with the default scale" do
      image = Image.open!(image_path("Kip_small.jpg"))
      assert {:ok, %Vimage{}} = Image.pixelate(image)
    end

    test "pixelate!/2" do
      image = Image.open!(image_path("Kip_small.jpg"))
      assert %Vimage{} = Image.pixelate!(image)
      assert %Vimage{} = Image.pixelate!(image, 0.1)
    end
  end

  describe "thumbnail!/3 with string dimensions" do
    test "with a WxH string" do
      image = Image.open!(image_path("Kip_small.jpg"))
      thumb = Image.thumbnail!(image, "50x50")
      assert Image.width(thumb) <= 50
    end

    test "with a single dimension string" do
      image = Image.open!(image_path("Kip_small.jpg"))
      assert %Vimage{} = Image.thumbnail!(image, "50")
    end

    test "raises with invalid dimensions" do
      image = Image.open!(image_path("Kip_small.jpg"))

      assert_raise Image.Error, fn ->
        Image.thumbnail!(image, "notxnumbers")
      end
    end
  end

  describe "avatar/2 from a file path" do
    test "avatar/2 with an image path" do
      assert {:ok, %Vimage{} = avatar} = Image.avatar(image_path("Kip_small.jpg"))
      assert Image.width(avatar) == Image.Options.Avatar.default_avatar_size()
    end

    test "avatar!/2 returns an image" do
      image = Image.open!(image_path("Kip_small.jpg"))
      assert %Vimage{} = Image.avatar!(image)
    end

    test "avatar!/2 raises for a missing file" do
      assert_raise Image.Error, fn ->
        Image.avatar!("does/not/exist.jpg")
      end
    end
  end

  describe "crop!/2 with a quadrilateral" do
    test "returns the cropped image" do
      image = Image.new!(20, 20, color: :white)
      cropped = Image.crop!(image, [{0, 0}, {9, 0}, {9, 9}, {0, 9}])
      assert Image.width(cropped) == 10
      assert Image.height(cropped) == 10
    end
  end

  describe "replace_color with default options" do
    test "replace_color/1" do
      image = Image.open!(image_path("chroma_key/greenscreen.jpg"))
      assert {:ok, %Vimage{}} = Image.replace_color(image)
    end

    test "replace_color!/1" do
      image = Image.open!(image_path("chroma_key/greenscreen.jpg"))
      assert %Vimage{} = Image.replace_color!(image)
    end
  end
end
