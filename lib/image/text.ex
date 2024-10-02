defmodule Image.Text do
  @moduledoc """
  Functions for the creation of images from text.

  """

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Operation
  alias Image.Options

  @doc """
  Create a new image from the provided string and
  formatting options.

  `text/2` creates an image with the
  following steps:

  * Render the text
  * Add an optional background color
  * Expand the background according to the required padding

  The text can be rendered as a positive (the default)
  in which an image of the provided string is rendered
  in the provided font, weight, size, fill color and
  stroke color.

  It can also be rendered transparently in which case
  a background color is required against which the
  transparent text can be composed. If not provided,
  the background color will be black.

  After rendering the text and composing it against
  the (optional) background, the background can
  be expanded to provide some padding between the
  text and any base image onto which it is later
  composed.  The default no padding.

  ### The Pango markup language

  The text string can take advantage of
  [Pango markup language](https://docs.gtk.org/Pango/pango_markup.html) that
  provides some simple HTML-like text transformation
  capabilities. Note that some of the options to `Image.Text.text/2`,
  such as `:font_weight` and `:letter_spacing` operate by adding markup
  to the provided string.

  ### Arguments

  * `string` is any string. The string will be
    HTML-escaped to avoid malicious code injection. If you
    are completely confident that the text is safe then
    you can pass it by calling with `Phoenix.HTML.raw/1`
    on the string first.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  See also the options for `Image.Text.simple_text/2` which
  is ultimately called by this function.

  * `:font` is any font recognised on the host system.
    The default is"Helvetica".

  * `:font_size` is an integer font size in pixels. The
    default is `50`.

  * `:dpi` sets the resolution of the text generation. The
    default `72` which is suitable for screen output. `300`
    may be more appropriate for printed output.

  * `:font_weight` is the [font weight](https://developer.mozilla.org/en-US/docs/Web/CSS/font-weight).
    The alternatives `:normal`, `:bold`, `:lighter`, `:bolder`,
    or an integer between `1` and `1_000`. The default is `:normal`
    which is equivalent to `400`.

  * `:text_fill_color` is the fill color of the text.
    The default is "white". If set to `:transparent` then
    the text will be rendered transparently against
    a background. A black background will be forced if a
    `:background_fill_color` is not provided

  * `:background_fill_opacity` is the opacity of the background fill.
    It is a float between `0.0` and `1.0` where `0.0` means transparent
    and `1.0` means opaque. The default is `0.7`.

  * `:padding` is the padding in pixels between the
    text and the edge of the background.  It can be expressed
    as a single integer integer in which case the same padding
    is applied to all four sides of the image.  It can also
    be expressed as a list of two integers like `[0, 0]`.
    The first integer will be used as the padding for the
    left and right of the image. The second integer will be used
    for the top and bottom of the image.  Another alternative is
    to pass a `t:Vimage.t/0` in which case the padding will be derived
    from the image dimensions such that the background covers the
    whole of the image.  The default is `[0, 0]`.

  * `:align` indicates how multiple lines of text are aligned.
    The options are `:left`, `:right` and `:center`. The default
    is `:left`.

  * `:letter_spacing` is the amount of space in pixels between each letter.
    Default is `:normal`.

  * `:background_fill_color` is the background fill color behind
    the text. The default is `:none` which indicates no
    background. Note that if

  * `:background_stroke_color` is the colour of the outline
    of the background. The default is "none",

  * `:background_stroke_width` is the integer size in pixels
    of the background border. The default is `1`.

  * `:background_stroke_opacity` is the opacity of the background
    string. It is a float between `0.0` and `1.0` where `0.0` means
    transparent and `1.0` means opaque. The default is `0.7`.

  * `:width` is the maximum width of the generated text image in pixels. The
    default is calculated by the rendering engine based upon the font
    and other options.

  * `:height` is the maximum height of the generated text image in pixels. The
    default is calculated by the rendering engine based upon the font
    and other options.

  * `:x` is the horizontal location of the text on its background.
    The value is either a non-negative integer or one of `:left`,
    `:right` or `:center`. The default is `:center` if `:width` is
    specified and `:left` if it is not.

  * `:y` is the vertical location of the text on its background.
    The value is either a non-negative integer or one of `:top`,
    `:middle` or `:bottom`. The default is `:middle` if `:height`
    is specified and `:top` if it is not.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  """
  @spec text(Phoenix.HTML.safe() | String.t(), Options.Text.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def text(string, options \\ []) when is_list(options) do
    with {:ok, options} <- Options.Text.validate_options(options),
         {:ok, text_layer} <- simple_text(string, options),
         {:ok, with_background} <- add_background(text_layer, options),
         {:ok, with_padding} <- add_background_padding(with_background, options) do
      add_background_border(with_padding, options)
    end
  end

  @doc """
  Create a new image from the provided string and
  formatting options returning an image or raising
  an exception.

  `text!/2` creates an image with the
  following steps:

  * Render the text
  * Add an optional background color
  * Expand the background according to the required padding

  The text can be rendered as a positive (the default)
  in which an image of the provided string is rendered
  in the provided font, weight, size, fill color and
  stroke color.

  It can also be rendered transparently in which case
  a background color is required against which the
  transparent text can be composed. If not provided,
  the background color will be black.

  After rendering the text and composing it against
  the (optional) background, the background can
  be expanded to provide some padding between the
  text and any base image onto which it is later
  composed.  The default no padding.

  ### The Pango markup language

  The text string can take advantage of
  [Pango markup language](https://docs.gtk.org/Pango/pango_markup.html) that
  provides some simple HTML-like text transformation
  capabilities. Note that some of the options to `Image.Text.text/2`,
  such as `:font_weight` and `:letter_spacing` operate by adding markup
  to the provided string.

  ### Arguments

  * `string` is any string. The string will be
    HTML-escaped to avoid malicious code injection. If you
    are completely confident that the text is safe then
    you can pass it by calling with `Phoenix.HTML.raw/1`
    on the string first.

  * `options` is a `t:Keyword.t/0` list of options

  ### Options

  See also the options for `Image.Text.simple_text/2` which
  is ultimately called by this function.

  * `:font` is any font recognised on the host system.
    The default is"Helvetica".

  * `:font_size` is an integer font size in pixels. The
    default is `50`.

  * `:dpi` sets the resolution of the text generation. The
    default `72` which is suitable for screen output. `300`
    may be more appropriate for printed output.

  * `:font_weight` is the [font weight](https://developer.mozilla.org/en-US/docs/Web/CSS/font-weight).
    The alternatives `:normal`, `:bold`, `:lighter`, `:bolder`,
    or an integer between `1` and `1_000`. The default is `:normal`
    which is equivalent to `400`.

  * `:text_fill_color` is the fill color of the text.
    The default is "white". If set to `:transparent` then
    the text will be rendered transparently against
    a background. A black background will be forced if a
    `:background_fill_color` is not provided

  * `:background_fill_opacity` is the opacity of the background fill.
    It is a float between `0.0` and `1.0` where `0.0` means transparent
    and `1.0` means opaque. The default is `0.7`.

  * `:padding` is the padding in pixels between the
    text and the edge of the background.  It can be expressed
    as a single integer integer in which case the same padding
    is applied to all four sides of the image.  It can also
    be expressed as a list of two integers like `[0, 0]`.
    The first integer will be used as the padding for the
    left and right of the image. The second integer will be used
    for the top and bottom of the image.  Another alternative is
    to pass a `t:Vimage.t/0` in which case the padding will be derived
    from the image dimensions such that the background covers the
    whole of the image.  The default is `[0, 0]`.

  * `:align` indicates how multiple lines of text are aligned.
    The options are `:left`, `:right` and `:center`. The default
    is `:left`.

  * `:letter_spacing` is the amount of space in pixels between each letter.
    Default is `:normal`.

  * `:background_fill_color` is the background fill color behind
    the text. The default is `:none` which indicates no
    background. Note that if

  * `:background_stroke_color` is the colour of the outline
    of the background. The default is "none",

  * `:background_stroke_width` is the integer size in pixels
    of the background border. The default is `1`.

  * `:background_stroke_opacity` is the opacity of the background
    string. It is a float between `0.0` and `1.0` where `0.0` means
    transparent and `1.0` means opaque. The default is `0.7`.

  * `:width` is the maximum width of the generated text image in pixels. The
    default is calculated by the rendering engine based upon the font
    and other options.

  * `:height` is the maximum height of the generated text image in pixels. The
    default is calculated by the rendering engine based upon the font
    and other options.

  * `:x` is the horizontal location of the text on its background.
    The value is either a non-negative integer or one of `:left`,
    `:right` or `:center`. The default is `:center` if `:width` is
    specified and `:left` if it is not.

  * `:y` is the vertical location of the text on its background.
    The value is either a non-negative integer or one of `:top`,
    `:middle` or `:bottom`. The default is `:middle` if `:height`
    is specified and `:top` if it is not.

  ### Returns

  * `image` or

  * raises an exception

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  """
  @spec text!(String.t(), Keyword.t()) :: Vimage.t() | no_return()
  def text!(string, options \\ []) do
    case text(string, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Creates an image from the provided text.

  This function creates an image from the text
  but does not apply a background or padding.

  ### Arguments

  * `string` is any string. The string will be
    HTML-escaped to avoid malicious code injection. If you
    are completely confident that the text is safe then
    you can pass it by calling with `Phoenix.HTML.raw/1`
    on the string first.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:text_fill_color` is the fill color of the text.
    The default is "white". If set to `:transparent` then
    the text will be rendered transparently against
    a background.

  * `:dpi` sets the resolution of the text generation. The
    default `72` which is suitable for screen output. `300`
    may be more appropriate for printed output.

  * `:width` is the maximum width of the generated text image in pixels. The
    default is calculated by the rendering engine based upon the font
    and other options.

  * `:height` is the maximum height of the generated text image in pixels. The
    default is calculated by the rendering engine based upon the font
    and other options.

  * `:font_size` is an integer font size in pixels. The
    default is `50`. If set to `0`, the font size will
    be calculated to fit the text within the specified `:width`
    and `:height`.

  * `:justify` is a boolean indicating whether to justify text.
    The default is `false`.

  * `:letter_spacing` is the amount of space in pixels between each letter.
    Default is `:normal`.

  * `:font` is any font recognised on the host system.
    The default is "Helvetica". The system command `fc-list`
    can be used to see what fonts are available.

  * `:font_weight` is the [font weight](https://developer.mozilla.org/en-US/docs/Web/CSS/font-weight).
    The alternatives are `:normal`, `:bold`, `:lighter`, `:bolder`,
    or an integer between `1` and `1_000`. The default is `:normal`
    which is equivalent to `400`.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`.

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  """
  @spec simple_text(String.t(), Keyword.t()) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def simple_text(string, options \\ [])

  def simple_text(string, options) when is_list(options) do
    with {:ok, options} <- Options.Text.validate_options(options) do
      simple_text(string, options)
    end
  end

  def simple_text(string, %{} = options) do
    with {:ok, string} <- escape_html_text(string) do
      {:ok, text_layer} = render_text(string, options)

      if transparent_text?(options) do
        Image.convert_alpha_to_mask(text_layer)
      else
        {:ok, text_layer}
      end
    end
  end

  @doc """
  Creates an image from the provided text and
  returns an image or raises an exception.

  This function creates an image from the text
  but does not apply a background or padding.

  ### Arguments

  * `string` is any string. The string will be
    HTML-escaped to avoid malicious code injection. If you
    are completely confident that the text is safe then
    you can pass it by calling with `Phoenix.HTML.raw/1`
    on the string first.

  * `options` is a `t:Keyword.t/0` list of options

  ### Options

  * `:text_fill_color` is the fill color of the text.
    The default is "white". If set to `:transparent` then
    the text will be rendered transparently against
    a background.

  * `:font_size` is an integer font size in pixels. The
    default is `50`.

  * `:dpi` sets the resolution of the text generation. The
    default `72` which is suitable for screen output. `300`
    may be more appropriate for printed output.

  * `:width` is the maximum width of the generated text image in pixels. The
    default is calculated by the rendering engine based upon the font
    and other options.

  * `:height` is the maximum height of the generated text image in pixels. The
    default is calculated by the rendering engine based upon the font
    and other options.

  * `:font_size` is an integer font size in pixels. The
    default is `50`. If set to `0`, the font size will
    be calculated to fit the text within the specified `:width`
    and `:height`.

  * `:justify` is a boolean indicating whether to justify text.
    The default is `false`.

  * `:letter_spacing` is the amount of space in pixels between each letter.
    Default is `:normal`.

  * `:font` is any font recognised on the host system.
    The default is "Helvetica". The system command `fc-list`
    can be used to see what fonts are available.

  * `:font_weight` is the [font weight](https://developer.mozilla.org/en-US/docs/Web/CSS/font-weight).
    The alternatives are `:normal`, `:bold`, `:lighter`, `:bolder`,
    or an integer between `1` and `1_000`. The default is `:normal`
    which is equivalent to `400`.

  ### Returns

  * `image` or

  * raises an exception.

  ### Notes

  * There is no text wrapping, justification or kerning
    applied. This means this function is not a general
    purpose text layout function and is suitable mostly
    for overlaying text for emphasis over another image.

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  """
  @spec simple_text!(String.t(), Keyword.t()) :: Vimage.t() | no_return()
  def simple_text!(string, options \\ []) do
    case simple_text(string, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Adds a background to an image generated from
  text.

  ### Arguments

  * `image` is any `t:Vimage.t/0` but is expected
    to be an image generated by `Image.Text.text/2`.

  * `options` is a `t:Keyword.t/0` list of options

  ### Options

  * `:background_fill_color` is the background fill color behind
    the text. The default is `:none` which indicates no
    background. Note that if

  * `:background_fill_opacity` is the opacity of the background. It is a
    float between `0.0` and `1.0` where `0.0` means transparent
    and `1.0` means opaque. The default is `0.7`.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  """
  @spec add_background(Vimage.t(), Keyword.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}
  def add_background(image, options \\ [])

  def add_background(%Vimage{} = image, options) when is_list(options) do
    with {:ok, options} <- Options.Text.validate_options(options) do
      add_background(image, options)
    end
  end

  def add_background(%Vimage{} = image, %{background_fill_color: :none} = _options) do
    {:ok, image}
  end

  def add_background(%Vimage{} = image, %{} = options) do
    {:ok, background} = render_background(image, options)

    # If its transparent text then the image
    # is a mask and we add it as the alpha channel
    # otherwise just composite the two images

    if transparent_text?(options) do
      {:ok, image} = Operation.bandjoin([background, image])
      {:ok, apply_opacity(image, options)}
    else
      Operation.composite2(background, image, :VIPS_BLEND_MODE_OVER)
    end
  end

  @doc """
  Adds a background to an image generated from
  text returning and image or raising an exception.

  ### Arguments

  * `image` is any `t:Vimage.t/0` but is expected
    to be an image generated by `Image.Text.text/2`.

  * `options` is a `t:Keyword.t/0` list of options

  ### Options

  * `:background_fill_color` is the background fill color behind
    the text. The default is `:none` which indicates no
    background. Note that if

  * `:background_fill_opacity` is the opacity of the background. It is a
    float between `0.0` and `1.0` where `0.0` means transparent
    and `1.0` means opaque. The default is `0.7`.

  ### Returns

  * `image` or

  * raises an exception

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  """
  @spec add_background!(Vimage.t(), Keyword.t()) :: Vimage.t() | no_return()
  def add_background!(image, options \\ []) do
    case add_background(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Adds padding to a background to an image generated from
  text.

  ### Arguments

  * `image` is any `t:Vimage.t/0` but is expected
    to be an image generated by `Image.Text.add_background/2`.

  * `options` is a `t:Keyword.t/0` list of options

  ### Options

  * `:background_fill_color` is the background fill color behind
    the text. The default is `:none` which indicates no
    background. Note that if

  * `:background_fill_opacity` is the opacity of the background. It is a
    float between `0.0` and `1.0` where `0.0` means transparent
    and `1.0` means opaque. The default is `0.7`.

  * `:padding` is the padding in pixels between the
    text and the edge of the background.  It can be expressed
    as a single integer integer in which case the same padding
    is applied to all four sides of the image.  It can also
    be expressed as a list of two integers like `[0, 0]`.
    The first integer will be used as the padding for the
    left and right of the image. The second integer will be used
    for the top and bottom of the image.  Another alternative is
    to pass a `t:Vimage.t/0` in which case the padding will be derived
    from the image dimensions such that the background covers the
    whole of the image.  The default is `[0, 0]`.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  """
  @spec add_background_padding(Vimage.t(), Keyword.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def add_background_padding(image, options \\ [])

  def add_background_padding(%Vimage{} = image, options) when is_list(options) do
    with {:ok, options} <- Options.Text.validate_options(options) do
      add_background_padding(image, options)
    end
  end

  def add_background_padding(%Vimage{} = image, %{} = options) do
    [padding_left, padding_top] = options.padding

    options =
      options
      |> Map.put_new(:background_width, Image.width(image) + padding_left * 2)
      |> Map.put_new(:background_height, Image.height(image) + padding_top * 2)

    width = Map.get(options, :background_width)
    height = Map.get(options, :background_height)
    opacity = Map.get(options, :background_fill_opacity)

    background_fill_color =
      options
      |> Map.get(:background_fill_color)
      |> Image.Color.rgba_color!(opacity)

    image =
      if Image.has_alpha?(image), do: image, else: Image.add_alpha!(image, :transparent)

    Operation.embed(image, padding_left, padding_top, width, height,
      background: background_fill_color
    )
  end

  @doc """
  Adds padding to a background to an image generated from
  text returning an image or raising an exception.

  ### Arguments

  * `image` is any `t:Vimage.t/0` but is expected
    to be an image generated by `Image.Text.add_background/2`.

  * `options` is a `t:Keyword.t/0` list of options

  ### Options

  * `:background_fill_color` is the background fill color behind
    the text. The default is `:none` which indicates no
    background. Note that if

  * `:background_fill_opacity` is the opacity of the background. It is a
    float between `0.0` and `1.0` where `0.0` means transparent
    and `1.0` means opaque. The default is `0.7`.

  * `:padding` is the padding in pixels between the
    text and the edge of the background.  It can be expressed
    as a single integer integer in which case the same padding
    is applied to all four sides of the image.  It can also
    be expressed as a list of two integers like `[0, 0]`.
    The first integer will be used as the padding for the
    left and right of the image. The second integer will be used
    for the top and bottom of the image.  Another alternative is
    to pass a `t:Vimage.t/0` in which case the padding will be derived
    from the image dimensions such that the background covers the
    whole of the image.  The default is `[0, 0]`.

  ### Returns

  * `image` or

  * raises an exception

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  """
  @spec add_background_padding!(Vimage.t(), Keyword.t()) :: Vimage.t() | no_return()
  def add_background_padding!(image, options \\ []) do
    case add_background_padding(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Adds a border on an image, typically an
  image generated from a string.

  ### Arguments

  * `image` is any `t:Vimage.t/0`

  * `options` is a `t:Keyword.t/0` list of options

  ### Options

  * `:background_stroke_color` is the colour of the outline
    of the background. The default is "none",

  * `:background_stroke_width` is the integer size in pixels
    of the background border. The default is `1`.

  * `:background_stroke_opacity` is the opacity of the background
    string. It is a float between `0.0` and `1.0` where `0.0` means
    transparent and `1.0` means opaque. The default is `0.7`.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  """
  @spec add_background_border(Vimage.t(), Keyword.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}
  def add_background_border(image, options \\ [])

  def add_background_border(%Vimage{} = image, options) when is_list(options) do
    with {:ok, options} <- Options.Text.validate_options(options) do
      add_background_border(image, options)
    end
  end

  def add_background_border(image, %{background_stroke_color: :none} = _options) do
    {:ok, image}
  end

  def add_background_border(image, %{padding: 0} = _options) do
    {:ok, image}
  end

  def add_background_border(image, %{} = options) do
    with {:ok, {border, _flags}} <- render_background_border(image, options) do
      Operation.composite2(image, border, :VIPS_BLEND_MODE_OVER)
    end
  end

  @doc """
  Adds a border on an image, typically an
  image generated from a string. Returns an
  image or raises an exception.

  ### Arguments

  * `image` is any `t:Vimage.t/0`

  * `options` is a `t:Keyword.t/0` list of options

  ### Options

  * `:background_stroke_color` is the colour of the outline
    of the background. The default is "none",

  * `:background_stroke_width` is the integer size in pixels
    of the background border. The default is `1`.

  * `:background_stroke_opacity` is the opacity of the background
    string. It is a float between `0.0` and `1.0` where `0.0` means
    transparent and `1.0` means opaque. The default is `0.7`.

  ### Returns

  * `image` or

  * raises an exception

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  """
  @spec add_background_border!(Vimage.t(), Keyword.t()) :: Vimage.t() | no_return()
  def add_background_border!(image, options \\ []) do
    case add_background_border(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  # For transparent text we need to render the text in
  # white which is then converted later to a transparency
  # mask
  @dialyzer {:nowarn_function, {:render_text, 2}}

  defp render_text(text, %{text_fill_color: :transparent} = options) do
    render_text(text, Map.put(options, :text_fill_color, :white))
  end

  defp render_text(text, options) do
    font_size =
      if options.font_size > 0, do: " #{inspect(options.font_size)}", else: ""

    font = options.font <> font_size
    height = options[:height]
    width = options[:width]

    text_options =
      [
        font: font,
        align: options.align,
        justify: options.justify
      ]
      |> maybe_add_height(height)
      |> maybe_add_width(width)
      |> maybe_add_dpi(options[:dpi])
      |> Image.maybe_add_fontfile(options[:fontfile])

    with {:ok, text} <- maybe_add_letter_spacing(text, options.letter_spacing),
         {:ok, {text_mask, _}} <- Operation.text(text, text_options),
         {:ok, color_layer} <- Image.new(text_mask, color: options.text_fill_color),
         {:ok, joined} <- Operation.bandjoin([color_layer, text_mask]),
         {:ok, {x, y}} <- location_from_options(joined, options.x, options.y, width, height) do
      if width && height do
        Operation.embed(joined, x, y, width, height)
      else
        {:ok, joined}
      end
    end
  end

  defp maybe_add_height(options, nil), do: options
  defp maybe_add_height(options, height), do: Keyword.put(options, :height, height)

  defp maybe_add_width(options, nil), do: options
  defp maybe_add_width(options, width), do: Keyword.put(options, :width, width)

  defp maybe_add_dpi(options, nil), do: options
  defp maybe_add_dpi(options, dpi), do: Keyword.put(options, :dpi, dpi)

  # If the text starts with a span then we assume the user is
  # determining the text format
  defp maybe_add_letter_spacing("<span" <> _rest = text, _letter_spacing) do
    {:ok, text}
  end

  # If the spacing is normal, don't change the text
  defp maybe_add_letter_spacing(text, :normal) do
    {:ok, text}
  end

  # pango letter_spacing is in 1/1024 of a point.
  # We need to convert pixels to this unit.
  defp maybe_add_letter_spacing(text, letter_spacing) do
    letter_spacing = round(letter_spacing * 1024)
    {:ok, "<span letter_spacing=\"#{letter_spacing}\">#{text}</span>"}
  end

  defp location_from_options(image, :left, y, width, height) do
    location_from_options(image, 0, y, width, height)
  end

  defp location_from_options(image, :center, y, width, height) when is_integer(width) do
    x = div(width - Image.width(image), 2)
    location_from_options(image, x, y, width, height)
  end

  defp location_from_options(image, :right, y, width, height) when is_integer(width) do
    x = width - Image.width(image)
    location_from_options(image, x, y, width, height)
  end

  defp location_from_options(image, x, :top, width, height) do
    location_from_options(image, x, 0, width, height)
  end

  defp location_from_options(image, x, :middle, width, height) when is_integer(height) do
    y = div(height - Image.height(image), 2)
    location_from_options(image, x, y, width, height)
  end

  defp location_from_options(image, x, :bottom, width, height) when is_integer(height) do
    y = height - Image.height(image)
    location_from_options(image, x, y, width, height)
  end

  defp location_from_options(_image, _x, _y, nil, nil) do
    {:ok, {0, 0}}
  end

  defp location_from_options(_image, x_location, _y, nil, _height)
       when x_location in [:center, :right] do
    {:error, ":center and :right cannot be specified unless :width is also specified"}
  end

  defp location_from_options(_image, _x, y_location, _width, nil)
       when y_location in [:middle, :bottom] do
    {:error, ":middle and :bottom cannot be specified unless :height is also specified"}
  end

  defp location_from_options(image, x, y, width, nil) when is_integer(width) do
    if Image.width(image) + x <= width do
      {:ok, {x, y}}
    else
      {:error,
       "Location [#{inspect(x)}, _] would place the text " <>
         "outside the image bounds specified"}
    end
  end

  defp location_from_options(image, x, y, width, height)
       when is_integer(width) and is_integer(height) do
    if Image.width(image) + x <= width && Image.height(image) + y <= height do
      {:ok, {x, y}}
    else
      {:error,
       "Location [#{inspect(x)}, #{inspect(y)}] would place the text " <>
         "outside the image bounds specified"}
    end
  end

  # Render a background rectangle and return
  # it without its alpha channel since we will
  # apply transparency from the text image

  # Don't apply a background stroke since
  # we want the stroke around the padded area.

  defp render_background(image, %{} = options) do
    width = Map.get(options, :background_width, Image.width(image))
    height = Map.get(options, :background_height, Image.height(image))

    svg = """
    <svg width="#{width}px" height="#{height}px">
      <rect
        fill="#{options.background_fill_color}"
        opacity="#{options.background_fill_opacity}"
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

  # Render a background border. The fill will be
  # transparent so the border cam be composed over
  # another layer.

  defp render_background_border(image, %{} = options) do
    width = Map.get(options, :background_width, Image.width(image))
    height = Map.get(options, :background_height, Image.height(image))

    # This because the stroke is along the centre line and therefore
    # 50% of it is clipped outside the background. We are after the
    # equivalent of the stroke inside the bounding box.

    stroke_width = options.background_stroke_width * 2

    svg = """
    <svg width="#{width}px" height="#{height}px">
      <rect
        fill="transparent"
        stroke="#{options.background_stroke_color}"
        stroke-width="#{stroke_width}"
        opacity="#{options.background_stroke_opacity}"
        width="100%"
        height="100%"
      />
    </svg>
    """

    Operation.svgload_buffer(svg)
  end

  defp apply_opacity(image, options) do
    use Image.Math

    image * [1.0, 1.0, 1.0, options.background_fill_opacity]
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
