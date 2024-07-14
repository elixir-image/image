defmodule Image.Test do
  use ExUnit.Case, async: false
  import Image.TestSupport
  alias Vix.Vips.Operation
  alias Vix.Vips.Image, as: Vimage

  doctest Image
  doctest Image.Classification
  doctest Image.Color
  doctest Image.BandFormat
  doctest Image.Blurhash

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

    assert_images_equal(out_path, validate_path("Kip_small_with_simple_exif.jpg"))
    assert input_info.size > output_info.size * 2
  end

  test "Circular Image", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)
    {:ok, circle} = Image.circle(kip)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok = Vimage.write_to_file(circle, out_path)

    assert_images_equal(out_path, validate_path("Kip_small_circle_mask.png"))
  end

  test "Rounded Image", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)
    {:ok, rounded} = Image.rounded(kip)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok = Vimage.write_to_file(rounded, out_path)

    assert_images_equal(out_path, validate_path("Kip_small_rounded_mask.png"))
  end

  test "Squircled Image", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)
    {:ok, squircled} = Image.squircle(kip)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok = Vimage.write_to_file(squircled, out_path)

    assert_images_equal(out_path, validate_path("Kip_small_squircle_mask.png"))
  end

  test "Image composition", %{dir: dir} do
    image = image_path("lamborghini-forsennato-concept.jpg")

    {:ok, lambo} = Vimage.new_from_file(image)
    {:ok, grad} = Image.linear_gradient(lambo)

    {:ok, composite} = Operation.composite2(lambo, grad, :VIPS_BLEND_MODE_OVER)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok = Vimage.write_to_file(composite, out_path)

    assert_images_equal(out_path, validate_path("composite_with_gradient.png"))
  end

  test "Circular Image Gradient 1", %{dir: dir} do
    use Image.Math
    validate_path = validate_path("radial_gradient_1.png")

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

    # Image.write!(out, validate_path)
    assert_images_equal(out_path, validate_path, 2.0)
  end

  test "Circular Image Gradient 2", %{dir: dir} do
    use Image.Math

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

    assert_images_equal(out_path, validate_path("radial_gradient_2.png"))
  end

  # This test validates the expected operation of infix operators
  # working on Image data. This behaviour is driven by `use Image.Math`.

  test "Math operators to create a white circle", %{dir: dir} do
    use Image.Math

    {:ok, im} = Operation.xyz(200, 200)

    # move the origin to the centre
    im = im - [Image.width(im) / 2, Image.height(im) / 2]

    # a one-band image where pixels are distance from the centre
    im = (im[0] ** 2 + im[1] ** 2) ** 0.5

    # relational operations make uchar images with 0 for false, 255 for true
    im = im < Image.width(im) / 3

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok = Vimage.write_to_file(im, out_path)

    assert_images_equal(out_path, validate_path("image_circle_white.png"))
  end

  test "Rotating an image 90 degrees", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)
    {:ok, rotated} = Image.rotate(kip, 90.0)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(rotated, out_path)

    assert_images_equal(out_path, validate_path("Kip_small_rotate90.jpg"))
  end

  test "Rotating an image -90 degrees", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)
    {:ok, rotated} = Image.rotate(kip, -90.0)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(rotated, out_path)

    assert_images_equal(out_path, validate_path("Kip_small_rotate-90.jpg"))
  end

  test "Rotating an image 45 degrees", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)
    {:ok, rotated} = Image.rotate(kip, 45)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(rotated, out_path)

    assert_images_equal(out_path, validate_path("Kip_small_rotate45.jpg"))
  end

  test "Rotating an image 45 degrees with white background", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)
    {:ok, rotated} = Image.rotate(kip, 45, background: [255, 255, 255])

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(rotated, out_path)

    assert_images_equal(out_path, validate_path("Kip_small_rotate45_white.jpg"))
  end

  test "Rotating an image 45 degrees with displacement", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)
    {:ok, rotated} = Image.rotate(kip, 45, odx: 10, ody: 10, background: [255, 255, 255])

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(rotated, out_path)

    assert_images_equal(out_path, validate_path("Kip_small_rotate45_displaced.jpg"))
  end

  test "Convert to polar coordinates", %{dir: dir} do
    image = image_path("San-Francisco-2018-04-2549.jpg")
    {:ok, image} = Vimage.new_from_file(image)
    {:ok, polar} = Image.to_polar_coordinates(image)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(polar, out_path)

    assert_images_equal(out_path, validate_path("polar.jpg"))
  end

  test "Convert to rectangular coordinates", %{dir: dir} do
    image = validate_path("polar.jpg")
    {:ok, image} = Vimage.new_from_file(image)
    {:ok, rectangular} = Image.to_rectangular_coordinates(image)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(rectangular, out_path)

    assert_images_equal(out_path, validate_path("rectangular.jpg"))
  end

  test "Ripple Effect", %{dir: dir} do
    image = image_path("San-Francisco-2018-04-2549.jpg")
    {:ok, image} = Vimage.new_from_file(image)
    {:ok, ripple} = Image.ripple(image)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(ripple, out_path)

    assert_images_equal(out_path, validate_path("ripple.jpg"))
  end

  test "Autorotate an image", %{dir: dir} do
    image = image_path("Kip_small_rotated.jpg")
    {:ok, image} = Vimage.new_from_file(image)
    {:ok, {autorotated, flags}} = Image.autorotate(image)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(autorotated, out_path)

    assert {:ok, 180} = Map.fetch(flags, :angle)
    assert_images_equal(out_path, validate_path("autorotated.jpg"))
  end

  test "Image.new/3" do
    # 100x100 pixel image of dark blue slate color
    assert {:ok, _image} = Image.new(100, 100, color: :dark_slate_blue)

    # 100x100 pixel green image, fully transparent
    assert {:ok, _image} = Image.new(100, 100, color: [0, 255, 0, 1], bands: 4)
  end

  test "Image.open/2 for different file formats" do
    jpeg_binary = File.read!(image_path("Kip_small.jpg"))
    assert {:ok, _i} = Image.open(jpeg_binary)

    png_binary = File.read!(image_path("Kip_small.png"))
    assert {:ok, _i} = Image.open(png_binary)

    webp_binary = File.read!(image_path("example.webp"))
    assert {:ok, _i} = Image.open(webp_binary)
  end

  test "Splitting an image into its bands" do
    image = Image.open!(image_path("/2x2-maze.png"))
    assert [_, _, _, _] = Image.split_bands(image)
  end

  test "Split alpha band" do
    image = Image.open!(image_path("2x2-maze.png"))
    {bands, alpha} = Image.split_alpha(image)
    assert Image.bands(bands) == 3
    assert Image.bands(alpha) == 1
  end

  test "Image/new 3 default bands" do
    assert Image.bands(Image.new!(20, 20, color: [0, 0, 0, 0])) == 4
    assert Image.bands(Image.new!(20, 20, color: [0, 0, 0])) == 3
  end

  test "Image color replacement" do
    validate_path = validate_path("green.tiff")

    {:ok, red} = Image.new(20, 20, color: :red)
    {:ok, replaced} = Image.replace_color(red, color: :red, replace_with: :green)

    assert_images_equal(replaced, validate_path)
  end

  test "Joining bands results in the same image" do
    image = Image.open! "./test/support/images/Singapore-2016-09-5887.jpg"
    bands = Image.split_bands(image)
    joined = Image.join_bands!(bands)
    assert {:ok, +0.0, _} = Image.compare(image, joined)
  end
end
