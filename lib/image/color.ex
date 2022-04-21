defmodule Image.Color do
  @typedoc """
  Reference to an ICC color profile

  * `:none` means no profile
  * `:cmyk`, `:srgb` and `:p3` refer to the built-in color profiles
  * `Path.t()` means any file system path. If the path is a relative
    path then is will be loaded from the systems profile directory.

  """
  @type icc_profile :: :none | :cmyk | :srgb | :p3 | Path.t()

  @type rgb_color :: [number()]

  @inbuilt_profiles [:none, :srgb, :cmyk, :p3]

  def inbuilt_profiles, do: @inbuilt_profiles

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
