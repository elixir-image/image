defmodule Image.Text do
  alias Vix.Vips.Operation

  def plain(image, options \\ []) do
    font = Keyword.get(options, :font, "Helvetica")
    font_size = Keyword.get(options, :font_size, 50)
    font_weight = Keyword.get(options, :font_weight, "normal")
    font_color = Keyword.get(options, :font_color, "white")
    height = Keyword.get(options, :height, round(font_size * 1.5))
    dy = div(height - font_size, 2)

    svg = """
    <svg height="#{font_size}px">
      <style type="text/css">
        svg text {
          font-family: #{font};
          font-size: #{font_size}px;
          font-weight: #{font_weight};
          fill: #{font_color};
          stroke: #{font_color};
          text-anchor: middle;
        }
      </style>
      <text dy="#{dy}px" x="50%" y="50%">Some jumbled text</text>
    </svg>
    """

    {:ok, {text, _}} = Operation.svgload_buffer(svg, disc: false)
    Image.write(text, "/Users/kip/Desktop/plain2.png")

    x = div(Image.width(image), 2) - div(Image.width(text), 2)
    y = div(Image.height(image), 2) - div(Image.height(text), 2)

    {:ok, image_with_text} = Operation.composite2(image, text, :VIPS_BLEND_MODE_OVER, x: x, y: y)

    Image.write(image_with_text, "/Users/kip/Desktop/plain.png")
  end

  def overlay(image, options \\ []) do
    font = Keyword.get(options, :font, "Helvetica")
    font_size = Keyword.get(options, :font_size, 50)
    font_weight = Keyword.get(options, :font_weight, "bold")
    height = Keyword.get(options, :height, round(font_size * 1.5))
    width = Keyword.get(options, :width, Image.width(image))
    background_color = Keyword.get(options, :background_color, "black")
    opacity = Keyword.get(options, :opacity, 0.7)
    dy = div(height - font_size, 2)

    svg = """
    <svg width="#{width}px" height="#{height}px">
      <style type="text/css">
        svg text {
          font-family: #{font};
          font-size: #{font_size}px;
          font-weight: #{font_weight};
          text-anchor: middle;
          dominant-baseline: middle;
        }
      </style>

      <defs>
        <mask id="mask" x="0" y="0" width="100%" height="100%">
          <rect fill="white" opacity="#{opacity}" x="0" y="0" width="100%" height="100%" />
          <text dy="#{dy}px" x="50%" y="50%">
            Some jumbled text
          </text>
        </mask>
      </defs>
      <rect fill="#{background_color}" mask="url(#mask)" x="0" y="0" width="100%" height="100%" />
    </svg>
    """

    {:ok, {text, _}} = Operation.svgload_buffer(svg, disc: false)
    x = div(Image.width(image), 2) - div(Image.width(text), 2)
    y = div(Image.height(image), 2) - div(Image.height(text), 2)
    {:ok, image_with_text} = Operation.composite2(image, text, :VIPS_BLEND_MODE_OVER, x: x, y: y)

    Image.write(image_with_text, "/Users/kip/Desktop/overlay.png")
  end

  def text(image, options \\ []) do
    font = Keyword.get(options, :font, "Helvetica")
    font_size = Keyword.get(options, :font_size, 50)
    font_color = Keyword.get(options, :font_color, "white")
    font_weight = Keyword.get(options, :font_weight, "bold")
    height = Keyword.get(options, :height, round(font_size * 1.5))
    width = Keyword.get(options, :width, Image.width(image))
    background_color = Keyword.get(options, :background_color, "black")
    opacity = Keyword.get(options, :opacity, 0.7)
    dy = div(height - font_size, 2)

    svg = """
    <svg width="#{width}px" height="#{height}px">
      <style type="text/css">
        svg text {
          font-family: #{font};
          font-size: #{font_size}px;
          font-weight: #{font_weight};
          fill: #{font_color};
          text-anchor: middle;
          dominant-baseline: middle;
        }
      </style>

      <rect fill="#{background_color}" opacity="#{opacity}" width="100%" height="100%" />
      <text dy="#{dy}px" x="50%" y="50%">
        Some jumbled text
      </text>
    </svg>
    """

    {:ok, {text, _}} = Operation.svgload_buffer(svg, disc: false)
    x = div(Image.width(image), 2) - div(Image.width(text), 2)
    y = div(Image.height(image), 2) - div(Image.height(text), 2)
    {:ok, image_with_text} = Operation.composite2(image, text, :VIPS_BLEND_MODE_OVER, x: x, y: y)

    Image.write(image_with_text, "/Users/kip/Desktop/overlay2.png")
  end

  # Using Operation.text() seems to be about 17% slower and use more
  # memory

  def text2(image, options \\ []) do
    font = Keyword.get(options, :font, "Helvetica")
    font_size = Keyword.get(options, :font_size, 50)

    words = """
      <span foreground="white">Some jumbled text</span>
    """

    {:ok, {text, _flags}} =
      Operation.text(words, font: "#{font} #{font_size}", rgba: true)

      x = div(Image.width(image), 2) - div(Image.width(text), 2)
      y = div(Image.height(image), 2) - div(Image.height(text), 2)

    {:ok, image_with_text} =
      Operation.composite2(image, text, :VIPS_BLEND_MODE_OVER, x: x, y: y)

    Image.write(image_with_text, "/Users/kip/Desktop/text2.png")

  end

  @alpha_channel 3

  def layer(image, options \\ []) do
    # The text layer
    {:ok, {text, _}} = render_text("This is jumbled text", options)
    {:ok, mask} = Operation.extract_band(text, @alpha_channel)
    {:ok, mask} = Operation.invert(mask)
    Image.write(text, "/Users/kip/Desktop/layer_1.png")

    # The background layer
    options =
      options
      |> Keyword.put_new(:background_width, Image.width(text))
      |> Keyword.put_new(:background_height, Image.height(text))

    {:ok, rectangle} = render_rectangle(options)
    Image.write(rectangle, "/Users/kip/Desktop/layer_2.png")

    # Composite and mask out the text
    {:ok, text_with_background} = Operation.bandjoin([rectangle, mask])
    Image.write(text_with_background, "/Users/kip/Desktop/layer_3.png")

    # Embed in a larger background
    padding = Keyword.get(options, :padding, 0)
    width = Image.width(text_with_background) + padding * 2
    height = Image.height(text_with_background) + padding * 2

    options =
      options
      |> Keyword.put(:background_width, width)
      |> Keyword.put(:background_height, height)
      |> Keyword.put_new(:background_color, "black")
      |> Keyword.put_new(:opacity, 0.7)

    {:ok, expanded_background} = render_rectangle(options)
    Image.write(expanded_background, "/Users/kip/Desktop/layer_4.png")

    background_color =
      options
      |> Keyword.get(:background_color)
      |> Image.Color.rgba_color!()

    {:ok, expanded} =
      Operation.embed(text_with_background, padding, padding, width, height,
        background: background_color);
    Image.write(expanded, "/Users/kip/Desktop/layer_5.png")
  end

  def render_text(text, options \\ []) do
    font = Keyword.get(options, :font, "Helvetica")
    font_size = Keyword.get(options, :font_size, 50)
    font_color = Keyword.get(options, :font_color, "white")
    font_weight = Keyword.get(options, :font_weight, "bold")
    height = Keyword.get(options, :height, round(font_size * 1.5))
    dy = div(height - font_size, 2)

    svg = """
    <svg height="#{font_size}px">
      <style type="text/css">
        svg text {
          font-family: #{font};
          font-size: #{font_size}px;
          font-weight: #{font_weight};
          fill: #{font_color};
          stroke: #{font_color};
          text-anchor: middle;
        }
      </style>
      <text dy="#{dy}px" x="50%" y="50%">#{text}</text>
    </svg>
    """

    Operation.svgload_buffer(svg)
  end

  def render_rectangle(options \\ []) do
    width = Keyword.get(options, :background_width)
    height = Keyword.get(options, :background_height)
    background_color = Keyword.get(options, :background_color)
    opacity = Keyword.get(options, :opacity)

    svg = """
    <svg width="#{width}px" height="#{height}px">
      <rect fill="#{background_color}" opacity="#{opacity}" width="100%" height="100%" />
    </svg>
    """

    {:ok, {rectangle, _flags}} = Operation.svgload_buffer(svg)
    Operation.extract_band(rectangle, 0, n: 3)
  end
end
