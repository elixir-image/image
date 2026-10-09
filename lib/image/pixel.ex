defmodule Image.Pixel do
  @moduledoc """
  Bridges the [`Color`](https://hexdocs.pm/color) library and libvips
  pixel arguments.

  Every libvips operation that takes a color (background, fill, draw,
  flatten, embed, …) ultimately wants a flat list of numbers in the
  interpretation, value range, and band layout of the image it is
  operating on. This module owns that conversion so that callers can
  pass user-friendly inputs (atoms, hex strings, `Color.*` structs,
  numeric lists) without worrying about whether the target image is
  sRGB, Lab, scRGB, CMYK, or 16-bit.

  ## Opacity, alpha and color

  An **opacity** (`t:opacity/0`) is the value a caller supplies,
  expressed relative to full opacity rather than to any image:
  `:transparent`, `:opaque`, a float in `0.0..1.0`, or an integer
  in `0..255` as the same value in 8-bit notation.

  An **alpha** is what an opacity becomes, the content of an image's
  alpha band. `alpha_for/2` scales an opacity to a given image's
  band, which runs to `65535` for 16-bit and `1.0` for scRGB, and
  `put_alpha/3` sets it on an existing pixel. Prefer a float when
  the alpha band is not 8-bit: an integer is a fraction of 255, so
  it cannot reach every value of a 16-bit or scRGB band.

  A **color** may be `:none`, `:transparent` or `:opaque` on top of
  everything `Color.new/2` accepts. All three resolve to black, the
  first two fully transparent.

  ## Example

      iex> {:ok, image} = Image.new(2, 2, color: :black)
      iex> Image.Pixel.to_pixel(image, :red)
      {:ok, [255, 0, 0]}

      iex> {:ok, image} = Image.new(2, 2, color: :black)
      iex> {:ok, lab_image} = Image.to_colorspace(image, :lab)
      iex> {:ok, [l, a, b]} = Image.Pixel.to_pixel(lab_image, :red)
      iex> {Float.round(l, 2), Float.round(a, 2), Float.round(b, 2)}
      {53.24, 80.09, 67.2}

  """

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.MutableImage

  @typedoc """
  Anything that `to_pixel/3` knows how to turn into a pixel.

  This includes any input accepted by `Color.new/2` (a `Color.*`
  struct, a numeric list of length 3..5, a hex string, a CSS named
  color string or atom), plus `:none`, `:transparent` and
  `:opaque`.

  """
  @type t ::
          struct()
          | [number()]
          | String.t()
          | atom()

  @typedoc """
  How opaque something should be, expressed relative to full
  opacity rather than to any particular image's alpha band.

  A float in `0.0..1.0` is the canonical form, being a fraction of
  full opacity. An integer in `0..255` is that same value in 8-bit
  notation, normalized as `n / 255`. The integer form does not
  imply that the target's alpha band is 8-bit: `128` means `128/255`
  on a 16-bit image too, not `128/65535`.

  > #### `1` and `1.0` differ {: .warning}
  >
  > `1` is 8-bit notation for `1/255`, which is very nearly
  > transparent. Fully opaque is `1.0` or `:opaque`.

  `:transparent` is `0.0` and `:opaque` is `1.0`. `:none` is not an
  opacity, only a color meaning no color at all.

  `alpha_for/2` scales an opacity to the alpha band of a given image,
  which is the range `0..65535` for a 16-bit image and `0.0..1.0` for
  an scRGB one.

  """
  @type opacity :: :transparent | :opaque | 0..255 | float()

  # Map Image.Interpretation atoms to the Color module that best
  # represents that space, and the encoder used by encode/3.
  @interpretation_to_target %{
    srgb: {Color.SRGB, :uchar_rgb},
    rgb: {Color.SRGB, :uchar_rgb},
    rgb16: {Color.SRGB, :ushort_rgb},
    scrgb: {Color.RGB, :float_rgb},
    lab: {Color.Lab, :float_lab},
    labs: {Color.Lab, :short_lab},
    lch: {Color.LCHab, :float_lch},
    cmyk: {Color.CMYK, :uchar_cmyk},
    hsv: {Color.HSV, :uchar_hsv},
    bw: {Color.SRGB, :uchar_grey},
    grey16: {Color.SRGB, :ushort_grey},
    multiband: {Color.SRGB, :uchar_rgb}
  }

  @doc """
  A defguard that loosely matches things that look like a pixel input.

  This is intentionally permissive — it accepts anything that *might*
  be a color (struct, numeric list, atom that isn't a boolean,
  binary). Actual validation happens in `to_pixel/3`.

  Use this in function-head guards where you need to dispatch a color
  argument away from an image argument (the `Image.if_then_else/4`
  pattern).

  """
  defguard is_pixel(value)
           when is_struct(value) or
                  (is_list(value) and value != [] and length(value) <= 5) or
                  is_binary(value) or
                  (is_atom(value) and value not in [nil, true, false]) or
                  is_number(value)

  @doc """
  Converts a color to a pixel matching the interpretation and band
  layout of `image`.

  ### Arguments

  * `image` is the target `t:Vix.Vips.Image.t/0`. Its interpretation
    and band count determine the output shape and value range.

  * `color` is anything `Color.new/2` accepts: a `Color.*` struct, a
    list of 3/4/5 numbers, a hex string (`"#ff0000"`, `"#f80"`,
    `"#ff000080"`), a CSS named color (`"rebeccapurple"`,
    `:misty_rose`), or `:none`, `:transparent` or `:opaque`.

  * `options` is a keyword list — see below.

  ### Options

  * `:opacity` — if the target image has an alpha band, force this
    opacity. Accepts any `t:opacity/0`. If unset, the input color's
    own alpha is used, or full opacity if it has none.

  * `:intent` — passed through to `Color.convert/3`. One of
    `:relative_colorimetric` (default), `:absolute_colorimetric`,
    `:perceptual`, or `:saturation`.

  ### Returns

  * `{:ok, [number(), ...]}` — a flat list of numbers in the band
    order and pixel range that the image's interpretation expects.

  * `{:error, reason}`.

  ### Notes

  * For 8-bit interpretations (`:srgb`, `:rgb`, `:cmyk`, `:hsv`,
    `:bw`) the output is integers in `0..255`.

  * For 16-bit interpretations (`:rgb16`, `:grey16`) the output is
    integers in `0..65535`.

  * For `:scrgb`, `:lab` and `:lch` the color bands are floats in the
    natural range of that space, and `:labs` uses 16-bit integers.
    The alpha component is `0.0..1.0` for `:scrgb` and `0..255` for
    the other three.

  * `:scrgb` is linear light: mid grey `"#808080"` encodes as `0.216`,
    not `0.502`.

  * The output band count matches `Vix.Vips.Image.bands/1` exactly.
    Alpha is appended when the image has an alpha band, and stripped
    when it does not.

  * 1-band `:bw` and `:grey16` images receive a single luminance
    channel computed from the perceptually-uniform `Color.Lab` `L*`,
    as does any other interpretation that arrives with one band.

  * 1-band `:scrgb` is the exception: it holds linear light, so it
    receives relative luminance computed from `Color.XYZ` `Y`.

  ### Examples

      iex> {:ok, image} = Image.new(2, 2, color: :black)
      iex> Image.Pixel.to_pixel(image, :red)
      {:ok, [255, 0, 0]}

      iex> {:ok, image} = Image.new(2, 2, color: [0, 0, 0, 255])
      iex> Image.Pixel.to_pixel(image, :red)
      {:ok, [255, 0, 0, 255]}

      iex> {:ok, image} = Image.new(2, 2, color: [0, 0, 0, 255])
      iex> Image.Pixel.to_pixel(image, :red, opacity: 0.5)
      {:ok, [255, 0, 0, 128]}

      iex> {:ok, image} = Image.new(2, 2, color: :black)
      iex> Image.Pixel.to_pixel(image, "#ff000080")
      {:ok, [255, 0, 0]}

  """
  @spec to_pixel(
          image :: Vimage.t() | MutableImage.t(),
          color :: t(),
          options :: Keyword.t()
        ) :: {:ok, [number()]} | {:error, Image.Error.t()}
  def to_pixel(image, color, options \\ [])

  # If the input is already a list of numbers whose length matches the
  # image's band count AND whose values are all in the natural pixel
  # range for the image's interpretation, treat it as a pre-encoded
  # pixel and pass it through unchanged. This is the back-compat path
  # for callers that already speak the image's interpretation
  # natively (Image.if_then_else, k-means clusters, gradient defaults,
  # etc).
  def to_pixel(%Vimage{} = image, color, options)
      when is_list(color) and color != [] do
    bands = Vimage.bands(image)
    interpretation = Image.colorspace(image)

    if length(color) == bands and pre_encoded?(color, interpretation) do
      case fetch_opacity(options) do
        nil -> {:ok, color}
        opacity -> put_alpha(color, image, opacity)
      end
    else
      do_to_pixel_vimage(image, color, options)
    end
  end

  def to_pixel(%Vimage{} = image, color, options) do
    do_to_pixel_vimage(image, color, options)
  end

  def to_pixel(%MutableImage{} = image, color, _options)
      when is_list(color) and color != [] do
    {:ok, {_w, _h, bands}} = MutableImage.shape(image)

    if length(color) == bands and pre_encoded?(color, :srgb) do
      {:ok, color}
    else
      do_to_pixel_mutable(image, color, [])
    end
  end

  def to_pixel(%MutableImage{} = image, color, options) do
    do_to_pixel_mutable(image, color, options)
  end

  # A list is already encoded for the image's interpretation if the
  # values sit in the natural range of that interpretation.
  defp pre_encoded?(list, interpretation)
       when interpretation in [:srgb, :rgb, :cmyk, :hsv, :bw, :multiband] do
    Enum.all?(list, fn v -> is_integer(v) and v >= 0 and v <= 255 end)
  end

  defp pre_encoded?(list, interpretation) when interpretation in [:rgb16, :grey16] do
    Enum.all?(list, fn v -> is_integer(v) and v >= 0 and v <= 65_535 end)
  end

  defp pre_encoded?(list, interpretation)
       when interpretation in [:lab, :labs, :lch, :scrgb, :xyz] do
    # Float-valued interpretations: if the caller sent floats at all,
    # trust them; integer lists in these spaces are almost always a
    # mis-use and we should convert instead.
    Enum.all?(list, &is_float/1)
  end

  defp pre_encoded?(_list, _interpretation), do: false

  defp do_to_pixel_vimage(image, color, options) do
    interpretation = Image.colorspace(image)
    bands = Vimage.bands(image)
    has_alpha = Vimage.has_alpha?(image)
    do_to_pixel(interpretation, bands, has_alpha, color, options)
  end

  defp do_to_pixel_mutable(image, color, options) do
    {:ok, {_w, _h, bands}} = MutableImage.shape(image)
    {:ok, has_alpha} = MutableImage.has_alpha?(image)
    # MutableImage does not expose an interpretation accessor, so we
    # default to :srgb. The mutable code path is almost always sRGB
    # because Image.mutate/2 is mostly used by the drawing functions
    # which assume sRGB inputs today. Callers who need exact
    # interpretation handling for mutable images should call
    # to_pixel/3 with the source Vimage before entering the mutate
    # block.
    do_to_pixel(:srgb, bands, has_alpha, color, options)
  end

  defp do_to_pixel(interpretation, bands, has_alpha, color, options) do
    intent = Keyword.get(options, :intent, :relative_colorimetric)
    explicit_opacity = fetch_opacity(options)
    color_bands = if has_alpha, do: bands - 1, else: bands

    with {:ok, source_struct} <- resolve(color),
         {:ok, {target_module, encoder}} <- target_for(interpretation, color_bands),
         {:ok, converted} <- convert(source_struct, target_module, intent),
         {:ok, base_pixel} <- encode(encoder, converted),
         {:ok, alpha_value} <- resolve_alpha(encoder, explicit_opacity, source_struct, has_alpha) do
      {:ok, fit_bands(base_pixel, alpha_value, bands, has_alpha)}
    else
      # `Color.convert/3` reports failures with its own exceptions too.
      {:error, %Image.Error{} = error} -> {:error, error}
      {:error, reason} -> {:error, invalid_color(color, reason)}
    end
  end

  @doc """
  Same as `to_pixel/3`, but raises on error.

  ### Examples

      iex> image = Image.new!(2, 2, color: :black)
      iex> Image.Pixel.to_pixel!(image, :red)
      [255, 0, 0]

      iex> image = Image.new!(2, 2, color: [0, 0, 0, 255])
      iex> Image.Pixel.to_pixel!(image, :red, opacity: 0.5)
      [255, 0, 0, 128]

  """
  @spec to_pixel!(image :: Vimage.t(), color :: t(), options :: Keyword.t()) :: [number()]
  def to_pixel!(image, color, options \\ []) do
    case to_pixel(image, color, options) do
      {:ok, pixel} -> pixel
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Returns a resolved pixel without its alpha component, if it
  has one.

  ### Arguments

  * `pixel` is a list of numbers in `image`'s band layout, such as
    the output of `to_pixel/3`.

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `pixel` without its last element if `image` has an alpha band
    and `pixel` spans all of `image`'s bands, or

  * `pixel` unchanged. A pixel that does not span the image's
    bands exactly has no identifiable alpha component, so it is
    left alone.

  ### Notes

  * The band count is the only check, so a pixel resolved against
    another image of the same band count is truncated just the same.

  ### Examples

      iex> {:ok, image} = Image.new(2, 2, color: [0, 0, 0, 255])
      iex> {:ok, pixel} = Image.Pixel.to_pixel(image, :red)
      iex> Image.Pixel.strip_alpha(pixel, image)
      [255, 0, 0]

      iex> {:ok, image} = Image.new(2, 2, color: :black)
      iex> {:ok, pixel} = Image.Pixel.to_pixel(image, :red)
      iex> Image.Pixel.strip_alpha(pixel, image)
      [255, 0, 0]

  """
  @spec strip_alpha(pixel :: [number()], image :: Vimage.t()) :: [number()]
  def strip_alpha(pixel, %Vimage{} = image) when is_list(pixel) do
    if Vimage.has_alpha?(image) and length(pixel) == Vimage.bands(image) do
      Enum.take(pixel, length(pixel) - 1)
    else
      pixel
    end
  end

  @doc """
  Returns `pixel` with its alpha component set to `opacity`, scaled
  to the alpha band of `image`.

  The inverse of `strip_alpha/2`, and like it a no-op on an image
  with no alpha band, since there is no component to set. `opacity`
  is validated either way.

  ### Arguments

  * `pixel` is a list of numbers already in `image`'s interpretation.

  * `image` is any `t:Vix.Vips.Image.t/0`. Its interpretation
    determines the alpha the opacity scales to.

  * `opacity` is any `t:opacity/0`.

  ### Returns

  * `{:ok, pixel}` with its last component replaced, or with `pixel`
    unchanged if `image` has no alpha band, or

  * `{:error, reason}`.

  ### Examples

      iex> {:ok, image} = Image.new(2, 2, color: [0, 0, 0, 255])
      iex> Image.Pixel.put_alpha([255, 0, 0, 255], image, 0.5)
      {:ok, [255, 0, 0, 128]}

      iex> {:ok, image} = Image.new(2, 2, color: :black)
      iex> Image.Pixel.put_alpha([255, 0, 0], image, 0.5)
      {:ok, [255, 0, 0]}

  """
  @spec put_alpha(pixel :: [number()], image :: Vimage.t(), opacity :: opacity()) ::
          {:ok, [number()]} | {:error, Image.Error.t()}

  def put_alpha(pixel, %Vimage{} = image, opacity) when is_list(pixel) do
    if Vimage.has_alpha?(image) do
      with {:ok, alpha} <- alpha_for(image, opacity) do
        {:ok, Enum.take(pixel, Vimage.bands(image) - 1) ++ [alpha]}
      end
    else
      # Checked even when there is no band to write it to.
      with {:ok, _unit} <- opacity_fraction(opacity), do: {:ok, pixel}
    end
  end

  @doc """
  Same as `put_alpha/3`, but raises on error.

  ### Examples

      iex> image = Image.new!(2, 2, color: [0, 0, 0, 255])
      iex> Image.Pixel.put_alpha!([255, 0, 0, 255], image, 0.5)
      [255, 0, 0, 128]

  """
  @spec put_alpha!(pixel :: [number()], image :: Vimage.t(), opacity :: opacity()) :: [number()]
  def put_alpha!(pixel, %Vimage{} = image, opacity) do
    case put_alpha(pixel, image, opacity) do
      {:ok, pixel} -> pixel
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Resolves a color input to an sRGB pixel `[r, g, b]` (or
  `[r, g, b, a]`) with channels in `0..255`, regardless of any
  image context.

  Use this for callers that need sRGB output specifically — for
  example SVG renderers — rather than the interpretation of an
  image. For image-aware encoding use `to_pixel/3`.

  ### Arguments

  * `color` is anything `Color.new/2` accepts, plus `:none`,
    `:transparent` and `:opaque`.

  ### Returns

  * `{:ok, [0..255, 0..255, 0..255]}` or
    `{:ok, [0..255, 0..255, 0..255, 0..255]}` if the source had an
    alpha channel.

  * `{:error, reason}`.

  ### Examples

      iex> Image.Pixel.to_srgb(:red)
      {:ok, [255, 0, 0]}

      iex> Image.Pixel.to_srgb("#ff000080")
      {:ok, [255, 0, 0, 128]}

      iex> Image.Pixel.to_srgb(%Color.Lab{l: 53.24, a: 80.09, b: 67.20})
      {:ok, [255, 0, 0]}

  """
  @spec to_srgb(color :: t()) :: {:ok, [0..255]} | {:error, Image.Error.t()}
  def to_srgb(color) do
    with {:ok, source_struct} <- resolve(color),
         {:ok, %Color.SRGB{r: r, g: g, b: b, alpha: alpha}} <-
           Color.convert(source_struct, Color.SRGB) do
      base = [scale(r, 255), scale(g, 255), scale(b, 255)]

      if is_nil(alpha) do
        {:ok, base}
      else
        {:ok, base ++ [scale(alpha, 255)]}
      end
    else
      {:error, %Image.Error{} = error} -> {:error, error}
      {:error, reason} -> {:error, invalid_color(color, reason)}
    end
  end

  @doc """
  Same as `to_srgb/1`, but raises on error.

  ### Examples

      iex> Image.Pixel.to_srgb!(:red)
      [255, 0, 0]

      iex> Image.Pixel.to_srgb!("#ff000080")
      [255, 0, 0, 128]

  """
  @spec to_srgb!(color :: t()) :: [0..255]
  def to_srgb!(color) do
    case to_srgb(color) do
      {:ok, pixel} -> pixel
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Returns an alpha value scaled to the alpha band of `image`.

  The result is in the range `image` actually uses: `0..65535` for
  16-bit images, `0.0..1.0` for scRGB, and `0..255` for everything
  else, including Lab and LCH despite their float color bands.

  The result is a band value, to be written into a pixel. It is
  not an opacity and must not be passed back where one is expected,
  such as `Image.add_alpha/2` or the `:opacity` option of
  `to_pixel/3`, which would scale it a second time.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `opacity` is any `t:opacity/0`.

  ### Returns

  * `{:ok, number}` or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(2, 2, color: :black)
      iex> Image.Pixel.alpha_for(image, :opaque)
      {:ok, 255}

      iex> image = Image.new!(2, 2, color: :black)
      iex> Image.Pixel.alpha_for(Image.to_colorspace!(image, :rgb16), 0.5)
      {:ok, 32768}

      iex> image = Image.new!(2, 2, color: :black)
      iex> Image.Pixel.alpha_for(Image.to_colorspace!(image, :scrgb), :opaque)
      {:ok, 1.0}

  """
  @spec alpha_for(image :: Vimage.t(), opacity :: opacity()) ::
          {:ok, number()} | {:error, Image.Error.t()}

  def alpha_for(%Vimage{} = image, opacity) do
    bands = Vimage.bands(image)
    color_bands = if Vimage.has_alpha?(image), do: bands - 1, else: bands

    with {:ok, unit} <- opacity_fraction(opacity),
         {:ok, {_target_module, encoder}} <- target_for(Image.colorspace(image), color_bands) do
      {:ok, scale_alpha_to_encoder(unit, encoder)}
    end
  end

  @doc """
  Same as `alpha_for/2`, but raises on error.

  ### Examples

      iex> image = Image.new!(2, 2, color: :black)
      iex> Image.Pixel.alpha_for!(image, :opaque)
      255

  """
  @spec alpha_for!(image :: Vimage.t(), opacity :: opacity()) :: number()
  def alpha_for!(%Vimage{} = image, opacity) do
    case alpha_for(image, opacity) do
      {:ok, alpha} -> alpha
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Returns an opacity as a fraction of full opacity.

  The `0.0..1.0` float is the canonical form of an opacity, so this
  is the identity for a float and `n / 255` for an integer. Unlike
  `alpha_for/2`, the result belongs to no particular image.

  ### Arguments

  * `opacity` is any `t:opacity/0`.

  ### Returns

  * `{:ok, float}` in `0.0..1.0`, or

  * `{:error, t:Image.Error.t/0}`.

  ### Examples

      iex> Image.Pixel.opacity_fraction(:opaque)
      {:ok, 1.0}

      iex> Image.Pixel.opacity_fraction(0.5)
      {:ok, 0.5}

      iex> Image.Pixel.opacity_fraction(128)
      {:ok, 0.5019607843137255}

  """
  @spec opacity_fraction(opacity :: opacity()) :: {:ok, float()} | {:error, Image.Error.t()}

  def opacity_fraction(:transparent), do: {:ok, 0.0}
  def opacity_fraction(:opaque), do: {:ok, 1.0}

  def opacity_fraction(int) when is_integer(int) and int in 0..255,
    do: {:ok, int / 255}

  def opacity_fraction(float) when is_float(float) and float >= 0.0 and float <= 1.0,
    do: {:ok, float}

  def opacity_fraction(other), do: invalid_opacity(other)

  @doc """
  Same as `opacity_fraction/1`, but raises on error.

  ### Examples

      iex> Image.Pixel.opacity_fraction!(:transparent)
      0.0

  """
  @spec opacity_fraction!(opacity :: opacity()) :: float()
  def opacity_fraction!(opacity) do
    case opacity_fraction(opacity) do
      {:ok, fraction} -> fraction
      {:error, reason} -> raise Image.Error, reason
    end
  end

  ## Internals --------------------------------------------------------------

  # Resolve the user input into a Color struct.
  defp resolve(:none), do: {:ok, %Color.SRGB{r: 0.0, g: 0.0, b: 0.0, alpha: 0.0}}
  defp resolve(:transparent), do: {:ok, %Color.SRGB{r: 0.0, g: 0.0, b: 0.0, alpha: 0.0}}
  defp resolve(:opaque), do: {:ok, %Color.SRGB{r: 0.0, g: 0.0, b: 0.0, alpha: 1.0}}

  # Image historically accepts a single integer or float as a uniform
  # grey value. Promote it to a 3-channel sRGB so the rest of the
  # pipeline doesn't have to special-case scalars.
  defp resolve(int) when is_integer(int) and int in 0..255,
    do: {:ok, %Color.SRGB{r: int / 255, g: int / 255, b: int / 255, alpha: nil}}

  defp resolve(float) when is_float(float) and float >= 0.0 and float <= 1.0,
    do: {:ok, %Color.SRGB{r: float, g: float, b: float, alpha: nil}}

  # `Color` reports invalid input with its own exceptions. Translated so no
  # foreign error shape escapes this module.
  defp resolve(other) do
    case Color.new(other) do
      {:ok, color} -> {:ok, color}
      {:error, reason} -> {:error, invalid_color(other, reason)}
    end
  end

  defp invalid_color(value, reason) do
    message = if is_exception(reason), do: Exception.message(reason), else: to_string(reason)

    %Image.Error{reason: :invalid_color, value: value, message: message}
  end

  # Color.RGB is the only target that needs a working space
  # libvips scRGB is linear light on the sRGB primaries.
  defp convert(source, Color.RGB, intent),
    do: Color.convert(source, Color.RGB, :SRGB, intent: intent)

  defp convert(source, target, intent),
    do: Color.convert(source, target, intent: intent)

  # When the image has only one color channel (greyscale), force a
  # luma encoder regardless of the nominal interpretation. libvips
  # tags single-band images as :srgb / :rgb / :multiband fairly often
  # so we can't rely on the interpretation atom alone. The tag still
  # picks the value range, which the band count cannot tell us.
  defp target_for(:scrgb, 1), do: {:ok, {Color.RGB, :float_grey}}

  defp target_for(interpretation, 1)
       when interpretation in [:srgb, :rgb, :multiband, :bw],
       do: {:ok, {Color.SRGB, :uchar_grey}}

  defp target_for(interpretation, 1) when interpretation in [:rgb16, :grey16],
    do: {:ok, {Color.SRGB, :ushort_grey}}

  defp target_for(interpretation, _bands) do
    case Map.fetch(@interpretation_to_target, interpretation) do
      {:ok, pair} ->
        {:ok, pair}

      :error ->
        {:error,
         %Image.Error{
           reason: :unsupported_interpretation,
           value: interpretation,
           message:
             "Image.Pixel does not yet support the #{inspect(interpretation)} interpretation. " <>
               "Pass a numeric pixel list directly, or open an issue."
         }}
    end
  end

  ## Encoders --------------------------------------------------------------

  defp encode(:uchar_rgb, %Color.SRGB{r: r, g: g, b: b}),
    do: {:ok, [scale(r, 255), scale(g, 255), scale(b, 255)]}

  defp encode(:ushort_rgb, %Color.SRGB{r: r, g: g, b: b}),
    do: {:ok, [scale(r, 65_535), scale(g, 65_535), scale(b, 65_535)]}

  defp encode(:float_rgb, %Color.RGB{r: r, g: g, b: b}),
    do: {:ok, [r * 1.0, g * 1.0, b * 1.0]}

  defp encode(:float_grey, %Color.RGB{} = rgb) do
    with {:ok, %Color.XYZ{y: y}} <- Color.RGB.to_xyz(rgb) do
      {:ok, [y * 1.0]}
    end
  end

  defp encode(:float_lab, %Color.Lab{l: l, a: a, b: b}),
    do: {:ok, [l * 1.0, a * 1.0, b * 1.0]}

  # libvips LABS uses signed shorts: L*327.68, a*256, b*256.
  defp encode(:short_lab, %Color.Lab{l: l, a: a, b: b}),
    do: {:ok, [round(l * 327.68), round(a * 256), round(b * 256)]}

  defp encode(:float_lch, %Color.LCHab{l: l, c: c, h: h}),
    do: {:ok, [l * 1.0, c * 1.0, h * 1.0]}

  defp encode(:uchar_cmyk, %Color.CMYK{c: c, m: m, y: y, k: k}),
    do: {:ok, [scale(c, 255), scale(m, 255), scale(y, 255), scale(k, 255)]}

  # libvips HSV uses uchar (0..255) for all three channels.
  # Color.HSV uses [0, 1] for h, s, v.
  defp encode(:uchar_hsv, %Color.HSV{h: h, s: s, v: v}),
    do: {:ok, [scale(h, 255), scale(s, 255), scale(v, 255)]}

  # 1-band greyscale: use Color.Lab L* as a perceptually-correct luma.
  # We get here with a Color.SRGB struct (target_for/1 picks SRGB for
  # :bw and :grey16) so we have to do the SRGB → Lab hop ourselves.
  defp encode(:uchar_grey, %Color.SRGB{} = srgb) do
    with {:ok, %Color.Lab{l: l}} <- Color.convert(srgb, Color.Lab) do
      {:ok, [scale(l / 100.0, 255)]}
    end
  end

  defp encode(:ushort_grey, %Color.SRGB{} = srgb) do
    with {:ok, %Color.Lab{l: l}} <- Color.convert(srgb, Color.Lab) do
      {:ok, [scale(l / 100.0, 65_535)]}
    end
  end

  defp encode(encoder, struct) do
    {:error,
     "Image.Pixel encoder #{inspect(encoder)} cannot encode a #{inspect(struct.__struct__)}"}
  end

  defp scale(value, max) when is_number(value) do
    value
    |> Kernel.*(max)
    |> :erlang.round()
    |> clamp(0, max)
  end

  defp clamp(value, lo, _hi) when value < lo, do: lo
  defp clamp(value, _lo, hi) when value > hi, do: hi
  defp clamp(value, _lo, _hi), do: value

  ## Alpha handling -------------------------------------------------------

  defp fetch_opacity(options) do
    Keyword.get(options, :opacity)
  end

  defp resolve_alpha(_encoder, _explicit, _source, false), do: {:ok, nil}

  defp resolve_alpha(encoder, explicit_opacity, source, true) do
    cond do
      not is_nil(explicit_opacity) ->
        with {:ok, normalized} <- opacity_fraction(explicit_opacity) do
          {:ok, scale_alpha_to_encoder(normalized, encoder)}
        end

      is_struct(source) and Map.get(source, :alpha) != nil ->
        {:ok, scale_alpha_to_encoder(source.alpha, encoder)}

      true ->
        {:ok, scale_alpha_to_encoder(1.0, encoder)}
    end
  end

  defp invalid_opacity(value) do
    {:error,
     %Image.Error{
       reason: :invalid_opacity,
       value: value,
       message:
         "Invalid opacity #{inspect(value)}. Must be a float in 0.0..1.0, " <>
           "an integer in 0..255, :transparent or :opaque"
     }}
  end

  # Encoders grouped by their alpha band's max value
  @alpha_max_255 [
    :uchar_rgb,
    :uchar_cmyk,
    :uchar_hsv,
    :uchar_grey,
    :float_lab,
    :float_lch,
    :short_lab
  ]
  @alpha_max_65535 [:ushort_rgb, :ushort_grey]
  @alpha_max_1 [:float_rgb, :float_grey]

  # The alpha band uses the same numeric type as the rest of the
  # interpretation: 0..255 for uchar, 0..65535 for ushort, 0.0..1.0
  # for float-typed bands. scRGB is the only float interpretation whose
  # alpha is in [0, 1]. LABS / Lab / LCH carry a 0..255 alpha band
  # despite their float/short color bands.
  defp scale_alpha_to_encoder(alpha, encoder) do
    case encoder do
      e when e in @alpha_max_255 -> scale(alpha, 255)
      e when e in @alpha_max_65535 -> scale(alpha, 65_535)
      e when e in @alpha_max_1 -> alpha * 1.0
    end
  end

  defp fit_bands(base_pixel, alpha_value, bands, has_alpha) do
    pixel = if has_alpha and alpha_value != nil, do: base_pixel ++ [alpha_value], else: base_pixel

    cond do
      length(pixel) == bands ->
        pixel

      length(pixel) > bands ->
        Enum.take(pixel, bands)

      length(pixel) < bands ->
        # Pad with the last channel (works for greyscale → multiband
        # corner cases — uncommon but defined).
        pixel ++ List.duplicate(List.last(pixel), bands - length(pixel))
    end
  end
end
