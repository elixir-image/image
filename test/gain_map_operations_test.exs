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

    test "by other angles", %{image: image} do
      for angle <- [30, -45, 200] do
        assert_aligned(image, &Image.rotate(&1, angle))
      end
    end

    test "with output displacements", %{image: image} do
      assert_aligned(image, &Image.rotate(&1, 30, odx: 25, ody: 13))
    end

    test "an image with an alpha band", %{image: image} do
      assert_aligned(image, &Image.rotate(Image.add_alpha!(&1, 255), 30))
    end

    test "fills the exposed corners with the gain for no boost", %{image: image} do
      # With these parameters the encoded value for a gain of 1.0 is 255 / 3.
      image = with_parameters(image, [0.5, 0.5, 0.5], [4.0, 4.0, 4.0], [1.0, 1.0, 1.0])
      {:ok, rotated} = Image.rotate(image, 30)
      {:ok, gain_map} = Image.GainMap.gain_map(rotated)

      assert {:ok, [corner]} = Image.get_pixel(gain_map, 0, 0)
      assert_in_delta corner, 85, 1
    end
  end

  describe "the affine family" do
    test "affine/3", %{image: image} do
      assert_aligned(image, &Image.affine(&1, [1.3, 0.2, -0.1, 0.7]))
      assert_aligned(image, &Image.affine(&1, [0.8, 0, 0, 0.8], idx: 30, idy: -10, odx: 12, ody: 3))
    end

    test "affine/3 with an output area", %{image: image} do
      assert_aligned(image, &Image.affine(&1, [1, 0, 0, 1], output_area: [33, 17, 300, 200]))
    end

    test "translate/4", %{image: image} do
      assert_aligned(image, &Image.translate(&1, 37, 21))
    end

    test "shear/4", %{image: image} do
      assert_aligned(image, &Image.shear(&1, 0.3, 0.2))
    end

    test "an RGB gain map with unequal axis scales" do
      image = Image.open!(image_path("gain_map_pixel_10_pro.jpg"))
      {:ok, rotated} = Image.rotate(image, 17)
      {:ok, gain_map} = Image.GainMap.gain_map(rotated)

      assert {2637, 2866, 3} = Image.shape(rotated)
      assert {1320, 1433, 3} = Image.shape(gain_map)
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

  # Operations that cannot yet transform the gain map remove it, so the result
  # saves as valid SDR rather than with a stale gain map.
  describe "operations that remove the gain map" do
    test "the coordinate remapping family", %{image: image} do
      corners = [{0, 0}, {479, 0}, {479, 259}, {0, 259}]
      {:ok, index} = Operation.xyz(480, 260)

      assert_gain_map_removed(Image.ripple(image))
      assert_gain_map_removed(Image.to_polar_coordinates(image))
      assert_gain_map_removed(Image.to_rectangular_coordinates(image))
      assert_gain_map_removed(Image.warp_perspective(image, corners, corners))
      {:ok, _destination, straightened} = Image.straighten_perspective(image, corners)
      assert_gain_map_removed({:ok, straightened})
      assert_gain_map_removed(Image.map(image, index))
    end

    test "compose/3 with one overlay and with a list", %{image: image} do
      overlay = Image.new!(40, 40, color: :white)

      assert_gain_map_removed(Image.compose(image, overlay))
      assert_gain_map_removed(Image.compose(image, [overlay, overlay]))
    end

    test "join/2", %{image: image} do
      assert_gain_map_removed(Image.join([image, image]))
    end
  end

  describe "colorspace conversion" do
    test "to the image's own colorspace keeps the gain map", %{image: image} do
      {:ok, converted} = Image.to_colorspace(image, :srgb)
      assert_marker_moved(round_trip(converted), @marker, {312, 140, 120, 80})
    end

    test "to another colorspace removes the gain map", %{image: image} do
      assert_gain_map_removed(Image.to_colorspace(image, :bw))
      assert_gain_map_removed(Image.to_colorspace(image, :lab))
    end

    test "with an ICC profile removes the gain map", %{image: image} do
      assert_gain_map_removed(Image.to_colorspace(image, :p3, []))
    end

    test "with_colorspace/3 round trips keep the gain map", %{image: image} do
      {:ok, adjusted} = Image.with_colorspace(image, :lab, fn lab -> {:ok, lab} end)
      assert_marker_moved(round_trip(adjusted), @marker, {312, 140, 120, 80})
    end
  end

  describe "feather/2" do
    # The single-band path crops and re-embeds the image; the gain map must
    # come through whole, not cropped.
    test "keeps the full gain map of a single-band image", %{image: image} do
      {:ok, single_band} = Operation.extract_band(image, 0)
      {:ok, feathered} = Image.feather(single_band)
      {:ok, gain_map} = Image.GainMap.gain_map(feathered)

      assert {480, 260, 1} = Image.shape(feathered)
      assert {240, 130, 1} = Image.shape(gain_map)
    end
  end

  defp assert_gain_map_removed(result) do
    assert {:ok, output} = result
    refute Image.GainMap.gain_map?(output)
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

  # Applies `transform` to the fixture and to a mask with the marker drawn on
  # it, then checks that the saved gain map's bright region is centred where
  # the transform put the mask's, to within a gain map pixel. The mask is the
  # oracle for where the transform moves the marker, independent of the gain
  # map code.
  defp assert_aligned(image, transform) do
    {:ok, transformed} = transform.(image)
    {:ok, transformed_mask} = transform.(marker_mask())
    {reloaded, gain_map} = round_trip(transformed)

    {mask_x, mask_y} = centroid(transformed_mask)
    {gain_x, gain_y} = centroid(gain_map)
    x_scale = Image.width(reloaded) / Image.width(gain_map)
    y_scale = Image.height(reloaded) / Image.height(gain_map)

    # JPEG has no alpha band, so only the dimensions are compared.
    assert {Image.width(reloaded), Image.height(reloaded)} ==
             {Image.width(transformed), Image.height(transformed)}

    assert_in_delta gain_x * x_scale, mask_x, 2
    assert_in_delta gain_y * y_scale, mask_y, 2
  end

  defp marker_mask do
    {left, top, width, height} = @marker
    {:ok, marker} = Operation.black(width, height)
    {:ok, marker} = Operation.linear(marker, [1.0], [255.0])
    {:ok, mask} = Operation.black(480, 260)
    {:ok, mask} = Operation.insert(mask, marker, left, top)
    {:ok, mask} = Operation.cast(mask, :VIPS_FORMAT_UCHAR)
    mask
  end

  # The centroid, in pixels, of the first band's pixels above half its maximum.
  defp centroid(image) do
    {:ok, band} = Operation.extract_band(image, 0)
    {:ok, {maximum, _position}} = Operation.max(band)
    {:ok, bright} = Operation.relational_const(band, :VIPS_OPERATION_RELATIONAL_MORE, [maximum / 2])
    {:ok, weight} = Operation.linear(bright, [1 / 255], [0.0])
    {:ok, coordinates} = Operation.xyz(Image.width(band), Image.height(band))
    {:ok, total} = Operation.avg(weight)

    for index <- [0, 1] do
      {:ok, coordinate} = Operation.extract_band(coordinates, index)
      {:ok, weighted} = Operation.multiply(coordinate, weight)
      {:ok, mean} = Operation.avg(weighted)
      mean / total + 0.5
    end
    |> List.to_tuple()
  end

  defp with_parameters(image, min_boost, max_boost, gamma) do
    {:ok, image} =
      Vix.Vips.Image.mutate(image, fn mutable ->
        :ok =
          Vix.Vips.MutableImage.set(
            mutable,
            "gainmap-min-content-boost",
            :VipsArrayDouble,
            min_boost
          )

        :ok =
          Vix.Vips.MutableImage.set(
            mutable,
            "gainmap-max-content-boost",
            :VipsArrayDouble,
            max_boost
          )

        Vix.Vips.MutableImage.set(mutable, "gainmap-gamma", :VipsArrayDouble, gamma)
      end)

    image
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
