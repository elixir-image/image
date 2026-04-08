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
  color string or atom), plus the Image-specific transparency aliases
  `:none`, `:transparent`, and `:opaque`.

  """
  @type t ::
          struct()
          | [number()]
          | String.t()
          | atom()

  @typedoc """
  A transparency value.

  * `:none` and `:transparent` are equivalent to `0` (fully transparent).
  * `:opaque` is equivalent to `255` (fully opaque).
  * An integer in `0..255` is used as-is.
  * A float in `0.0..1.0` is scaled to `0..255`.

  """
  @type transparency :: :none | :transparent | :opaque | 0..255 | float()

  @max_opacity 255
  @min_opacity 0

  # Map Image.Interpretation atoms to the Color module that best
  # represents that space, and the encoder used by encode/3.
  @interpretation_to_target %{
    srgb: {Color.SRGB, :uchar_rgb},
    rgb: {Color.SRGB, :uchar_rgb},
    rgb16: {Color.SRGB, :ushort_rgb},
    scrgb: {Color.SRGB, :float_rgb},
    lab: {Color.Lab, :float_lab},
    labs: {Color.Lab, :short_lab},
    lch: {Color.LCHab, :float_lch},
    cmyk: {Color.CMYK, :uchar_cmyk},
    hsv: {Color.Hsv, :uchar_hsv},
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
                  (is_list(value) and length(value) >= 1 and length(value) <= 5) or
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
    `:misty_rose`), or one of Image's transparency aliases (`:none`,
    `:transparent`, `:opaque`).

  * `options` is a keyword list — see below.

  ### Options

  * `:alpha` — if the target image has an alpha band, force this
    transparency. Accepts any value `transparency/1` accepts. If
    unset, the input color's own alpha is used (or full opacity if
    none).

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

  * For float interpretations (`:scrgb`, `:lab`, `:lch`, etc.) the
    output is floats in the natural range of that space.

  * The output band count matches `Vix.Vips.Image.bands/1` exactly.
    Alpha is appended when the image has an alpha band, and stripped
    when it does not.

  * 1-band (`:bw`, `:grey16`) images receive a single luminance
    channel computed from the perceptually-uniform `Color.Lab` `L*`.

  ### Examples

      iex> {:ok, image} = Image.new(2, 2, color: :black)
      iex> Image.Pixel.to_pixel(image, :red)
      {:ok, [255, 0, 0]}

      iex> {:ok, image} = Image.new(2, 2, color: [0, 0, 0, 255])
      iex> Image.Pixel.to_pixel(image, :red)
      {:ok, [255, 0, 0, 255]}

      iex> {:ok, image} = Image.new(2, 2, color: [0, 0, 0, 255])
      iex> Image.Pixel.to_pixel(image, :red, alpha: 0.5)
      {:ok, [255, 0, 0, 128]}

      iex> {:ok, image} = Image.new(2, 2, color: :black)
      iex> Image.Pixel.to_pixel(image, "#ff000080")
      {:ok, [255, 0, 0]}

  """
  @spec to_pixel(
          image :: Vimage.t() | MutableImage.t(),
          color :: t(),
          options :: Keyword.t()
        ) :: {:ok, [number()]} | {:error, String.t()}
  def to_pixel(image, color, options \\ [])

  # If the input is already a list of numbers whose length matches the
  # image's band count AND whose values are all in the natural pixel
  # range for the image's interpretation, treat it as a pre-encoded
  # pixel and pass it through unchanged. This is the back-compat path
  # for callers that already speak the image's interpretation
  # natively (Image.if_then_else, k-means clusters, gradient defaults,
  # etc).
  def to_pixel(%Vimage{} = image, color, _options)
      when is_list(color) and length(color) > 0 do
    bands = Vimage.bands(image)
    interpretation = Image.colorspace(image)

    if length(color) == bands and pre_encoded?(color, interpretation) do
      {:ok, color}
    else
      do_to_pixel_vimage(image, color, [])
    end
  end

  def to_pixel(%Vimage{} = image, color, options) do
    do_to_pixel_vimage(image, color, options)
  end

  def to_pixel(%MutableImage{} = image, color, _options)
      when is_list(color) and length(color) > 0 do
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
    explicit_alpha = Keyword.get(options, :alpha)
    color_bands = if has_alpha, do: bands - 1, else: bands

    with {:ok, source_struct} <- resolve(color),
         {:ok, {target_module, encoder}} <- target_for(interpretation, color_bands),
         {:ok, converted} <- Color.convert(source_struct, target_module, intent: intent),
         {:ok, base_pixel} <- encode(encoder, converted),
         {:ok, alpha_value} <- alpha_for(encoder, explicit_alpha, source_struct, has_alpha) do
      {:ok, fit_bands(base_pixel, alpha_value, bands, has_alpha)}
    end
  end

  @doc """
  Same as `to_pixel/3`, but raises on error.

  """
  @spec to_pixel!(image :: Vimage.t(), color :: t(), options :: Keyword.t()) :: [number()]
  def to_pixel!(image, color, options \\ []) do
    case to_pixel(image, color, options) do
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

  * `color` is anything `Color.new/2` accepts, plus the
    transparency aliases.

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
  @spec to_srgb(color :: t()) :: {:ok, [0..255]} | {:error, Image.Error.t() | term()}
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
    end
  end

  @doc """
  Same as `to_srgb/1`, but raises on error.

  """
  @spec to_srgb!(color :: t()) :: [0..255]
  def to_srgb!(color) do
    case to_srgb(color) do
      {:ok, pixel} -> pixel
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Returns a transparency value in `0..255` where `0` is transparent
  and `255` is opaque.

  ### Arguments

  * `transparency` is one of:

    * The atoms `:none`, `:transparent`, or `:opaque`.

    * An integer in `0..255`.

    * A float in `0.0..1.0`.

  ### Returns

  * `{:ok, 0..255}` or

  * `{:error, reason}`.

  ### Examples

      iex> Image.Pixel.transparency(:opaque)
      {:ok, 255}

      iex> Image.Pixel.transparency(:transparent)
      {:ok, 0}

      iex> Image.Pixel.transparency(0.5)
      {:ok, 128}

      iex> Image.Pixel.transparency(200)
      {:ok, 200}

  """
  @spec transparency(value :: transparency()) :: {:ok, 0..255} | {:error, Image.Error.t()}
  def transparency(:none), do: {:ok, @min_opacity}
  def transparency(:transparent), do: {:ok, @min_opacity}
  def transparency(:opaque), do: {:ok, @max_opacity}
  def transparency(int) when is_integer(int) and int in 0..255, do: {:ok, int}

  def transparency(float) when is_float(float) and float >= 0.0 and float <= 1.0,
    do: {:ok, round(@max_opacity * float)}

  def transparency(other) do
    {:error,
     %Image.Error{
       reason: :invalid_transparency,
       value: other,
       message: "Invalid transparency value: #{inspect(other)}"
     }}
  end

  @doc """
  The maximum opacity value (255).

  """
  @spec max_opacity() :: 255
  def max_opacity, do: @max_opacity

  @doc """
  The minimum opacity value (0).

  """
  @spec min_opacity() :: 0
  def min_opacity, do: @min_opacity

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

  defp resolve(other), do: Color.new(other)

  # When the image has only one color channel (greyscale), force a
  # luma encoder regardless of the nominal interpretation. libvips
  # tags single-band images as :srgb / :rgb / :multiband fairly often
  # so we can't rely on the interpretation atom alone.
  defp target_for(interpretation, 1)
       when interpretation in [:srgb, :rgb, :multiband, :bw, :scrgb],
       do: {:ok, {Color.SRGB, :uchar_grey}}

  defp target_for(interpretation, 1) when interpretation in [:rgb16, :grey16],
    do: {:ok, {Color.SRGB, :ushort_grey}}

  defp target_for(interpretation, _bands) do
    case Map.fetch(@interpretation_to_target, interpretation) do
      {:ok, pair} ->
        {:ok, pair}

      :error ->
        {:error,
         "Image.Pixel does not yet support the #{inspect(interpretation)} interpretation. " <>
           "Pass a numeric pixel list directly, or open an issue."}
    end
  end

  ## Encoders --------------------------------------------------------------

  defp encode(:uchar_rgb, %Color.SRGB{r: r, g: g, b: b}),
    do: {:ok, [scale(r, 255), scale(g, 255), scale(b, 255)]}

  defp encode(:ushort_rgb, %Color.SRGB{r: r, g: g, b: b}),
    do: {:ok, [scale(r, 65_535), scale(g, 65_535), scale(b, 65_535)]}

  defp encode(:float_rgb, %Color.SRGB{r: r, g: g, b: b}),
    do: {:ok, [r * 1.0, g * 1.0, b * 1.0]}

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
  # Color.Hsv uses [0, 1] for h, s, v.
  defp encode(:uchar_hsv, %Color.Hsv{h: h, s: s, v: v}),
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

  defp alpha_for(_encoder, _explicit, _source, false), do: {:ok, nil}

  defp alpha_for(encoder, explicit, source, true) do
    cond do
      not is_nil(explicit) ->
        with {:ok, byte} <- transparency(explicit) do
          {:ok, scale_alpha_to_encoder(byte / 255.0, encoder)}
        end

      is_struct(source) and Map.get(source, :alpha) != nil ->
        {:ok, scale_alpha_to_encoder(source.alpha, encoder)}

      true ->
        {:ok, scale_alpha_to_encoder(1.0, encoder)}
    end
  end

  # The alpha band uses the same numeric type as the rest of the
  # interpretation: 0..255 for uchar, 0..65535 for ushort, 0.0..1.0
  # for float-typed bands. LABS / Lab / LCH happen to be float-typed
  # interpretations whose alpha band is also a float in [0, 1].
  defp scale_alpha_to_encoder(alpha, encoder) do
    case encoder do
      e when e in [:uchar_rgb, :uchar_cmyk, :uchar_hsv, :uchar_grey] ->
        scale(alpha, 255)

      e when e in [:ushort_rgb, :ushort_grey] ->
        scale(alpha, 65_535)

      :float_rgb ->
        alpha * 1.0

      e when e in [:float_lab, :float_lch] ->
        alpha * 1.0

      :short_lab ->
        round(alpha * 65_535)
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
