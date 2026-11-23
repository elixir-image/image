defmodule Image.Options.Generation.Test do
  use ExUnit.Case, async: true

  import Image.TestSupport

  alias Vix.Vips.Image, as: Vimage

  describe "Image.radial_gradient/3 options" do
    test "with default options" do
      assert {:ok, %Vimage{}} = Image.radial_gradient(20, 20)
    end

    test "with named colors" do
      assert {:ok, %Vimage{}} =
               Image.radial_gradient(20, 20, start_color: :red, finish_color: :blue)
    end

    test "with numeric colors of 3 and 4 elements" do
      assert {:ok, %Vimage{}} =
               Image.radial_gradient(20, 20,
                 start_color: [0, 0, 0, 128],
                 finish_color: [255, 255, 255]
               )
    end

    test "with valid :feather and :radius" do
      assert {:ok, %Vimage{}} = Image.radial_gradient(20, 20, feather: 5, radius: 1.5)
    end

    test "with an invalid :start_color" do
      assert {:error, %Image.Error{}} =
               Image.radial_gradient(20, 20, start_color: :not_a_color)
    end

    test "with an invalid :finish_color" do
      assert {:error, %Image.Error{}} =
               Image.radial_gradient(20, 20, finish_color: "no such color")
    end

    test "with a zero :feather" do
      assert {:error, %Image.Error{}} = Image.radial_gradient(20, 20, feather: 0)
    end

    test "with a :feather greater than 10" do
      assert {:error, %Image.Error{}} = Image.radial_gradient(20, 20, feather: 11)
    end

    test "with a non-numeric :radius" do
      assert {:error, %Image.Error{}} = Image.radial_gradient(20, 20, radius: "big")
    end

    test "with an unknown option" do
      assert {:error, %Image.Error{}} = Image.radial_gradient(20, 20, angle: 45)
    end
  end

  describe "Image.radial_gradient/3 centre" do
    @start [0, 0, 0, 255]
    @finish [200, 100, 50, 255]

    defp gradient_pixel(options, x, y) do
      options = Keyword.merge([start_color: @start, finish_color: @finish], options)
      {:ok, gradient} = Image.radial_gradient(100, 50, options)
      {:ok, pixel} = Image.get_pixel(gradient, x, y)

      Enum.map(pixel, &round/1)
    end

    test "defaults to the middle of the image" do
      assert gradient_pixel([], 50, 25) == @start
      assert gradient_pixel([x: :center, y: :middle], 50, 25) == @start
    end

    test "at a pixel offset" do
      assert gradient_pixel([x: 10, y: 5], 10, 5) == @start
    end

    test "at a negative pixel offset from the right and bottom" do
      assert gradient_pixel([x: -10, y: -5], 90, 45) == @start
    end

    test "at a fraction of the width and height" do
      assert gradient_pixel([x: 0.25, y: 0.2], 25, 10) == @start
    end

    test "at the edges named by keyword" do
      assert gradient_pixel([x: :left, y: :top], 0, 0) == @start

      assert gradient_pixel([x: :right, y: :bottom], 99, 49) ==
               gradient_pixel([x: 100, y: 50], 99, 49)
    end

    test "off the canvas" do
      assert {:ok, %Vimage{}} = Image.radial_gradient(100, 50, x: -0.5, y: 1.5)
      assert {:ok, %Vimage{}} = Image.radial_gradient(100, 50, x: 400, y: -400)
    end

    test "never passes the finish color beyond the radius" do
      for options <- [[], [x: :right, y: :bottom], [x: -0.5, y: 1.5]] do
        options = Keyword.merge([start_color: @start, finish_color: @finish], options)
        {:ok, gradient} = Image.radial_gradient(100, 50, options)

        for band <- 0..2 do
          {maximum, _extras} = Vix.Vips.Operation.max!(gradient[band])
          assert maximum <= Enum.at(@finish, band) + 0.001
        end
      end
    end

    test "with an :x keyword for the other axis" do
      assert {:error, %Image.Error{}} = Image.radial_gradient(20, 20, x: :middle)
    end

    test "with a :y keyword for the other axis" do
      assert {:error, %Image.Error{}} = Image.radial_gradient(20, 20, y: :center)
    end

    test "with a string centre" do
      assert {:error, %Image.Error{}} = Image.radial_gradient(20, 20, x: "left")
    end
  end

  describe "Image.linear_gradient/3 options" do
    test "with default options" do
      assert {:ok, %Vimage{}} = Image.linear_gradient(20, 20)
    end

    test "with named colors" do
      assert {:ok, %Vimage{}} =
               Image.linear_gradient(20, 20, start_color: :blue, finish_color: :green)
    end

    test "with numeric colors" do
      assert {:ok, %Vimage{}} =
               Image.linear_gradient(20, 20,
                 start_color: [255, 0, 0],
                 finish_color: [0, 0, 255, 255]
               )
    end

    test "with a valid :angle" do
      assert {:ok, %Vimage{}} = Image.linear_gradient(20, 20, angle: 45)
    end

    test "with an :angle greater than 360 degrees" do
      assert {:ok, %Vimage{}} = Image.linear_gradient(20, 20, angle: 400)
    end

    test "with an invalid :start_color" do
      assert {:error, %Image.Error{}} =
               Image.linear_gradient(20, 20, start_color: :not_a_color)
    end

    test "with a non-numeric :angle" do
      assert {:error, %Image.Error{}} = Image.linear_gradient(20, 20, angle: "steep")
    end

    test "with an unknown option" do
      assert {:error, %Image.Error{}} = Image.linear_gradient(20, 20, feather: 1)
    end

    test "from an existing image" do
      image = Image.new!(20, 20, color: :red)
      assert {:ok, %Vimage{}} = Image.linear_gradient(image, angle: 90)
    end
  end

  describe "Image.meme/3 options" do
    setup do
      {:ok, image} = Image.open(image_path("Kip_small.jpg"))
      {:ok, image: image}
    end

    test "with default options", %{image: image} do
      assert {:ok, %Vimage{}} = Image.meme(image, "One simply cannot")
    end

    test "with valid options", %{image: image} do
      assert {:ok, %Vimage{}} =
               Image.meme(image, "Headline",
                 text: "Some text",
                 weight: :normal,
                 transform: :none,
                 justify: true,
                 color: :yellow,
                 outline_color: :blue,
                 margin: 10,
                 headline_size: 30,
                 text_size: 20
               )
    end

    test "with a valid :font", %{image: image} do
      assert {:ok, %Vimage{}} = Image.meme(image, "Headline", font: "Helvetica")
    end

    test "with an invalid :weight", %{image: image} do
      assert {:error, %Image.Error{}} = Image.meme(image, "Headline", weight: :black)
    end

    test "with an invalid :transform", %{image: image} do
      assert {:error, %Image.Error{}} = Image.meme(image, "Headline", transform: :reverse)
    end

    test "with a non-boolean :justify", %{image: image} do
      assert {:error, %Image.Error{}} = Image.meme(image, "Headline", justify: "yes")
    end

    test "with an invalid :color", %{image: image} do
      assert {:error, %Image.Error{}} = Image.meme(image, "Headline", color: :not_a_color)
    end

    test "with an invalid :outline_color", %{image: image} do
      assert {:error, %Image.Error{}} =
               Image.meme(image, "Headline", outline_color: :not_a_color)
    end

    test "with a non-binary :text", %{image: image} do
      assert {:error, %Image.Error{}} = Image.meme(image, "Headline", text: 123)
    end

    test "with a non-binary :font", %{image: image} do
      assert {:error, %Image.Error{}} = Image.meme(image, "Headline", font: :impact)
    end

    test "with a zero :margin", %{image: image} do
      assert {:error, %Image.Error{}} = Image.meme(image, "Headline", margin: 0)
    end

    test "with a zero :headline_size", %{image: image} do
      assert {:error, %Image.Error{}} = Image.meme(image, "Headline", headline_size: 0)
    end

    test "with a zero :text_size", %{image: image} do
      assert {:error, %Image.Error{}} = Image.meme(image, "Headline", text_size: 0)
    end

    test "with a :font_file that does not exist", %{image: image} do
      assert {:error, %Image.Error{message: message}} =
               Image.meme(image, "Headline", font_file: "/no/such/font.ttf")

      assert message =~ "could not be found"
    end

    test "with an unknown option", %{image: image} do
      assert {:error, %Image.Error{}} = Image.meme(image, "Headline", subtitle: "nope")
    end
  end

  describe "Image.Histogram.as_svg/2 options" do
    setup do
      {:ok, image: Image.new!(20, 20, color: :red)}
    end

    test "with default options", %{image: image} do
      assert {:ok, svg} = Image.Histogram.as_svg(image)
      assert svg =~ "<svg"
      assert svg =~ ~s(width="auto")
      assert svg =~ ~s(height="auto")
    end

    test "with integer :width and :height", %{image: image} do
      assert {:ok, svg} = Image.Histogram.as_svg(image, width: 100, height: 150)
      assert svg =~ ~s(width="100px")
      assert svg =~ ~s(height="150px")
    end

    test "with explicit :auto dimensions", %{image: image} do
      assert {:ok, svg} = Image.Histogram.as_svg(image, width: :auto, height: :auto)
      assert svg =~ ~s(width="auto")
    end

    test "with a zero :width", %{image: image} do
      assert {:error, %Image.Error{}} = Image.Histogram.as_svg(image, width: 0)
    end

    test "with a negative :height", %{image: image} do
      assert {:error, %Image.Error{}} = Image.Histogram.as_svg(image, height: -2)
    end

    test "with a non-integer :width", %{image: image} do
      assert {:error, %Image.Error{}} = Image.Histogram.as_svg(image, width: "wide")
    end

    test "with an unknown option", %{image: image} do
      assert {:error, %Image.Error{}} = Image.Histogram.as_svg(image, depth: 8)
    end
  end
end
