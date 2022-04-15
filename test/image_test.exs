defmodule ImageTest do
  use ExUnit.Case
  import Image.TestSupport
  import Image.Math
  alias Vix.Vips.Operation
  alias Vix.Vips.Image, as: Vimage

  doctest Image

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  test "Minimise metadata", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)

    {:ok, minimised} = Image.add_minimal_exif(kip)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok = Vimage.write_to_file(minimised, out_path)

    assert_files_equal(out_path, validate_path("Kip_small_with_simple_exif.png"))
  end

  test "Circular Image", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)
    {:ok, circle} = Image.circle(kip)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok = Vimage.write_to_file(circle, out_path)

    assert_files_equal(out_path, validate_path("Kip_small_circle_mask.png"))
  end

  test "Rounded Image", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)
    {:ok, rounded} = Image.rounded(kip)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok = Vimage.write_to_file(rounded, out_path)
    Vimage.write_to_file(rounded, validate_path("Kip_small_rounded_mask.png"))
    assert_files_equal(out_path, validate_path("Kip_small_rounded_mask.png"))
  end

  test "Image composition", %{dir: dir} do
    image = image_path("lamborghini-forsennato-concept.jpg")

    {:ok, lambo} = Vimage.new_from_file(image)
    {:ok, grad} = Image.linear_gradient(lambo)

    {:ok, composite} = Operation.composite2(lambo, grad, :VIPS_BLEND_MODE_OVER)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok = Vimage.write_to_file(composite, out_path)

    assert_files_equal(out_path, validate_path("composite_with_gradient.png"))
  end

  test "Circular Image Gradient 1", %{dir: dir} do
    start = [100, 50, 0]
    finish = [50, 0, 50]
    size = 512

    {:ok, x} = Operation.xyz(size, size)
    {:ok, x} = subtract(x, [Image.width(x) / 2, Image.height(x) / 2])

    {:ok, x0} = Operation.extract_band(x, 0)
    {:ok, x1} = Operation.extract_band(x, 1)

    d =
      pow!(x0, 2)
      |> add!(pow!(x1, 2))
      |> pow!(0.5)
      |> divide!(2 ** 0.5 * size / 2)

    out =
      d
      |> multiply!(finish)
      |> add!(multiply!(d, -1) |> add!(1) |> multiply!(start))

    {:ok, out} = Operation.copy(out, interpretation: :VIPS_INTERPRETATION_LAB)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok = Vimage.write_to_file(out, out_path)

    assert_files_equal(out_path, validate_path("radial_gradient_1.png"))
  end

  test "Circular Image Gradient 2", %{dir: dir} do
    start = [255, 0, 0]
    finish = [0, 0, 255]

    {:ok, x} = Operation.xyz(100, 200)
    {:ok, x} = subtract(x, [Image.width(x) / 2, Image.height(x) / 2])

    {:ok, x0} = Operation.extract_band(x, 0)
    {:ok, x1} = Operation.extract_band(x, 1)

    d =
      x0
      |> pow!(2)
      |> add!(pow!(x1, 2))
      |> pow!(0.5)

    d =
      d
      |> multiply!(10)
      |> cos!()
      |> divide!(2)
      |> add!(0.5)

    out =
      d
      |> multiply!(finish)
      |> add!(multiply!(d, -1) |> add!(1) |> multiply!(start))

    {:ok, out} = Operation.copy(out, interpretation: :VIPS_INTERPRETATION_sRGB)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok = Vimage.write_to_file(out, out_path)

    assert_files_equal(out_path, validate_path("radial_gradient_2.png"))
  end
end
