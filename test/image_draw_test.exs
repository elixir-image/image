defmodule Image.Draw.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  alias Vix.Vips.Image, as: Vimage

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
end
