defmodule Image.Options.BlurEffects.Test do
  use ExUnit.Case, async: true

  alias Vix.Vips.Image, as: Vimage

  setup_all do
    {:ok, image: Image.new!(20, 20, color: :red)}
  end

  describe "Image.blur/2 options" do
    test "with default options", %{image: image} do
      assert {:ok, %Vimage{}} = Image.blur(image)
    end

    test "with a valid float :sigma", %{image: image} do
      assert {:ok, %Vimage{}} = Image.blur(image, sigma: 2.5)
    end

    test "with a valid integer :sigma", %{image: image} do
      assert {:ok, %Vimage{}} = Image.blur(image, sigma: 3)
    end

    test "with a valid :min_amplitude", %{image: image} do
      assert {:ok, %Vimage{}} = Image.blur(image, min_amplitude: 0.1)
    end

    test "with a zero :sigma", %{image: image} do
      assert {:error, %Image.Error{message: message}} = Image.blur(image, sigma: 0)
      assert message =~ "Invalid option"
    end

    test "with a negative :sigma", %{image: image} do
      assert {:error, %Image.Error{}} = Image.blur(image, sigma: -1.0)
    end

    test "with a non-numeric :sigma", %{image: image} do
      assert {:error, %Image.Error{}} = Image.blur(image, sigma: "big")
    end

    test "with an integer :min_amplitude", %{image: image} do
      assert {:error, %Image.Error{}} = Image.blur(image, min_amplitude: 1)
    end

    test "with an unknown option", %{image: image} do
      assert {:error, %Image.Error{}} = Image.blur(image, radius: 3)
    end

    test "validate_options/1 passes a map through unchanged" do
      assert {:ok, %{sigma: 1}} = Image.Options.Blur.validate_options(%{sigma: 1})
    end
  end

  describe "Image.local_contrast/2 options" do
    test "with default options", %{image: image} do
      assert {:ok, %Vimage{}} = Image.local_contrast(image)
    end

    test "with a valid :window_size", %{image: image} do
      assert {:ok, %Vimage{}} = Image.local_contrast(image, window_size: 5)
    end

    test "with a valid :max_slope", %{image: image} do
      assert {:ok, %Vimage{}} = Image.local_contrast(image, max_slope: 3)
    end

    test "with a zero :window_size", %{image: image} do
      assert {:error, %Image.Error{}} = Image.local_contrast(image, window_size: 0)
    end

    test "with a non-integer :window_size", %{image: image} do
      assert {:error, %Image.Error{}} = Image.local_contrast(image, window_size: 2.5)
    end

    test "with a negative :max_slope", %{image: image} do
      assert {:error, %Image.Error{}} = Image.local_contrast(image, max_slope: -1)
    end

    test "with an unknown option", %{image: image} do
      assert {:error, %Image.Error{}} = Image.local_contrast(image, window: 3)
    end
  end

  describe "Image.modulate/2 options" do
    test "with default options", %{image: image} do
      assert {:ok, %Vimage{}} = Image.modulate(image)
    end

    test "with valid :brightness, :saturation, :hue and :lightness", %{image: image} do
      assert {:ok, %Vimage{}} =
               Image.modulate(image,
                 brightness: 1.5,
                 saturation: 0.5,
                 hue: 180,
                 lightness: 10
               )
    end

    test "with a negative :brightness", %{image: image} do
      assert {:error, %Image.Error{}} = Image.modulate(image, brightness: -1.0)
    end

    test "with a non-numeric :saturation", %{image: image} do
      assert {:error, %Image.Error{}} = Image.modulate(image, saturation: "lots")
    end

    test "with a float :hue", %{image: image} do
      assert {:error, %Image.Error{}} = Image.modulate(image, hue: 1.5)
    end

    test "with a non-numeric :lightness", %{image: image} do
      assert {:error, %Image.Error{}} = Image.modulate(image, lightness: :dark)
    end

    test "with an unknown option", %{image: image} do
      assert {:error, %Image.Error{}} = Image.modulate(image, contrast: 1.0)
    end
  end

  describe "Image.vibrance/3 options" do
    test "with default options", %{image: image} do
      assert {:ok, %Vimage{}} = Image.vibrance(image, 1.2)
    end

    test "with a valid :threshold", %{image: image} do
      assert {:ok, %Vimage{}} = Image.vibrance(image, 0.8, threshold: 40)
    end

    test "with the maximum :threshold", %{image: image} do
      assert {:ok, %Vimage{}} = Image.vibrance(image, 1.2, threshold: 100)
    end

    test "with a zero :threshold", %{image: image} do
      assert {:error, %Image.Error{}} = Image.vibrance(image, 1.2, threshold: 0)
    end

    test "with a :threshold greater than 100", %{image: image} do
      assert {:error, %Image.Error{}} = Image.vibrance(image, 1.2, threshold: 101)
    end

    test "with a float :threshold", %{image: image} do
      assert {:error, %Image.Error{}} = Image.vibrance(image, 1.2, threshold: 50.0)
    end

    test "with an unknown option", %{image: image} do
      assert {:error, %Image.Error{}} = Image.vibrance(image, 1.2, strength: 5)
    end
  end

  describe "Image.apply_tone_curve/2 options" do
    test "with default options", %{image: image} do
      assert {:ok, %Vimage{}} = Image.apply_tone_curve(image)
    end

    test "with valid set points and adjustments", %{image: image} do
      assert {:ok, %Vimage{}} =
               Image.apply_tone_curve(image,
                 black_point: 10,
                 white_point: 90,
                 shadow_point: 0.1,
                 mid_point: 0.4,
                 highlight_point: 0.9,
                 shadows: 10,
                 mid_points: -10,
                 highlights: 30
               )
    end

    test "with a negative :black_point", %{image: image} do
      assert {:error, %Image.Error{}} = Image.apply_tone_curve(image, black_point: -1)
    end

    test "with a :white_point greater than 100", %{image: image} do
      assert {:error, %Image.Error{}} = Image.apply_tone_curve(image, white_point: 101)
    end

    test "with a :shadow_point greater than 1.0", %{image: image} do
      assert {:error, %Image.Error{}} = Image.apply_tone_curve(image, shadow_point: 1.2)
    end

    test "with an integer :mid_point", %{image: image} do
      assert {:error, %Image.Error{}} = Image.apply_tone_curve(image, mid_point: 5)
    end

    test "with an integer :highlight_point out of range", %{image: image} do
      assert {:error, %Image.Error{}} = Image.apply_tone_curve(image, highlight_point: 2.0)
    end

    test "with an out of range :shadows adjustment", %{image: image} do
      assert {:error, %Image.Error{}} = Image.apply_tone_curve(image, shadows: 31)
    end

    test "with an out of range :mid_points adjustment", %{image: image} do
      assert {:error, %Image.Error{}} = Image.apply_tone_curve(image, mid_points: -31)
    end

    test "with an out of range :highlights adjustment", %{image: image} do
      assert {:error, %Image.Error{}} = Image.apply_tone_curve(image, highlights: 100)
    end

    test "with an unknown option", %{image: image} do
      assert {:error, %Image.Error{}} = Image.apply_tone_curve(image, gamma: 2.2)
    end

    test "when :black_point is not less than :white_point", %{image: image} do
      assert {:error, %Image.Error{message: message}} =
               Image.apply_tone_curve(image, black_point: 50, white_point: 50)

      assert message =~ "White_point must be greater than black_point"
    end

    test "when :shadow_point is not less than :mid_point", %{image: image} do
      assert {:error, %Image.Error{message: message}} =
               Image.apply_tone_curve(image, shadow_point: 0.5, mid_point: 0.5)

      assert message =~ "Mid_point must be greater than shadow_point"
    end

    test "when :mid_point is not less than :highlight_point", %{image: image} do
      assert {:error, %Image.Error{message: message}} =
               Image.apply_tone_curve(image, mid_point: 0.9, highlight_point: 0.8)

      assert message =~ "Highlight_point must be greater than mid_point"
    end
  end

  describe "Image.equalize/2 and Image.Options.Equalize" do
    test "equalize with the default bands", %{image: image} do
      assert {:ok, %Vimage{}} = Image.equalize(image)
    end

    test "equalize with :each band", %{image: image} do
      assert {:ok, %Vimage{}} = Image.equalize(image, :each)
    end

    test "equalize with :luminance", %{image: image} do
      assert {:ok, %Vimage{}} = Image.equalize(image, :luminance)
    end

    test "equalize with invalid bands", %{image: image} do
      assert {:error, %Image.Error{message: message}} = Image.equalize(image, :bogus)
      assert message =~ "Invalid bands parameter"
    end

    test "validate_options with default options" do
      assert {:ok, %{bands: :all}} = Image.Options.Equalize.validate_options([])
    end

    test "validate_options with each valid band choice" do
      for bands <- [:all, :each, :luminance] do
        assert {:ok, %{bands: ^bands}} =
                 Image.Options.Equalize.validate_options(bands: bands)
      end
    end

    test "validate_options with an invalid :bands value" do
      assert {:error, %Image.Error{}} = Image.Options.Equalize.validate_options(bands: :bogus)
    end

    test "validate_options with an unknown option" do
      assert {:error, %Image.Error{}} = Image.Options.Equalize.validate_options(channel: :all)
    end
  end
end
