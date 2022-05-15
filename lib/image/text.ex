defmodule Image.Text do
  alias Vix.Vips.Operation

  def plain(image, options \\ []) do
    font = Keyword.get(options, :font, "Helvetica")
    font_size = Keyword.get(options, :font_size, 50)
    font_weight = Keyword.get(options, :font_weight, "bold")
    font_color = Keyword.get(options, :font_color, "white")
    height = Keyword.get(options, :height, round(font_size * 1.5))
    width = Keyword.get(options, :width, Image.width(image))
    dy = div(height - font_size, 2)

    svg = """
    <svg>
      <style type="text/css">
        svg text {
          font-family: #{font};
          font-size: #{font_size}px;
          font-weight: #{font_weight};
          fill: #{font_color};
          stroke: #{font_color};
          text-anchor: middle;
          dominant-baseline: middle;
        }
      </style>
      <text dy="#{dy}px" x="50%" y="50%">
        Some jumbled text
      </text>
    </svg>
    """

    {:ok, {text, _}} = Operation.svgload_buffer(svg, disc: false)
    x = div(Image.width(image), 2) - div(Image.width(text), 2)
    y = div(Image.height(image), 2) - div(Image.height(text), 2)
    {:ok, image_with_text} = Operation.composite2(image, text, :VIPS_BLEND_MODE_OVER, x: 0, y: 0)

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
    font_color = Keyword.get(options, :font_color, "navy")
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

end
