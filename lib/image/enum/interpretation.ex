defmodule Image.Interpretation do
  @moduledoc """
  Defines the known color interpretations to which
  an image can be converted to and from.

  """
  @type interpretation ::
          :multiband
          | :bw
          | :histogram
          | :xyz
          | :lab
          | :cmyk
          | :labq
          | :rbg
          | :cmc
          | :lch
          | :labs
          | :srgb
          | :yxy
          | :fourier
          | :rgb16
          | :grey16
          | :matrix
          | :scrgb
          | :hsv

  @interpretation_map %{
    multiband: :VIPS_INTERPRETATION_MULTIBAND,
    bw: :VIPS_INTERPRETATION_B_W,
    histogram: :VIPS_INTERPRETATION_HISTOGRAM,
    xyz: :VIPS_INTERPRETATION_XYZ,
    lab: :VIPS_INTERPRETATION_LAB,
    cmyk: :VIPS_INTERPRETATION_CMYK,
    labq: :VIPS_INTERPRETATION_LABQ,
    rbg: :VIPS_INTERPRETATION_RGB,
    cmc: :VIPS_INTERPRETATION_CMC,
    lch: :VIPS_INTERPRETATION_LCH,
    labs: :VIPS_INTERPRETATION_LABS,
    srgb: :VIPS_INTERPRETATION_sRGB,
    yxy: :VIPS_INTERPRETATION_YXY,
    fourier: :VIPS_INTERPRETATION_FOURIER,
    rgb16: :VIPS_INTERPRETATION_RGB16,
    grey16: :VIPS_INTERPRETATION_GREY16,
    matrix: :VIPS_INTERPRETATION_MATRIX,
    scrgb: :VIPS_INTERPRETATION_scRGB,
    hsv: :VIPS_INTERPRETATION_HSV
  }

  @interpretation Map.keys(@interpretation_map)

  @doc """
  Returns the known colorspace interpretations

  """
  def known_interpretations do
    @interpretation
  end

  @doc false
  def vips_interpretation(interpretation) when is_atom(interpretation) do
    case Map.fetch(@interpretation_map, interpretation) do
      {:ok, interpretation} -> {:ok, interpretation}
      :error -> {:error, "Unknown interpretation. Found #{inspect(interpretation)}"}
    end
  end
end
