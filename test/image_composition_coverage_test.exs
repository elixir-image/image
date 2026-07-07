defmodule Image.CompositionCoverageTest do
  use ExUnit.Case, async: true

  import Image.TestSupport
  alias Vix.Vips.Image, as: Vimage

  # A green base with a red square composed at (15, 15) gives a
  # scene with a known chroma (green) background and a known
  # foreground color for chroma and replacement tests.
  defp scene do
    base = Image.new!(40, 40, color: :green)
    foreground = Image.new!(10, 10, color: :red)

    base
    |> Image.compose!(foreground, x: 15, y: 15)
    |> Image.flatten!()
  end

  describe "Image.compose/3 with a single overlay" do
    setup do
      base = Image.new!(40, 40, color: :green)
      overlay = Image.new!(10, 10, color: :red)
      {:ok, %{base: base, overlay: overlay}}
    end

    test "composes at integer offsets", %{base: base, overlay: overlay} do
      assert {:ok, composed} = Image.compose(base, overlay, x: 15, y: 15)
      assert Image.get_pixel!(composed, 20, 20) == [255, 0, 0, 255]
      assert Image.get_pixel!(composed, 0, 0) == [0, 128, 0, 255]
    end

    test "composes with keyword positions", %{base: base, overlay: overlay} do
      assert {:ok, composed} = Image.compose(base, overlay, x: :left, y: :top)
      assert Image.get_pixel!(composed, 0, 0) == [255, 0, 0, 255]

      assert {:ok, composed} = Image.compose(base, overlay, x: :right, y: :bottom)
      assert Image.get_pixel!(composed, 39, 39) == [255, 0, 0, 255]
    end

    test "centers the overlay by default", %{base: base, overlay: overlay} do
      assert {:ok, composed} = Image.compose(base, overlay)
      assert Image.get_pixel!(composed, 20, 20) == [255, 0, 0, 255]
      assert Image.get_pixel!(composed, 5, 5) == [0, 128, 0, 255]
    end

    test "negative offsets are relative to the right and bottom", %{
      base: base,
      overlay: overlay
    } do
      # x = base_width - overlay_width + x, so the overlay is
      # placed at {20, 20} for a -10 offset.
      assert {:ok, composed} = Image.compose(base, overlay, x: -10, y: -10)
      assert Image.get_pixel!(composed, 25, 25) == [255, 0, 0, 255]
      assert Image.get_pixel!(composed, 35, 35) == [0, 128, 0, 255]
    end

    test "accepts a :blend_mode", %{base: base, overlay: overlay} do
      assert {:ok, %Vimage{}} = Image.compose(base, overlay, blend_mode: :multiply)
    end

    test "returns an error for an unknown blend mode", %{base: base, overlay: overlay} do
      assert {:error, %Image.Error{message: "Unknown blend mode. Found :bogus"}} =
               Image.compose(base, overlay, blend_mode: :bogus)
    end

    test "compose!/3 returns an image", %{base: base, overlay: overlay} do
      assert %Vimage{} = Image.compose!(base, overlay, x: 1, y: 1)
    end

    test "compose!/3 raises for an unknown blend mode", %{base: base, overlay: overlay} do
      assert_raise Image.Error, fn ->
        Image.compose!(base, overlay, blend_mode: :bogus)
      end
    end
  end

  describe "Image.rounded/2, Image.squircle/2 and Image.circle/2" do
    test "rounded/2 adds an alpha band with transparent corners" do
      image = Image.new!(30, 20, color: :red)
      assert {:ok, rounded} = Image.rounded(image, radius: 8)

      assert Image.shape(rounded) == {30, 20, 4}
      assert Image.get_pixel!(rounded, 0, 0) == [255, 0, 0, 0]
      assert Image.get_pixel!(rounded, 15, 10) == [255, 0, 0, 255]
    end

    test "rounded/2 preserves an existing alpha band" do
      image = Image.open!(image_path("penguin_with_alpha.png"))
      assert {:ok, rounded} = Image.rounded(image)
      assert Image.bands(rounded) == 4
    end

    test "rounded!/2 returns an image" do
      assert %Vimage{} = Image.rounded!(Image.new!(20, 20, color: :red))
    end

    test "squircle/2 adds an alpha band" do
      image = Image.new!(30, 30, color: :red)
      assert {:ok, squircled} = Image.squircle(image, radius: 20)

      assert Image.shape(squircled) == {30, 30, 4}
      assert Image.get_pixel!(squircled, 0, 0) == [255, 0, 0, 0]
      assert Image.get_pixel!(squircled, 15, 15) == [255, 0, 0, 255]
    end

    test "squircle!/2 returns an image" do
      assert %Vimage{} = Image.squircle!(Image.new!(30, 30, color: :red))
    end

    test "circle/2 center-crops to a square and masks" do
      image = Image.new!(30, 20, color: :red)
      assert {:ok, circle} = Image.circle(image)

      assert Image.shape(circle) == {20, 20, 4}
      assert Image.get_pixel!(circle, 0, 0) == [255, 0, 0, 0]
      assert Image.get_pixel!(circle, 10, 10) == [255, 0, 0, 255]
    end

    test "circle/2 preserves an existing alpha band" do
      image = Image.open!(image_path("penguin_with_alpha.png"))
      assert {:ok, circle} = Image.circle(image)
      assert Image.bands(circle) == 4
    end

    test "circle!/2 returns an image" do
      assert %Vimage{} = Image.circle!(Image.new!(20, 20, color: :red))
    end
  end

  describe "Image.convert_alpha_to_mask/1" do
    test "extracts and inverts the alpha band" do
      image = Image.open!(image_path("penguin_with_alpha.png"))
      assert {:ok, mask} = Image.convert_alpha_to_mask(image)
      assert Image.bands(mask) == 1
    end

    test "returns an error when there is no alpha band" do
      image = Image.new!(10, 10, color: :red)

      assert {:error, %Image.Error{message: "Image has no alpha band"}} =
               Image.convert_alpha_to_mask(image)
    end

    test "convert_alpha_to_mask!/1 raises when there is no alpha band" do
      image = Image.new!(10, 10, color: :red)

      assert_raise Image.Error, fn ->
        Image.convert_alpha_to_mask!(image)
      end
    end
  end

  describe "Image.chroma_color/1, chroma_mask/2 and chroma_key/2" do
    test "chroma_color/1 samples the top left of the image" do
      assert Image.chroma_color(scene()) == [0, 128, 0]
    end

    test "chroma_mask/2 with the default :auto color masks the background" do
      assert {:ok, mask} = Image.chroma_mask(scene())

      assert Image.bands(mask) == 1
      assert Image.get_pixel!(mask, 0, 0) == [0]
      assert Image.get_pixel!(mask, 20, 20) == [255]
    end

    test "chroma_mask/2 with an explicit color and threshold" do
      assert {:ok, mask} = Image.chroma_mask(scene(), color: :green, threshold: 20)

      assert Image.get_pixel!(mask, 0, 0) == [0]
      assert Image.get_pixel!(mask, 20, 20) == [255]
    end

    test "chroma_mask/2 with a color range" do
      assert {:ok, mask} =
               Image.chroma_mask(scene(),
                 greater_than: [0, 100, 0],
                 less_than: [50, 255, 50]
               )

      assert Image.bands(mask) == 1
      assert Image.get_pixel!(mask, 20, 20) == [255]
    end

    test "chroma_mask/2 returns an error for an invalid threshold" do
      assert {:error, %Image.Error{reason: :invalid_option}} =
               Image.chroma_mask(scene(), threshold: -5)
    end

    test "chroma_mask!/2 raises for an invalid option" do
      assert_raise Image.Error, fn ->
        Image.chroma_mask!(scene(), color: :bogus_color)
      end
    end

    test "chroma_key/2 adds an alpha band masking the chroma color" do
      assert {:ok, keyed} = Image.chroma_key(scene(), color: :green, threshold: 20)

      assert Image.bands(keyed) == 4
      assert Image.get_pixel!(keyed, 0, 0) == [0, 128, 0, 0]
      assert Image.get_pixel!(keyed, 20, 20) == [255, 0, 0, 255]
    end

    test "chroma_key/2 returns an error for an invalid option" do
      assert {:error, %Image.Error{reason: :invalid_option}} =
               Image.chroma_key(scene(), color: :bogus_color)
    end

    test "chroma_key!/2 returns an image" do
      assert %Vimage{} = Image.chroma_key!(scene())
    end

    test "chroma_key!/2 raises for an invalid option" do
      assert_raise Image.Error, fn ->
        Image.chroma_key!(scene(), threshold: -1)
      end
    end
  end

  describe "Image.replace_color/2" do
    test "replaces a color selected by threshold" do
      image = Image.new!(10, 10, color: :red)

      assert {:ok, replaced} = Image.replace_color(image, color: :red, replace_with: :blue)
      assert Image.get_pixel!(replaced, 5, 5) == [0, 0, 255]
    end

    test "replaces a color with blending" do
      assert {:ok, replaced} =
               Image.replace_color(scene(),
                 color: :green,
                 replace_with: :white,
                 blend: true
               )

      assert Image.get_pixel!(replaced, 0, 0) == [255, 255, 255]
    end

    test "returns an error for an invalid option" do
      assert {:error, %Image.Error{}} =
               Image.replace_color(scene(), color: :bogus_color)
    end

    test "replace_color!/2 returns an image" do
      image = Image.new!(10, 10, color: :red)
      assert %Vimage{} = Image.replace_color!(image, color: :red, replace_with: :blue)
    end

    test "replace_color!/2 raises for an invalid option" do
      assert_raise Image.Error, fn ->
        Image.replace_color!(scene(), color: :bogus_color)
      end
    end
  end

  describe "Image.feather/2" do
    test "feathers the alpha band of an image" do
      image = Image.open!(image_path("penguin_with_alpha.png"))

      assert {:ok, feathered} = Image.feather(image, sigma: 2)
      assert Image.bands(feathered) == 4
    end

    test "feathers a single band mask" do
      mask = Image.new!(50, 50, color: 255, bands: 1)

      assert {:ok, feathered} = Image.feather(mask, sigma: 2)
      assert Image.bands(feathered) == 1

      # The border is embedded and blurred so it is no longer
      # fully opaque.
      assert [edge] = Image.get_pixel!(feathered, 0, 0)
      assert edge < 255
    end

    test "returns an error when a mask is too small to feather" do
      mask = Image.new!(10, 10, color: 255, bands: 1)

      assert {:error, %Image.Error{message: message}} = Image.feather(mask, sigma: 5)
      assert message =~ "too small to feather"
    end

    test "returns an error for a multi-band image with no alpha" do
      image = Image.new!(50, 50, color: :green)

      assert {:error, %Image.Error{message: message}} = Image.feather(image)
      assert message =~ "no alpha band"
    end

    test "feather!/2 raises for a multi-band image with no alpha" do
      image = Image.new!(50, 50, color: :green)

      assert_raise Image.Error, fn ->
        Image.feather!(image)
      end
    end
  end

  describe "Image.if_then_else/4" do
    test "selects pixels from two images based on a mask" do
      {:ok, mask} = Image.chroma_mask(scene(), color: :green)
      red = Image.new!(40, 40, color: :red)
      blue = Image.new!(40, 40, color: :blue)

      assert {:ok, selected} = Image.if_then_else(mask, red, blue)
      assert Image.get_pixel!(selected, 0, 0) == [0, 0, 255]
      assert Image.get_pixel!(selected, 20, 20) == [255, 0, 0]
    end

    test "accepts colors for the if and else branches" do
      {:ok, mask} = Image.chroma_mask(scene(), color: :green)
      blue = Image.new!(40, 40, color: :blue)

      assert {:ok, selected} = Image.if_then_else(mask, :red, blue)
      assert Image.get_pixel!(selected, 20, 20) == [255, 0, 0]

      assert {:ok, selected} = Image.if_then_else(mask, Image.new!(40, 40, color: :red), :blue)
      assert Image.get_pixel!(selected, 0, 0) == [0, 0, 255]
    end

    test "the :blend option blends across the mask boundary" do
      {:ok, mask} = Image.chroma_mask(scene(), color: :green)
      {:ok, feathered_mask} = Image.feather(mask, sigma: 2)
      red = Image.new!(40, 40, color: :red)
      blue = Image.new!(40, 40, color: :blue)

      assert {:ok, blended} = Image.if_then_else(feathered_mask, red, blue, blend: true)

      # At the boundary of the feathered mask the result is a
      # mix of the two images.
      [r, _g, b] = Image.get_pixel!(blended, 19, 15)
      assert r > 0 and r < 255
      assert b > 0 and b < 255
    end

    test "returns an error for an unknown color" do
      {:ok, mask} = Image.chroma_mask(scene(), color: :green)
      assert {:error, _reason} = Image.if_then_else(mask, :bogus_color, :blue)
    end

    test "if_then_else!/4 returns an image" do
      {:ok, mask} = Image.chroma_mask(scene(), color: :green)
      assert %Vimage{} = Image.if_then_else!(mask, :red, :blue)
    end
  end

  describe "Image.meme/3" do
    setup do
      image = Image.open!(image_path("Kip_small.jpg"))
      {:ok, %{image: image}}
    end

    test "generates a meme with a headline", %{image: image} do
      assert {:ok, %Vimage{} = meme} = Image.meme(image, "One Does Not Simply")
      assert Image.width(meme) == Image.width(image)
      assert Image.height(meme) == Image.height(image)
    end

    test "generates a meme with options", %{image: image} do
      assert {:ok, %Vimage{}} =
               Image.meme(image, "One Does Not Simply",
                 text: "write tests",
                 transform: :none,
                 color: :yellow,
                 outline_color: :blue,
                 weight: :normal
               )
    end

    test "returns an error for an invalid weight", %{image: image} do
      assert {:error, %Image.Error{reason: :invalid_option}} =
               Image.meme(image, "HI", weight: :bogus)
    end

    test "meme!/3 returns an image", %{image: image} do
      assert %Vimage{} = Image.meme!(image, "HI")
    end

    test "meme!/3 raises for an invalid option", %{image: image} do
      assert_raise Image.Error, fn ->
        Image.meme!(image, "HI", weight: :bogus)
      end
    end
  end
end
