defmodule Image.Color do
  @moduledoc """
  Functions to manage image color and color conversion.

  """

  @typedoc """
  Reference to an ICC color profile

  * `:none` means no profile
  * `:cmyk`, `:srgb` and `:p3` refer to the built-in color profiles
  * `Path.t()` means any file system path. If the path is a relative
    path then is will be loaded from the systems profile directory.

  """
  @type icc_profile :: :none | :cmyk | :srgb | :p3 | Path.t()

  @typedoc """
  An rbg color expressed as a list of numbers.

  The number of list elements and the type
  varies depending on the image format, colorspace
  and dimensions.

  For a common `sRGB` image it will be a list of
  three of four images. If the fourth number is provided
  it will be considered as an alpha transparency band.

  """
  @type rgb_color :: [number()]

  @inbuilt_profiles [:none, :srgb, :cmyk, :p3]

  @doc """
  Guards whether a given value can be interpreted
  as a color value.

  """
  defguard is_color(color)
           when (is_number(color) and color > 0) or (is_list(color) and length(color) == 3)

  @doc """
  Guards whether a given profile is one of the inbuilt
  profiles.

  """
  defguard is_inbuilt_profile(profile) when profile in @inbuilt_profiles

  @doc """
  Returns the list of color profiles built into
  `libvips`.

  """
  def inbuilt_profiles, do: @inbuilt_profiles

  @doc """
  Returns a boolean indicating if the given
  profile is known and can be used for image
  operations.

  """
  def known_icc_profile?(profile) when profile in @inbuilt_profiles do
    true
  end

  def known_icc_profile?(path) do
    case Vix.Vips.Operation.profile_load(path) do
      {:ok, _} -> true
      _other -> false
    end
  end
end
