defmodule Image.Lqip.Css.Test do
  use ExUnit.Case, async: true

  import Image.TestSupport

  doctest Image.Lqip.Css

  # Builds an image from `bands`-per-pixel tuples in row-major order.
  defp image_3x3(pixels, bands) do
    binary = for tuple <- pixels, into: <<>>, do: for(v <- Tuple.to_list(tuple), into: <<>>, do: <<v>>)
    Vix.Vips.Image.new_from_binary(binary, 3, 3, bands, :VIPS_FORMAT_UCHAR)
  end

  @filler {0, 0, 0}

  # Reconstructs color c0 from a packed hex the way the LQIP CSS does, and
  # returns its chroma (max channel − min channel). Zero == perfectly neutral.
  defp c0_chroma("#" <> hex) do
    <<r, g, _b, _a>> = Base.decode16!(hex, case: :lower)
    red = div(r, 16) * 255 / 15
    green = rem(r, 16) * 255 / 15
    blue = div(g, 32) * 255 / 7
    Enum.max([red, green, blue]) - Enum.min([red, green, blue])
  end

  test "packs top-left, center and bottom-right into an 8-digit hex (reference vector)" do
    {:ok, image} =
      image_3x3(
        [
          {255, 0, 0}, @filler, @filler,
          @filler, {0, 255, 0}, @filler,
          @filler, @filler, {0, 0, 255}
        ],
        3
      )

    assert Image.Lqip.Css.encode(image) == {:ok, "#f001e007"}
  end

  test "ignores the alpha channel, matching the reference which samples only RGB" do
    {:ok, image} =
      image_3x3(
        [
          {255, 0, 0, 17}, {0, 0, 0, 255}, {0, 0, 0, 255},
          {0, 0, 0, 255}, {0, 255, 0, 3}, {0, 0, 0, 255},
          {0, 0, 0, 255}, {0, 0, 0, 255}, {0, 0, 255, 200}
        ],
        4
      )

    assert Image.Lqip.Css.encode(image) == {:ok, "#f001e007"}
  end

  test "encodes a single-band greyscale image by converting to sRGB" do
    {:ok, gray} = image_3x3([{40}, {80}, {120}, {160}, {200}, {240}, {10}, {50}, {90}], 1)

    assert {:ok, "#" <> rest} = Image.Lqip.Css.encode(gray)
    assert String.length(rest) == 8
  end

  test "encodes a real image to a well-formed hex value" do
    image = image_path("Kip_small.jpg") |> Image.open!()

    assert {:ok, "#" <> rest} = Image.Lqip.Css.encode(image)
    assert rest =~ ~r/^[0-9a-f]{8}$/
  end

  test "encode!/1 returns the bare hex string" do
    {:ok, image} =
      image_3x3(
        [
          {255, 0, 0}, @filler, @filler,
          @filler, {0, 255, 0}, @filler,
          @filler, @filler, {0, 0, 255}
        ],
        3
      )

    assert Image.Lqip.Css.encode!(image) == "#f001e007"
  end

  test "packs near-grey colors to a near-neutral value (chroma-aware)" do
    {:ok, grey} = image_3x3(List.duplicate({200, 200, 200}, 9), 3)

    {:ok, hex} = Image.Lqip.Css.encode(grey)

    # Naive per-channel rounding would give this grey a chroma of ~22 (a visible
    # tint); the perceptually-nearest packing keeps it near-neutral.
    assert c0_chroma(hex) <= 8
  end
end
