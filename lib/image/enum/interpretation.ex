defmodule Image.Interpretation do
  @moduledoc """
  Defines the known color interpretations to which
  an image can be converted to and from.

  """

  @interpretation_map %{
    multiband: :VIPS_INTERPRETATION_MULTIBAND,
    bw: :VIPS_INTERPRETATION_B_W,
    histogram: :VIPS_INTERPRETATION_HISTOGRAM,
    xyz: :VIPS_INTERPRETATION_XYZ,
    lab: :VIPS_INTERPRETATION_LAB,
    cmyk: :VIPS_INTERPRETATION_CMYK,
    labq: :VIPS_INTERPRETATION_LABQ,
    rgb: :VIPS_INTERPRETATION_RGB,
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

  @reverse_interpretation Enum.map(@interpretation_map, fn {k, v} -> {v, k} end)
                          |> Map.new()

  @interpretation Map.keys(@interpretation_map)
  @vips_interpretation Map.values(@interpretation_map)

  @reverse_interpretation Enum.map(@interpretation_map, fn {k, v} -> {v, k} end)
                          |> Map.new()

  @typedoc """
  Defines the known colorspace interpretations.

  """
  @type t :: unquote(Enum.reduce(@interpretation, &{:|, [], [&1, &2]}))

  @doc """
  Returns the known colorspace interpretations

  """
  def known_interpretations do
    @interpretation
  end

  @doc """
  Normalizes and validates a color interpretation.

  ### Arguments

  * `interpretation` is any atom or string value
    in `Image.Interpretation.known_interpretations/0`.

  ### Returns

  * `{:error, normalized_interpretation}` or

  * `{:error, reason}`

  ### Examples

      iex> Image.Interpretation.validate_interpretation(:bw)
      {:ok, :VIPS_INTERPRETATION_B_W}

      iex> Image.Interpretation.validate_interpretation(:VIPS_INTERPRETATION_sRGB)
      {:ok, :VIPS_INTERPRETATION_sRGB}

      iex> Image.Interpretation.validate_interpretation(:unknown)
      {:error, "Unknown interpretation. Found :unknown"}

  """
  def validate_interpretation(interpretation) when interpretation in @vips_interpretation do
    {:ok, interpretation}
  end

  def validate_interpretation(interpretation) when is_atom(interpretation) do
    case Map.fetch(@interpretation_map, interpretation) do
      {:ok, interpretation} -> {:ok, interpretation}
      :error -> {:error, unknown_interpretation_error(interpretation)}
    end
  end

  def validate_interpretation(interpretation) when is_binary(interpretation) do
    interpretation
    |> String.downcase()
    |> String.to_existing_atom()
    |> validate_interpretation()
  rescue
    ArgumentError ->
      {:error, unknown_interpretation_error(interpretation)}
  end

  @doc false
  def decode_interpretation(interpretation) do
    Map.fetch!(@reverse_interpretation, interpretation)
  end

  defp unknown_interpretation_error(interpretation) do
    "Unknown interpretation. Found #{inspect(interpretation)}"
  end
end
