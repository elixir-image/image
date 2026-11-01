defmodule Image.GainMapFixture.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Operation

  @moduletag :gain_map

  # The fixture's marker in base image pixels (left, top, width, height), as
  # written by test/support/generate_gain_map_fixture.exs.
  @marker {48, 40, 120, 80}

  setup_all do
    {:ok, image} = Image.open(image_path("gain_map.jpg"))
    {:ok, gain_map_data} = Vimage.header_value(image, "gainmap-data")
    {:ok, gain_map} = Vimage.new_from_buffer(gain_map_data)

    %{image: image, gain_map_image: gain_map}
  end

  test "loads through uhdrload with its gain map", %{image: image} do
    assert {:ok, "uhdrload"} = Vimage.header_value_as_string(image, "vips-loader")
    assert {:ok, 2} = Vimage.header_value(image, "gainmap-scale-factor")
    assert {480, 260, 3} = Image.shape(image)
  end

  test "the gain map is half the base resolution", %{gain_map_image: gain_map} do
    assert {240, 130, _bands} = Image.shape(gain_map)
  end

  test "the gain map is high only inside the top-left marker", %{gain_map_image: gain_map} do
    {left, top, width, height} = @marker

    # The marker in gain map pixels, inset by one pixel so the edges, where the
    # encoder blends, are not sampled. The same-sized region in each of the
    # other three quadrants must be much lower, which is what makes the marker
    # usable for checking that a transform moved the gain map with the image.
    {sample_width, sample_height} = {div(width, 2) - 2, div(height, 2) - 2}
    inside = mean(gain_map, div(left, 2) + 1, div(top, 2) + 1, sample_width, sample_height)

    for {quadrant_left, quadrant_top} <- [{160, 21}, {25, 80}, {160, 80}] do
      outside = mean(gain_map, quadrant_left, quadrant_top, sample_width, sample_height)
      assert inside > 3 * outside
    end
  end

  describe "third-party fixtures" do
    test "odd dimensions round the gain map up, to ceil(base / 2)" do
      {image, gain_map} = open_with_gain_map("gain_map_odd_dimensions.jpg")

      assert {129, 97, 3} = Image.shape(image)
      assert {65, 49, 1} = Image.shape(gain_map)
      assert {:ok, 2} = Vimage.header_value(image, "gainmap-scale-factor")
    end

    test "a Pixel camera file carries an RGB gain map with its own boost" do
      {image, gain_map} = open_with_gain_map("gain_map_pixel_10_pro.jpg")

      assert {2031, 2376, 3} = Image.shape(image)
      assert {1016, 1188, 3} = Image.shape(gain_map)

      {:ok, [max_boost | _]} = Vimage.header_value(image, "gainmap-max-content-boost")
      assert_in_delta max_boost, 1.79, 0.01
    end
  end

  defp open_with_gain_map(name) do
    {:ok, image} = Image.open(image_path(name))
    {:ok, gain_map_data} = Vimage.header_value(image, "gainmap-data")
    {:ok, gain_map} = Vimage.new_from_buffer(gain_map_data)
    {image, gain_map}
  end

  defp mean(image, left, top, width, height) do
    {:ok, region} = Operation.extract_area(image, left, top, width, height)
    {:ok, average} = Operation.avg(region)
    average
  end
end
