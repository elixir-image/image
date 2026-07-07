defmodule Image.WriteTest do
  use ExUnit.Case, async: true

  describe "write/3 format-specific options" do
    test "writes a GIF with the :effort option" do
      # Regression: conform_effort/2 had no clause for GIF although the
      # option is documented and admitted for GIF writes.
      image = Image.new!(10, 10, color: :red)

      assert {:ok, _binary} = Image.write(image, :memory, suffix: ".gif", effort: 7)
    end

    test "writes a PNG, WEBP, and GIF with boundary :effort values" do
      image = Image.new!(10, 10, color: :red)

      for suffix <- [".png", ".webp", ".gif"], effort <- [1, 10] do
        assert {:ok, _binary} = Image.write(image, :memory, suffix: suffix, effort: effort)
      end
    end
  end
end
