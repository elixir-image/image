defmodule Image.Draw.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  alias Vix.Vips.Image, as: Vimage

  doctest Image.Draw

  test "mutating draw a rectangle on a white image" do
    {:ok, image} = Vix.Vips.Operation.black!(500, 500, bands: 3) |> Vix.Vips.Operation.invert()

    assert {:ok, _image} =
             Image.mutate(image, fn mut_img ->
               {:ok, _} = Image.Draw.rect(mut_img, 10, 10, 100, 100, color: :green, fill: true)
             end)
  end

  test "mutating draw a circle on a white image" do
    {:ok, image} = Vix.Vips.Operation.black!(500, 500, bands: 3) |> Vix.Vips.Operation.invert()
    cx = cy = div(Image.height(image), 2)

    assert {:ok, _image} =
             Image.mutate(image, fn mut_img ->
               {:ok, _} = Image.Draw.circle(mut_img, cx, cy, 100, fill: true, color: [0, 200, 0])
             end)
  end

  test "mutating draw a line on a white image" do
    {:ok, image} = Vix.Vips.Operation.black!(500, 500, bands: 3) |> Vix.Vips.Operation.invert()

    assert {:ok, _image} =
             Image.mutate(image, fn mut_img ->
               {:ok, _} = Image.Draw.line(mut_img, 0, 0, 499, 499, color: [0, 200, 0])
             end)
  end

  test "mutating draw an image onto another image" do
    {:ok, image} = Vix.Vips.Operation.black(500, 500, bands: 4)
    {:ok, star} = Image.Shape.star(5, rotation: 90, fill_color: :green, stroke_color: :green)

    assert {:ok, _image} =
             Image.mutate(image, fn mut_img ->
               {:ok, _} = Image.Draw.image(mut_img, star, 100, 100, mode: :VIPS_COMBINE_MODE_ADD)
             end)
  end

  test "draw a line" do
    {:ok, image} = Image.new(100, 100, color: :white)
    {:ok, diagonal} = Image.Draw.line(image, 0, 0, 99, 99)

    assert_images_equal(diagonal, validate_path("draw/line.png"))
  end

  test "flood an image" do
    assert {:ok, {%Vimage{} = _image, %{left: 0, width: 1, height: 2, top: 0}}} =
             Image.new!(1, 2) |> Image.Draw.flood(0, 0, color: :white)
  end

  describe "drawing on non-3-band images" do
    # Regression: maybe_add_alpha/2 assumed 3-band = no alpha and
    # 4-band = alpha, crashing on greyscale images and deleting the K
    # channel of CMYK images.

    test "draws a point on a greyscale image" do
      grey = Image.new!(20, 20, color: 128) |> Image.to_colorspace!(:bw)

      assert {:ok, %Vimage{}} = Image.Draw.point(grey, 5, 5, color: :white)
    end

    test "draws a rect on a CMYK image without deleting the K band" do
      cmyk = Image.new!(20, 20, color: :white) |> Image.to_colorspace!(:cmyk)

      assert {:ok, %Vimage{} = drawn} = Image.Draw.rect(cmyk, 2, 2, 5, 5, color: :red, fill: true)
      assert Image.bands(drawn) == Image.bands(cmyk)
    end

    test "draws a circle on an image with an alpha band" do
      rgba = Image.new!(20, 20, color: [255, 255, 255, 255])

      assert {:ok, %Vimage{} = drawn} = Image.Draw.circle(rgba, 10, 10, 5, color: :blue, fill: true)
      assert Image.bands(drawn) == 4
    end
  end
end
