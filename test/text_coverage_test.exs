defmodule Image.TextCoverageTest do
  use ExUnit.Case, async: true

  alias Vix.Vips.Image, as: Vimage

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
end
