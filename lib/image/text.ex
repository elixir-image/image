defmodule Image.Text do
  @moduledoc """
  Functions for the creation of images from text.

  ### Fonts

  Text is drawn by Pango, which finds a font by its family name, the
  `:font` option. There are two ways to draw with fonts that are not
  installed on the system:

  * **`:font_file`** loads one font file for a call. Give the font's
    family name in `:font` too.

  * **A fontconfig configuration** names the folders fonts are found
    in, so every font in them can be used by family name with no
    `:font_file`. Write a `fonts.conf` and point the `FONTCONFIG_FILE`
    environment variable at it. A `<dir prefix="relative">` element
    is read relative to the `fonts.conf`, so the file can sit beside
    the fonts in the application's `priv` folder. List the system
    folders after your own so that scripts your fonts do not cover
    still have a font:

  ```xml
  <?xml version="1.0"?>
  <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
  <fontconfig>
    <dir prefix="relative">.</dir>
    <dir>/usr/share/fonts</dir>
    <dir>/usr/local/share/fonts</dir>
    <dir>/System/Library/Fonts</dir>
    <dir>/Library/Fonts</dir>
    <cachedir prefix="xdg">my_app-fontconfig</cachedir>
  </fontconfig>
  ```

  On Linux, Pango uses fontconfig, so both work as they are. On
  macOS, Pango uses the system's CoreText backend by default, which
  never sees a font loaded through fontconfig: `:font_file` and
  `FONTCONFIG_FILE` are both silently ignored and a system font is
  drawn instead. Set `PANGOCAIRO_BACKEND=fc` as well, and both work
  on macOS as they do on Linux.

  Both environment variables are read when libvips starts, so set
  them before the BEAM starts: in the shell, in a release's
  `rel/env.sh.eex`, or in the service definition. Setting them with
  `System.put_env/2` at runtime has no effect. `Image.meme/3`'s
  bundled Anton font is loaded as a `:font_file` and needs the same
  setting on macOS.

  """

  alias Vix.Vips.Image, as: Vimage
  alias Image.Vips.Operation
  alias Image.Options

  @doc """
  Create a new image from the provided string and
  formatting options.

  `text/2` creates an image with the
  following steps:

  * Render the text.

  * Add an optional background color.

  * Expand the background according to the required padding.

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
    The default is "Helvetica". The system command `fc-list`
    can typically be used to see what fonts are available.

  * `:font_size` is an integer font size in pixels, or a list
    of them. The default is `50`. Given a list, the text is set at
    the largest size at which it fits in `:max_lines` lines and
    within `:height`, and at the smallest size, shortened, when it
    fits at none. A list requires `:width`.

  * `:max_lines` is the most lines the text may take when it is
    wrapped at `:width`. Text that does not fit at the smallest
    `:font_size` is cut at the end of a word, or between graphemes
    in text written without spaces, and `:ellipsis` is added.
    Markup passed with `Phoenix.HTML.raw/1` is cut to the lines
    but not shortened. Words are kept whole when fitting: a word
    wider than `:width` steps the text down a size or is cut.
    Requires `:width`. The default is `nil`, meaning no limit.

  * `:ellipsis` is the string added to shortened text. The
    default is `"…"`.

  * `:font_weight` is one of `:ultralight`, `:light`, `:normal`, `:bold`,
    `:ultrabold`, `:heavy` or an integer between `1` and `1_000`.
    The default is `:normal` which is equivalent to `400`.

  * `:font_file` is a path to any `.ttf` font file. If specified,
    the `:font` parameter is also required. On macOS it takes effect
    only when `PANGOCAIRO_BACKEND=fc` is set; see "Fonts" in the
    module documentation, which also covers `FONTCONFIG_FILE`.

  * `:dpi` sets the resolution of the text generation. The
    default `72` which is suitable for screen output. `300`
    may be more appropriate for printed output.

  * `:text_fill_color` is the fill color of the text.
    The default is "white". If set to `:transparent` then
    the text will be rendered transparently against
    a background. A black background will be forced if a
    `:background_fill_color` is not provided. If set to
    `:markup` then the color of each part of the text is
    taken from the Pango markup, allowing text of more than
    one color. Text with no color set in the markup is
    rendered black.

  * `:background_fill_opacity` is the opacity of the background fill, as
    any `t:Image.Pixel.opacity/0`: a float in `0.0..1.0`, an integer in
    `0..255` as the same value in 8-bit notation, or `:transparent` /
    `:opaque`. The default is `0.7`.

  * `:padding` is the padding in pixels between the
    text and the edge of the background.  It can be expressed
    as a single integer integer in which case the same padding
    is applied to all four sides of the image.  It can also
    be expressed as a list of two integers like `[0, 0]`.
    The first integer will be used as the padding for the
    left and right of the image. The second integer will be used
    for the top and bottom of the image.  Another alternative is
    to pass a `t:Vix.Vips.Image.t/0` in which case the padding will be derived
    from the image dimensions such that the background covers the
    whole of the image.  The default is `[0, 0]`.

  * `:align` indicates how multiple lines of text are aligned.
    The options are `:left`, `:right` and `:center`. The default
    is `:left`.

  * `:letter_spacing` is the amount of space in pixels between each letter.
    Default is `:normal`.

  * `:background_fill_color` is the background fill color behind
    the text. The default is `:none` which indicates no
    background.

  * `:background_stroke_color` is the colour of the outline
    of the background. The default is "none".

  * `:background_stroke_width` is the integer size in pixels
    of the background border. The default is `1`.

  * `:background_stroke_opacity` is the opacity of the background
    string, as any `t:Image.Pixel.opacity/0`: a float in `0.0..1.0`, an
    integer in `0..255` as the same value in 8-bit notation, or
    `:transparent` / `:opaque`. The default is `0.7`.

  * `:width` is the maximum width of the generated text image in pixels.
    Text is wrapped at words to fit, and a word wider than `:width`
    is broken between characters. The default is calculated by the
    rendering engine based upon the font and other options.

  * `:height` is the maximum height of the generated text image in pixels. The
    default is calculated by the rendering engine based upon the font
    and other options. `:height` may only be specified if `:width` is
    also specified.

  * `:x` is the horizontal location of the text on its background.
    The value is either a non-negative integer or one of `:left`,
    `:right` or `:center`. The default is `:center` if `:width` is
    specified and `:left` if it is not.

  * `:y` is the vertical location of the text on its background.
    The value is either a non-negative integer or one of `:top`,
    `:middle` or `:bottom`. The default is `:middle` if `:height`
    is specified and `:top` if it is not.

  ### Returns

  * `{:ok, image}`, or

  * `{:error, reason}`.

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  * The options `:font_weight` and `:letter_spacing` are implemented by
    wrapping the text in a [Pango markup](https://docs.gtk.org/Pango/pango_markup.html) `span`
    tag. If the `string` parameter starts with `<span` then these two
    options are ignored since this implies the user is taking full control
    of the markup.

  ### Examples

      iex> {:ok, text_image} = Image.Text.text("hello", font_size: 24)
      iex> Image.bands(text_image)
      4

      iex> {:ok, _} = Image.Text.text("ok", text_fill_color: :red)
      iex> :ok
      :ok

      iex> title = "A title that is far too long to fit in two lines at the larger size"
      iex> {:ok, image} = Image.Text.text(title, font_size: [48, 32], width: 400, max_lines: 2)
      iex> Image.width(image) <= 400
      true

  """
  @spec text(Phoenix.HTML.safe() | String.t(), Options.Text.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}

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

  * Render the text.

  * Add an optional background color.

  * Expand the background according to the required padding.

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

  * `:font` is any font name recognised on the host system.
    The default is "Helvetica". The system command `fc-list`
    can typically be used to see what fonts are available.

  * `:font_size` is an integer font size in pixels, or a list
    of them. The default is `50`. Given a list, the text is set at
    the largest size at which it fits in `:max_lines` lines and
    within `:height`, and at the smallest size, shortened, when it
    fits at none. A list requires `:width`.

  * `:max_lines` is the most lines the text may take when it is
    wrapped at `:width`. Text that does not fit at the smallest
    `:font_size` is cut at the end of a word, or between graphemes
    in text written without spaces, and `:ellipsis` is added.
    Markup passed with `Phoenix.HTML.raw/1` is cut to the lines
    but not shortened. Words are kept whole when fitting: a word
    wider than `:width` steps the text down a size or is cut.
    Requires `:width`. The default is `nil`, meaning no limit.

  * `:ellipsis` is the string added to shortened text. The
    default is `"…"`.

  * `:font_file` is a path to any `.ttf` font file. If specified,
    the `:font` parameter is also required. On macOS it takes effect
    only when `PANGOCAIRO_BACKEND=fc` is set; see "Fonts" in the
    module documentation, which also covers `FONTCONFIG_FILE`.

  * `:font_weight` is one of `:ultralight`, `:light`, `:normal`, `:bold`,
    `:ultrabold`, `:heavy` or an integer between `1` and `1_000`.
    The default is `:normal` which is equivalent to `400`.

  * `:dpi` sets the resolution of the text generation. The
    default `72` which is suitable for screen output. `300`
    may be more appropriate for printed output.

  * `:text_fill_color` is the fill color of the text.
    The default is "white". If set to `:transparent` then
    the text will be rendered transparently against
    a background. A black background will be forced if a
    `:background_fill_color` is not provided. If set to
    `:markup` then the color of each part of the text is
    taken from the Pango markup, allowing text of more than
    one color. Text with no color set in the markup is
    rendered black.

  * `:background_fill_opacity` is the opacity of the background fill, as
    any `t:Image.Pixel.opacity/0`: a float in `0.0..1.0`, an integer in
    `0..255` as the same value in 8-bit notation, or `:transparent` /
    `:opaque`. The default is `0.7`.

  * `:padding` is the padding in pixels between the
    text and the edge of the background.  It can be expressed
    as a single integer integer in which case the same padding
    is applied to all four sides of the image.  It can also
    be expressed as a list of two integers like `[0, 0]`.
    The first integer will be used as the padding for the
    left and right of the image. The second integer will be used
    for the top and bottom of the image.  Another alternative is
    to pass a `t:Vix.Vips.Image.t/0` in which case the padding will be derived
    from the image dimensions such that the background covers the
    whole of the image.  The default is `[0, 0]`.

  * `:align` indicates how multiple lines of text are aligned.
    The options are `:left`, `:right` and `:center`. The default
    is `:left`.

  * `:letter_spacing` is the amount of space in pixels between each letter.
    Default is `:normal`.

  * `:background_fill_color` is the background fill color behind
    the text. The default is `:none` which indicates no
    background.

  * `:background_stroke_color` is the colour of the outline
    of the background. The default is "none".

  * `:background_stroke_width` is the integer size in pixels
    of the background border. The default is `1`.

  * `:background_stroke_opacity` is the opacity of the background
    string, as any `t:Image.Pixel.opacity/0`: a float in `0.0..1.0`, an
    integer in `0..255` as the same value in 8-bit notation, or
    `:transparent` / `:opaque`. The default is `0.7`.

  * `:width` is the maximum width of the generated text image in pixels.
    Text is wrapped at words to fit, and a word wider than `:width`
    is broken between characters. The default is calculated by the
    rendering engine based upon the font and other options.

  * `:height` is the maximum height of the generated text image in pixels. The
    default is calculated by the rendering engine based upon the font
    and other options. `:height` may only be specified if `:width` is
    also specified.

  * `:x` is the horizontal location of the text on its background.
    The value is either a non-negative integer or one of `:left`,
    `:right` or `:center`. The default is `:center` if `:width` is
    specified and `:left` if it is not.

  * `:y` is the vertical location of the text on its background.
    The value is either a non-negative integer or one of `:top`,
    `:middle` or `:bottom`. The default is `:middle` if `:height`
    is specified and `:top` if it is not.

  ### Returns

  * `image`, or

  * raises an exception.

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  * The options `:font_weight` and `:letter_spacing` are implemented by
    wrapping the text in a [Pango markup](https://docs.gtk.org/Pango/pango_markup.html) `span`
    tag. If the `string` parameter starts with `<span` then these two
    options are ignored since this implies the user is taking full control
    of the markup.

  ### Examples

      iex> text_image = Image.Text.text!("hello", font_size: 24)
      iex> Image.bands(text_image)
      4

  """
  @spec text!(Phoenix.HTML.safe() | String.t(), Keyword.t()) :: Vimage.t() | no_return()
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
    a background. If set to `:markup` then the color of
    each part of the text is taken from the Pango markup,
    allowing text of more than one color. Text with no
    color set in the markup is rendered black.

  * `:width` is the maximum width of the generated text image in pixels.
    Text is wrapped at words to fit, and a word wider than `:width`
    is broken between characters. The default is calculated by the
    rendering engine based upon the font and other options.

  * `:height` is the maximum height of the generated text image in pixels. The
    default is calculated by the rendering engine based upon the font
    and other options.

  * `:justify` is a boolean indicating whether to justify text.
    The default is `false`.

  * `:letter_spacing` is the amount of space in pixels between each letter.
    Default is `:normal`.

  * `:font` is any font recognised on the host system.
    The default is "Helvetica". The system command `fc-list`
    can typically be used to see what fonts are available.

  * `:font_weight` is one of `:ultralight`, `:light`, `:normal`, `:bold`,
    `:ultrabold`, `:heavy` or an integer between `1` and `1_000`.
    The default is `:normal` which is equivalent to `400`.

  * `:font_size` is an integer font size in pixels, or a list
    of them. The default is `50`. Given a list, the text is set at
    the largest size at which it fits in `:max_lines` lines and
    within `:height`, and at the smallest size, shortened, when it
    fits at none. A list requires `:width`. If set to `0`, libvips chooses
    the size that fills `:width` and `:height`.

  * `:max_lines` is the most lines the text may take when it is
    wrapped at `:width`. Text that does not fit at the smallest
    `:font_size` is cut at the end of a word, or between graphemes
    in text written without spaces, and `:ellipsis` is added.
    Markup passed with `Phoenix.HTML.raw/1` is cut to the lines
    but not shortened. Words are kept whole when fitting: a word
    wider than `:width` steps the text down a size or is cut.
    Requires `:width`. The default is `nil`, meaning no limit.

  * `:ellipsis` is the string added to shortened text. The
    default is `"…"`.

  * `:dpi` sets the resolution of the text generation. The
    default `72` which is suitable for screen output. `300`
    may be more appropriate for printed output.

  ### Returns

  * `{:ok, image}`, or

  * `{:error, reason}`.

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  ### Examples

      iex> {:ok, image} = Image.Text.simple_text("hi", font_size: 24)
      iex> Image.bands(image)
      4

      iex> markup = ~s(<span color="red">Red</span> <span color="blue">Blue</span>)
      iex> {:ok, image} = Image.Text.simple_text({:safe, markup}, text_fill_color: :markup)
      iex> Image.bands(image)
      4

  """
  @spec simple_text(Phoenix.HTML.safe() | String.t(), Keyword.t() | map()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}
  def simple_text(string, options \\ [])

  def simple_text(string, options) when is_list(options) do
    with {:ok, options} <- Options.Text.validate_options(options) do
      simple_text(string, options)
    end
  end

  def simple_text(string, %{} = options) do
    with {:ok, text_layer} <- render(string, options) do
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

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:text_fill_color` is the fill color of the text.
    The default is "white". If set to `:transparent` then
    the text will be rendered transparently against
    a background. If set to `:markup` then the color of
    each part of the text is taken from the Pango markup,
    allowing text of more than one color. Text with no
    color set in the markup is rendered black.

  * `:width` is the maximum width of the generated text image in pixels.
    Text is wrapped at words to fit, and a word wider than `:width`
    is broken between characters. The default is calculated by the
    rendering engine based upon the font and other options.

  * `:height` is the maximum height of the generated text image in pixels. The
    default is calculated by the rendering engine based upon the font
    and other options.

  * `:justify` is a boolean indicating whether to justify text.
    The default is `false`.

  * `:letter_spacing` is the amount of space in pixels between each letter.
    Default is `:normal`.

  * `:font` is any font recognised on the host system.
    The default is "Helvetica". The system command `fc-list`
    can typically be used to see what fonts are available.

  * `:font_weight` is one of `:ultralight`, `:light`, `:normal`, `:bold`,
    `:ultrabold`, `:heavy` or an integer between `1` and `1_000`.
    The default is `:normal` which is equivalent to `400`.

  * `:font_size` is an integer font size in pixels, or a list
    of them. The default is `50`. Given a list, the text is set at
    the largest size at which it fits in `:max_lines` lines and
    within `:height`, and at the smallest size, shortened, when it
    fits at none. A list requires `:width`. If set to `0`, libvips chooses
    the size that fills `:width` and `:height`.

  * `:max_lines` is the most lines the text may take when it is
    wrapped at `:width`. Text that does not fit at the smallest
    `:font_size` is cut at the end of a word, or between graphemes
    in text written without spaces, and `:ellipsis` is added.
    Markup passed with `Phoenix.HTML.raw/1` is cut to the lines
    but not shortened. Words are kept whole when fitting: a word
    wider than `:width` steps the text down a size or is cut.
    Requires `:width`. The default is `nil`, meaning no limit.

  * `:ellipsis` is the string added to shortened text. The
    default is `"…"`.

  * `:dpi` sets the resolution of the text generation. The
    default `72` which is suitable for screen output. `300`
    may be more appropriate for printed output.

  ### Returns

  * `image`, or

  * raises an exception.

  ### Notes

  * Text is wrapped only when `:width` is given, and laid
    out by Pango with no hyphenation. This function is not a
    general purpose text layout function and is suitable mostly
    for overlaying text for emphasis over another image.

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  ### Examples

      iex> image = Image.Text.simple_text!("hi", font_size: 24)
      iex> Image.bands(image)
      4

  """
  @spec simple_text!(Phoenix.HTML.safe() | String.t(), Keyword.t()) ::
          Vimage.t() | no_return()
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

  * `image` is any `t:Vix.Vips.Image.t/0` but is expected
    to be an image generated by `Image.Text.text/2`.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:background_fill_color` is the background fill color behind
    the text. The default is `:none` which indicates no
    background. Note that if.

  * `:background_fill_opacity` is the opacity of the background, as any
    `t:Image.Pixel.opacity/0`: a float in `0.0..1.0`, an integer in
    `0..255` as the same value in 8-bit notation, or `:transparent` /
    `:opaque`. The default is `0.7`.

  ### Returns

  * `{:ok, image}`, or

  * `{:error, reason}`.

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  ### Examples

      iex> image = Image.new!(20, 10, color: [255, 255, 255, 255], bands: 4)
      iex> {:ok, with_background} = Image.Text.add_background(image, background_fill_color: :blue)
      iex> Image.shape(with_background)
      {20, 10, 4}

  """
  @spec add_background(Vimage.t(), Keyword.t() | map()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}
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
    with {:ok, background} <- render_background(image, options) do
      join_background(background, image, options)
    end
  end

  @doc """
  Adds a background to an image generated from
  text returning an image or raising an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` but is expected
    to be an image generated by `Image.Text.text/2`.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:background_fill_color` is the background fill color behind
    the text. The default is `:none` which indicates no
    background.

  * `:background_fill_opacity` is the opacity of the background, as any
    `t:Image.Pixel.opacity/0`: a float in `0.0..1.0`, an integer in
    `0..255` as the same value in 8-bit notation, or `:transparent` /
    `:opaque`. The default is `0.7`.

  ### Returns

  * `image`, or

  * raises an exception.

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  ### Examples

      iex> image = Image.new!(20, 10, color: [255, 255, 255, 255], bands: 4)
      iex> with_background = Image.Text.add_background!(image, background_fill_color: :blue)
      iex> Image.shape(with_background)
      {20, 10, 4}

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

  * `image` is any `t:Vix.Vips.Image.t/0` but is expected
    to be an image generated by `Image.Text.add_background/2`.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:background_fill_color` is the background fill color behind
    the text. The default is `:none` which indicates no
    background.

  * `:background_fill_opacity` is the opacity of the background, as any
    `t:Image.Pixel.opacity/0`: a float in `0.0..1.0`, an integer in
    `0..255` as the same value in 8-bit notation, or `:transparent` /
    `:opaque`. The default is `0.7`.

  * `:padding` is the padding in pixels between the
    text and the edge of the background.  It can be expressed
    as a single integer integer in which case the same padding
    is applied to all four sides of the image.  It can also
    be expressed as a list of two integers like `[0, 0]`.
    The first integer will be used as the padding for the
    left and right of the image. The second integer will be used
    for the top and bottom of the image.  Another alternative is
    to pass a `t:Vix.Vips.Image.t/0` in which case the padding will be derived
    from the image dimensions such that the background covers the
    whole of the image.  The default is `[0, 0]`.

  ### Returns

  * `{:ok, image}`, or

  * `{:error, reason}`.

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  ### Examples

      iex> image = Image.new!(20, 10, color: [255, 255, 255, 255], bands: 4)
      iex> {:ok, padded} = Image.Text.add_background_padding(image, background_fill_color: :blue, padding: 5)
      iex> Image.shape(padded)
      {30, 20, 4}

  """
  @spec add_background_padding(Vimage.t(), Keyword.t() | map()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}

  def add_background_padding(image, options \\ [])

  def add_background_padding(%Vimage{} = image, options) when is_list(options) do
    with {:ok, options} <- Options.Text.validate_options(options) do
      add_background_padding(image, options)
    end
  end

  def add_background_padding(%Vimage{} = image, %{} = options) do
    [padding_left, padding_top] = padding_from_options(image, options.padding)

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
      |> background_to_rgba(opacity)
      |> Enum.map(&(&1 * 1.0))

    image =
      if Image.has_alpha?(image), do: image, else: Image.add_alpha!(image, :opaque)

    Operation.embed(image, padding_left, padding_top, width, height,
      background: background_fill_color
    )
  end

  # Resolve a text background colour into an RGBA pixel in 0..255.
  # Honours the `:none` / `:transparent` aliases (which always yield a
  # fully transparent black, regardless of the opacity option) so that
  # the default text background remains invisible.
  defp background_to_rgba(color, _opacity) when color in [:none, :transparent] do
    [0, 0, 0, 0]
  end

  defp background_to_rgba(color, opacity)
       when is_float(opacity) and opacity >= 0.0 and opacity <= 1.0 do
    [r, g, b | _] = Image.Pixel.to_srgb!(color)
    [r, g, b, round(255 * opacity)]
  end

  @doc """
  Adds padding to a background to an image generated from
  text returning an image or raising an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` but is expected
    to be an image generated by `Image.Text.add_background/2`.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:background_fill_color` is the background fill color behind
    the text. The default is `:none` which indicates no
    background.

  * `:background_fill_opacity` is the opacity of the background, as any
    `t:Image.Pixel.opacity/0`: a float in `0.0..1.0`, an integer in
    `0..255` as the same value in 8-bit notation, or `:transparent` /
    `:opaque`. The default is `0.7`.

  * `:padding` is the padding in pixels between the
    text and the edge of the background.  It can be expressed
    as a single integer integer in which case the same padding
    is applied to all four sides of the image.  It can also
    be expressed as a list of two integers like `[0, 0]`.
    The first integer will be used as the padding for the
    left and right of the image. The second integer will be used
    for the top and bottom of the image.  Another alternative is
    to pass a `t:Vix.Vips.Image.t/0` in which case the padding will be derived
    from the image dimensions such that the background covers the
    whole of the image.  The default is `[0, 0]`.

  ### Returns

  * `image`, or

  * raises an exception.

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  ### Examples

      iex> image = Image.new!(20, 10, color: [255, 255, 255, 255], bands: 4)
      iex> padded = Image.Text.add_background_padding!(image, background_fill_color: :blue, padding: 5)
      iex> Image.shape(padded)
      {30, 20, 4}

  """
  @spec add_background_padding!(Vimage.t(), Keyword.t()) :: Vimage.t() | no_return()
  def add_background_padding!(image, options \\ []) do
    case add_background_padding(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  defp padding_from_options(image, %Vimage{} = base_image) do
    padding_left = div(Image.width(base_image) - Image.width(image), 2)
    padding_top = div(Image.height(base_image) - Image.height(image), 2)
    [padding_left, padding_top]
  end

  defp padding_from_options(_image, [_padding_left, _padding_top] = padding) do
    padding
  end

  @doc """
  Adds a border on an image, typically an
  image generated from a string.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:background_stroke_color` is the colour of the outline
    of the background. The default is ":none".

  * `:background_stroke_width` is the integer size in pixels
    of the background border. The default is `1`.

  * `:background_stroke_opacity` is the opacity of the background
    string, as any `t:Image.Pixel.opacity/0`: a float in `0.0..1.0`, an
    integer in `0..255` as the same value in 8-bit notation, or
    `:transparent` / `:opaque`. The default is `0.7`.

  ### Returns

  * `{:ok, image}`, or

  * `{:error, reason}`.

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  ### Examples

      iex> image = Image.new!(30, 20, color: [0, 0, 255, 255], bands: 4)
      iex> {:ok, bordered} = Image.Text.add_background_border(image, background_stroke_color: :red, padding: 5)
      iex> Image.shape(bordered)
      {30, 20, 4}

  """
  @spec add_background_border(Vimage.t(), Keyword.t() | map()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}
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

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:background_stroke_color` is the colour of the outline
    of the background. The default is "none".

  * `:background_stroke_width` is the integer size in pixels
    of the background border. The default is `1`.

  * `:background_stroke_opacity` is the opacity of the background
    string, as any `t:Image.Pixel.opacity/0`: a float in `0.0..1.0`, an
    integer in `0..255` as the same value in 8-bit notation, or
    `:transparent` / `:opaque`. The default is `0.7`.

  ### Returns

  * `image`, or

  * raises an exception.

  ### Notes

  * Colors may be any valid
    [CSS color name](https://www.w3.org/wiki/CSS/Properties/color/keywords) or
    a six hexadecimal digit string prefixed with `#`. For example
    `#FF00FF` for the color "Fuchsia".

  ### Examples

      iex> image = Image.new!(30, 20, color: [0, 0, 255, 255], bands: 4)
      iex> bordered = Image.Text.add_background_border!(image, background_stroke_color: :red, padding: 5)
      iex> Image.shape(bordered)
      {30, 20, 4}

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
  defp render_text(text, %{text_fill_color: :transparent} = options) do
    render_text(text, Map.put(options, :text_fill_color, :white))
  end

  defp render_text(text, options) do
    height = options[:height]
    width = options[:width]

    with {:ok, text_layer} <- rasterize_text(text, options),
         {:ok, text_layer} <- within_box(text_layer, width, height),
         {:ok, {x, y}} <-
           location_from_options(text_layer, options.x, options.y, width, height) do
      if width && height do
        Operation.embed(text_layer, x, y, width, height)
      else
        {:ok, text_layer}
      end
    end
  end

  # libvips can set text a pixel or two wider than `:width`, or taller than
  # `:height`, where a glyph overhangs its advance, as Persian glyphs do.
  # The overhang is cropped evenly from both sides so that the layer is
  # within the box it was asked for.
  defp within_box(layer, width, height) do
    crop_width = box_size(Image.width(layer), width)
    crop_height = box_size(Image.height(layer), height)

    if crop_width == Image.width(layer) and crop_height == Image.height(layer) do
      {:ok, layer}
    else
      left = div(Image.width(layer) - crop_width, 2)
      top = div(Image.height(layer) - crop_height, 2)
      Image.crop(layer, left, top, crop_width, crop_height)
    end
  end

  defp box_size(size, nil) do
    size
  end

  defp box_size(size, limit) do
    min(size, limit)
  end

  # The text drawn and colored, before it is placed: a layer as wide and as
  # tall as libvips set it, which can be wider than `:width` where a glyph
  # overhangs, or where a word cannot be broken when wrapping by words only.
  # A word wider than `:width` is broken between characters unless the
  # internal `:wrap` says otherwise; text whose words all fit a line is set
  # identically either way.
  defp rasterize_text(text, %{text_fill_color: :transparent} = options) do
    rasterize_text(text, Map.put(options, :text_fill_color, :white))
  end

  defp rasterize_text(text, options) do
    font = options.font <> font_size(options)

    text_options =
      [
        font: font,
        align: options.align,
        justify: options.justify,
        wrap: Map.get(options, :wrap, :VIPS_TEXT_WRAP_WORD_CHAR)
      ]
      |> maybe_add_height(options[:height])
      |> maybe_add_width(options[:width])
      |> maybe_add_dpi(options[:dpi])
      |> maybe_add_rgba(options.text_fill_color)
      |> Image.maybe_add_fontfile(options[:fontfile])

    with {:ok, text} <- maybe_add_pango_span(text, options),
         {:ok, {rendered, _}} <- Operation.text(text, text_options) do
      colorize_text(rendered, options.text_fill_color)
    end
  end

  # Text is fitted when it is given a list of sizes to try or a number of
  # lines to fit in, and rendered as it is otherwise.
  defp render(string, %{font_size: font_sizes} = options) when is_list(font_sizes) do
    fit_text(string, font_sizes, options)
  end

  defp render(string, %{max_lines: max_lines} = options) when is_integer(max_lines) do
    fit_text(string, [options.font_size], options)
  end

  defp render(string, options) do
    render_string(string, options)
  end

  defp render_string(string, options) do
    with {:ok, escaped} <- escape_html_text(string) do
      render_text(escaped, options)
    end
  end

  # Fitting sets words whole, so that a word too long for a line steps the
  # text down a size or shortens it rather than being broken.
  defp measure_string(string, options) do
    with {:ok, escaped} <- escape_html_text(string),
         {:ok, layer} <- rasterize_text(escaped, Map.put(options, :wrap, :VIPS_TEXT_WRAP_WORD)) do
      crop_overhang(layer, escaped, options)
    end
  end

  # A layer wider than `:width` is either a word too long for a line, which
  # does not fit, or a glyph overhanging a line, which does once cropped.
  # Breaking the words that must be broken tells them apart: an overhang
  # breaks none, so the text is set pixel for pixel as it was. (Comparing
  # heights alone is not enough: a broken word can reflow into as many
  # lines as before.)
  defp crop_overhang(layer, escaped, %{width: width} = options) when is_integer(width) do
    if Image.width(layer) <= width do
      {:ok, layer}
    else
      with {:ok, broken} <- rasterize_text(escaped, options) do
        overhang_or_overflow(layer, broken, width)
      end
    end
  end

  defp crop_overhang(layer, _escaped, _options) do
    {:ok, layer}
  end

  defp overhang_or_overflow(layer, broken, width) do
    if same_pixels?(layer, broken) do
      within_box(layer, width, nil)
    else
      {:ok, layer}
    end
  end

  defp same_pixels?(image, other) do
    Image.shape(image) == Image.shape(other) and
      Vimage.write_to_binary(image) == Vimage.write_to_binary(other)
  end

  # The largest size at which the text fits, else the smallest size with
  # the text shortened until it fits.
  defp fit_text(string, [font_size | smaller], options) do
    with {:ok, limits} <- limits(string, font_size, options),
         {:ok, layer} <- measure_string(string, measuring_options(options, font_size)) do
      cond do
        fits?(layer, limits) -> place(layer, options)
        smaller == [] -> shorten(string, font_size, limits, layer, options)
        true -> fit_text(string, smaller, options)
      end
    end
  end

  # Measured with no :height, which would have libvips choose its own size,
  # and from the top, so that the layer is the text and nothing more.
  defp measuring_options(options, font_size) do
    Map.merge(options, %{font_size: font_size, height: nil, y: :top})
  end

  # A layer fits when it is no wider than `:width` (libvips sets a word that
  # cannot be broken wider) and no taller than every height limit.
  defp fits?(layer, %{width: width, heights: heights}) do
    height = Image.height(layer)
    Image.width(layer) <= width and Enum.all?(heights, &(height <= &1))
  end

  defp limits(string, font_size, options) do
    with {:ok, lines_height} <- lines_height(string, font_size, options) do
      heights = Enum.reject([lines_height, Map.get(options, :height)], &is_nil/1)
      {:ok, %{width: options.width, heights: heights}}
    end
  end

  # How tall `:max_lines` lines are: each line holds every character the text
  # (and its ellipsis) uses, so the measure is that of the tallest line the
  # text can have, whatever the fonts its scripts are drawn from.
  defp lines_height(_string, _font_size, %{max_lines: nil}) do
    {:ok, nil}
  end

  defp lines_height(string, font_size, options) do
    sample = line_sample(string, options.ellipsis)

    lines =
      sample
      |> List.duplicate(options.max_lines)
      |> Enum.join("\n")

    sample_options =
      options
      |> measuring_options(font_size)
      |> Map.merge(%{width: nil, x: :left})

    with {:ok, layer} <- measure_string(lines, sample_options) do
      {:ok, Image.height(layer)}
    end
  end

  defp line_sample(string, ellipsis) do
    graphemes =
      (plain_text(string) <> ellipsis)
      |> String.graphemes()
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.uniq()

    case graphemes do
      [] -> "A"
      [_ | _] -> Enum.join(graphemes)
    end
  end

  defp plain_text({:safe, markup}) do
    markup
    |> IO.iodata_to_binary()
    |> String.replace(~r/<[^>]*>/, "")
  end

  defp plain_text(string) do
    string
  end

  # Markup is not shortened: cutting it at a word could cut through a tag.
  defp shorten({:safe, _markup}, _font_size, limits, layer, options) do
    clip(layer, limits, options)
  end

  defp shorten(string, font_size, limits, layer, options) do
    tokens = Regex.split(~r/(\s+)/u, String.trim(string), include_captures: true)
    word_count = div(length(tokens) + 1, 2)

    cut = fn count ->
      tokens
      |> Enum.take(2 * count - 1)
      |> Enum.join()
      |> measure_cut(font_size, limits, options)
    end

    case largest_fitting(1, word_count - 1, cut, nil) do
      {:ok, nil} -> shorten_word(hd(tokens), font_size, limits, layer, options)
      {:ok, fitted} -> place(fitted, options)
      {:error, _reason} = error -> error
    end
  end

  # When not even the first word fits, as for text written without spaces,
  # the first word is cut between its graphemes.
  defp shorten_word(word, font_size, limits, layer, options) do
    cut = fn count ->
      word
      |> String.slice(0, count)
      |> measure_cut(font_size, limits, options)
    end

    case largest_fitting(1, String.length(word) - 1, cut, nil) do
      {:ok, nil} -> clip(layer, limits, options)
      {:ok, fitted} -> place(fitted, options)
      {:error, _reason} = error -> error
    end
  end

  # Text that fits at no size and no length, in a box too small for even
  # one grapheme, is cut to the box rather than returned as an error.
  defp clip(layer, %{width: width, heights: heights}, options) do
    width = min(Image.width(layer), width)
    height = Enum.min([Image.height(layer) | heights])

    with {:ok, clipped} <- Image.crop(layer, 0, 0, width, height) do
      place(clipped, options)
    end
  end

  defp measure_cut(text, font_size, limits, options) do
    shortened = String.replace(text, ~r/[\s\p{Pd},;:]+$/u, "") <> options.ellipsis

    with {:ok, layer} <- measure_string(shortened, measuring_options(options, font_size)) do
      {:ok, {layer, fits?(layer, limits)}}
    end
  end

  # The largest count in `low..high` whose cut fits, searched by halving on
  # the grounds that a shorter cut fits whenever a longer one does.
  defp largest_fitting(low, high, _cut, best) when low > high do
    {:ok, best}
  end

  defp largest_fitting(low, high, cut, best) do
    middle = div(low + high, 2)

    case cut.(middle) do
      {:ok, {layer, true}} -> largest_fitting(middle + 1, high, cut, layer)
      {:ok, {_layer, false}} -> largest_fitting(low, middle - 1, cut, best)
      {:error, _reason} = error -> error
    end
  end

  # A fitted layer is placed on a `:width` by `:height` canvas when a height
  # is given, as unfitted text is.
  defp place(layer, options) do
    height = Map.get(options, :height)

    if is_nil(height) do
      {:ok, layer}
    else
      with {:ok, {x, y}} <-
             location_from_options(layer, options.x, options.y, options.width, height) do
        Operation.embed(layer, x, y, options.width, height)
      end
    end
  end

  defp font_size(options) do
    if options.font_size > 0, do: " #{inspect(options.font_size)}", else: ""
  end

  defp maybe_add_height(options, nil), do: options
  defp maybe_add_height(options, height), do: Keyword.put(options, :height, height)

  defp maybe_add_width(options, nil), do: options
  defp maybe_add_width(options, width), do: Keyword.put(options, :width, width)

  defp maybe_add_dpi(options, nil), do: options
  defp maybe_add_dpi(options, dpi), do: Keyword.put(options, :dpi, dpi)

  # `:markup` has libvips render RGBA directly so that the colors set in the
  # Pango markup survive. Any other fill color renders as a single band
  # coverage mask which is colorized afterwards.
  defp maybe_add_rgba(options, :markup) do
    Keyword.put(options, :rgba, true)
  end

  defp maybe_add_rgba(options, _text_fill_color) do
    options
  end

  # An RGBA render is already a complete four band image. A coverage mask
  # becomes the alpha band of a layer filled with the text color.
  defp colorize_text(rendered, :markup) do
    {:ok, rendered}
  end

  defp colorize_text(text_mask, text_fill_color) do
    with {:ok, color_layer} <- Image.new(text_mask, color: text_fill_color) do
      Operation.bandjoin([color_layer, text_mask])
    end
  end

  @span_params [:letter_spacing, :font_weight]

  # If the text starts with a span then we assume the user is
  # determining the text format
  defp maybe_add_pango_span("<span" <> _rest = text, _options) do
    {:ok, text}
  end

  defp maybe_add_pango_span(text, options) do
    span_params =
      @span_params
      |> Enum.map(&span_param(&1, options[&1]))
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")

    if span_params == "" do
      {:ok, text}
    else
      {:ok, "<span #{span_params}>#{text}</span>"}
    end
  end

  defp span_param(:letter_spacing, letter_spacing) when is_integer(letter_spacing) do
    "letter_spacing='#{round(letter_spacing * 1024)}'"
  end

  defp span_param(:font_weight, :normal) do
    nil
  end

  defp span_param(:font_weight, font_weight)
       when is_atom(font_weight) or is_integer(font_weight) do
    "font_weight='#{font_weight}'"
  end

  defp span_param(_, _) do
    nil
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
    {:error,
     %Image.Error{
       message: ":center and :right cannot be specified unless :width is also specified",
       reason: ":center and :right cannot be specified unless :width is also specified"
     }}
  end

  defp location_from_options(_image, _x, y_location, _width, nil)
       when y_location in [:middle, :bottom] do
    {:error,
     %Image.Error{
       message: ":middle and :bottom cannot be specified unless :height is also specified",
       reason: ":middle and :bottom cannot be specified unless :height is also specified"
     }}
  end

  defp location_from_options(image, x, y, width, nil) when is_integer(width) do
    if Image.width(image) + x <= width do
      {:ok, {x, y}}
    else
      message =
        "Location [#{inspect(x)}, _] would place the text " <>
          "outside the image bounds specified"

      {:error, %Image.Error{message: message, reason: message}}
    end
  end

  defp location_from_options(image, x, y, nil, height) when is_integer(height) do
    if Image.height(image) + y <= height do
      {:ok, {x, y}}
    else
      message =
        "Location [_, #{inspect(y)}] would place the text " <>
          "outside the image bounds specified"

      {:error, %Image.Error{message: message, reason: message}}
    end
  end

  defp location_from_options(image, x, y, width, height)
       when is_integer(width) and is_integer(height) do
    if Image.width(image) + x <= width && Image.height(image) + y <= height do
      {:ok, {x, y}}
    else
      message =
        "Location [#{inspect(x)}, #{inspect(y)}] would place the text " <>
          "outside the image bounds specified"

      {:error, %Image.Error{message: message, reason: message}}
    end
  end

  # Transparent text is a mask, so it becomes the background's alpha
  # channel. Otherwise the text is composited over the background.
  defp join_background(background, image, options) do
    if transparent_text?(options) do
      with {:ok, joined} <- Operation.bandjoin([background, image]) do
        {:ok, apply_opacity(joined, options)}
      end
    else
      Operation.composite2(background, image, :VIPS_BLEND_MODE_OVER)
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

    with {:ok, {rectangle, _flags}} <- Operation.svgload_buffer(svg) do
      if transparent_text?(options) do
        Operation.extract_band(rectangle, 0, n: 3)
      else
        {:ok, rectangle}
      end
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
