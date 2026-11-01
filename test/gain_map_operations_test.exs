defmodule Image.GainMap.Operations.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  alias Vix.Vips.Operation

  @moduletag :gain_map

  # The generated fixture is 480x260 with its HDR marker at this area, in base
  # image pixels. Each test transforms the image, saves and reloads it, then
  # checks that the gain map is high where the transform moved the marker and
  # low where the marker used to be, which a stale gain map would not be.
  @marker {48, 40, 120, 80}

  setup_all do
    %{image: Image.open!(image_path("gain_map.jpg"))}
  end

  describe "flip/2" do
    test "horizontally", %{image: image} do
      {:ok, flipped} = Image.flip(image, :horizontal)
      saved = round_trip(flipped)

      assert_marker_moved(saved, {312, 40, 120, 80}, @marker)
    end

    test "vertically", %{image: image} do
      {:ok, flipped} = Image.flip(image, :vertical)
      saved = round_trip(flipped)

      assert_marker_moved(saved, {48, 140, 120, 80}, @marker)
    end
  end

  describe "crop/5 and the functions that delegate to it" do
    test "crop/5", %{image: image} do
      {:ok, cropped} = Image.crop(image, 30, 20, 300, 200)
      saved = round_trip(cropped)

      assert {300, 200, 3} = Image.shape(elem(saved, 0))
      assert_marker_moved(saved, {18, 20, 120, 80}, {170, 110, 120, 80})
    end

    test "center_crop/3", %{image: image} do
      {:ok, cropped} = Image.center_crop(image, 400, 200)
      saved = round_trip(cropped)

      assert {400, 200, 3} = Image.shape(elem(saved, 0))
      assert_marker_moved(saved, {8, 10, 120, 80}, {200, 100, 120, 80})
    end

    test "crop/2 with a rectangle", %{image: image} do
      {:ok, cropped} = Image.crop(image, [{30, 20}, {329, 20}, {329, 219}, {30, 219}])
      saved = round_trip(cropped)

      assert_marker_moved(saved, {18, 20, 120, 80}, {170, 110, 120, 80})
    end

    test "an odd-dimension gain map covers the whole crop" do
      image = Image.open!(image_path("gain_map_odd_dimensions.jpg"))
      {:ok, cropped} = Image.crop(image, 1, 1, 127, 95)
      {:ok, gain_map} = Image.GainMap.gain_map(cropped)

      # The near edges round down and the far edges up, so the 127x95 crop
      # keeps the whole 65x49 gain map rather than losing an edge.
      assert {65, 49, 1} = Image.shape(gain_map)

      {:ok, jpeg} = Image.write(cropped, :memory, suffix: ".jpg")
      {:ok, reloaded} = Image.from_binary(jpeg)
      assert {:ok, %Image.GainMap{scale_factor: 2}} = Image.GainMap.info(reloaded)
    end
  end

  describe "resize/3" do
    test "by half", %{image: image} do
      {:ok, resized} = Image.resize(image, 0.5)
      saved = round_trip(resized)

      assert {240, 130, 3} = Image.shape(elem(saved, 0))
      assert_marker_moved(saved, {24, 20, 60, 40}, {150, 80, 60, 40})
    end

    test "by a scale that is not a simple fraction", %{image: image} do
      {:ok, resized} = Image.resize(image, 0.37)
      saved = round_trip(resized)

      assert_marker_moved(saved, {18, 15, 44, 30}, {110, 55, 44, 30})
    end

    test "with a different vertical scale", %{image: image} do
      {:ok, resized} = Image.resize(image, 0.5, vertical_scale: 0.25)
      saved = round_trip(resized)

      assert {240, 65, 3} = Image.shape(elem(saved, 0))
      assert_marker_moved(saved, {24, 10, 60, 20}, {150, 40, 60, 20})
    end
  end

  describe "rotate/3" do
    # Rotation is clockwise, so the top-left marker moves to the top-right for
    # 90 degrees, the bottom-right for 180 and the bottom-left for 270.
    test "by 90 degrees", %{image: image} do
      {:ok, rotated} = Image.rotate(image, 90)
      saved = round_trip(rotated)

      assert {260, 480, 3} = Image.shape(elem(saved, 0))
      assert_marker_moved(saved, {140, 48, 80, 120}, {40, 48, 80, 120})
    end

    test "by 180 degrees", %{image: image} do
      {:ok, rotated} = Image.rotate(image, 180)
      saved = round_trip(rotated)

      assert_marker_moved(saved, {312, 140, 120, 80}, @marker)
    end

    test "by 270 degrees", %{image: image} do
      {:ok, rotated} = Image.rotate(image, 270)
      saved = round_trip(rotated)

      assert {260, 480, 3} = Image.shape(elem(saved, 0))
      assert_marker_moved(saved, {40, 312, 80, 120}, {40, 48, 80, 120})
    end

    test "by another angle removes the gain map", %{image: image} do
      {:ok, rotated} = Image.rotate(image, 30)
      refute Image.GainMap.gain_map?(rotated)

      {:ok, jpeg} = Image.write(rotated, :memory, suffix: ".jpg")
      {:ok, reloaded} = Image.from_binary(jpeg)
      refute Image.GainMap.gain_map?(reloaded)
    end
  end

  describe "autorotate/1" do
    test "EXIF orientation 6 rotates the gain map 90 degrees", %{image: image} do
      {:ok, {rotated, %{angle: 90}}} = Image.autorotate(with_orientation(image, 6))
      saved = round_trip(rotated)

      assert {260, 480, 3} = Image.shape(elem(saved, 0))
      assert_marker_moved(saved, {140, 48, 80, 120}, {40, 48, 80, 120})
    end

    test "EXIF orientation 2 mirrors the gain map", %{image: image} do
      {:ok, {mirrored, %{flip: true}}} = Image.autorotate(with_orientation(image, 2))
      saved = round_trip(mirrored)

      assert_marker_moved(saved, {312, 40, 120, 80}, @marker)
    end

    test "an image without an orientation keeps its gain map", %{image: image} do
      {:ok, {unrotated, _flags}} = Image.autorotate(image)
      saved = round_trip(unrotated)

      assert_marker_moved(saved, @marker, {312, 40, 120, 80})
    end
  end

  describe "embed/4" do
    # The marker moves by the embed offset, and the new border has the gain
    # map value for no boost, which is 0 for this fixture's 1.0 minimum boost.
    # The comparison area is inside the embedded image but away from the
    # marker, since the marker's old position overlaps its new one here.
    test "with the default fill", %{image: image} do
      {:ok, embedded} = Image.embed(image, 600, 400, x: 60, y: 70)
      saved = round_trip(embedded)

      assert {600, 400, 3} = Image.shape(elem(saved, 0))
      assert_marker_moved(saved, {108, 110, 120, 80}, {300, 250, 120, 80})
      assert gain_mean(saved, {0, 0, 50, 60}) < 5
    end

    test "with a background colour", %{image: image} do
      {:ok, embedded} = Image.embed(image, 600, 400, x: 60, y: 70, background: :red)
      saved = round_trip(embedded)

      assert_marker_moved(saved, {108, 110, 120, 80}, {300, 250, 120, 80})
      assert gain_mean(saved, {0, 0, 50, 60}) < 5
    end

    test "with a content extend mode", %{image: image} do
      {:ok, embedded} = Image.embed(image, 600, 400, x: 60, y: 70, extend_mode: :copy)
      saved = round_trip(embedded)

      assert_marker_moved(saved, {108, 110, 120, 80}, {300, 250, 120, 80})
    end
  end

  # libvips' own thumbnail carries the gain map, so these confirm that
  # `Image.thumbnail/3` keeps that behaviour in each of its forms.
  describe "thumbnail/3" do
    test "from a path" do
      {:ok, thumbnail} = Image.thumbnail(image_path("gain_map.jpg"), 240)
      saved = round_trip(thumbnail)

      assert {240, 130, 3} = Image.shape(elem(saved, 0))
      assert_marker_moved(saved, {24, 20, 60, 40}, {150, 80, 60, 40})
    end

    test "from an image", %{image: image} do
      {:ok, thumbnail} = Image.thumbnail(image, 240)
      saved = round_trip(thumbnail)

      assert_marker_moved(saved, {24, 20, 60, 40}, {150, 80, 60, 40})
    end

    test "with a crop", %{image: image} do
      {:ok, thumbnail} = Image.thumbnail(image, "200x200", crop: :center)
      {thumbnail, _gain_map} = round_trip(thumbnail)

      assert {200, 200, 3} = Image.shape(thumbnail)
    end
  end

  describe "trim/2" do
    test "crops the gain map with the image", %{image: image} do
      {:ok, embedded} = Image.embed(image, 600, 400, x: 60, y: 70, background: :black)
      {:ok, {left, top, _width, _height}} = Image.find_trim(embedded)
      {:ok, trimmed} = Image.trim(embedded)
      saved = round_trip(trimmed)

      assert_marker_moved(saved, {108 - left, 110 - top, 120, 80}, {300, 150, 120, 80})
    end
  end

  defp with_orientation(image, orientation) do
    {:ok, image} =
      Vix.Vips.Image.mutate(
        image,
        &Vix.Vips.MutableImage.set(&1, "orientation", :gint, orientation)
      )

    image
  end

  # Saves `image` as a JPEG and reloads it, returning the reloaded image and
  # its gain map, so each test checks what a caller would actually write.
  defp round_trip(image) do
    {:ok, jpeg} = Image.write(image, :memory, suffix: ".jpg")
    {:ok, reloaded} = Image.from_binary(jpeg)
    {:ok, gain_map} = Image.GainMap.gain_map(reloaded)

    # The gain map must stay at about half the base resolution.
    assert_in_delta Image.width(gain_map), Image.width(reloaded) / 2, 1
    assert_in_delta Image.height(gain_map), Image.height(reloaded) / 2, 1

    {reloaded, gain_map}
  end

  defp assert_marker_moved(saved, marker, old_marker) do
    assert gain_mean(saved, marker) > 3 * gain_mean(saved, old_marker)
  end

  # The mean gain map value over an area given in base image pixels, inset by
  # one gain map pixel on each side so that blended edges are not sampled.
  defp gain_mean({image, gain_map}, {left, top, width, height}) do
    x_scale = Image.width(gain_map) / Image.width(image)
    y_scale = Image.height(gain_map) / Image.height(image)

    {:ok, region} =
      Operation.extract_area(
        gain_map,
        ceil(left * x_scale) + 1,
        ceil(top * y_scale) + 1,
        floor(width * x_scale) - 2,
        floor(height * y_scale) - 2
      )

    {:ok, mean} = Operation.avg(region)
    mean
  end
end
