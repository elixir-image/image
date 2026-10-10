defmodule Image.CompareTest do
  @moduledoc """
  Tests for `Image.compare/3`, in particular its handling of images that
  are not three-band sRGB.

  See https://github.com/elixir-image/image/issues/232.

  """
  use ExUnit.Case, async: true

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
end
