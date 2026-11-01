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

  describe "apply/1" do
    # The generated fixture lifts its marker to an HDR value of 4.0 and leaves
    # the rest at or below SDR white.
    test "renders the marker at its HDR value and the rest at SDR" do
      image = Image.open!(image_path("gain_map.jpg"))

      assert {:ok, hdr} = Image.GainMap.apply(image)
      assert {480, 260, 3} = Image.shape(hdr)
      assert :scrgb = Image.colorspace(hdr)
      refute Image.GainMap.gain_map?(hdr)

      assert_in_delta region_mean(hdr, 60, 50, 40, 30), 4.0, 0.1
      assert region_mean(hdr, 330, 160, 100, 60) <= 1.0
    end

    test "uses a gain map that an operation has transformed" do
      image = Image.open!(image_path("gain_map.jpg"))
      {:ok, cropped} = Image.crop(image, 30, 20, 300, 200)

      assert {:ok, hdr} = Image.GainMap.apply(cropped)
      assert {300, 200, 3} = Image.shape(hdr)
      assert_in_delta region_mean(hdr, 30, 30, 40, 30), 4.0, 0.1
    end

    test "converts an image without a gain map to scRGB with no boost" do
      image = Image.open!(image_path("Kip_small.jpg"))

      assert {:ok, sdr} = Image.GainMap.apply(image)
      assert :scrgb = Image.colorspace(sdr)
      assert {:ok, {max, _position}} = Operation.max(sdr)
      assert max <= 1.0
    end

    test "saving the result as a JPEG writes a new gain map" do
      image = Image.open!(image_path("gain_map.jpg"))
      {:ok, hdr} = Image.GainMap.apply(image)

      assert {:ok, jpeg} = Image.write(hdr, :memory, suffix: ".jpg")
      assert {:ok, reloaded} = Image.from_binary(jpeg)
      assert Image.GainMap.gain_map?(reloaded)
    end
  end

  describe "Image.open/2 :gain_map option" do
    test "keeps the gain map by default" do
      assert {:ok, image} = Image.open(image_path("gain_map.jpg"))
      assert Image.GainMap.gain_map?(image)
    end

    test ":drop removes it" do
      assert {:ok, image} = Image.open(image_path("gain_map.jpg"), gain_map: :drop)
      refute Image.GainMap.gain_map?(image)
    end

    test ":apply renders the image to HDR" do
      assert {:ok, image} = Image.open(image_path("gain_map.jpg"), gain_map: :apply)
      assert :scrgb = Image.colorspace(image)
      refute Image.GainMap.gain_map?(image)
    end

    test "works for an image given as a binary" do
      binary = File.read!(image_path("gain_map.jpg"))

      assert {:ok, kept} = Image.open(binary)
      assert Image.GainMap.gain_map?(kept)

      assert {:ok, dropped} = Image.open(binary, gain_map: :drop)
      refute Image.GainMap.gain_map?(dropped)
    end

    test "rejects an invalid value" do
      assert {:error, %Image.Error{reason: :invalid_option, value: {:gain_map, :bogus}}} =
               Image.open(image_path("gain_map.jpg"), gain_map: :bogus)
    end
  end

  # The Pixel camera file carries EXIF including GPS, so these check that the
  # personal metadata is stripped while the gain map is kept.
  # libvips selects the UltraHDR loader and saver by content, so each of these
  # routes is expected to carry the gain map without any help from Image.
  describe "binaries and streams" do
    setup do
      %{path: image_path("gain_map.jpg")}
    end

    test "Image.open/2 from a binary keeps the gain map", %{path: path} do
      assert {:ok, image} = Image.open(File.read!(path))
      assert Image.GainMap.gain_map?(image)
    end

    test "Image.open/2 from a stream keeps the gain map", %{path: path} do
      assert {:ok, image} = Image.open(File.stream!(path, 2048))
      assert Image.GainMap.gain_map?(image)
    end

    test "the :gain_map open option applies to a stream", %{path: path} do
      assert {:ok, dropped} = Image.open(File.stream!(path, 2048), gain_map: :drop)
      refute Image.GainMap.gain_map?(dropped)

      assert {:ok, applied} = Image.open(File.stream!(path, 2048), gain_map: :apply)
      assert Image.colorspace(applied) == :scrgb
    end

    @tag :tmp_dir
    test "Image.write/3 to a stream keeps the gain map", %{path: path, tmp_dir: tmp_dir} do
      out = Path.join(tmp_dir, "streamed.jpg")

      assert {:ok, _image} = Image.write(Image.open!(path), File.stream!(out), suffix: ".jpg")
      assert_gain_map_binary(File.read!(out))
    end

    test "Image.stream!/2 keeps the gain map", %{path: path} do
      jpeg =
        path
        |> Image.open!()
        |> Image.stream!(suffix: ".jpg")
        |> Enum.to_list()
        |> IO.iodata_to_binary()

      assert_gain_map_binary(jpeg)
    end

    test "Image.write/3 to a Plug.Conn keeps the gain map", %{path: path} do
      conn =
        :get
        |> Plug.Test.conn("/")
        |> Plug.Conn.send_chunked(200)

      assert {:ok, conn} = Image.write(Image.open!(path), conn, suffix: ".jpg")

      {_adapter, state} = conn.adapter
      assert_gain_map_binary(IO.iodata_to_binary(state.chunks))
    end
  end

  defp assert_gain_map_binary(jpeg) do
    assert {:ok, reloaded} = Image.from_binary(jpeg)
    assert Image.GainMap.gain_map?(reloaded)
  end

  describe "Image.write/3 metadata options" do
    setup do
      %{image: Image.open!(image_path("gain_map_pixel_10_pro.jpg"))}
    end

    test "strip_metadata keeps the gain map and strips the EXIF", %{image: image} do
      assert {:ok, jpeg} = Image.write(image, :memory, suffix: ".jpg", strip_metadata: true)
      assert_stripped_with_gain_map(jpeg)
    end

    @tag :tmp_dir
    test "strip_metadata does the same when writing to a file", %{image: image, tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "stripped.jpg")

      assert {:ok, _image} = Image.write(image, path, strip_metadata: true)
      assert_stripped_with_gain_map(File.read!(path))
    end

    test "minimize_file_size keeps the gain map and strips the EXIF", %{image: image} do
      assert {:ok, jpeg} = Image.write(image, :memory, suffix: ".jpg", minimize_file_size: true)
      assert_stripped_with_gain_map(jpeg)
    end

    test "a format without gain maps still strips cleanly", %{image: image} do
      assert {:ok, png} = Image.write(image, :memory, suffix: ".png", strip_metadata: true)
      assert {:ok, reloaded} = Image.from_binary(png)
      refute Image.GainMap.gain_map?(reloaded)
    end
  end

  defp assert_stripped_with_gain_map(jpeg) do
    {:ok, reloaded} = Image.from_binary(jpeg)
    {:ok, names} = Vimage.header_field_names(reloaded)

    assert Image.GainMap.gain_map?(reloaded)
    refute Enum.any?(names, &String.starts_with?(&1, "exif-ifd3-")), "GPS EXIF was not stripped"
    refute "exif-ifd0-Make" in names, "camera EXIF was not stripped"
  end

  defp region_mean(image, left, top, width, height) do
    {:ok, region} = Operation.extract_area(image, left, top, width, height)
    {:ok, mean} = Operation.avg(region)
    mean
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
