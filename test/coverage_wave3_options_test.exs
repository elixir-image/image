defmodule Image.CoverageWave3.Options.Test do
  use ExUnit.Case, async: true

  import Image.TestSupport

  defp rgb(size \\ 20), do: Image.new!(size, size, color: [10, 20, 30])
  defp rgba(size \\ 20), do: Image.new!(size, size, color: [10, 20, 30, 255])

  describe "Image.Options.WarpPerspective" do
    test "an unknown option returns an error" do
      from = [{10, 10}, {90, 12}, {88, 90}, {12, 88}]
      to = [{0, 0}, {100, 0}, {100, 100}, {0, 100}]

      assert {:error, %Image.Error{}} =
               Image.warp_perspective(rgb(100), from, to, bogus: 1)
    end

    test "an invalid background color returns an error" do
      from = [{10, 10}, {90, 12}, {88, 90}, {12, 88}]
      to = [{0, 0}, {100, 0}, {100, 100}, {0, 100}]

      assert {:error, _} =
               Image.warp_perspective(rgb(100), from, to, background_color: :not_a_color)
    end

    test ":extend defaults to background and :extend_mode is renamed for libvips" do
      assert {:ok, options} = Image.Options.WarpPerspective.validate_options(rgb(100), [])
      assert Keyword.get(options, :extend) == :VIPS_EXTEND_BACKGROUND
      refute Keyword.has_key?(options, :extend_mode)

      assert {:ok, options} =
               Image.Options.WarpPerspective.validate_options(rgb(100), extend_mode: :copy)

      assert Keyword.get(options, :extend) == :VIPS_EXTEND_COPY
      refute Keyword.has_key?(options, :extend_mode)
    end

    test "only :background and :copy are valid extend modes" do
      for extend_mode <- [:repeat, :mirror, :black, :white] do
        assert {:error, %Image.Error{reason: :invalid_option}} =
                 Image.Options.WarpPerspective.validate_options(rgb(100), extend_mode: extend_mode)
      end
    end
  end

  describe "Image.Options.Compose function-valued offsets" do
    test "a function-valued :x and :y are evaluated" do
      base = Image.new!(50, 50, color: :white)
      overlay = Image.new!(10, 10, color: :red)

      x_fun = fn _image, prev_x, _prev_width, _x, _dx, _baseline -> prev_x + 5 end
      y_fun = fn _image, prev_y, _prev_height, _y, _dy, _baseline -> prev_y + 5 end

      assert {:ok, %Vix.Vips.Image{}} =
               Image.compose(base, [{overlay, x: x_fun, y: y_fun}])
    end

    test "a function-valued :dx and :dy are evaluated" do
      base = Image.new!(50, 50, color: :white)
      overlay = Image.new!(10, 10, color: :red)

      dx_fun = fn _image, _prev_x, _prev_width, _x, _dx, _baseline -> 2 end
      dy_fun = fn _image, _prev_y, _prev_height, _y, _dy, _baseline -> 2 end

      assert {:ok, %Vix.Vips.Image{}} =
               Image.compose(base, [{overlay, x: 1, y: 1, dx: dx_fun, dy: dy_fun}])
    end

    test "a nil :x with an :x_baseline of :right" do
      base = Image.new!(50, 50, color: :white)
      overlay = Image.new!(10, 10, color: :red)

      assert {:ok, %Vix.Vips.Image{}} =
               Image.compose(base, [{overlay, x: nil, y: 1, x_baseline: :right}])
    end
  end

  describe "Image.Options.Blurhash" do
    test "an unknown option returns an error" do
      assert {:error, %Image.Error{}} = Image.Blurhash.encode(rgb(), bogus: 1)
    end

    test "encoding a non-3-band image returns an error" do
      grey = Image.to_colorspace!(rgb(), :bw)
      assert {:error, _} = Image.Blurhash.encode(grey)
    end
  end

  describe "Image.Options.Compare" do
    test "an unknown option returns an error" do
      assert {:error, %Image.Error{}} = Image.compare(rgb(), rgb(), bogus: 1)
    end

    test "an invalid difference color returns an error" do
      assert {:error, %Image.Error{}} =
               Image.compare(rgb(), rgb(), difference_color: :not_a_color)
    end
  end

  describe "Image.Options.Avatar" do
    test "an unknown option returns an error" do
      assert {:error, %Image.Error{}} = Image.avatar(rgb(100), bogus: 1)
    end

    test "an invalid size propagates the error" do
      assert {:error, _} = Image.avatar(rgb(100), size: -1)
    end
  end

  describe "Image.Options.Crop normalize_dims" do
    alias Image.Options.Crop

    test "percent width and height are scaled to pixels" do
      assert Crop.normalize_dims({100, 100}, 0.5, 0.5) == {50, 50}
      assert Crop.normalize_dims({100, 100}, 0.5, 50) == {50, 50}
      assert Crop.normalize_dims({100, 100}, 50, 0.5) == {50, 50}
    end

    test "invalid dimensions return errors" do
      assert {:error, %Image.Error{}} = Crop.normalize_dims({100, 100}, :bogus, 50)
      assert {:error, %Image.Error{}} = Crop.normalize_dims({100, 100}, 50, :bogus)
      assert {:error, %Image.Error{}} = Crop.normalize_dims({100, 100}, -5, -5)
    end

    test "normalize_box rejects invalid top and generic invalid combinations" do
      assert {:error, %Image.Error{}} = Crop.normalize_box({100, 100}, 0, :bogus, 10, 10)
      assert {:error, %Image.Error{}} = Crop.normalize_box({100, 100}, :bogus, :bogus, :x, :y)
    end

    test "validate_options passes unknown options through" do
      assert {:ok, []} = Crop.validate_options([])
      assert {:ok, [crop: :bogus]} = Crop.validate_options(crop: :bogus)
    end
  end

  describe "Image.Options.Embed" do
    alias Image.Options.Embed

    test "map options pass through validate_options" do
      assert {:ok, %{extend_mode: :VIPS_EXTEND_BLACK}} =
               Embed.validate_options(rgb(), 40, 40, %{extend_mode: :VIPS_EXTEND_BLACK})
    end

    test "the default is a background extend with no injected background" do
      # With no :background passed, libvips fills with its native all-zeros
      # pixel: transparent on this alpha image.
      assert {:ok, %{extend_mode: :VIPS_EXTEND_BACKGROUND} = options} =
               Embed.validate_options(rgba(), 40, 40, [])

      refute Map.has_key?(options, :background)
    end

    test "an explicit :background combined with a content extend_mode is an error" do
      # A content mode consumes no color, so the combination is contradictory
      # rather than one option silently winning.
      assert {:error, %Image.Error{reason: :invalid_option, message: message}} =
               Embed.validate_options(rgba(), 40, 40, background: :red, extend_mode: :copy)

      assert message =~ "cannot be combined with an explicit :background"
    end

    test "a geometric extend_mode is honored when no :background is given" do
      assert {:ok, %{extend_mode: :VIPS_EXTEND_COPY}} =
               Embed.validate_options(rgba(), 40, 40, extend_mode: :copy)
    end

    test "extend_mode: :background explicitly selects the color fill" do
      assert {:ok, %{extend_mode: :VIPS_EXTEND_BACKGROUND, background: [255, 0, 0, 255]}} =
               Embed.validate_options(rgba(), 40, 40, extend_mode: :background, background: :red)
    end

    test "extend_mode: :background with no color uses the native fill" do
      assert {:ok, %{extend_mode: :VIPS_EXTEND_BACKGROUND} = options} =
               Embed.validate_options(rgba(), 40, 40, extend_mode: :background)

      refute Map.has_key?(options, :background)
    end

    test ":background nil is treated as unset and does not override a content extend mode" do
      assert {:ok, %{extend_mode: :VIPS_EXTEND_COPY}} =
               Embed.validate_options(rgba(), 40, 40, background: nil, extend_mode: :copy)
    end

    test ":average background color on an alpha image" do
      assert {:ok, embedded} = Image.embed(rgba(), 40, 40, background: :average)
      assert Image.shape(embedded) == {40, 40, 4}
    end

    test ":average background color on an rgb image" do
      assert {:ok, embedded} = Image.embed(rgb(), 40, 40, background: :average)
      assert Image.get_pixel!(embedded, 0, 0) == [10, 20, 30]
    end

    test "negative offsets are normalized from the far edge" do
      assert {:ok, embedded} = Image.embed(rgb(), 40, 40, x: -1, y: -1)
      assert Image.shape(embedded) == {40, 40, 3}
    end

    test "invalid offsets return errors" do
      assert {:error, %Image.Error{}} = Image.embed(rgb(), 40, 40, x: :bogus)
    end
  end

  describe "Image.Options.Text uncovered options" do
    test "integer x and y positions validate" do
      assert {:ok, options} = Image.Options.Text.validate_options(x: 3, y: 4)
      assert options.x == 3
      assert options.y == 4
    end

    test "out-of-bounds x and y return an error struct" do
      assert {:error, %Image.Error{message: message}} =
               Image.Text.text("hello world", x: 90, y: 4, width: 100, height: 50)

      assert message =~ "outside the image bounds"
    end

    test "explicit nil width and height" do
      assert {:ok, _} = Image.Text.text("hi", width: nil, height: nil)
    end

    test "integer font weight and dpi" do
      assert {:ok, _} = Image.Text.text("hi", font_weight: 700, dpi: 100)
    end

    test "deprecated :font_file key is renamed and nil is removed" do
      assert {:ok, _} = Image.Text.text("hi", font_file: nil)
    end

    test ":fontfile as a binary is accepted" do
      # The font file does not need to exist for option validation;
      # pango falls back to the default font.
      assert {:ok, options} = Image.Options.Text.validate_options(fontfile: "/no/such/font.ttf")
      assert options.fontfile == "/no/such/font.ttf"
    end

    test "align :right, :center and raw vips atoms" do
      assert {:ok, _} = Image.Text.text("hi", align: :right, width: 100)
      assert {:ok, _} = Image.Text.text("hi", align: :center, width: 100)
      assert {:ok, _} = Image.Text.text("hi", align: :VIPS_ALIGN_LOW, width: 100)
    end

    test "transparent text applies the default black background" do
      assert {:ok, options} =
               Image.Options.Text.validate_options(text_fill_color: :transparent)

      assert options.background_fill_color == "black"
    end

    test "height without width is an error" do
      assert {:error, _} = Image.Options.Text.validate_options(height: 50, width: nil)
    end
  end

  describe "Image.Options.Vibrance" do
    test "default_vibrance_threshold/0" do
      assert Image.Options.Vibrance.default_vibrance_threshold() == 60
    end

    test "map options pass through validate_options" do
      assert {:ok, %{threshold: 50}} = Image.Options.Vibrance.validate_options(%{threshold: 50})
    end
  end

  describe "Image.Options.Trim and ChromaKey passthrough clauses" do
    test "trim map options pass through" do
      assert {:ok, %{background: [0, 0, 0]}} =
               Image.Options.Trim.validate_options(rgb(), %{background: [0, 0, 0], threshold: 10})
    end

    test "trim with :alpha background option" do
      assert {:ok, _} = Image.Options.Trim.validate_options(rgba(), background: :alpha)
    end

    test "trim with an explicit background on an alpha image strips the alpha band" do
      canvas = Image.new!(30, 30, color: [255, 0, 0, 255])
      assert {:ok, options} = Image.Options.Trim.validate_options(canvas, background: :red)
      assert options.background == [255, 0, 0]
    end

    test "chroma_key map options pass through" do
      assert {:ok, %{color: [0, 255, 0]}} =
               Image.Options.ChromaKey.validate_options(rgb(), %{color: [0, 255, 0], threshold: 20})
    end

    test "chroma_key :sigma and :min_amplitude options" do
      green = Image.new!(20, 20, color: [0, 255, 0])
      assert {:ok, _} = Image.chroma_key(green, sigma: 2.0, min_amplitude: 0.05)
    end
  end

  describe "Image.Options.New" do
    test "a hex color is converted via to_srgb" do
      assert {:ok, image} = Image.new(4, 4, color: "#ff0000")
      assert Image.get_pixel!(image, 0, 0) == [255, 0, 0]
    end

    test "a format option is validated" do
      assert {:ok, image} = Image.new(4, 4, format: {:u, 16})
      assert Image.band_format(image) == {:u, 16}
    end

    test "an invalid color list returns an error" do
      assert {:error, _} = Image.new(4, 4, color: ["not", "numbers", "here"])
    end
  end

  describe "Image.Scholar gaps" do
    test "unique_colors on a 2-band image returns an error" do
      grey_alpha =
        Image.new!(4, 4, color: 128)
        |> Image.to_colorspace!(:bw)
        |> Image.add_alpha!(:opaque)

      assert {:error, %Image.Error{message: message}} =
               Image.Scholar.unique_colors(grey_alpha)

      assert message =~ "3- or 4-band"
    end

    test "unique_colors on a 4-band image uses the 4-band codec" do
      assert {:ok, {counts, colors}} = Image.Scholar.unique_colors(rgba(4))
      assert Nx.to_flat_list(counts) == [16]
      assert Nx.to_list(colors) == [[10, 20, 30, 255]]
    end

    test "k_means with default options" do
      assert {:ok, _colors} = Image.k_means(rgb(4))
    end
  end

  describe "Image.Palette gaps" do
    test "extract with default options" do
      {:ok, image} = Image.open(image_path("Hong-Kong-2015-07-1998.jpg"))
      assert {:ok, palette} = Image.Palette.extract(image)
      refute Enum.empty?(palette)
    end

    test "extract! with default options" do
      {:ok, image} = Image.open(image_path("Hong-Kong-2015-07-1998.jpg"))
      assert is_list(Image.Palette.extract!(image))
    end

    test "extract! raises on invalid options" do
      assert_raise Image.Error, fn ->
        Image.Palette.extract!(rgb(), k: 0)
      end
    end

    test "sort: nil returns unsorted swatches" do
      {:ok, palette} = Image.Palette.extract(rgb(), sort: nil, key: Nx.Random.key(1))
      refute Enum.empty?(palette)
    end

    test "an invalid option returns an error" do
      assert {:error, %Image.Error{message: message}} = Image.Palette.extract(rgb(), final: 0)
      assert message =~ ":final"
    end

    test "a 4-band image with some transparent pixels extracts from opaque pixels" do
      transparent = Image.new!(20, 20, color: [255, 0, 0, 0])
      opaque = Image.new!(10, 10, color: [0, 0, 255, 255])
      {:ok, composed} = Image.compose(transparent, opaque, x: 0, y: 0)

      assert {:ok, palette} = Image.Palette.extract(composed, key: Nx.Random.key(1))
      refute Enum.empty?(palette)
    end

    test "a 16-bit image is converted to u8 before clustering" do
      rgb16 = Image.to_colorspace!(rgb(), :rgb16)
      assert {:ok, palette} = Image.Palette.extract(rgb16, key: Nx.Random.key(1))
      refute Enum.empty?(palette)
    end

    test "an image larger than :max_pixels is subsampled" do
      {:ok, image} = Image.open(image_path("Hong-Kong-2015-07-1998.jpg"))

      assert {:ok, palette} =
               Image.Palette.extract(image, max_pixels: 500, key: Nx.Random.key(1))

      refute Enum.empty?(palette)
    end
  end
end
