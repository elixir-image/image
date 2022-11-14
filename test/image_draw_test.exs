defmodule Image.Draw.Test do
  use ExUnit.Case, async: true
  alias Vix.Vips.Image, as: Vimage
  import Image.TestSupport

  test "drawing a circle on a white image" do
    {:ok, image} = Vix.Vips.Operation.black!(500,500, bands: 3) |> Vix.Vips.Operation.invert()
    cx = cy = div(Image.height(image), 2)

    {:ok, image} =
      Vimage.mutate image, fn mut_img ->
        :ok = Vix.Vips.MutableOperation.draw_circle(mut_img, [0,200,0], cx, cy, 100, fill: true)
      end

      Image.write(image, "/Users/kip/Desktop/draw.jpg")
  end

  test "draw an image onto another image" do
    {:ok, image} = Vix.Vips.Operation.black(500,500, bands: 4)
    {:ok, star} = Image.Shape.star(5, rotation: 90, fill_color: :green, stroke_color: :green)

    {:ok, image} =
      Vimage.mutate image, fn mut_img ->
        :ok = Vix.Vips.MutableOperation.draw_image(mut_img, star, 100, 100, mode: :VIPS_COMBINE_MODE_ADD)
      end

      Image.write(image, "/Users/kip/Desktop/draw2.png")
  end

  test "draw a line" do
    {:ok, image} = Image.new(100,100, color: :white)
    {:ok, diagonal} = Image.Draw.line(image, 0, 0, 99, 99)

    assert_images_equal(diagonal, validate_path("draw/line.png"))
  end

end