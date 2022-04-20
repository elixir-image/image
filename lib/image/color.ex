defmodule Image.Color do
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