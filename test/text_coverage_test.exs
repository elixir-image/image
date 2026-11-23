defmodule Image.TextCoverageTest do
  use ExUnit.Case, async: true

  alias Vix.Vips.Image, as: Vimage

  @markup ~s(<span color="red">Red</span> <span color="blue">Blue</span>)
  @red [255, 0, 0]
  @blue [0, 0, 255]
  @black [0, 0, 0]
  @white [255, 255, 255]

  describe "Image.Text.text/2" do
    test "renders text with default options as an image with alpha" do
      assert {:ok, %Vimage{} = image} = Image.Text.text("hello", font_size: 20)
      assert Image.bands(image) == 4
      assert Image.has_alpha?(image)
    end

    test "renders text with an explicit font and weight" do
      assert {:ok, %Vimage{}} =
               Image.Text.text("hello", font: "Helvetica", font_size: 20, font_weight: :bold)
    end

    test "renders text with a fill color" do
      assert {:ok, %Vimage{}} =
               Image.Text.text("hello", font_size: 20, text_fill_color: "red")
    end

    test "a background fill color and padding expands the image" do
      assert {:ok, plain} = Image.Text.text("hello", font_size: 20)

      assert {:ok, padded} =
               Image.Text.text("hello",
                 font_size: 20,
                 background_fill_color: "blue",
                 padding: 10
               )

      assert Image.width(padded) == Image.width(plain) + 20
      assert Image.height(padded) == Image.height(plain) + 20
    end

    test "padding can be expressed as a two-element list" do
      assert {:ok, plain} = Image.Text.text("hello", font_size: 20)

      assert {:ok, padded} =
               Image.Text.text("hello",
                 font_size: 20,
                 background_fill_color: "blue",
                 padding: [10, 5]
               )

      assert Image.width(padded) == Image.width(plain) + 20
      assert Image.height(padded) == Image.height(plain) + 10
    end

    test "a background stroke draws a border" do
      assert {:ok, %Vimage{}} =
               Image.Text.text("hello",
                 font_size: 20,
                 background_fill_color: "blue",
                 background_stroke_color: "red",
                 background_stroke_width: 2,
                 padding: 5
               )
    end

    test "transparent text forces a background" do
      assert {:ok, %Vimage{} = image} =
               Image.Text.text("hello", font_size: 20, text_fill_color: :transparent)

      assert Image.has_alpha?(image)
    end

    test "text can be positioned on a sized background" do
      assert {:ok, %Vimage{} = image} =
               Image.Text.text("hi",
                 font_size: 20,
                 width: 200,
                 height: 100,
                 x: :center,
                 y: :middle,
                 background_fill_color: "green"
               )

      assert Image.width(image) == 200
      assert Image.height(image) == 100
    end

    test "letter spacing is accepted" do
      assert {:ok, %Vimage{}} =
               Image.Text.text("hello", font_size: 20, letter_spacing: 5)
    end

    test "returns an error for an invalid option" do
      assert {:error, _reason} = Image.Text.text("hello", align: :bogus)
    end

    test "returns an error when :height is given without :width" do
      assert {:error, %Image.Error{}} = Image.Text.text("hello", height: 100)
    end
  end

  describe "Image.Text.text!/2" do
    test "returns an image" do
      assert %Vimage{} = Image.Text.text!("hello", font_size: 20)
    end

    test "raises on an invalid option" do
      assert_raise Image.Error, fn ->
        Image.Text.text!("hello", align: :bogus)
      end
    end
  end

  describe "Image.Text.simple_text/2" do
    test "renders text without background or padding" do
      assert {:ok, %Vimage{} = image} = Image.Text.simple_text("hey", font_size: 20)
      assert Image.bands(image) == 4
    end

    test "returns an error for an invalid option" do
      assert {:error, _reason} = Image.Text.simple_text("hey", align: :bogus)
    end

    test "simple_text!/2 returns an image" do
      assert %Vimage{} = Image.Text.simple_text!("hey", font_size: 20)
    end

    test "simple_text!/2 raises on an invalid option" do
      assert_raise Image.Error, fn ->
        Image.Text.simple_text!("hey", align: :bogus)
      end
    end
  end

  describe "Image.Text markup colors" do
    test "text_fill_color: :markup takes each color from the Pango markup" do
      assert {:ok, image} =
               Image.Text.simple_text({:safe, @markup},
                 font_size: 20,
                 text_fill_color: :markup
               )

      colors = opaque_colors(image)

      assert MapSet.member?(colors, @red)
      assert MapSet.member?(colors, @blue)
    end

    test "the rendered image keeps the shape the other fill colors produce" do
      assert {:ok, image} =
               Image.Text.simple_text({:safe, @markup},
                 font_size: 20,
                 text_fill_color: :markup
               )

      assert Image.bands(image) == 4
      assert Image.has_alpha?(image)
      assert Image.colorspace(image) == :srgb
    end

    test "markup colors are ignored without the option, so the default is unchanged" do
      assert {:ok, image} = Image.Text.simple_text({:safe, @markup}, font_size: 20)

      assert opaque_colors(image) == MapSet.new([@white])
    end

    test "text with no color in the markup renders black" do
      assert {:ok, image} =
               Image.Text.simple_text("plain", font_size: 20, text_fill_color: :markup)

      assert opaque_colors(image) == MapSet.new([@black])
    end

    test "text/2 keeps the markup colors through background, padding and border" do
      assert {:ok, image} =
               Image.Text.text({:safe, @markup},
                 font_size: 20,
                 text_fill_color: :markup,
                 background_fill_color: :white,
                 padding: 10,
                 background_stroke_color: :black
               )

      colors = opaque_colors(image)

      assert MapSet.member?(colors, @red)
      assert MapSet.member?(colors, @blue)
    end

    test ":markup validates, and an unknown fill color still does not" do
      assert {:ok, _options} = Image.Options.Text.validate_options(text_fill_color: :markup)

      assert {:error, _reason} =
               Image.Options.Text.validate_options(text_fill_color: :not_a_color)
    end

    test ":transparent still renders a single band mask" do
      assert {:ok, image} =
               Image.Text.simple_text("hey", font_size: 20, text_fill_color: :transparent)

      assert Image.bands(image) == 1
    end
  end

  describe "Image.Text.add_background/2" do
    setup do
      {:ok, text} = Image.Text.simple_text("hey", font_size: 20)
      {:ok, %{text: text}}
    end

    test "adds a background color", %{text: text} do
      assert {:ok, %Vimage{} = with_background} =
               Image.Text.add_background(text, background_fill_color: "blue")

      assert Image.shape(with_background) == Image.shape(text)
    end

    test "default options preserve the image shape", %{text: text} do
      assert {:ok, unchanged} = Image.Text.add_background(text)
      assert Image.shape(unchanged) == Image.shape(text)
    end

    test "add_background!/2 returns an image", %{text: text} do
      assert %Vimage{} = Image.Text.add_background!(text, background_fill_color: "blue")
    end
  end

  describe "Image.Text.add_background_padding/2" do
    setup do
      {:ok, text} = Image.Text.simple_text("hey", font_size: 20)
      {:ok, %{text: text}}
    end

    test "expands the image by the padding", %{text: text} do
      assert {:ok, padded} =
               Image.Text.add_background_padding(text,
                 background_fill_color: "blue",
                 padding: 10
               )

      assert Image.width(padded) == Image.width(text) + 20
      assert Image.height(padded) == Image.height(text) + 20
    end

    test "add_background_padding!/2 returns an image", %{text: text} do
      assert %Vimage{} =
               Image.Text.add_background_padding!(text,
                 background_fill_color: "blue",
                 padding: 5
               )
    end
  end

  describe "Image.Text.add_background_border/2" do
    setup do
      {:ok, text} = Image.Text.simple_text("hey", font_size: 20)
      {:ok, %{text: text}}
    end

    test "adds a border when a stroke color and padding are provided", %{text: text} do
      assert {:ok, %Vimage{}} =
               Image.Text.add_background_border(text,
                 background_stroke_color: "red",
                 padding: 5
               )
    end

    test "default options preserve the image shape", %{text: text} do
      assert {:ok, unchanged} = Image.Text.add_background_border(text)
      assert Image.shape(unchanged) == Image.shape(text)
    end

    test "add_background_border!/2 returns an image", %{text: text} do
      assert %Vimage{} =
               Image.Text.add_background_border!(text,
                 background_stroke_color: "red",
                 padding: 5
               )
    end
  end

  describe "Image.Text fitting to lines" do
    @long "The quick brown fox jumps over the lazy dog and keeps on running far beyond the hills"

    test "uses the largest size when the text fits at it" do
      {:ok, fitted} =
        Image.Text.simple_text("Short", font_size: [60, 44], width: 600, max_lines: 1)

      {:ok, at_largest} = Image.Text.simple_text("Short", font_size: 60, width: 600)

      assert Image.shape(fitted) == Image.shape(at_largest)
    end

    test "steps down to the first size at which the text fits" do
      {:ok, fitted} = Image.Text.simple_text(@long, font_size: [60, 20], width: 600, max_lines: 2)
      {:ok, at_smaller} = Image.Text.simple_text(@long, font_size: 20, width: 600)

      assert Image.shape(fitted) == Image.shape(at_smaller)
    end

    test "shortens the text at the smallest size when it fits at none" do
      {:ok, unfitted} = Image.Text.simple_text(@long, font_size: 30, width: 300)
      {:ok, one_line} = Image.Text.simple_text(@long, font_size: 30)

      {:ok, fitted} = Image.Text.simple_text(@long, font_size: [30], width: 300, max_lines: 1)

      assert Image.width(fitted) <= 300
      assert Image.height(fitted) <= Image.height(one_line)
      assert Image.height(fitted) < Image.height(unfitted)
    end

    test "a single size with :max_lines is fitted" do
      {:ok, fitted} = Image.Text.simple_text(@long, font_size: 30, width: 300, max_lines: 2)
      {:ok, unfitted} = Image.Text.simple_text(@long, font_size: 30, width: 300)
      {:ok, two_lines} = Image.Text.simple_text(@long <> "\n" <> @long, font_size: 30)

      assert Image.height(fitted) <= Image.height(two_lines)
      assert Image.height(fitted) < Image.height(unfitted)
    end

    test "the ellipsis is the one given" do
      options = [font_size: [30], width: 300, max_lines: 1]

      {:ok, with_ellipsis} = Image.Text.simple_text(@long, options)
      {:ok, without} = Image.Text.simple_text(@long, Keyword.put(options, :ellipsis, ""))

      assert Image.width(without) < Image.width(with_ellipsis)
    end

    test "a word wider than :width counts as not fitting" do
      word = "Supercalifragilisticexpialidocious"
      {:ok, unfitted} = Image.Text.simple_text(word, font_size: 30)
      assert Image.width(unfitted) > 150

      {:ok, fitted} = Image.Text.simple_text(word, font_size: [30], width: 150, max_lines: 1)
      assert Image.width(fitted) <= 150
    end

    test "fits within :height and is placed on a :width by :height canvas" do
      {:ok, fitted} =
        Image.Text.simple_text(@long, font_size: [60, 44, 30], width: 600, height: 100)

      assert {600, 100, 4} = Image.shape(fitted)
    end

    test "markup is clipped to the lines rather than shortened" do
      markup = {:safe, "<b>Bold</b> " <> @long}
      {:ok, one_line} = Image.Text.simple_text(@long, font_size: 30)

      {:ok, fitted} = Image.Text.simple_text(markup, font_size: [30], width: 300, max_lines: 1)

      assert Image.width(fitted) <= 300
      assert Image.height(fitted) <= Image.height(one_line)
    end

    test "a box too small for any text is clipped to the box" do
      {:ok, fitted} = Image.Text.simple_text(@long, font_size: [40], width: 20, max_lines: 1)

      assert Image.width(fitted) <= 20
    end

    test "text/2 adds its background to fitted text" do
      assert {:ok, %Vimage{} = image} =
               Image.Text.text(@long,
                 font_size: [60, 44],
                 width: 600,
                 max_lines: 2,
                 background_fill_color: :blue,
                 padding: 10
               )

      assert Image.width(image) <= 620
    end

    test "a list of sizes needs a :width" do
      assert {:error, %Image.Error{reason: :invalid_option}} =
               Image.Text.simple_text(@long, font_size: [60, 44])
    end

    test ":max_lines needs a :width" do
      assert {:error, %Image.Error{reason: :invalid_option}} =
               Image.Text.simple_text(@long, max_lines: 2)
    end

    test ":max_lines needs a font size other than 0" do
      assert {:error, %Image.Error{reason: :invalid_option}} =
               Image.Text.simple_text(@long, font_size: 0, width: 300, max_lines: 2)
    end

    test "invalid sizes, line counts and ellipses are errors" do
      for options <- [
            [font_size: []],
            [font_size: [40, 0]],
            [font_size: [40, 2.5]],
            [max_lines: 0],
            [max_lines: :two],
            [ellipsis: :dots]
          ] do
        assert {:error, %Image.Error{}} =
                 Image.Text.simple_text(@long, Keyword.put(options, :width, 300))
      end
    end
  end

  # The distinct fully opaque colors in a four band image, read straight from
  # the pixel data. This is what the Pango markup determines.
  defp opaque_colors(image) do
    {:ok, binary} = Vimage.write_to_binary(image)

    for <<red::8, green::8, blue::8, alpha::8 <- binary>>, alpha == 255, into: MapSet.new() do
      [red, green, blue]
    end
  end
end
