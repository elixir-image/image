defmodule Image.Lqip.Css do
  @moduledoc """
  Encodes an image as an [LQIP CSS](https://dev.to/frzi/image-placeholders-in-pure-css-or-defying-gods-with-math-and-color-3a5d)
  (Low Quality Image Placeholder) value.

  LQIP CSS represents a placeholder as a single 32-bit value packed into an RGBA
  hex code such as `#a1b2c3d4`. A static CSS rule then unpacks that value into
  three colors and paints two radial gradients over a background color, producing
  a blurred gradient placeholder using only the browser's CSS engine.

  This module is the encoder only: it extracts the three colors and returns
  the packed hex string. The CSS is static and identical for every image.

  See the [LQIP CSS guide](lqip_css.md) for the copy-and-paste stylesheet.

  ### How it works

  The image is resized to a 3x3 thumbnail and three pixels are sampled:

  * the top-left pixel becomes the background color (`--lqip-c0`)
  * the center pixel becomes the first radial gradient (`--lqip-c1`)
  * the bottom-right pixel becomes the second radial gradient (`--lqip-c2`)

  Each color is quantized ([adjusted for chroma](#module-chroma-aware-packing))
  and bit-packed: the first two into 11 bits (`RRRR GGGG BBB`) and the third
  into 10 bits (`RRR GGGG BBB`). They are then combined into a single 32-bit
  value rendered as an 8-digit `#RRGGBBAA` hex string.

  ### Usage

  Compute the value once and store it. Then set a CSS variable using inline
  styles or use a data attribute, and include the LQIP CSS stylesheet:

      hex = Image.Lqip.Css.encode!(image)
      # => "#a1b2c3d4"

      # In your template:
      # <img src="photo.jpg" style="--lqip: #a1b2c3d4" />
      # or
      # <img src="photo.jpg" data-lqip="#a1b2c3d4" />

  See the [LQIP CSS guide](lqip_css.md) for more usage information.

  ### Chroma-aware packing

  Because each channel is packed into only 3 or 4 bits, independent per-channel
  rounding can give near-grey colors a visible tint. To reduce that, the encoder
  chooses each color's packed value to be the one closest to the source in the
  CIELAB space, measured with CIEDE2000 (via `Color.Distance.delta_e_2000/3`).

  This keeps near-greys closer to neutral while still preserving chroma for
  saturated colors.

  ### Example

      iex> image = Image.open!("./test/support/images/Kip_small.jpg")
      iex> Image.Lqip.Css.encode(image)
      {:ok, "#22333091"}

  """

  alias Vix.Vips.Image, as: Vimage

  # Every packable value mapped to the CIELAB color it reconstructs to (channel
  # level n of m -> n / m), used by the chroma-aware search in `nearest/2`.
  # Built once, at compile time.
  @table_11 (for r4 <- 0..15, g4 <- 0..15, b3 <- 0..7 do
               {:ok, lab} = Color.convert([r4 / 15, g4 / 15, b3 / 7], Color.Lab)
               <<packed::11>> = <<r4::4, g4::4, b3::3>>
               {packed, lab}
             end)

  @table_10 (for r3 <- 0..7, g4 <- 0..15, b3 <- 0..7 do
               {:ok, lab} = Color.convert([r3 / 7, g4 / 15, b3 / 7], Color.Lab)
               <<packed::10>> = <<r3::3, g4::4, b3::3>>
               {packed, lab}
             end)

  @doc """
  Encodes an image as a packed LQIP hex value.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`. It is converted to the `:srgb`
    colorspace before sampling, and any alpha channel is ignored.

  ### Returns

  * `{:ok, hex}` where `hex` is an 8-digit `#RRGGBBAA` string, or

  * `{:error, reason}`

  ### Example

      iex> image = Image.open!("./test/support/images/Kip_small.jpg")
      iex> Image.Lqip.Css.encode(image)
      {:ok, "#22333091"}

  """
  @doc subject: "Operation"

  @spec encode(image :: Vimage.t()) :: {:ok, String.t()} | {:error, Image.error()}

  def encode(%Vimage{} = image) do
    with {:ok, image} <- Image.to_colorspace(image, :srgb),
         {:ok, image} <- Image.thumbnail(image, "3x3", resize: :force),
         {:ok, [r0, g0, b0 | _]} <- Image.get_pixel(image, 0, 0),
         {:ok, [r1, g1, b1 | _]} <- Image.get_pixel(image, 1, 1),
         {:ok, [r2, g2, b2 | _]} <- Image.get_pixel(image, 2, 2) do
      c0 = nearest({r0, g0, b0}, @table_11)
      c1 = nearest({r1, g1, b1}, @table_11)
      c2 = nearest({r2, g2, b2}, @table_10)

      packed = <<c0::11, c1::11, c2::10>>
      {:ok, "#" <> Base.encode16(packed, case: :lower)}
    end
  end

  @doc """
  Encodes an image as a packed LQIP hex value, or raises on error.

  See `encode/1`.
  """
  @doc subject: "Operation"

  @spec encode!(image :: Vimage.t()) :: String.t() | no_return()

  def encode!(%Vimage{} = image) do
    case encode(image) do
      {:ok, hex} -> hex
      {:error, reason} -> raise Image.Error, reason
    end
  end

  # Returns the packed value perceptually nearest to `{r, g, b}` in CIELAB using
  # the precompiled table
  defp nearest({r, g, b}, table) do
    {:ok, lab} = Color.convert([r / 255, g / 255, b / 255], Color.Lab)
    {packed, _lab} = Enum.min_by(table, fn {_packed, candidate} -> Color.Distance.delta_e_2000(lab, candidate) end)
    packed
  end
end
