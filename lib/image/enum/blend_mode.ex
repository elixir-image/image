defmodule Image.BlendMode do
  @moduledoc """
  Functions to define and validate the blending
  modes that can be applied when composing images.

  """

  @default_blend_mode :VIPS_BLEND_MODE_OVER

  @vips_blend_mode_list [
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

  # Convert the list of modes into a mapping
  # from an "Elixir friendly" term to the
  # underlying Vix/libvips terms

  @blend_mode_map @vips_blend_mode_list
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

  @typedoc """
  Blend mode to use when compositing images. See `Image.compose/3`.

  * `:over` the image shows what you would expect if you held two
    semi-transparent slides on top of each other. This is the default
    when composing images
  * `:clear` where the second image is drawn, the first is removed
  * `:source` the second image is drawn as if nothing were below
  * `:in` the first image is removed completely, the second is only
    drawn where the first was
  * `:out` the second is drawn only where the first isn't
  * `:atop` this leaves the first image mostly intact, but mixes
    both images in the overlapping area
  * `:dest` leaves the first image untouched, the second is discarded
    completely
  * `:dest_over` like `:over`, but swaps the arguments
  * `:dest_in` like `:in`, but swaps the arguments
  * `:dest_out` like `:out`, but swaps the arguments
  * `:dest_atop` like `:atop`, but swaps the arguments
  * `:xor` something like a difference operator
  * `:add` a bit like adding the two images
  * `:saturate` a bit like the darker of the two
  * `:multiply` at least as dark as the darker of the two inputs
  * `:screen` at least as light as the lighter of the inputs
  * `:overlay` multiplies or screens colors, depending on the lightness
  * `:darken` the darker of each component
  * `:lighten` the lighter of each component
  * `:colour_dodge` brighten first by a factor second
  * `:colour_burn` darken first by a factor of second
  * `:hard_light` multiply or screen, depending on lightness
  * `:soft_light` darken or lighten, depending on lightness
  * `:difference` difference of the two
  * `:exclusion` somewhat like :difference, but lower-contrast

  """
  @type t :: unquote(Enum.reduce(@blend_modes, &{:|, [], [&1, &2]}))

  @doc """
  Returns the known blending modes.

  See `t:Image.BlendMode.t/0` for a description
  of each mode.

  """
  def known_blend_modes do
    @blend_modes
  end

  @doc """
  Returns the default blend mode

  ### Example

      iex> Image.BlendMode.default_blend_mode
      :VIPS_BLEND_MODE_OVER

  """
  def default_blend_mode do
    @default_blend_mode
  end

  @doc """
  Normalizes and validates a blend mode.

  ### Argument

  * `blend_mode` is one of `Image.BlendMode.known_blend_modes/0`
    as either a `t:String.t/0` or an `atom`.

  ### Returns

  * `{:ok, atom_blend_mode}` where `atom_blend_mode` is
    a valid blend mode for `libvips`

  * `{:error, reason}`

  ### Examples

      iex> Image.BlendMode.validate_blend_mode :clear
      {:ok, :VIPS_BLEND_MODE_CLEAR}

      iex> Image.BlendMode.validate_blend_mode "Over"
      {:ok, :VIPS_BLEND_MODE_OVER}

      iex> Image.BlendMode.validate_blend_mode :VIPS_BLEND_MODE_XOR
      {:ok, :VIPS_BLEND_MODE_XOR}

      iex> Image.BlendMode.validate_blend_mode :woops
      {:error, {:error, "Unknown blend mode. Found :woops"}}

  """
  @spec validate_blend_mode(t() | nil) :: {:ok, atom()} | {:error, Image.error_message()}
  def validate_blend_mode(nil) do
    {:ok, default_blend_mode()}
  end

  def validate_blend_mode(blend_mode) when blend_mode in @vips_blend_mode_list do
    {:ok, blend_mode}
  end

  def validate_blend_mode(blend_mode) when is_atom(blend_mode) do
    case Map.fetch(@blend_mode_map, blend_mode) do
      {:ok, blend_mode} -> {:ok, blend_mode}
      :error -> {:error, unknown_blend_mode_error(blend_mode)}
    end
  end

  def validate_blend_mode(blend_mode) when is_binary(blend_mode) do
    blend_mode
    |> String.downcase()
    |> String.to_existing_atom()
    |> validate_blend_mode()
  rescue
    ArgumentError ->
      {:error, unknown_blend_mode_error(blend_mode)}
  end

  defp unknown_blend_mode_error(blend_mode) do
    {:error, "Unknown blend mode. Found #{inspect(blend_mode)}"}
  end
end
