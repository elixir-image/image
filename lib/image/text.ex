defmodule Image.Text do
  @doc """
  Functions for the creation of images based
  upon text.

  """

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Operation
  alias Image.Options

  def new(string, options \\ []) when is_binary(string) and is_list(options) do
    with {:ok, options} <- Options.Text.validate_options(options),
         {:ok, string} <- escape_html_text(string),
         {:ok, text_layer} <- text(string, options),
         {:ok, text_with_background} <- add_background(text_layer, options) do
      pad_background(text_with_background, options)
    end
  end

  def text(string, options \\ [])

  def text(string, options) when is_list(options) do
    with {:ok, options} <- Options.Text.validate_options(options) do
      text(string, options)
    end
  end

  def text(string, %{} = options) do
    {:ok, text_layer} = render_text(string, options)

    if transparent_text?(options) do
      Image.convert_to_mask(text_layer)
    else
      {:ok, text_layer}
    end
  end

  def add_background(image, options \\ [])

  def add_background(%Vimage{} = image, options) when is_list(options) do
    with {:ok, options} <- Options.Text.validate_options(options) do
      add_background(image, options)
    end
  end

  def add_background(%Vimage{} = image, %{background_color: :none} = _options) do
    {:ok, image}
  end

  def add_background(%Vimage{} = image, %{} = options) do
    {:ok, background} = render_background(image, options)

    # If its transparent text then the image
    # is a mask and we add it as the alpha channel
    # otherwise just composite the two images

    if transparent_text?(options) do
      Operation.bandjoin([background, image])
    else
      Operation.composite2(background, image, :VIPS_BLEND_MODE_OVER)
    end
  end

  def pad_background(image, options \\ [])

  def pad_background(%Vimage{} = image, options) when is_list(options) do
    with {:ok, options} <- Options.Text.validate_options(options) do
      pad_background(image, options)
    end
  end

  def pad_background(%Vimage{} = image, %{background_color: :none} = _options) do
    {:ok, image}
  end

  def pad_background(%Vimage{} = image, %{} = options)  do
    padding =
      Map.get(options, :padding)

    options =
      options
      |> Map.put_new(:background_width, Image.width(image) + padding * 2)
      |> Map.put_new(:background_height, Image.height(image) + padding * 2)

    width = Map.get(options, :background_width)
    height = Map.get(options, :background_height)
    opacity = Map.get(options, :opacity)

    background_color =
      options
      |> Map.get(:background_color)
      |> Image.Color.rgba_color!(opacity)

    Operation.embed(image, padding, padding, width, height, background: background_color)
  end


  # For transparent text we need to render the text in
  # white which is then converted later to a transparency
  # mask

  defp render_text(text, %{text_fill_color: :transparent} = options) do
    render_text(text, Map.put(options, :text_fill_color, :white))
  end

  defp render_text(text, %{} = options) do
    height = Map.get(options, :height, round(options.font_size * 1.5))
    dy = div(height - options.font_size, 2)

    svg = """
    <svg height="#{options.font_size}px">
      <style type="text/css">
        svg text {
          font-family: #{options.font};
          font-size: #{options.font_size};
          font-weight: #{options.font_weight};
          fill: #{options.text_fill_color};
          stroke: #{options.text_stroke_color};
          stroke-width: #{options.text_stroke_width};
          text-anchor: middle;
        }
      </style>
      <text dy="#{dy}" x="50%" y="50%">#{text}</text>
    </svg>
    """

    {:ok, {image, _flags}} = Operation.svgload_buffer(svg)
    {:ok, image}
  end

  # Render a background rectangle and return
  # it without its alpha channel since we will
  # apply transparency from the text image

  defp render_background(image, %{} = options) do
    width = Map.get(options, :background_width, Image.width(image))
    height = Map.get(options, :background_height, Image.height(image))

    svg = """
    <svg width="#{width}px" height="#{height}px">
      <rect
        fill="#{options.background_color}"
        stroke="#{options.background_stroke}"
        stroke-width="#{options.background_stroke_width}"
        opacity="#{options.opacity}"
        width="100%"
        height="100%"
      />
    </svg>
    """

    {:ok, {rectangle, _flags}} = Operation.svgload_buffer(svg)

    if transparent_text?(options) do
      Operation.extract_band(rectangle, 0, n: 3)
    else
      {:ok, rectangle}
    end
  end

  defp transparent_text?(%{} = options) do
    Map.get(options, :text_fill_color) in [:transparent, nil]
  end

  defp escape_html_text({:safe, string}) do
    {:ok, string}
  end

  defp escape_html_text(string) do
    string =
      string
      |> Phoenix.HTML.html_escape()
      |> Phoenix.HTML.safe_to_string()

    {:ok, string}
  end
end
