defmodule Image.ShapeCoverage.Test do
  use ExUnit.Case, async: true

  alias Image.Shape
  alias Vix.Vips.Image, as: Vimage

  describe "polygon/2" do
    test "from a list of points" do
      assert {:ok, %Vimage{} = polygon} =
               Shape.polygon([[0, 0], [100, 0], [50, 80]], fill_color: :red)

      assert Image.width(polygon) == 500
      assert Image.height(polygon) == 400
      assert Image.bands(polygon) == 4
    end

    test "from an SVG points string" do
      assert {:ok, %Vimage{} = polygon} =
               Shape.polygon("0,0 100,0 50,80", fill_color: :blue, width: 100, height: 100)

      assert Image.width(polygon) == 100
      assert Image.height(polygon) == 100
    end

    test "from a number of sides" do
      assert {:ok, %Vimage{} = hexagon} =
               Shape.polygon(6, radius: 50, rotation: 90, fill_color: :green)

      assert Image.width(hexagon) == 500
      assert Image.height(hexagon) == 433
    end

    test "with only a width option the height respects the aspect ratio" do
      assert {:ok, %Vimage{} = polygon} =
               Shape.polygon([[0, 0], [100, 0], [50, 80]], width: 200)

      assert Image.width(polygon) == 200
      assert Image.height(polygon) == 160
    end

    test "with only a height option the width respects the aspect ratio" do
      assert {:ok, %Vimage{} = polygon} =
               Shape.polygon([[0, 0], [100, 0], [50, 80]], height: 160)

      assert Image.width(polygon) == 200
      assert Image.height(polygon) == 160
    end

    test "returns an error with fewer than three points" do
      assert {:error, %Image.Error{message: message}} = Shape.polygon([[0, 0], [10, 10]])
      assert message =~ "A polygon requires at least 3 points"
    end

    test "returns an error when points are not [x, y] pairs" do
      assert {:error, %Image.Error{message: message}} =
               Shape.polygon([[0, 0], [10, 10], :bad])

      assert message =~ "Polygon points must be [x, y] pairs of numbers"
    end

    test "returns an error when points are collinear" do
      assert {:error, %Image.Error{message: message}} =
               Shape.polygon([[0, 0], [10, 0], [20, 0]])

      assert message =~ "must not all lie on a single horizontal or vertical line"
    end

    test "returns an error for an invalid token in a points string" do
      assert {:error, %Image.Error{message: message}} = Shape.polygon("0,0 abc,10 20,20")
      assert message == "Invalid value \"abc\" in polygon points string"
    end

    test "returns an error for an invalid opacity" do
      assert {:error, %Image.Error{message: "Invalid option or option value: opacity: 3.0"}} =
               Shape.polygon([[0, 0], [10, 0], [5, 8]], opacity: 3.0)
    end

    test "returns an error for an invalid fill color" do
      assert {:error,
              %Image.Error{message: "Invalid option or option value: fill_color: :not_a_color"}} =
               Shape.polygon([[0, 0], [10, 0], [5, 8]], fill_color: :not_a_color)
    end

    test "returns an error for an unknown option" do
      assert {:error, %Image.Error{message: "Invalid option or option value: {:bogus, 1}"}} =
               Shape.polygon([[0, 0], [10, 0], [5, 8]], bogus: 1)
    end

    test "polygon!/2 returns the image or raises" do
      assert %Vimage{} = Shape.polygon!([[0, 0], [100, 0], [50, 80]])

      assert_raise Image.Error, fn ->
        Shape.polygon!([[0, 0], [10, 10]])
      end
    end
  end

  describe "star/2" do
    test "with default options" do
      assert {:ok, %Vimage{} = star} = Shape.star()
      assert Image.width(star) == 500
    end

    test "with radius and rotation options" do
      assert {:ok, %Vimage{} = star} =
               Shape.star(6,
                 inner_radius: 30,
                 outer_radius: 100,
                 rotation: 45,
                 fill_color: :yellow
               )

      assert Image.width(star) == 500
    end

    test "star!/2 returns the image or raises" do
      assert %Vimage{} = Shape.star!(5, fill_color: :red)

      assert_raise Image.Error, fn ->
        Shape.star!(5, fill_color: :not_a_color)
      end
    end
  end

  describe "rect/3" do
    test "creates a rectangle image" do
      assert {:ok, %Vimage{} = rectangle} =
               Shape.rect(50, 100, fill_color: :red, stroke_color: :yellow)

      assert Image.width(rectangle) == 50
      assert Image.height(rectangle) == 100
    end

    test "returns an error for an invalid stroke width" do
      assert {:error, %Image.Error{message: "Invalid option or option value: stroke_width: -1"}} =
               Shape.rect(50, 100, stroke_width: -1)
    end

    test "rect!/3 returns the image or raises" do
      assert %Vimage{} = Shape.rect!(50, 100, fill_color: :red)

      assert_raise Image.Error, fn ->
        Shape.rect!(50, 100, stroke_width: -1)
      end
    end
  end

  describe "circle/2" do
    test "creates a circle image" do
      assert {:ok, %Vimage{} = circle} =
               Shape.circle(25, fill_color: :green, stroke_color: :blue)

      assert Image.width(circle) == 50
      assert Image.height(circle) == 50
    end

    test "returns an error for an invalid opacity" do
      assert {:error, %Image.Error{message: "Invalid option or option value: opacity: \"x\""}} =
               Shape.circle(25, opacity: "x")
    end

    test "circle!/2 returns the image or raises" do
      assert %Vimage{} = Shape.circle!(25, fill_color: :green)

      assert_raise Image.Error, fn ->
        Shape.circle!(25, opacity: "x")
      end
    end
  end

  describe "ellipse/3" do
    test "creates an ellipse image" do
      assert {:ok, %Vimage{} = ellipse} =
               Shape.ellipse(20, 40, fill_color: :green, stroke_color: :none)

      assert Image.width(ellipse) == 40
      assert Image.height(ellipse) == 80
    end

    test "returns an error for an invalid stroke color" do
      assert {:error,
              %Image.Error{message: "Invalid option or option value: stroke_color: :not_a_color"}} =
               Shape.ellipse(20, 40, stroke_color: :not_a_color)
    end

    test "ellipse!/3 returns the image or raises" do
      assert %Vimage{} = Shape.ellipse!(20, 40, fill_color: :green)

      assert_raise Image.Error, fn ->
        Shape.ellipse!(20, 40, stroke_color: :not_a_color)
      end
    end
  end

  describe "line/5" do
    test "creates a line image" do
      assert {:ok, %Vimage{} = line} =
               Shape.line(0, 0, 30, 40, stroke_color: :black, stroke_width: 2)

      assert Image.width(line) == 31
      assert Image.height(line) == 41
    end

    test "returns an error for an invalid stroke width" do
      assert {:error, %Image.Error{message: "Invalid option or option value: stroke_width: 0"}} =
               Shape.line(0, 0, 30, 40, stroke_width: 0)
    end

    test "line!/5 returns the image or raises" do
      assert %Vimage{} = Shape.line!(5, 5, 15, 15, stroke_width: 2, stroke_color: :white)

      assert_raise Image.Error, fn ->
        Shape.line!(0, 0, 30, 40, stroke_width: 0)
      end
    end
  end

  describe "rescale/5 and aspect_ratio/1" do
    test "rescale/5 rescales a number" do
      assert Shape.rescale(5, 0, 10, 0, 100) == 50
    end

    test "rescale/6 rescales a polygon" do
      assert Shape.rescale([[0, 0], [10, 10]], 0, 100, 0, 100) == [[0, 0], [100, 100]]
    end

    test "rescale/2 rescales a polygon to an image" do
      image = Image.new!(100, 50, color: :white)
      rescaled = Shape.rescale([[0, 0], [10, 5], [10, 10]], image)

      assert is_list(rescaled)
      assert Enum.all?(rescaled, &match?([x, y] when is_integer(x) and is_integer(y), &1))
    end

    test "aspect_ratio/1 of an image" do
      assert Shape.aspect_ratio(Image.new!(100, 50, color: :white)) == 2.0
    end

    test "aspect_ratio/1 of a polygon" do
      assert Shape.aspect_ratio([[0, 0], [100, 0], [100, 50]]) == 2.0
    end
  end

  describe "Image.Options.Shape" do
    test "validate_polygon_options/1 returns defaults as a map" do
      assert {:ok, options} = Image.Options.Shape.validate_polygon_options([])

      assert options.opacity == 0.7
      assert options.stroke_width == 1
      assert options.stroke_color == "white"
      assert options.fill_color == :transparent
    end

    test "an [r, g, b] color is converted to a hex string" do
      assert {:ok, %{fill_color: "#FF0000"}} =
               Image.Options.Shape.validate_polygon_options(fill_color: [255, 0, 0])
    end

    test "a :none color is converted to :transparent" do
      assert {:ok, %{stroke_color: :transparent}} =
               Image.Options.Shape.validate_polygon_options(stroke_color: :none)
    end

    test "a hex string color is accepted" do
      assert {:ok, %{fill_color: "#00FF00"}} =
               Image.Options.Shape.validate_polygon_options(fill_color: "#00FF00")
    end

    test "invalid width and height options return an error" do
      assert {:error, _reason} = Image.Options.Shape.validate_polygon_options(width: 0)
      assert {:error, _reason} = Image.Options.Shape.validate_polygon_options(height: -1)
    end
  end
end
