defmodule Image.WriteOptionsCoverageTest do
  use ExUnit.Case, async: true

  alias Image.Options.Write

  setup do
    {:ok, image} = Image.new(4, 4, color: :red)
    {:ok, alpha_image} = Image.new(4, 4, color: [255, 0, 0, 255])
    {:ok, image: image, alpha_image: alpha_image}
  end

  describe "minimize_file_size option" do
    test "webp write sets min-size, metadata stripping and mixed encoding", %{image: image} do
      assert {:ok, options} = Write.validate_options(image, "test.webp", minimize_file_size: true)

      assert options[:"min-size"] == true
      assert options[:mixed] == true
      assert options[:keep] == [:VIPS_FOREIGN_KEEP_NONE] or options[:strip] == true
      refute Keyword.has_key?(options, :minimize_file_size)
    end

    test "heif write strips metadata", %{image: image} do
      assert {:ok, options} = Write.validate_options(image, "test.heif", minimize_file_size: true)

      assert options[:keep] == [:VIPS_FOREIGN_KEEP_NONE] or options[:strip] == true
      refute Keyword.has_key?(options, :minimize_file_size)
    end

    test "avif write strips metadata", %{image: image} do
      assert {:ok, options} = Write.validate_options(image, "test.avif", minimize_file_size: true)

      assert options[:keep] == [:VIPS_FOREIGN_KEEP_NONE] or options[:strip] == true
      refute Keyword.has_key?(options, :minimize_file_size)
    end

    test "minimize_file_size: false is accepted and removed for png, jpg and webp", %{
      image: image
    } do
      for suffix <- ["test.png", "test.jpg", "test.webp"] do
        assert {:ok, options} = Write.validate_options(image, suffix, minimize_file_size: false)
        refute Keyword.has_key?(options, :minimize_file_size)
      end
    end

    test "a minimized png actually writes", %{image: image} do
      assert {:ok, binary} =
               Image.write(image, :memory, suffix: ".png", minimize_file_size: true)

      assert is_binary(binary)
    end
  end

  describe "tiff options" do
    test "the :pyramid option is accepted for tiff images", %{image: image} do
      assert {:ok, options} = Write.validate_options(image, "test.tif", pyramid: true)
      assert options[:pyramid] == true
    end

    test "the :pyramid option is rejected for other image types", %{image: image} do
      assert {:error, %Image.Error{reason: :invalid_option}} =
               Write.validate_options(image, "test.png", pyramid: true)
    end
  end

  describe "icc_profile option" do
    test "a known inbuilt profile is accepted", %{image: image} do
      assert {:ok, options} = Write.validate_options(image, "test.jpg", icc_profile: :srgb)
      assert options[:profile] == "srgb"
      refute Keyword.has_key?(options, :icc_profile)
    end

    test "an unknown profile path is rejected", %{image: image} do
      assert {:error, %Image.Error{}} =
               Write.validate_options(image, "test.jpg", icc_profile: "no/such/profile.icc")
    end
  end

  describe "gif options" do
    test "the :interframe_maxerror option is accepted for gif images", %{image: image} do
      assert {:ok, options} =
               Write.validate_options(image, "test.gif", interframe_maxerror: 10)

      assert options[:interframe_maxerror] == 10
    end

    test "an out of range :interframe_maxerror is rejected", %{image: image} do
      assert {:error, %Image.Error{reason: :invalid_option}} =
               Write.validate_options(image, "test.gif", interframe_maxerror: 33)
    end
  end

  describe "lossy option" do
    test "avif maps :lossy to :lossless", %{image: image} do
      assert {:ok, options} = Write.validate_options(image, "test.avif", lossy: true)
      assert options[:lossless] == false

      assert {:ok, options} = Write.validate_options(image, "test.avif", lossy: false)
      assert options[:lossless] == true
    end

    test "png maps :lossy to :palette", %{image: image} do
      assert {:ok, options} = Write.validate_options(image, "test.png", lossy: true)
      assert options[:palette] == true

      assert {:ok, options} = Write.validate_options(image, "test.png", lossy: false)
      assert options[:palette] == false
    end
  end

  describe "effort option" do
    test "heif and avif effort is rebased to 0..9", %{image: image} do
      assert {:ok, options} = Write.validate_options(image, "test.heif", effort: 5)
      assert options[:effort] == 4

      assert {:ok, options} = Write.validate_options(image, "test.avif", effort: 1)
      assert options[:effort] == 0
    end
  end

  describe "heif and avif compression option" do
    test "heif compression atoms map to vips enums", %{image: image} do
      assert {:ok, options} = Write.validate_options(image, "test.heif", compression: :hevc)
      assert options[:compression] == :VIPS_FOREIGN_HEIF_COMPRESSION_HEVC
    end

    test "avif compression atoms map to vips enums", %{image: image} do
      assert {:ok, options} = Write.validate_options(image, "test.avif", compression: :avc)
      assert options[:compression] == :VIPS_FOREIGN_HEIF_COMPRESSION_AVC
    end
  end

  describe "background option" do
    test "background is resolved to a pixel for an image without alpha", %{image: image} do
      assert {:ok, options} = Write.validate_options(image, "test.png", background: :white)
      assert options[:background] == [255, 255, 255]
    end

    test "background has the alpha band stripped for an image with alpha", %{
      alpha_image: alpha_image
    } do
      assert {:ok, options} =
               Write.validate_options(alpha_image, "test.png", background: :white)

      assert options[:background] == [255, 255, 255]
    end

    test "an invalid background is rejected", %{image: image} do
      # The specific resolution error is passed through, carrying the
      # underlying Color error as its reason.
      assert {:error, %Image.Error{message: "Invalid background color" <> _}} =
               Write.validate_options(image, "test.png", background: "no-such-color")
    end

    test "background :average resolves to the image average", %{image: image} do
      assert {:ok, options} = Write.validate_options(image, "test.png", background: :average)
      assert options[:background] == [255, 0, 0]
    end
  end

  describe "image type determination" do
    test "a path without an extension and no :suffix is an error", %{image: image} do
      assert {:error, %Image.Error{}} = Write.validate_options(image, "no_extension", [])
    end

    test "an unknown extension is an error", %{image: image} do
      assert {:error, %Image.Error{}} = Write.validate_options(image, "test.bmp", [])
    end
  end
end
