defmodule Image.PixelColorGapTest do
  use ExUnit.Case, async: true

  alias Image.Pixel
  alias Vix.Vips.Operation

  describe "Image.Pixel.to_pixel/3 pre-encoded list detection" do
    test "an in-range integer list passes through unchanged for an rgb16 image" do
      image = Image.new!(2, 2, color: :black) |> Image.to_colorspace!(:rgb16)
      assert Pixel.to_pixel(image, [10, 20, 30]) == {:ok, [10, 20, 30]}
    end

    test "a float list passes through unchanged for a lab image" do
      image = Image.new!(2, 2, color: :black) |> Image.to_colorspace!(:lab)
      assert Pixel.to_pixel(image, [50.0, 10.0, 10.0]) == {:ok, [50.0, 10.0, 10.0]}
    end

    test "a list for an unsupported interpretation is not pre-encoded and errors" do
      image = Image.new!(2, 2, color: :black)
      {:ok, yxy} = Operation.copy(image, interpretation: :VIPS_INTERPRETATION_YXY)

      assert {:error, message} = Pixel.to_pixel(yxy, [1, 2, 3])
      assert message =~ ":yxy interpretation"
    end

    test "a non-pre-encoded float list on a mutable image is converted" do
      image = Image.new!(2, 2, color: :black)

      {:ok, _image} =
        Image.mutate(image, fn mutable ->
          send(self(), {:pixel, Pixel.to_pixel(mutable, [0.5, 0.5, 0.5])})
          :ok
        end)

      assert_received {:pixel, {:ok, [r, g, b]}}
      assert Enum.all?([r, g, b], &(&1 in 127..128))
    end
  end

  describe "Image.Pixel.to_pixel/3 interpretation targets" do
    test "a 1-band grey16 image encodes to a single ushort luma value" do
      image = Image.new!(2, 2, color: :black) |> Image.to_colorspace!(:grey16)

      assert {:ok, [luma]} = Pixel.to_pixel(image, :red)
      assert is_integer(luma)
      assert luma in 0..65_535
      assert luma == 34_891
    end

    test "a 1-band lab image truncates the pixel to the band count" do
      lab = Image.new!(2, 2, color: :black) |> Image.to_colorspace!(:lab)
      band0 = lab[0]

      assert {:ok, [l]} = Pixel.to_pixel(band0, :red)
      assert_in_delta l, 53.24, 0.01
    end

    test "an image with more bands than the encoded pixel is padded" do
      image = Image.new!(2, 2, color: :black)
      {:ok, six_band} = Operation.bandjoin([image, image])

      assert {:ok, pixel} = Pixel.to_pixel(six_band, :red)
      assert length(pixel) == 6
      assert pixel == [255, 0, 0, 255, 255, 255]
    end
  end

  describe "Image.Pixel bang variants and opacity" do
    test "to_pixel! raises on an invalid color" do
      image = Image.new!(2, 2, color: :black)

      assert_raise Image.Error, fn ->
        Pixel.to_pixel!(image, "no-such-color")
      end
    end

    test "to_srgb! returns a pixel and raises on an invalid color" do
      assert Pixel.to_srgb!(:red) == [255, 0, 0]

      assert_raise Image.Error, fn ->
        Pixel.to_srgb!("no-such-color")
      end
    end

    test "max_opacity and min_opacity" do
      assert Pixel.max_opacity() == 255
      assert Pixel.min_opacity() == 0
    end

    test "out of gamut colors are clamped to the channel range" do
      assert Pixel.to_srgb(%Color.Lab{l: 150.0, a: 0.0, b: 0.0}) == {:ok, [255, 255, 255]}
      assert Pixel.to_srgb(%Color.Lab{l: -10.0, a: 0.0, b: 0.0}) == {:ok, [0, 0, 0]}
    end
  end

  describe "Image.Color.srgb_tensor_to_oklab/1 tensor type dispatch" do
    test "signed integer tensors are scaled by 1/255" do
      rgb = Nx.tensor([[255, 0, 0]], type: :s32)
      oklab = Image.Color.srgb_tensor_to_oklab(rgb)

      assert Nx.shape(oklab) == {1, 3}
      assert_in_delta Nx.to_number(oklab[0][0]), 0.6279, 0.001
    end

    test "float tensors are assumed to be in the unit range" do
      rgb = Nx.tensor([[1.0, 0.0, 0.0]], type: :f32)
      oklab = Image.Color.srgb_tensor_to_oklab(rgb)

      assert Nx.shape(oklab) == {1, 3}
      assert_in_delta Nx.to_number(oklab[0][0]), 0.6279, 0.001
    end

    test "bf16 tensors are assumed to be in the unit range" do
      rgb = Nx.tensor([[1.0, 0.0, 0.0]], type: :bf16)
      oklab = Image.Color.srgb_tensor_to_oklab(rgb)

      assert Nx.shape(oklab) == {1, 3}
      assert_in_delta Nx.to_number(oklab[0][0]), 0.6279, 0.01
    end
  end

  describe "Image.BackgroundColor.resolve/2" do
    test "resolving :average for an alpha image in an unsupported interpretation errors" do
      alpha_image = Image.new!(2, 2, color: [10, 20, 30, 255])
      {:ok, yxy_alpha} = Operation.copy(alpha_image, interpretation: :VIPS_INTERPRETATION_YXY)

      assert {:error, %Image.Error{message: message}} =
               Image.BackgroundColor.resolve(yxy_alpha, :average)

      assert message =~ "Could not construct alpha"
    end

    test "resolving an invalid color errors" do
      image = Image.new!(2, 2, color: :black)

      assert {:error, %Image.Error{message: message}} =
               Image.BackgroundColor.resolve(image, "no-such-color")

      assert message =~ "Invalid background color"
    end
  end

  describe "Image.Histogram" do
    setup do
      {:ok, image} = Image.new(8, 8, color: :red)
      {:ok, image: image}
    end

    test "as_svg! returns an svg string", %{image: image} do
      svg = Image.Histogram.as_svg!(image, width: 100, height: 100)
      assert is_binary(svg)
      assert svg =~ "<svg"
      assert svg =~ "100px"
    end

    test "as_svg! raises on invalid options", %{image: image} do
      assert_raise Image.Error, fn ->
        Image.Histogram.as_svg!(image, width: -1)
      end
    end

    test "as_image returns an image", %{image: image} do
      assert {:ok, %Vix.Vips.Image{} = histogram} =
               Image.Histogram.as_image(image, width: 50, height: 50)

      assert Image.width(histogram) == 50
    end

    test "as_image returns an error on invalid options", %{image: image} do
      assert {:error, %Image.Error{reason: :invalid_option}} =
               Image.Histogram.as_image(image, width: -1)
    end

    test "as_image! returns an image", %{image: image} do
      assert %Vix.Vips.Image{} = Image.Histogram.as_image!(image, width: 50, height: 50)
    end

    # Note: as_image!/2 currently returns an error tuple rather than
    # raising. This test documents the current behaviour.
    test "as_image! with invalid options returns an error tuple", %{image: image} do
      assert {:error, %Image.Error{reason: :invalid_option}} =
               Image.Histogram.as_image!(image, width: -1)
    end
  end
end
