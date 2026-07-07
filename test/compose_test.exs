defmodule Image.ComposeTest do
  use ExUnit.Case, async: true

  describe "compose/3 with a composition list" do
    setup do
      base = Image.new!(50, 50, color: :white)
      overlay = Image.new!(10, 10, color: :red)
      {:ok, %{base: base, overlay: overlay}}
    end

    test "composes a valid list of overlays", %{base: base, overlay: overlay} do
      assert {:ok, %Vix.Vips.Image{}} =
               Image.compose(base, [{overlay, x: 5, y: 5}, {overlay, x: 20, y: 20}])
    end

    test "returns an error for an invalid composition option", %{base: base, overlay: overlay} do
      # Regression: an invalid option halted the reduction with the unwrapped
      # error, raising CaseClauseError instead of returning {:error, _}.
      assert {:error, %Image.Error{}} = Image.compose(base, [{overlay, x: "10"}])
    end

    test "returns a single-wrapped error for an unknown blend mode", %{
      base: base,
      overlay: overlay
    } do
      # Regression: unknown blend modes were double-wrapped as
      # {:error, {:error, %Image.Error{}}}.
      assert {:error, %Image.Error{message: message}} =
               Image.compose(base, [{overlay, blend_mode: :bogus}])

      assert message =~ "Unknown blend mode"
    end

    test "applies top-level options as defaults for each composition", %{
      base: base,
      overlay: overlay
    } do
      # Regression: options were silently ignored for composition lists.
      # An invalid top-level option must now surface as an error because
      # it applies to each composition.
      assert {:error, %Image.Error{}} =
               Image.compose(base, [overlay], blend_mode: :bogus)

      # And a valid top-level option is inherited by list entries.
      assert {:ok, %Vix.Vips.Image{}} =
               Image.compose(base, [overlay, overlay], blend_mode: :multiply, x: 1, y: 1)
    end
  end
end
