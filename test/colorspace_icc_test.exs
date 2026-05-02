defmodule Image.Colorspace.ICC.Test do
  @moduledoc """
  Tests for the ICC-profile-driven `Image.to_colorspace/3`
  variant added in 0.67.0.
  """
  use ExUnit.Case, async: true
  import Image.TestSupport

  setup do
    %{hk: Image.open!(image_path("Hong-Kong-2015-07-1998.jpg"))}
  end

  describe "Image.to_colorspace/3" do
    test "converts via a libvips built-in profile (:srgb)", %{hk: image} do
      assert {:ok, converted} = Image.to_colorspace(image, :srgb, intent: :perceptual)
      assert Image.width(converted) == Image.width(image)
      assert Image.height(converted) == Image.height(image)
    end

    test ":depth: 16 produces a deeper output", %{hk: image} do
      assert {:ok, converted} = Image.to_colorspace(image, :srgb, depth: 16)
      band_format = Vix.Vips.Image.format(converted)
      assert band_format in [:VIPS_FORMAT_USHORT, :VIPS_FORMAT_SHORT]
    end

    test "all four intents are accepted", %{hk: image} do
      for intent <- [:relative, :perceptual, :saturation, :absolute] do
        assert {:ok, _} = Image.to_colorspace(image, :srgb, intent: intent)
      end
    end

    test "rejects an unknown ICC profile", %{hk: image} do
      assert {:error, %Image.Error{reason: :unknown_icc_profile}} =
               Image.to_colorspace(image, :not_a_profile, [])
    end

    test "rejects an unknown intent", %{hk: image} do
      assert {:error, %Image.Error{reason: :invalid_intent}} =
               Image.to_colorspace(image, :srgb, intent: :bogus)
    end

    test "rejects an invalid depth", %{hk: image} do
      assert {:error, %Image.Error{reason: :invalid_depth}} =
               Image.to_colorspace(image, :srgb, depth: 12)
    end
  end
end
