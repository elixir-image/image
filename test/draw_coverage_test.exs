defmodule Image.DrawCoverage.Test do
  use ExUnit.Case, async: true

  alias Image.Draw
  alias Vix.Vips.Image, as: Vimage

  defp white_image do
    Image.new!(20, 20, color: :white)
  end

  defp bw_mask do
    Image.new!(10, 10, color: 255) |> Image.to_colorspace!(:bw)
  end

  describe "point/4" do
    test "draws a point on an image" do
      assert {:ok, %Vimage{} = drawn} = Draw.point(white_image(), 5, 5, color: :red)
      assert Image.get_pixel!(drawn, 5, 5) == [255, 0, 0]
      assert Image.get_pixel!(drawn, 6, 6) == [255, 255, 255]
    end

    test "adds an alpha band to the color for an image with alpha" do
      rgba = Image.new!(20, 20, color: [255, 255, 255, 255])

      assert {:ok, %Vimage{} = drawn} = Draw.point(rgba, 5, 5, color: :red)
      assert Image.get_pixel!(drawn, 5, 5) == [255, 0, 0, 255]
    end

    test "returns an error for an invalid option" do
      assert {:error,
              %Image.Error{message: "Invalid option or option value for draw_point: bogus: true"}} =
               Draw.point(white_image(), 1, 1, bogus: true)
    end

    test "returns an error for an unknown color" do
      assert {:error, _reason} = Draw.point(white_image(), 1, 1, color: :not_a_color)
    end

    test "point!/4 returns the image or raises" do
      drawn = Draw.point!(white_image(), 0, 0, color: :black)
      assert Image.get_pixel!(drawn, 0, 0) == [0, 0, 0]

      assert_raise Image.Error, fn ->
        Draw.point!(white_image(), 0, 0, color: :not_a_color)
      end
    end
  end

  describe "rect/6" do
    test "draws a filled rectangle" do
      assert {:ok, %Vimage{} = drawn} = Draw.rect(white_image(), 4, 4, 10, 10, color: :red)
      assert Image.get_pixel!(drawn, 8, 8) == [255, 0, 0]
      assert Image.get_pixel!(drawn, 1, 1) == [255, 255, 255]
    end

    test "draws an unfilled rectangle with a wide stroke" do
      assert {:ok, %Vimage{} = drawn} =
               Draw.rect(white_image(), 2, 2, 10, 10, color: :red, fill: false, stroke_width: 2)

      assert Image.get_pixel!(drawn, 3, 3) == [255, 0, 0]
      assert Image.get_pixel!(drawn, 7, 7) == [255, 255, 255]
    end

    test "returns an error for an invalid option" do
      assert {:error,
              %Image.Error{message: "Invalid option or option value for draw_rect: bogus: 1"}} =
               Draw.rect(white_image(), 1, 1, 2, 2, bogus: 1)
    end

    test "rect!/6 returns the image or raises" do
      drawn = Draw.rect!(white_image(), 4, 4, 10, 10, color: :blue)
      assert Image.get_pixel!(drawn, 8, 8) == [0, 0, 255]

      assert_raise Image.Error, fn ->
        Draw.rect!(white_image(), 4, 4, 10, 10, color: :not_a_color)
      end
    end
  end

  describe "circle/5" do
    test "draws a filled circle" do
      assert {:ok, %Vimage{} = drawn} = Draw.circle(white_image(), 10, 10, 5, color: :red)
      assert Image.get_pixel!(drawn, 10, 10) == [255, 0, 0]
      assert Image.get_pixel!(drawn, 0, 0) == [255, 255, 255]
    end

    test "draws an unfilled circle with a stroke width of 2" do
      assert {:ok, %Vimage{} = drawn} =
               Draw.circle(white_image(), 10, 10, 6, color: :blue, fill: false, stroke_width: 2)

      assert Image.get_pixel!(drawn, 10, 4) == [0, 0, 255]
      assert Image.get_pixel!(drawn, 10, 10) == [255, 255, 255]
    end

    test "draws an unfilled circle with a stroke width of 3" do
      assert {:ok, %Vimage{} = drawn} =
               Draw.circle(white_image(), 10, 10, 7, color: :blue, fill: false, stroke_width: 3)

      assert Image.get_pixel!(drawn, 10, 3) == [0, 0, 255]
      assert Image.get_pixel!(drawn, 10, 10) == [255, 255, 255]
    end

    test "returns an error for an invalid option" do
      assert {:error,
              %Image.Error{message: "Invalid option or option value for draw_circle: bogus: 1"}} =
               Draw.circle(white_image(), 10, 10, 5, bogus: 1)
    end

    test "circle!/5 returns the image or raises" do
      drawn = Draw.circle!(white_image(), 10, 10, 5, color: :green)
      assert Image.get_pixel!(drawn, 10, 10) == [0, 128, 0]

      assert_raise Image.Error, fn ->
        Draw.circle!(white_image(), 10, 10, 5, color: :not_a_color)
      end
    end
  end

  describe "line/6" do
    test "draws a line" do
      assert {:ok, %Vimage{} = drawn} = Draw.line(white_image(), 0, 0, 19, 19, color: :red)
      assert Image.get_pixel!(drawn, 10, 10) == [255, 0, 0]
      assert Image.get_pixel!(drawn, 0, 10) == [255, 255, 255]
    end

    test "returns an error for an invalid option" do
      assert {:error,
              %Image.Error{message: "Invalid option or option value for draw_line: bogus: 1"}} =
               Draw.line(white_image(), 0, 0, 19, 19, bogus: 1)
    end

    test "line!/6 returns the image or raises" do
      drawn = Draw.line!(white_image(), 0, 0, 19, 19, color: :red)
      assert Image.get_pixel!(drawn, 0, 0) == [255, 0, 0]

      assert_raise Image.Error, fn ->
        Draw.line!(white_image(), 0, 0, 19, 19, color: :not_a_color)
      end
    end
  end

  describe "flood/4" do
    test "flood fills an image from a starting point" do
      assert {:ok, {%Vimage{} = flooded, box}} =
               Draw.flood(white_image(), 0, 0, color: :red, equal: true)

      assert box == %{left: 0, top: 0, width: 20, height: 20}
      assert Image.get_pixel!(flooded, 10, 10) == [255, 0, 0]
    end

    test "returns an error for an invalid option" do
      assert {:error,
              %Image.Error{message: "Invalid option or option value for draw_flood: bogus: 1"}} =
               Draw.flood(white_image(), 0, 0, bogus: 1)
    end

    test "flood!/4 returns the image or raises" do
      flooded = Draw.flood!(white_image(), 0, 0, color: :red, equal: true)
      assert Image.get_pixel!(flooded, 10, 10) == [255, 0, 0]

      assert_raise Image.Error, fn ->
        Draw.flood!(white_image(), 0, 0, color: :not_a_color)
      end
    end
  end

  describe "mask/5" do
    test "draws a mask on an image" do
      assert {:ok, %Vimage{} = drawn} = Draw.mask(white_image(), bw_mask(), 2, 2, color: :blue)
      assert Image.get_pixel!(drawn, 5, 5) == [0, 0, 255]
      assert Image.get_pixel!(drawn, 15, 15) == [255, 255, 255]
    end

    test "returns an error for an invalid option" do
      assert {:error,
              %Image.Error{message: "Invalid option or option value for draw_mask: bogus: 1"}} =
               Draw.mask(white_image(), bw_mask(), 2, 2, bogus: 1)
    end
  end

  describe "image/5" do
    test "draws a sub-image over an image" do
      sub_image = Image.new!(5, 5, color: :green)

      assert {:ok, %Vimage{} = drawn} = Draw.image(white_image(), sub_image, 3, 3)
      assert Image.get_pixel!(drawn, 5, 5) == [0, 128, 0]
      assert Image.get_pixel!(drawn, 15, 15) == [255, 255, 255]
    end

    test "returns an error for an invalid combine mode" do
      sub_image = Image.new!(5, 5, color: :green)

      assert {:error, %Image.Error{message: message}} =
               Draw.image(white_image(), sub_image, 3, 3, mode: :not_a_mode)

      assert message =~ "Invalid combine mode"
    end

    test "returns an error for an invalid combine mode on a mutable image" do
      sub_image = Image.new!(5, 5, color: :green)

      assert {:ok, %Vimage{}} =
               Image.mutate(white_image(), fn mutable ->
                 assert {:error, %Image.Error{message: message}} =
                          Draw.image(mutable, sub_image, 3, 3, mode: :not_a_mode)

                 assert message =~ "Invalid combine mode"
                 :ok
               end)
    end

    test "image!/5 returns the image" do
      sub_image = Image.new!(5, 5, color: :green)

      drawn = Draw.image!(white_image(), sub_image, 3, 3)
      assert Image.get_pixel!(drawn, 5, 5) == [0, 128, 0]
    end
  end

  describe "smudge/6" do
    test "smudges a section of an image" do
      assert {:ok, %Vimage{} = smudged} = Draw.smudge(white_image(), 2, 2, 5, 5)
      assert Image.shape(smudged) == {20, 20, 3}
    end

    test "returns an error for an invalid option" do
      assert {:error,
              %Image.Error{message: "Invalid option or option value for draw_smudge: bogus: 1"}} =
               Draw.smudge(white_image(), 2, 2, 5, 5, bogus: 1)
    end
  end

  describe "drawing on a MutableImage within Image.mutate/2" do
    test "point, rect, circle and line mutate the image in place" do
      assert {:ok, %Vimage{} = mutated} =
               Image.mutate(white_image(), fn mutable ->
                 {:ok, _} = Draw.point(mutable, 1, 1, color: :red)
                 {:ok, _} = Draw.rect(mutable, 3, 3, 4, 4, color: :blue)
                 {:ok, _} = Draw.circle(mutable, 14, 14, 3, color: :green)
                 {:ok, _} = Draw.line(mutable, 0, 19, 19, 19, color: :black)
                 :ok
               end)

      assert Image.get_pixel!(mutated, 1, 1) == [255, 0, 0]
      assert Image.get_pixel!(mutated, 4, 4) == [0, 0, 255]
      assert Image.get_pixel!(mutated, 14, 14) == [0, 128, 0]
      assert Image.get_pixel!(mutated, 10, 19) == [0, 0, 0]
    end

    test "rect with a wide stroke mutates the image in place" do
      assert {:ok, %Vimage{} = mutated} =
               Image.mutate(white_image(), fn mutable ->
                 {:ok, _} =
                   Draw.rect(mutable, 2, 2, 10, 10, color: :red, fill: false, stroke_width: 2)

                 :ok
               end)

      assert Image.get_pixel!(mutated, 3, 3) == [255, 0, 0]
    end

    test "flood on a mutable image returns the bounding box" do
      assert {:ok, {%Vimage{} = flooded, box}} =
               Image.mutate(Image.new!(6, 6, color: :white), fn mutable ->
                 Draw.flood(mutable, 0, 0, color: :red, equal: true)
               end)

      assert box == %{left: 0, top: 0, width: 6, height: 6}
      assert Image.get_pixel!(flooded, 3, 3) == [255, 0, 0]
    end

    test "mask on a mutable image" do
      assert {:ok, %Vimage{} = mutated} =
               Image.mutate(white_image(), fn mutable ->
                 {:ok, _} = Draw.mask(mutable, bw_mask(), 5, 5, color: :blue)
                 :ok
               end)

      assert Image.get_pixel!(mutated, 8, 8) == [0, 0, 255]
    end

    test "smudge on a mutable image" do
      assert {:ok, %Vimage{} = mutated} =
               Image.mutate(white_image(), fn mutable ->
                 {:ok, _} = Draw.smudge(mutable, 2, 2, 5, 5)
                 :ok
               end)

      assert Image.shape(mutated) == {20, 20, 3}
    end

    test "image on a mutable image" do
      sub_image = Image.new!(5, 5, color: :green)

      assert {:ok, %Vimage{} = mutated} =
               Image.mutate(white_image(), fn mutable ->
                 {:ok, _} = Draw.image(mutable, sub_image, 3, 3)
                 :ok
               end)

      assert Image.get_pixel!(mutated, 5, 5) == [0, 128, 0]
    end

    test "invalid options on a mutable image return an error" do
      assert {:ok, %Vimage{}} =
               Image.mutate(white_image(), fn mutable ->
                 assert {:error,
                         %Image.Error{
                           message: "Invalid option or option value for draw_point: bogus: true"
                         }} =
                          Draw.point(mutable, 1, 1, bogus: true)

                 :ok
               end)
    end
  end

  describe "Image.Options.Draw" do
    test "validate_options/3 passes a map through unchanged" do
      options = %{color: [1, 2, 3]}
      assert Image.Options.Draw.validate_options(white_image(), :point, options) == {:ok, options}
    end

    test "default options for each draw operation" do
      assert Image.Options.Draw.default_options(:point) == [color: :black]
      assert Image.Options.Draw.default_options(:line) == [color: :black]
      assert Image.Options.Draw.default_options(:mask) == [color: :black]

      assert Image.Options.Draw.default_options(:circle) == [
               color: :black,
               fill: true,
               stroke_width: 1
             ]

      assert Image.Options.Draw.default_options(:rect) == [
               color: :black,
               fill: true,
               stroke_width: 1
             ]

      assert Image.Options.Draw.default_options(:flood) == [color: :black, equal: false]
      assert Image.Options.Draw.default_options(:image) == [mode: :VIPS_COMBINE_MODE_SET]
      assert Image.Options.Draw.default_options(:smudge) == []
    end

    test "invalid_option/2 and invalid_option/3 build error structs" do
      assert %Image.Error{message: "Invalid option or option value for draw_rect: :bogus"} =
               Image.Options.Draw.invalid_option(:rect, :bogus)

      assert %Image.Error{message: "Invalid option or option value for draw_rect: bogus: 1"} =
               Image.Options.Draw.invalid_option(:rect, :bogus, 1)
    end

    test "flood :equal option is normalised to a boolean" do
      assert {:ok, %{equal: true}} =
               Image.Options.Draw.validate_options(white_image(), :flood, equal: 1)

      assert {:ok, %{equal: false}} =
               Image.Options.Draw.validate_options(white_image(), :flood, equal: nil)
    end

    test "fill option is normalised to a boolean" do
      assert {:ok, %{fill: true}} =
               Image.Options.Draw.validate_options(white_image(), :rect, fill: 1)

      assert {:ok, %{fill: false}} =
               Image.Options.Draw.validate_options(white_image(), :circle, fill: false)
    end
  end
end
