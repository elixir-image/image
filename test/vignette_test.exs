defmodule Image.Vignette.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  @sample_path image_path("Kip_small.jpg")

  test "default vignette darkens the corners and leaves the centre alone" do
    image = Image.open!(@sample_path, access: :random)
    {:ok, vignetted} = Image.vignette(image)

    centre_x = div(Image.width(image), 2)
    centre_y = div(Image.height(image), 2)

    [src_corner | _] = Image.get_pixel!(image, 0, 0)
    [dst_corner | _] = Image.get_pixel!(vignetted, 0, 0)
    [src_centre | _] = Image.get_pixel!(image, centre_x, centre_y)
    [dst_centre | _] = Image.get_pixel!(vignetted, centre_x, centre_y)

    assert dst_corner < src_corner, "expected vignette to darken the corner"
    assert_in_delta dst_centre, src_centre, 1.0, "expected the centre to be unchanged"
  end

  test ":strength controls how dark the corner gets" do
    image = Image.open!(@sample_path, access: :random)
    {:ok, mild} = Image.vignette(image, strength: 0.2)
    {:ok, strong} = Image.vignette(image, strength: 0.8)

    [mild_corner | _] = Image.get_pixel!(mild, 0, 0)
    [strong_corner | _] = Image.get_pixel!(strong, 0, 0)

    assert strong_corner < mild_corner
  end

  test "negative :strength brightens the corners" do
    image = Image.open!(@sample_path, access: :random)
    {:ok, brightened} = Image.vignette(image, strength: -0.4)

    [src_corner | _] = Image.get_pixel!(image, 0, 0)
    [dst_corner | _] = Image.get_pixel!(brightened, 0, 0)

    assert dst_corner > src_corner
  end

  test ":k1/:k2/:k3 take precedence over :strength" do
    image = Image.open!(@sample_path, access: :random)

    # k1 = 0 means no vignette regardless of :strength.
    {:ok, no_vignette} = Image.vignette(image, strength: 0.9, k1: 0.0)

    [src_corner | _] = Image.get_pixel!(image, 0, 0)
    [dst_corner | _] = Image.get_pixel!(no_vignette, 0, 0)

    assert_in_delta dst_corner, src_corner, 1.0
  end

  test "preserves the image's band format" do
    image = Image.open!(@sample_path, access: :random)
    {:ok, vignetted} = Image.vignette(image)
    assert Image.band_format(vignetted) == Image.band_format(image)
  end

  test "rejects invalid options" do
    image = Image.open!(@sample_path, access: :random)
    assert {:error, _} = Image.vignette(image, strength: "loud")
    assert {:error, _} = Image.vignette(image, k1: :nope)
  end

  test "vignette!/2 raises on invalid options" do
    image = Image.open!(@sample_path, access: :random)

    assert_raise Image.Error, fn ->
      Image.vignette!(image, strength: "loud")
    end
  end
end
