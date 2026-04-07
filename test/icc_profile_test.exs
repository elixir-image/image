defmodule Image.ICCProfileTest do
  use ExUnit.Case, async: true

  doctest Image.ICCProfile

  alias Image.ICCProfile

  test "inbuilt/0 lists the libvips built-ins" do
    assert ICCProfile.inbuilt() == [:none, :srgb, :cmyk, :p3]
  end

  test "known?/1 accepts built-ins" do
    assert ICCProfile.known?(:none)
    assert ICCProfile.known?(:srgb)
    assert ICCProfile.known?(:cmyk)
    assert ICCProfile.known?(:p3)
  end

  test "known?/1 rejects nonsense" do
    refute ICCProfile.known?("/nonexistent.icc")
    refute ICCProfile.known?(:not_a_profile)
    refute ICCProfile.known?(42)
  end

  test "is_inbuilt/1 defguard" do
    require ICCProfile

    cases = [
      {:srgb, true},
      {:cmyk, true},
      {:p3, true},
      {:none, true},
      {:something_else, false},
      {"/path.icc", false}
    ]

    for {value, expected} <- cases do
      result =
        case value do
          v when ICCProfile.is_inbuilt(v) -> true
          _ -> false
        end

      assert result == expected, "is_inbuilt(#{inspect(value)}) expected #{expected}"
    end
  end
end
