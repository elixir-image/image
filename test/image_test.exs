defmodule Image.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport
  import Image.Math
  alias Vix.Vips.Operation
  alias Vix.Vips.Image, as: Vimage
  use Image.Math

  doctest Image

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  test "Minimise metadata", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, input_info} = File.stat(image)
    {:ok, kip} = Vimage.new_from_file(image)

    {:ok, minimised} = Image.minimize_metadata(kip)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    validate_path = validate_path("Kip_small_with_simple_exif.jpg")

    assert :ok = Vimage.write_to_file(minimised, out_path)

    {:ok, output_info} = File.stat(validate_path)

    assert_files_equal(out_path, validate_path("Kip_small_with_simple_exif.jpg"))
    assert input_info.size > output_info.size * 2
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

  # This test validates the expected operation of infix operators
  # working on Image data. This behaviour is driven by `use Image.Math`.

  test "Math operators to create a white circle", %{dir: dir} do
    {:ok, im} = Operation.xyz(200, 200)

    # move the origin to the centre
    im = im - [Image.width(im) / 2, Image.height(im) / 2]

    # a one-band image where pixels are distance from the centre
    im = (im[0] ** 2 + im[1] ** 2) ** 0.5

    # relational operations make uchar images with 0 for false, 255 for true
    im = im < Image.width(im) / 3

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok = Vimage.write_to_file(im, out_path)

    assert_files_equal out_path, validate_path("image_circle_white.png")
  end

  test "Rotating an image 90 degrees", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)
    {:ok, rotated} = Image.rotate(kip, 90.0)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(rotated, out_path)

    assert_files_equal(out_path, validate_path("Kip_small_rotate90.jpg"))
  end

  test "Rotating an image -90 degrees", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)
    {:ok, rotated} = Image.rotate(kip, -90.0)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(rotated, out_path)

    assert_files_equal(out_path, validate_path("Kip_small_rotate-90.jpg"))
  end

  test "Rotating an image 45 degrees", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)
    {:ok, rotated} = Image.rotate(kip, 45)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(rotated, out_path)

    assert_files_equal(out_path, validate_path("Kip_small_rotate45.jpg"))
  end

  test "Rotating an image 45 degrees with white background", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)
    {:ok, rotated} = Image.rotate(kip, 45, background: [255, 255, 255])

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(rotated, out_path)

    assert_files_equal(out_path, validate_path("Kip_small_rotate45_white.jpg"))
  end

  test "Rotating an image 45 degrees with displacement", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)
    {:ok, rotated} = Image.rotate(kip, 45, odx: 10, ody: 10, background: [255, 255, 255])

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(rotated, out_path)

    assert_files_equal out_path, validate_path("Kip_small_rotate45_displaced.jpg")
  end

  test "Convert to polar coordinates", %{dir: dir} do
    image = image_path("San-Francisco-2018-04-2549.jpg")
    {:ok, image} = Vimage.new_from_file(image)
    {:ok, polar} = Image.to_polar_coordinates(image)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(polar, out_path)

    assert_files_equal out_path, validate_path("polar.jpg")
  end

  test "Convert to rectangular coordinates", %{dir: dir} do
    image = validate_path("polar.jpg")
    {:ok, image} = Vimage.new_from_file(image)
    {:ok, polar} = Image.to_rectangular_coordinates(image)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(polar, out_path)

    assert_files_equal out_path, validate_path("rectangular.jpg")
  end

  test "Ripple Effect", %{dir: dir} do
    image = image_path("San-Francisco-2018-04-2549.jpg")
    {:ok, image} = Vimage.new_from_file(image)
    {:ok, ripple} = Image.ripple(image)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(ripple, out_path)

    assert_files_equal out_path, validate_path("ripple.jpg")
  end

  test "Autorotate an image", %{dir: dir} do
    image = image_path("Kip_small_rotated.jpg")
    {:ok, image} = Vimage.new_from_file(image)
    {:ok, {autorotated, flags}} = Image.autorotate(image)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(autorotated, out_path)

    assert {:ok, 180} = Keyword.fetch(flags, :angle)
    assert_files_equal out_path, validate_path("autorotated.jpg")
  end
end
