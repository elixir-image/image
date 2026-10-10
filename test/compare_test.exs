defmodule Image.CompareTest do
  @moduledoc """
  Tests for `Image.compare/3`, in particular its handling of images that
  are not three-band sRGB.

  See https://github.com/elixir-image/image/issues/232.

  """
  use ExUnit.Case, async: true
  import Image.TestSupport

  @patch_pixels 100
  @image_pixels 40 * 40

  setup do
    base = Image.new!(40, 40, color: [100, 100, 100])
    {:ok, changed} = Image.Draw.rect(base, 5, 5, 10, 10, color: [200, 200, 200])
    %{base: base, changed: changed}
  end

  describe "Image.compare/3 band handling" do
    test "compares a one-band greyscale image with itself", %{base: base} do
      bitonal = Image.to_colorspace!(base, :bw)

      assert {:ok, +0.0, composed} = Image.compare(bitonal, bitonal)
      assert Image.bands(composed) == 2
    end

    test "compares a two-band greyscale image with an alpha band", %{base: base} do
      bitonal = base |> Image.to_colorspace!(:bw) |> Image.add_alpha!(:opaque)

      assert Image.bands(bitonal) == 2
      assert {:ok, +0.0, composed} = Image.compare(bitonal, bitonal)
      assert Image.bands(composed) == 2
    end

    test "reports the same metric whatever the band layout", %{base: base, changed: changed} do
      expected = @patch_pixels / @image_pixels

      layouts = [
        {:bw, & &1},
        {:bw, &Image.add_alpha!(&1, :opaque)},
        {:grey16, & &1},
        {:srgb, & &1},
        {:srgb, &Image.add_alpha!(&1, :opaque)}
      ]

      for {interpretation, wrap} <- layouts do
        a = base |> Image.to_colorspace!(interpretation) |> then(wrap)
        b = changed |> Image.to_colorspace!(interpretation) |> then(wrap)

        assert {:ok, metric, _composed} = Image.compare(a, b)

        assert_in_delta metric,
                        expected,
                        0.0001,
                        "#{interpretation}/#{Image.bands(a)} bands gave #{metric}"
      end
    end

    test "a CMYK comparison keeps the base image rather than blanking it",
         %{base: base, changed: changed} do
      a = Image.to_colorspace!(base, :cmyk)
      b = Image.to_colorspace!(changed, :cmyk)

      assert {:ok, _metric, composed} = Image.compare(a, b)

      background = Image.get_pixel!(composed, 30, 30)
      highlighted = Image.get_pixel!(composed, 10, 10)

      # Deriving the mask by converting the difference to greyscale
      # inverted it for CMYK, because a zero CMYK difference is "no ink"
      # and converts to white. The background came back blank white.
      refute Enum.all?(background, &(&1 >= 250)),
             "the unchanged background came back blank: #{inspect(background)}"

      assert highlighted != background
    end

    test "returns the composed difference in the interpretation it was given",
         %{base: base, changed: changed} do
      for interpretation <- [:bw, :grey16, :srgb] do
        a = Image.to_colorspace!(base, interpretation)
        b = Image.to_colorspace!(changed, interpretation)

        assert {:ok, _metric, composed} = Image.compare(a, b)

        assert Image.colorspace(composed) == interpretation,
               "#{interpretation} came back as #{Image.colorspace(composed)}"

        # The difference is drawn over the base, so the result gains an
        # alpha band but no colour bands.
        assert Image.bands(composed) == Image.bands(a) + 1
      end
    end

    test "the highlight is visible against the background whatever the band depth",
         %{base: base, changed: changed} do
      for interpretation <- [:bw, :grey16, :srgb] do
        a = Image.to_colorspace!(base, interpretation)
        b = Image.to_colorspace!(changed, interpretation)
        alpha_max = Image.Pixel.alpha_for!(a, :opaque)

        assert {:ok, _metric, composed} = Image.compare(a, b)

        highlighted = Image.get_pixel!(composed, 10, 10)
        background = Image.get_pixel!(composed, 30, 30)

        contrast =
          [highlighted, background]
          |> Enum.zip_with(fn [x, y] -> abs(x - y) end)
          |> Enum.max()
          |> Kernel./(alpha_max)

        # An 8-bit difference mask written into a 16-bit alpha band gives
        # a contrast near zero, which is the defect this guards.
        assert contrast > 0.05,
               "#{interpretation} highlight #{inspect(highlighted)} is only " <>
                 "#{Float.round(contrast * 100, 2)}% different from " <>
                 "#{inspect(background)}"
      end
    end
  end

  describe "Image.compare/3 on the image from issue 232" do
    # A single-band bitonal JPEG, contributed by the issue's reporter and
    # derived from a public domain scan of Jacob van Ruisdael's
    # "Il castello di Bentheim".
    setup do
      %{bitonal: Image.open!(image_path("bitonal.jpg"))}
    end

    test "is a one-band greyscale image, as reported", %{bitonal: image} do
      assert Image.bands(image) == 1
      assert Image.colorspace(image) == :bw
      refute Image.has_alpha?(image)
    end

    test "compares with itself", %{bitonal: image} do
      assert {:ok, +0.0, composed} = Image.compare(image, image)

      assert Image.colorspace(composed) == :bw
      assert Image.bands(composed) == 2
    end

    test "reports and highlights a real difference", %{bitonal: image} do
      {:ok, changed} = Image.Draw.rect(image, 10, 10, 50, 50, color: :white)

      assert {:ok, metric, composed} = Image.compare(image, changed)

      # The patch is 2_500 of 150_000 pixels. Some of it already matched
      # white, so the metric is at most that and definitely not zero.
      assert metric > 0.0
      assert metric <= 2_500 / (500 * 300)

      assert Image.get_pixel!(composed, 30, 30) != Image.get_pixel!(composed, 400, 250)
    end
  end
end
