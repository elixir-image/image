defmodule Image.Options.Geometry.Test do
  use ExUnit.Case, async: true

  import Image.TestSupport

  alias Vix.Vips.Image, as: Vimage

  setup_all do
    {:ok, image: Image.new!(20, 20, color: :red)}
  end

  describe "Image.resize/3 options" do
    test "with default options", %{image: image} do
      assert {:ok, resized} = Image.resize(image, 2.0)
      assert Image.width(resized) == 40
      assert Image.height(resized) == 40
    end

    test "with a valid :center option", %{image: image} do
      assert {:ok, %Vimage{}} = Image.resize(image, 0.5, center: true)
    end

    test "a falsy :center option is normalized", %{image: image} do
      assert {:ok, %Vimage{}} = Image.resize(image, 0.5, center: nil)
    end

    test "with a valid :interpolate kernel", %{image: image} do
      assert {:ok, %Vimage{}} = Image.resize(image, 2.0, interpolate: :cubic)
    end

    test "with a vips-form :interpolate kernel", %{image: image} do
      assert {:ok, %Vimage{}} = Image.resize(image, 2.0, interpolate: :VIPS_KERNEL_LINEAR)
    end

    test "with a valid :vertical_scale", %{image: image} do
      assert {:ok, resized} = Image.resize(image, 2.0, vertical_scale: 0.5)
      assert Image.width(resized) == 40
      assert Image.height(resized) == 10
    end

    test "with an unknown :interpolate kernel", %{image: image} do
      assert {:error, %Image.Error{}} = Image.resize(image, 2.0, interpolate: :bogus)
    end

    test "with an integer :vertical_scale", %{image: image} do
      assert {:error, %Image.Error{}} = Image.resize(image, 2.0, vertical_scale: 1)
    end

    test "with an unknown option", %{image: image} do
      assert {:error, %Image.Error{}} = Image.resize(image, 2.0, scale: 2)
    end
  end

  describe "Image.thumbnail/3 options" do
    test "with default options", %{image: image} do
      assert {:ok, thumb} = Image.thumbnail(image, 10)
      assert Image.width(thumb) == 10
    end

    test "from an image path" do
      # Kip_small.jpg is 300x328 so a length of 50 constrains the height.
      assert {:ok, thumb} = Image.thumbnail(image_path("Kip_small.jpg"), 50)
      assert Image.height(thumb) == 50
      assert Image.width(thumb) <= 50
    end

    test "with dimensions as a string", %{image: image} do
      assert {:ok, %Vimage{}} = Image.thumbnail(image, "10x10")
      assert {:ok, %Vimage{}} = Image.thumbnail(image, "10x")
      assert {:ok, %Vimage{}} = Image.thumbnail(image, "10")
    end

    test "with invalid string dimensions", %{image: image} do
      assert {:error, %Image.Error{message: message}} = Image.thumbnail(image, "axb")
      assert message =~ "Invalid dimensions"
    end

    test "with a valid :autorotate", %{image: image} do
      assert {:ok, %Vimage{}} = Image.thumbnail(image, 10, autorotate: true)
    end

    test "with a valid :linear", %{image: image} do
      assert {:ok, %Vimage{}} = Image.thumbnail(image, 10, linear: true)
    end

    test "with a valid :resize", %{image: image} do
      assert {:ok, %Vimage{}} = Image.thumbnail(image, 10, resize: :down)
      assert {:ok, %Vimage{}} = Image.thumbnail(image, 10, resize: :force)
    end

    test "with a valid :intent", %{image: image} do
      assert {:ok, %Vimage{}} = Image.thumbnail(image, 10, intent: :perceptual)
    end

    test "with a valid :height", %{image: image} do
      assert {:ok, %Vimage{}} = Image.thumbnail(image, 10, height: 8)
    end

    test "with a valid :crop", %{image: image} do
      assert {:ok, %Vimage{}} = Image.thumbnail(image, 10, crop: :center)
      assert {:ok, %Vimage{}} = Image.thumbnail(image, 10, crop: :attention)
    end

    test "with each :fit mode", %{image: image} do
      assert {:ok, %Vimage{}} = Image.thumbnail(image, 10, fit: :fill)
      assert {:ok, %Vimage{}} = Image.thumbnail(image, 10, fit: :contain)
      assert {:ok, %Vimage{}} = Image.thumbnail(image, 10, fit: :cover)
    end

    test "with valid ICC profiles", %{image: image} do
      assert {:ok, %Vimage{}} =
               Image.thumbnail(image, 10, import_icc_profile: :srgb, export_icc_profile: :srgb)
    end

    test "with an invalid :resize", %{image: image} do
      assert {:error, %Image.Error{}} = Image.thumbnail(image, 10, resize: :sideways)
    end

    test "with an invalid :intent", %{image: image} do
      assert {:error, %Image.Error{}} = Image.thumbnail(image, 10, intent: :bogus)
    end

    test "with an invalid :crop", %{image: image} do
      assert {:error, %Image.Error{}} = Image.thumbnail(image, 10, crop: :bogus)
    end

    test "with a zero :height", %{image: image} do
      assert {:error, %Image.Error{}} = Image.thumbnail(image, 10, height: 0)
    end

    test "with a non-boolean :autorotate", %{image: image} do
      assert {:error, %Image.Error{}} = Image.thumbnail(image, 10, autorotate: "yes")
    end

    test "with a non-boolean :linear", %{image: image} do
      assert {:error, %Image.Error{}} = Image.thumbnail(image, 10, linear: 1)
    end

    test "with an unknown import ICC profile", %{image: image} do
      assert {:error, %Image.Error{message: message}} =
               Image.thumbnail(image, 10, import_icc_profile: "bogus.icc")

      assert message =~ "not known"
    end

    test "with an unknown export ICC profile", %{image: image} do
      assert {:error, %Image.Error{message: message}} =
               Image.thumbnail(image, 10, export_icc_profile: "bogus.icc")

      assert message =~ "not known"
    end

    test "with an unknown option", %{image: image} do
      assert {:error, %Image.Error{}} = Image.thumbnail(image, 10, scale: 2)
    end
  end

  describe "Image.crop/5 options" do
    test "with integer coordinates", %{image: image} do
      assert {:ok, cropped} = Image.crop(image, 2, 2, 10, 10)
      assert Image.width(cropped) == 10
      assert Image.height(cropped) == 10
    end

    test "with percentage coordinates", %{image: image} do
      assert {:ok, cropped} = Image.crop(image, 0.25, 0.25, 0.5, 0.5)
      assert Image.width(cropped) == 10
      assert Image.height(cropped) == 10
    end

    test "with symbolic :center and :middle", %{image: image} do
      assert {:ok, cropped} = Image.crop(image, :center, :middle, 10, 10)
      assert Image.width(cropped) == 10
    end

    test "with symbolic :left and :top", %{image: image} do
      assert {:ok, %Vimage{}} = Image.crop(image, :left, :top, 10, 10)
    end

    test "with symbolic :right and :bottom", %{image: image} do
      assert {:ok, %Vimage{}} = Image.crop(image, :right, :bottom, 10, 10)
    end

    test "with negative offsets", %{image: image} do
      assert {:ok, %Vimage{}} = Image.crop(image, -5, -5, 5, 5)
    end

    test "with a crop region larger than the image", %{image: image} do
      assert {:error, %Image.Error{message: message}} = Image.crop(image, 0, 0, 100, 100)
      assert message =~ "larger than the image"
    end

    test "with a zero width", %{image: image} do
      assert {:error, %Image.Error{}} = Image.crop(image, 0, 0, 0, 10)
    end

    test "with an out of range float left", %{image: image} do
      assert {:error, %Image.Error{message: message}} = Image.crop(image, 2.0, 0, 5, 5)
      assert message =~ "left"
    end

    test "with an invalid quadrilateral", %{image: image} do
      assert {:error, %Image.Error{message: message}} =
               Image.crop(image, [{0, 0}, {5, 0}, {5, 5}])

      assert message =~ "Invalid crop bounding box"
    end
  end

  describe "Image.trim/2 options" do
    setup %{image: _image} do
      base = Image.new!(40, 40, color: :white)
      dot = Image.new!(10, 10, color: :black)
      {:ok, composed} = Image.compose(base, dot, x: 15, y: 15)
      {:ok, flattened} = Image.flatten(composed)
      {:ok, trimmable: flattened}
    end

    test "with default options", %{trimmable: trimmable} do
      assert {:ok, trimmed} = Image.trim(trimmable)
      assert Image.width(trimmed) == 10
      assert Image.height(trimmed) == 10
    end

    test "with a named :background color", %{trimmable: trimmable} do
      assert {:ok, trimmed} = Image.trim(trimmable, background: :white)
      assert Image.width(trimmed) == 10
    end

    test "with a numeric :background color", %{trimmable: trimmable} do
      assert {:ok, %Vimage{}} = Image.trim(trimmable, background: [255, 255, 255])
    end

    test "with a valid :threshold", %{trimmable: trimmable} do
      assert {:ok, %Vimage{}} = Image.trim(trimmable, threshold: 20)
    end

    test "with an :alpha background" do
      dice = Image.open!(image_path("dice_transparent.png"))
      assert {:ok, %Vimage{}} = Image.trim(dice, background: :alpha)
    end

    test "with an invalid :background color", %{trimmable: trimmable} do
      assert {:error, %Image.Error{}} = Image.trim(trimmable, background: :not_a_color)
    end

    test "with a zero :threshold", %{trimmable: trimmable} do
      assert {:error, %Image.Error{}} = Image.trim(trimmable, threshold: 0)
    end

    test "with a negative :threshold", %{trimmable: trimmable} do
      assert {:error, %Image.Error{}} = Image.trim(trimmable, threshold: -5)
    end

    test "with an unknown option", %{trimmable: trimmable} do
      assert {:error, %Image.Error{}} = Image.trim(trimmable, tolerance: 5)
    end
  end

  describe "Image.open/2 options" do
    test "with default options" do
      assert {:ok, %Vimage{}} = Image.open(image_path("Kip_small.jpg"))
    end

    test "with :access modes" do
      assert {:ok, %Vimage{}} = Image.open(image_path("Kip_small.jpg"), access: :sequential)
      assert {:ok, %Vimage{}} = Image.open(image_path("Kip_small.jpg"), access: :random)
    end

    test "with a valid :fail_on" do
      assert {:ok, %Vimage{}} = Image.open(image_path("Kip_small.jpg"), fail_on: :error)
      assert {:ok, %Vimage{}} = Image.open(image_path("Kip_small.jpg"), fail_on: :warning)
    end

    test "with a valid :shrink" do
      assert {:ok, image} = Image.open(image_path("Kip_small.jpg"), shrink: 2)
      assert Image.width(image) == 150
    end

    test "with a valid :page on a multi-page image" do
      assert {:ok, %Vimage{}} = Image.open(image_path("animated.webp"), page: 1)
    end

    test "with :pages as :all on a multi-page image" do
      assert {:ok, image} = Image.open(image_path("animated.webp"), pages: :all)
      assert Image.pages(image) > 1
    end

    test "with :pages as an integer" do
      assert {:ok, %Vimage{}} = Image.open(image_path("animated.webp"), pages: 2)
    end

    test "with a valid :scale on a webp image" do
      assert {:ok, %Vimage{}} = Image.open(image_path("animated.webp"), scale: 0.5)
      assert {:ok, %Vimage{}} = Image.open(image_path("animated.webp"), scale: 2)
    end

    test "with an invalid :access" do
      assert {:error, %Image.Error{}} = Image.open(image_path("Kip_small.jpg"), access: :bogus)
    end

    test "with an invalid :fail_on" do
      assert {:error, %Image.Error{}} =
               Image.open(image_path("Kip_small.jpg"), fail_on: :sometimes)
    end

    test "with a negative :page" do
      assert {:error, %Image.Error{}} = Image.open(image_path("animated.webp"), page: -1)
    end

    test "with an invalid :pages" do
      assert {:error, %Image.Error{}} = Image.open(image_path("animated.webp"), pages: 0)
    end

    test "with an out of range :shrink" do
      assert {:error, %Image.Error{}} = Image.open(image_path("Kip_small.jpg"), shrink: 0)
      assert {:error, %Image.Error{}} = Image.open(image_path("Kip_small.jpg"), shrink: 17)
    end

    test "with an invalid :scale" do
      assert {:error, %Image.Error{}} = Image.open(image_path("animated.webp"), scale: 0)
      assert {:error, %Image.Error{}} = Image.open(image_path("animated.webp"), scale: :big)
    end

    test "with the removed :autorotate option" do
      assert {:error, %Image.Error{message: message}} =
               Image.open(image_path("Kip_small.jpg"), autorotate: true)

      assert message =~ "no longer a supported option"
    end

    test "with an unknown option" do
      assert {:error, %Image.Error{}} = Image.open(image_path("Kip_small.jpg"), quality: 80)
    end
  end

  describe "Image.new/3 options" do
    test "with default options" do
      assert {:ok, image} = Image.new(20, 20)
      assert Image.width(image) == 20
      assert Image.bands(image) == 3
    end

    test "with a named :color" do
      assert {:ok, %Vimage{}} = Image.new(20, 20, color: :blue)
    end

    test "with a numeric list :color derives the band count" do
      assert {:ok, image} = Image.new(20, 20, color: [10, 20, 30, 255])
      assert Image.bands(image) == 4
    end

    test "with an integer :color" do
      assert {:ok, %Vimage{}} = Image.new(20, 20, color: 128)
    end

    test "with an explicit :bands" do
      assert {:ok, image} = Image.new(20, 20, bands: 4)
      assert Image.bands(image) == 4
    end

    test "with a valid :format" do
      assert {:ok, %Vimage{}} = Image.new(20, 20, format: {:u, 8})
    end

    test "with a valid :interpretation" do
      assert {:ok, %Vimage{}} = Image.new(20, 20, interpretation: :srgb)
    end

    test "with valid resolution and offset options" do
      assert {:ok, %Vimage{}} =
               Image.new(20, 20, x_res: 72, y_res: 72, x_offset: 1, y_offset: 1)
    end

    test "with an unknown :color name" do
      assert {:error, _reason} = Image.new(20, 20, color: :not_a_color)
    end

    test "with a negative :bands" do
      assert {:error, reason} = Image.new(20, 20, bands: -1)
      assert reason =~ "Invalid option"
    end

    test "with an invalid tuple :format" do
      assert {:error, %Image.Error{}} = Image.new(20, 20, format: {:x, 99})
    end

    test "with an invalid atom :format" do
      assert {:error, %Image.Error{}} = Image.new(20, 20, format: :bogus_format)
    end

    test "with an invalid :interpretation" do
      assert {:error, %Image.Error{}} = Image.new(20, 20, interpretation: :bogus)
    end

    test "with a negative :x_res" do
      assert {:error, reason} = Image.new(20, 20, x_res: -1)
      assert reason =~ "Invalid option"
    end
  end

  describe "Image.join/2 options" do
    setup do
      images = [Image.new!(10, 10, color: :red), Image.new!(10, 10, color: :blue)]
      {:ok, images: images}
    end

    test "with default options", %{images: images} do
      assert {:ok, joined} = Image.join(images)
      assert Image.width(joined) == 10
      assert Image.height(joined) == 20
    end

    test "with a valid :across", %{images: images} do
      assert {:ok, joined} = Image.join(images, across: 2)
      assert Image.width(joined) == 20
      assert Image.height(joined) == 10
    end

    test "with valid spacing options", %{images: images} do
      assert {:ok, %Vimage{}} =
               Image.join(images, across: 2, horizontal_spacing: 15, vertical_spacing: 15)
    end

    test "with a valid :shim", %{images: images} do
      assert {:ok, %Vimage{}} = Image.join(images, shim: 2)
    end

    test "with a valid :background_color", %{images: images} do
      assert {:ok, %Vimage{}} = Image.join(images, background_color: :green, shim: 2)
    end

    test "with valid alignment options", %{images: images} do
      assert {:ok, %Vimage{}} =
               Image.join(images, vertical_align: :middle, horizontal_align: :centre)
    end

    test "with a zero :across", %{images: images} do
      assert {:error, %Image.Error{}} = Image.join(images, across: 0)
    end

    test "with a negative :shim", %{images: images} do
      assert {:error, %Image.Error{}} = Image.join(images, shim: -1)
    end

    test "with an invalid :background_color", %{images: images} do
      assert {:error, %Image.Error{}} = Image.join(images, background_color: :not_a_color)
    end

    test "with a negative :vertical_spacing", %{images: images} do
      assert {:error, %Image.Error{}} = Image.join(images, vertical_spacing: -1)
    end

    test "with a non-integer :horizontal_spacing", %{images: images} do
      assert {:error, %Image.Error{}} = Image.join(images, horizontal_spacing: :big)
    end

    test "with an invalid :vertical_align", %{images: images} do
      assert {:error, %Image.Error{}} = Image.join(images, vertical_align: :diagonal)
    end

    test "with an invalid :horizontal_align", %{images: images} do
      assert {:error, %Image.Error{}} = Image.join(images, horizontal_align: :up)
    end

    test "with an unknown option", %{images: images} do
      assert {:error, %Image.Error{}} = Image.join(images, spacing: 3)
    end

    test "with an empty image list" do
      assert {:error, %Image.Error{message: message}} = Image.join([])
      assert message =~ "empty list"
    end
  end

  describe "Image.compose/3 options" do
    setup do
      base = Image.new!(100, 100, color: :white)
      overlay = Image.new!(20, 20, color: :blue)
      {:ok, base: base, overlay: overlay}
    end

    test "with default options", %{base: base, overlay: overlay} do
      assert {:ok, %Vimage{}} = Image.compose(base, overlay)
    end

    test "with integer offsets", %{base: base, overlay: overlay} do
      assert {:ok, %Vimage{}} = Image.compose(base, overlay, x: 10, y: 10)
    end

    test "with a valid :blend_mode", %{base: base, overlay: overlay} do
      assert {:ok, %Vimage{}} = Image.compose(base, overlay, blend_mode: :over)
    end

    test "with an invalid :blend_mode", %{base: base, overlay: overlay} do
      assert {:error, %Image.Error{message: message}} =
               Image.compose(base, overlay, blend_mode: :bogus)

      assert message =~ "blend mode"
    end

    test "composition list with integer offsets", %{base: base, overlay: overlay} do
      assert {:ok, %Vimage{}} = Image.compose(base, [{overlay, x: 5, y: 5}])
    end

    test "composition list with symbolic positions", %{base: base, overlay: overlay} do
      assert {:ok, %Vimage{}} = Image.compose(base, [{overlay, x: :center, y: :middle}])
      assert {:ok, %Vimage{}} = Image.compose(base, [{overlay, x: :left, y: :top}])
      assert {:ok, %Vimage{}} = Image.compose(base, [{overlay, x: :right, y: :bottom}])
    end

    test "composition list with relative offsets and baselines", %{base: base, overlay: overlay} do
      assert {:ok, %Vimage{}} =
               Image.compose(base, [
                 {overlay, x: 5, y: 5},
                 {overlay, dx: 5, dy: 5, x_baseline: :left, y_baseline: :top}
               ])
    end

    test "composition list with an invalid :x", %{base: base, overlay: overlay} do
      assert {:error, %Image.Error{message: message}} =
               Image.compose(base, [{overlay, x: :bogus, y: 10}])

      assert message =~ "Invalid value for :x"
    end

    test "composition list with an invalid :y", %{base: base, overlay: overlay} do
      assert {:error, %Image.Error{message: message}} =
               Image.compose(base, [{overlay, x: 10, y: :bogus}])

      assert message =~ "Invalid value for :y"
    end
  end

  describe "Image.chroma_key/2 options" do
    setup do
      {:ok, green: Image.new!(20, 20, color: :green)}
    end

    test "with default options", %{green: green} do
      assert {:ok, keyed} = Image.chroma_key(green)
      assert Image.has_alpha?(keyed)
    end

    test "with a named :color and :threshold", %{green: green} do
      assert {:ok, %Vimage{}} = Image.chroma_key(green, color: :green, threshold: 30)
    end

    test "with a numeric :color", %{green: green} do
      assert {:ok, %Vimage{}} = Image.chroma_key(green, color: [0, 255, 0])
    end

    test "with :greater_than and :less_than", %{green: green} do
      assert {:ok, %Vimage{}} =
               Image.chroma_key(green,
                 greater_than: [0, 180, 0],
                 less_than: [100, 255, 100]
               )
    end

    test "with an invalid :color", %{green: green} do
      assert {:error, %Image.Error{}} = Image.chroma_key(green, color: :not_a_color)
    end

    test "with an invalid :greater_than", %{green: green} do
      assert {:error, %Image.Error{}} =
               Image.chroma_key(green, greater_than: :not_a_color, less_than: [1, 1, 1])
    end

    test "with a negative :threshold", %{green: green} do
      assert {:error, %Image.Error{}} = Image.chroma_key(green, threshold: -1)
    end

    test "with a float :threshold", %{green: green} do
      assert {:error, %Image.Error{}} = Image.chroma_key(green, threshold: 1.5)
    end

    test "with a zero :sigma", %{green: green} do
      assert {:error, %Image.Error{}} = Image.chroma_key(green, sigma: 0)
    end

    test "with an integer :min_amplitude", %{green: green} do
      assert {:error, %Image.Error{}} = Image.chroma_key(green, min_amplitude: 1)
    end

    test "with an unknown option", %{green: green} do
      assert {:error, %Image.Error{}} = Image.chroma_key(green, feather: 2)
    end
  end
end
