defmodule Image.GeometryCoverageTest do
  use ExUnit.Case, async: true

  import Image.TestSupport

  alias Vix.Vips.Image, as: Vimage

  describe "resize/3 and resize!/3" do
    test "resizes by a scale factor" do
      image = Image.new!(20, 20, color: :white)

      assert {:ok, resized} = Image.resize(image, 2.0)
      assert Image.width(resized) == 40
      assert Image.height(resized) == 40
    end

    test "downsizes by a scale factor" do
      image = Image.new!(20, 20, color: :white)

      assert {:ok, resized} = Image.resize(image, 0.5)
      assert Image.width(resized) == 10
      assert Image.height(resized) == 10
    end

    test "resizes with a vertical_scale option" do
      image = Image.new!(20, 20, color: :white)

      assert {:ok, resized} = Image.resize(image, 2.0, vertical_scale: 0.5)
      assert Image.width(resized) == 40
      assert Image.height(resized) == 10
    end

    test "resizes an image with an alpha band preserving the band format" do
      image = Image.open!(image_path("penguin_with_alpha.png"))

      assert {:ok, resized} = Image.resize(image, 0.5)
      assert Image.bands(resized) == 4
      assert Image.band_format(resized) == Image.band_format(image)
    end

    test "returns an error for an invalid option" do
      image = Image.new!(20, 20, color: :white)

      assert {:error, %Image.Error{}} = Image.resize(image, 2.0, interpolate: :invalid)
    end

    test "resize!/3 returns an image" do
      image = Image.new!(20, 20, color: :white)

      resized = Image.resize!(image, 2.0)
      assert Image.width(resized) == 40
    end

    test "resize!/3 raises on an invalid option" do
      image = Image.new!(20, 20, color: :white)

      assert_raise Image.Error, fn ->
        Image.resize!(image, 2.0, interpolate: :invalid)
      end
    end
  end

  describe "thumbnail/3 and thumbnail!/3" do
    test "thumbnails an image to a length" do
      image = Image.open!(image_path("Kip_small.jpg"))

      assert {:ok, thumb} = Image.thumbnail(image, 100)
      assert max(Image.width(thumb), Image.height(thumb)) == 100
    end

    test "thumbnails from a file path" do
      assert {:ok, thumb} = Image.thumbnail(image_path("Kip_small.jpg"), 100)
      assert max(Image.width(thumb), Image.height(thumb)) == 100
    end

    test "thumbnails from a non-existent path returns an error" do
      assert {:error, %Image.Error{}} = Image.thumbnail("does/not/exist.jpg", 100)
    end

    test "thumbnails with a dimension string" do
      image = Image.open!(image_path("Kip_small.jpg"))

      assert {:ok, thumb} = Image.thumbnail(image, "50x50", crop: :center)
      assert Image.width(thumb) == 50
      assert Image.height(thumb) == 50
    end

    test "thumbnails with a width-only dimension string" do
      image = Image.open!(image_path("Kip_small.jpg"))

      assert {:ok, thumb} = Image.thumbnail(image, "100")
      assert max(Image.width(thumb), Image.height(thumb)) == 100
    end

    test "thumbnails with an invalid dimension string returns an error" do
      image = Image.open!(image_path("Kip_small.jpg"))

      assert {:error, %Image.Error{}} = Image.thumbnail(image, "not_a_dimension")
    end

    test "thumbnail!/3 returns an image" do
      image = Image.open!(image_path("Kip_small.jpg"))

      thumb = Image.thumbnail!(image, 100)
      assert max(Image.width(thumb), Image.height(thumb)) == 100
    end

    test "thumbnail!/3 from a path returns an image" do
      thumb = Image.thumbnail!(image_path("Kip_small.jpg"), 100)
      assert max(Image.width(thumb), Image.height(thumb)) == 100
    end

    test "thumbnail!/3 raises for a non-existent path" do
      assert_raise Image.Error, fn ->
        Image.thumbnail!("does/not/exist.jpg", 100)
      end
    end

    test "thumbnail!/3 raises for an invalid dimension string" do
      image = Image.open!(image_path("Kip_small.jpg"))

      assert_raise Image.Error, fn ->
        Image.thumbnail!(image, "not_a_dimension")
      end
    end
  end

  describe "crop/5 and crop!/5" do
    setup do
      {:ok, image: Image.new!(100, 100, color: :white)}
    end

    test "crops with absolute offsets", %{image: image} do
      assert {:ok, cropped} = Image.crop(image, 10, 10, 50, 40)
      assert Image.width(cropped) == 50
      assert Image.height(cropped) == 40
    end

    test "crops with negative offsets relative to right and bottom", %{image: image} do
      assert {:ok, cropped} = Image.crop(image, -50, -40, 50, 40)
      assert Image.width(cropped) == 50
      assert Image.height(cropped) == 40
    end

    test "crops with :left, :top", %{image: image} do
      assert {:ok, cropped} = Image.crop(image, :left, :top, 30, 30)
      assert Image.shape(cropped) == {30, 30, 3}
    end

    test "crops with :center, :middle", %{image: image} do
      assert {:ok, cropped} = Image.crop(image, :center, :middle, 30, 30)
      assert Image.shape(cropped) == {30, 30, 3}
    end

    test "crops with :right, :bottom", %{image: image} do
      assert {:ok, cropped} = Image.crop(image, :right, :bottom, 30, 30)
      assert Image.shape(cropped) == {30, 30, 3}
    end

    test "crops with percentage dimensions", %{image: image} do
      assert {:ok, cropped} = Image.crop(image, 0.1, 0.1, 0.5, 0.5)
      assert Image.width(cropped) == 50
      assert Image.height(cropped) == 50
    end

    test "crops with negative float offsets", %{image: image} do
      assert {:ok, cropped} = Image.crop(image, -0.5, -0.5, 0.5, 0.5)
      assert Image.width(cropped) == 50
      assert Image.height(cropped) == 50
    end

    test "returns an error when the crop area is out of bounds", %{image: image} do
      assert {:error, %Image.Error{}} = Image.crop(image, 90, 90, 50, 50)
    end

    test "crop!/5 returns an image", %{image: image} do
      cropped = Image.crop!(image, 0, 0, 10, 10)
      assert Image.shape(cropped) == {10, 10, 3}
    end

    test "crop!/5 raises when the crop area is out of bounds", %{image: image} do
      assert_raise Image.Error, fn ->
        Image.crop!(image, 90, 90, 50, 50)
      end
    end
  end

  describe "crop/2 with a quadrilateral" do
    test "crops to a rectangular bounding box" do
      image = Image.new!(100, 100, color: :white)
      quadrilateral = [{10, 10}, {59, 10}, {59, 39}, {10, 39}]

      assert {:ok, cropped} = Image.crop(image, quadrilateral)
      assert Image.width(cropped) == 50
      assert Image.height(cropped) == 30
    end

    test "returns an error for a non-rectangular quadrilateral" do
      image = Image.new!(100, 100, color: :white)
      quadrilateral = [{10, 10}, {60, 15}, {60, 40}, {10, 45}]

      assert {:error, %Image.Error{}} = Image.crop(image, quadrilateral)
    end

    test "crop!/2 raises for a non-rectangular quadrilateral" do
      image = Image.new!(100, 100, color: :white)
      quadrilateral = [{10, 10}, {60, 15}, {60, 40}, {10, 45}]

      assert_raise Image.Error, fn ->
        Image.crop!(image, quadrilateral)
      end
    end
  end

  describe "center_crop/3 and center_crop!/3" do
    test "crops the center of an image" do
      image = Image.new!(100, 100, color: :white)

      assert {:ok, cropped} = Image.center_crop(image, 40, 20)
      assert Image.shape(cropped) == {40, 20, 3}
    end

    test "returns an error when larger than the image" do
      image = Image.new!(100, 100, color: :white)

      assert {:error, %Image.Error{}} = Image.center_crop(image, 200, 200)
    end

    test "center_crop!/3 returns an image" do
      image = Image.new!(100, 100, color: :white)

      cropped = Image.center_crop!(image, 40, 20)
      assert Image.shape(cropped) == {40, 20, 3}
    end

    test "center_crop!/3 raises when larger than the image" do
      image = Image.new!(100, 100, color: :white)

      assert_raise Image.Error, fn ->
        Image.center_crop!(image, 200, 200)
      end
    end
  end

  describe "flip/2 and flip!/2" do
    setup do
      base = Image.new!(20, 20, color: :white)

      {:ok, marked} =
        Image.mutate(base, fn mutable ->
          {:ok, _} = Image.Draw.rect(mutable, 0, 0, 10, 10, color: :black)
        end)

      {:ok, image: marked}
    end

    test "flips horizontally", %{image: image} do
      assert {:ok, flipped} = Image.flip(image, :horizontal)
      assert Image.get_pixel!(flipped, 15, 5) == [0, 0, 0]
      assert Image.get_pixel!(flipped, 5, 5) == [255, 255, 255]
    end

    test "flips vertically", %{image: image} do
      assert {:ok, flipped} = Image.flip(image, :vertical)
      assert Image.get_pixel!(flipped, 5, 15) == [0, 0, 0]
      assert Image.get_pixel!(flipped, 5, 5) == [255, 255, 255]
    end

    test "returns an error for an invalid direction", %{image: image} do
      assert {:error, %Image.Error{message: message}} = Image.flip(image, :diagonal)
      assert message =~ "Invalid flip direction"
    end

    test "flip!/2 returns an image", %{image: image} do
      assert %Vimage{} = Image.flip!(image, :horizontal)
    end

    test "flip!/2 raises for an invalid direction", %{image: image} do
      # Constructed at runtime so the compiler's type checker does not
      # flag the deliberately invalid direction argument.
      invalid_direction = String.to_atom("diagonal")

      assert_raise Image.Error, fn ->
        Image.flip!(image, invalid_direction)
      end
    end
  end

  describe "rotate/3 and rotate!/3" do
    test "discrete rotation by 90 degrees swaps dimensions" do
      image = Image.new!(20, 40, color: :white)

      assert {:ok, rotated} = Image.rotate(image, 90)
      assert Image.width(rotated) == 40
      assert Image.height(rotated) == 20
    end

    test "rotation by 180 degrees preserves dimensions" do
      image = Image.new!(20, 40, color: :white)

      assert {:ok, rotated} = Image.rotate(image, 180)
      assert Image.width(rotated) == 20
      assert Image.height(rotated) == 40
    end

    test "arbitrary angle rotation enlarges the canvas" do
      image = Image.new!(20, 20, color: :white)

      assert {:ok, rotated} = Image.rotate(image, 45)
      assert Image.width(rotated) > 20
      assert Image.height(rotated) > 20
    end

    test "rotation with a background color" do
      image = Image.new!(20, 20, color: :white)

      assert {:ok, rotated} = Image.rotate(image, 45, background: :red)
      assert Image.get_pixel!(rotated, 0, 0) == [255, 0, 0]
    end

    test "returns an error for an invalid option" do
      image = Image.new!(20, 20, color: :white)

      assert {:error, %Image.Error{}} = Image.rotate(image, 45, interpolate: :invalid)
    end

    test "rotate!/3 returns an image" do
      image = Image.new!(20, 40, color: :white)

      rotated = Image.rotate!(image, 90)
      assert Image.width(rotated) == 40
    end

    test "rotate!/3 raises for an invalid option" do
      image = Image.new!(20, 20, color: :white)

      assert_raise Image.Error, fn ->
        Image.rotate!(image, 45, interpolate: :invalid)
      end
    end
  end

  describe "autorotate/1 and autorotate!/1" do
    test "autorotates an image with EXIF orientation" do
      image = Image.open!(image_path("Kip_small_rotated.jpg"), access: :random)

      assert {:ok, {rotated, flags}} = Image.autorotate(image)
      assert %Vimage{} = rotated
      assert flags[:angle] in [0, 90, 180, 270]
      assert is_boolean(flags[:flip])
    end

    test "autorotate!/1 returns an image" do
      image = Image.open!(image_path("Kip_small_rotated.jpg"), access: :random)

      assert %Vimage{} = Image.autorotate!(image)
    end
  end

  describe "embed/4 and embed!/4" do
    test "embeds an image centered in a larger canvas" do
      image = Image.new!(20, 20, color: :white)

      assert {:ok, embedded} = Image.embed(image, 40, 40)
      assert Image.shape(embedded) == {40, 40, 3}
      # Default background is black
      assert Image.get_pixel!(embedded, 0, 0) == [0, 0, 0]
      # Original image is centered
      assert Image.get_pixel!(embedded, 20, 20) == [255, 255, 255]
    end

    test "embeds with x and y offsets" do
      image = Image.new!(20, 20, color: :white)

      assert {:ok, embedded} = Image.embed(image, 40, 40, x: 0, y: 0)
      assert Image.get_pixel!(embedded, 0, 0) == [255, 255, 255]
      assert Image.get_pixel!(embedded, 30, 30) == [0, 0, 0]
    end

    test "embeds with a background color" do
      image = Image.new!(20, 20, color: :white)

      assert {:ok, embedded} = Image.embed(image, 40, 40, background: :red)
      assert Image.get_pixel!(embedded, 0, 0) == [255, 0, 0]
    end

    test "returns an error for an invalid option" do
      image = Image.new!(20, 20, color: :white)

      assert {:error, %Image.Error{}} = Image.embed(image, 40, 40, x: :invalid_position)
    end

    test "embed!/4 returns an image" do
      image = Image.new!(20, 20, color: :white)

      embedded = Image.embed!(image, 40, 40)
      assert Image.shape(embedded) == {40, 40, 3}
    end

    test "embed!/4 raises for an invalid option" do
      image = Image.new!(20, 20, color: :white)

      assert_raise Image.Error, fn ->
        Image.embed!(image, 40, 40, x: :invalid_position)
      end
    end
  end

  describe "trim/2 and trim!/2" do
    setup do
      inner = Image.new!(20, 20, color: :white)
      {:ok, framed} = Image.embed(inner, 60, 60, background: :black)

      {:ok, image: framed}
    end

    test "trims to the non-background bounding box", %{image: image} do
      assert {:ok, trimmed} = Image.trim(image, background: :black)
      assert Image.width(trimmed) == 20
      assert Image.height(trimmed) == 20
    end

    test "returns an error when there is nothing to trim" do
      flat = Image.new!(30, 30, color: :black)

      assert {:error, %Image.Error{}} = Image.trim(flat, background: :black)
    end

    test "trim!/2 returns an image", %{image: image} do
      trimmed = Image.trim!(image, background: :black)
      assert Image.shape(trimmed) == {20, 20, 3}
    end

    test "trim!/2 raises when there is nothing to trim" do
      flat = Image.new!(30, 30, color: :black)

      assert_raise Image.Error, fn ->
        Image.trim!(flat, background: :black)
      end
    end
  end

  describe "find_trim/2" do
    test "returns the bounding box of the non-background area" do
      inner = Image.new!(20, 20, color: :white)
      {:ok, framed} = Image.embed(inner, 60, 60, background: :black)

      assert {:ok, {left, top, width, height}} = Image.find_trim(framed, background: :black)
      assert left == 20
      assert top == 20
      assert width == 20
      assert height == 20
    end
  end

  describe "split_bands/1 and join_bands/1" do
    test "splits an image into single-band images" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      bands = Image.split_bands(image)

      assert length(bands) == 3
      assert Enum.all?(bands, &(Image.bands(&1) == 1))
      assert Image.get_pixel!(Enum.at(bands, 0), 0, 0) == [10]
      assert Image.get_pixel!(Enum.at(bands, 1), 0, 0) == [20]
      assert Image.get_pixel!(Enum.at(bands, 2), 0, 0) == [30]
    end

    test "join_bands/1 is the inverse of split_bands/1" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      assert {:ok, joined} =
               image
               |> Image.split_bands()
               |> Image.join_bands()

      assert Image.bands(joined) == 3
      assert Image.get_pixel!(joined, 5, 5) == [10, 20, 30]
    end

    test "join_bands/1 returns an error for an empty list" do
      assert {:error, %Image.Error{}} = Image.join_bands([])
    end

    test "join_bands!/1 returns an image" do
      image = Image.new!(10, 10, color: [10, 20, 30])

      joined = Image.join_bands!(Image.split_bands(image))
      assert Image.bands(joined) == 3
    end

    test "join_bands!/1 raises for an empty list" do
      assert_raise Image.Error, fn ->
        Image.join_bands!([])
      end
    end
  end

  describe "crop on multi-page images" do
    test "crops each page of an animated image" do
      {:ok, image} = Image.open(image_path("animated.webp"), pages: :all)
      {:ok, single} = Image.open(image_path("animated.webp"))

      page_width = Image.width(single)
      page_height = Image.height(single)

      assert page_width > 20 and page_height > 20

      assert {:ok, cropped} = Image.crop(image, 0, 0, 20, 20)
      assert Image.width(cropped) == 20
      assert Image.height(cropped) == 20 * 12
    end
  end
end
