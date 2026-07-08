defmodule Image.Rotate.Test do
  use ExUnit.Case, async: true

  alias Vix.Vips.Image, as: Vimage

  # A black canvas with a single white pixel drawn at (x, y). Gives us a
  # deterministic feature to track through a rotation.
  defp white_dot(width, height, x, y) do
    Image.new!(width, height, color: [0, 0, 0])
    |> Image.Draw.rect!(x, y, 1, 1, color: [255, 255, 255])
  end

  describe "Image.rotate/3 options" do
    test ":interpolate selects an interpolator from the public vocabulary" do
      image = white_dot(20, 20, 2, 3)

      for interpolator <- [:nearest, :bilinear, :bicubic, :lbb, :nohalo, :vsqbs] do
        assert {:ok, %Vimage{}} = Image.rotate(image, 45, interpolate: interpolator)
      end
    end

    test "rejects an unknown :interpolate value" do
      image = white_dot(20, 20, 2, 3)

      assert {:error, %Image.Error{reason: :invalid_option, value: {:interpolate, :unknown}}} =
               Image.rotate(image, 45, interpolate: :unknown)
    end

    test "rejects an unknown option" do
      image = white_dot(20, 20, 2, 3)

      assert {:error, %Image.Error{reason: :invalid_option, value: {:not_an_option, 1}}} =
               Image.rotate(image, 45, not_an_option: 1)
    end

    test "routes :background through to_pixel and fills the exposed canvas with it" do
      # A four-element (RGBA) background also exercises the alpha case the
      # original API could not express.
      image =
        Image.new!(20, 20, color: [0, 0, 0, 255])
        |> Image.Draw.rect!(2, 3, 1, 1, color: [255, 255, 255, 255])

      {:ok, result} = Image.rotate(image, 45, background: [10, 20, 30, 255])
      assert Image.bands(result) == 4
      assert Image.get_pixel!(result, 0, 0) == [10, 20, 30, 255]
    end

    test "accepts :average as the :background fill" do
      image = white_dot(20, 20, 2, 3)
      assert {:ok, %Vimage{}} = Image.rotate(image, 45, background: :average)
    end

    test "resolves :average against an image with an alpha band" do
      image = Image.new!(20, 20, color: [10, 20, 30, 255])

      assert {:ok, result} = Image.rotate(image, 45, background: :average)
      assert Image.bands(result) == 4
      assert Image.get_pixel!(result, 0, 0) == [10, 20, 30, 255]
    end

    test "rejects an invalid :background" do
      image = white_dot(20, 20, 2, 3)
      assert {:error, _reason} = Image.rotate(image, 45, background: :not_a_colour)
    end

    test "defaults :interpolate and leaves :background to libvips when unset" do
      image = white_dot(20, 20, 2, 3)
      {:ok, options} = Image.Options.Rotate.validate_options(image, [])

      assert %Vix.Vips.Interpolate{} = Keyword.get(options, :interpolate)
      # No default :background is injected so libvips keeps its native
      # fill (transparent for alpha images, black otherwise).
      refute Keyword.has_key?(options, :background)
    end

    test "preserves libvips' transparent fill for alpha images when :background is unset" do
      image =
        Image.new!(20, 20, color: [0, 0, 0, 255])
        |> Image.Draw.rect!(2, 3, 1, 1, color: [255, 255, 255, 255])

      {:ok, rotated} = Image.rotate(image, 45)
      assert Image.get_pixel!(rotated, 0, 0) == [0, 0, 0, 0]
    end

    test "rotate!/3 raises on error" do
      image = white_dot(20, 20, 2, 3)
      assert_raise Image.Error, fn -> Image.rotate!(image, 45, interpolate: :unknown) end
    end

    test "a 90-degree rotation still uses the discrete path despite options" do
      image = white_dot(20, 20, 2, 3)
      # No crash even though :interpolate/:background are resolved but unused.
      assert {:ok, %Vimage{}} = Image.rotate(image, 90, interpolate: :nearest, background: :red)
    end

    test "a partially transparent :background fill is reproduced exactly" do
      image = Image.new!(20, 20, color: [255, 0, 0, 255])

      {:ok, result} = Image.rotate(image, 45, background: [10, 20, 30, 40])

      # Corner is exposed canvas, center is source content.
      assert Image.get_pixel!(result, 1, 1) == [10, 20, 30, 40]
      assert Image.band_format(result) == Image.band_format(image)

      {width, height, 4} = Image.shape(result)
      assert Image.get_pixel!(result, div(width, 2), div(height, 2)) == [255, 0, 0, 255]
    end
  end
end
