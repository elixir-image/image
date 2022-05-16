defmodule Image.BlendMode do
  @moduledoc false

  @default_blend_mode :VIPS_BLEND_MODE_OVER

  @blend_mode_list [
    :VIPS_BLEND_MODE_CLEAR,
    :VIPS_BLEND_MODE_SOURCE,
    :VIPS_BLEND_MODE_OVER,
    :VIPS_BLEND_MODE_IN,
    :VIPS_BLEND_MODE_OUT,
    :VIPS_BLEND_MODE_ATOP,
    :VIPS_BLEND_MODE_DEST,
    :VIPS_BLEND_MODE_DEST_OVER,
    :VIPS_BLEND_MODE_DEST_IN,
    :VIPS_BLEND_MODE_DEST_OUT,
    :VIPS_BLEND_MODE_DEST_ATOP,
    :VIPS_BLEND_MODE_XOR,
    :VIPS_BLEND_MODE_ADD,
    :VIPS_BLEND_MODE_SATURATE,
    :VIPS_BLEND_MODE_MULTIPLY,
    :VIPS_BLEND_MODE_SCREEN,
    :VIPS_BLEND_MODE_OVERLAY,
    :VIPS_BLEND_MODE_DARKEN,
    :VIPS_BLEND_MODE_LIGHTEN,
    :VIPS_BLEND_MODE_COLOUR_DODGE,
    :VIPS_BLEND_MODE_COLOUR_BURN,
    :VIPS_BLEND_MODE_HARD_LIGHT,
    :VIPS_BLEND_MODE_SOFT_LIGHT,
    :VIPS_BLEND_MODE_DIFFERENCE,
    :VIPS_BLEND_MODE_EXCLUSION
  ]

  @blend_mode_map @blend_mode_list
  |> Enum.map(fn mode ->
    ["", key] =
      mode
      |> to_string
      |> String.downcase()
      |> String.split("vips_blend_mode_")

    {String.to_atom(key), mode}
  end)
  |> Map.new()

  @blend_modes Map.keys(@blend_mode_map)

  @doc """
  Returns the known colorspace interpretations

  """
  def known_blend_modes do
    @blend_modes
  end

  @doc false
  def validate_blend_mode(nil) do
    {:ok, @default_blend_mode}
  end

  def validate_blend_mode(blend_mode) do
    case Map.fetch(@blend_mode_map, blend_mode) do
      {:ok, interpretation} -> {:ok, blend_mode}
      :error -> {:error, "Unknown blend mode. Found #{inspect(blend_mode)}"}
    end
  end
end