defmodule Image.Draw.Test do
  use ExUnit.Case, async: true
  alias Vix.Vips.Image, as: Vimage

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

  describe "line/6" do
    test "draws a line on given image" do
      {:ok, image} = Vix.Vips.Operation.black(5, 5, bands: 1)
      {:ok, image} = Image.Draw.line(image, 0, 0, 0, 4, color: :white)

      assert {
        :ok,
        <<255, 0, 0, 0, 0,
          255, 0, 0, 0, 0,
          255, 0, 0, 0, 0,
          255, 0, 0, 0, 0,
          255, 0, 0, 0, 0>>
      } = Vix.Vips.Image.write_to_binary(image)
    end
  end
end
