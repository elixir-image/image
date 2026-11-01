defmodule Image.GainMap.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.MutableImage
  alias Vix.Vips.Operation

  @moduletag :gain_map

  doctest Image.GainMap

  # The generated fixture's HDR marker in base image pixels.
  @marker {48, 40, 120, 80}

  describe "gain_map?/1 and gain_map/1" do
    test "decode the gain map of each fixture" do
      for {name, shape} <- [
            {"gain_map.jpg", {240, 130, 1}},
            {"gain_map_odd_dimensions.jpg", {65, 49, 1}},
            {"gain_map_pixel_10_pro.jpg", {1016, 1188, 3}}
          ] do
        image = Image.open!(image_path(name))

        assert Image.GainMap.gain_map?(image)
        assert {:ok, gain_map} = Image.GainMap.gain_map(image)
        assert Image.shape(gain_map) == shape
      end
    end

    test "prefer the decoded gainmap field over gainmap-data" do
      image = Image.open!(image_path("gain_map.jpg"))
      replacement = Image.new!(12, 7, color: 0, bands: 1)

      {:ok, image} =
        Vimage.mutate(image, &MutableImage.set(&1, "gainmap", :VipsImage, replacement))

      assert {:ok, gain_map} = Image.GainMap.gain_map(image)
      assert {12, 7, 1} = Image.shape(gain_map)
    end

    test "return an error for gain map data that is not a JPEG" do
      image = Image.open!(image_path("Kip_small.jpg"))

      {:ok, image} =
        Vimage.mutate(image, &MutableImage.set(&1, "gainmap-data", :VipsBlob, "not a jpeg"))

      assert {:error, %Image.Error{reason: :invalid_gain_map}} = Image.GainMap.gain_map(image)
    end
  end

  describe "info/1" do
    test "reads a camera file's parameters" do
      image = Image.open!(image_path("gain_map_pixel_10_pro.jpg"))

      assert {:ok, %Image.GainMap{} = info} = Image.GainMap.info(image)
      assert info.scale_factor == 2
      assert [max_boost, max_boost, max_boost] = info.max_content_boost
      assert_in_delta max_boost, 1.79, 0.01
      assert info.use_base_color_gamut
    end

    test "returns nil for an image without a gain map" do
      image = Image.open!(image_path("Kip_small.jpg"))
      assert {:ok, nil} = Image.GainMap.info(image)
    end
  end

  describe "remove/1" do
    test "the image then saves as a plain JPEG" do
      image = Image.open!(image_path("gain_map.jpg"))

      assert {:ok, sdr} = Image.GainMap.remove(image)
      assert {:ok, jpeg} = Image.write(sdr, :memory, suffix: ".jpg")
      assert {:ok, reloaded} = Image.from_binary(jpeg)
      refute Image.GainMap.gain_map?(reloaded)
    end

    test "returns an image without a gain map unchanged" do
      image = Image.open!(image_path("Kip_small.jpg"))
      assert {:ok, ^image} = Image.GainMap.remove(image)
    end
  end

  describe "carry/3" do
    test "carries a crop through to a correct UltraHDR file" do
      image = Image.open!(image_path("gain_map.jpg"))
      {left, top, width, height} = @marker

      result =
        image
        |> Operation.extract_area(left, top, width, height)
        |> Image.GainMap.carry(image, fn gain_map, scale ->
          {gain_left, gain_top, gain_width, gain_height} =
            Image.GainMap.scale_area(scale, gain_map, left, top, width, height)

          Operation.extract_area(gain_map, gain_left, gain_top, gain_width, gain_height)
        end)

      assert {:ok, cropped} = result
      assert {:ok, jpeg} = Image.write(cropped, :memory, suffix: ".jpg")
      assert {:ok, reloaded} = Image.from_binary(jpeg)
      assert {:ok, gain_map} = Image.GainMap.gain_map(reloaded)

      assert {120, 80, 3} = Image.shape(reloaded)
      assert {60, 40, 1} = Image.shape(gain_map)

      # The crop is exactly the marker, so the carried gain map is high
      # throughout, which a misaligned gain map would not be.
      assert {:ok, mean} = Operation.avg(gain_map)
      assert mean > 80
    end

    test "leaves an image without a gain map unchanged" do
      image = Image.open!(image_path("Kip_small.jpg"))
      {:ok, cropped} = Operation.extract_area(image, 0, 0, 10, 10)

      assert {:ok, ^cropped} =
               Image.GainMap.carry({:ok, cropped}, image, fn _gain_map, _scale ->
                 flunk("transform must not be called without a gain map")
               end)
    end

    test "removes the gain map when the transform fails" do
      image = Image.open!(image_path("gain_map.jpg"))
      {:ok, cropped} = Operation.extract_area(image, 0, 0, 10, 10)

      assert {:ok, output} =
               Image.GainMap.carry({:ok, cropped}, image, fn _gain_map, _scale ->
                 {:error, :failed}
               end)

      refute Image.GainMap.gain_map?(output)
    end

    test "passes an error result through" do
      image = Image.open!(image_path("gain_map.jpg"))

      assert {:error, :failed} =
               Image.GainMap.carry({:error, :failed}, image, fn _gain_map, _scale ->
                 flunk("transform must not be called for an error result")
               end)
    end
  end

  describe "unit_gain/2" do
    test "is 0 when the minimum boost is 1.0" do
      image = Image.open!(image_path("gain_map.jpg"))
      {:ok, gain_map} = Image.GainMap.gain_map(image)

      assert Image.GainMap.unit_gain(image, gain_map) == [0.0]
    end

    test "places no boost between a minimum below 1.0 and the maximum" do
      # log2(0.5) = -1 and log2(4) = 2, so no boost (log2 1 = 0) is a third of
      # the way up the range, and gamma 2 squares that.
      image =
        with_parameters(Image.open!(image_path("gain_map.jpg")), [0.5, 0.5, 0.5], [4.0, 4.0, 4.0], [
          1.0,
          1.0,
          2.0
        ])

      rgb_gain_map = Image.new!(4, 4, bands: 3)

      assert [first, second, third] = Image.GainMap.unit_gain(image, rgb_gain_map)
      assert_in_delta first, 255 / 3, 0.001
      assert_in_delta second, 255 / 3, 0.001
      assert_in_delta third, 255 / 9, 0.001
    end
  end

  defp with_parameters(image, min_boost, max_boost, gamma) do
    {:ok, image} =
      Vimage.mutate(image, fn mutable ->
        :ok = MutableImage.set(mutable, "gainmap-min-content-boost", :VipsArrayDouble, min_boost)
        :ok = MutableImage.set(mutable, "gainmap-max-content-boost", :VipsArrayDouble, max_boost)
        MutableImage.set(mutable, "gainmap-gamma", :VipsArrayDouble, gamma)
      end)

    image
  end

  describe "scale_area/6" do
    # The odd-dimension fixture's geometry: a 129x97 base with a 65x49 gain map.
    setup do
      %{scale: {65 / 129, 49 / 97}, gain_map: Image.new!(65, 49)}
    end

    test "maps the whole image to the whole gain map", %{scale: scale, gain_map: gain_map} do
      assert {0, 0, 65, 49} = Image.GainMap.scale_area(scale, gain_map, 0, 0, 129, 97)
    end

    test "rounds the near edges down and the far edges up", %{scale: scale, gain_map: gain_map} do
      assert {0, 0, 65, 49} = Image.GainMap.scale_area(scale, gain_map, 1, 1, 127, 95)
    end

    test "keeps a one-pixel area inside the gain map", %{scale: scale, gain_map: gain_map} do
      assert {64, 48, 1, 1} = Image.GainMap.scale_area(scale, gain_map, 128, 96, 1, 1)
    end
  end
end
