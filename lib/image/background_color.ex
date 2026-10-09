defmodule Image.BackgroundColor do
  @moduledoc """
  Resolves an `Image.Pixel.t()` / `:average` value into a concrete pixel in the
  image's colorspace.

  A background color specification is either the atom `:average` (the average
  color of the image), or any color accepted by
  `Image.Pixel.to_pixel/2` (a `Color` struct, a hex string, a CSS named color,
  an atom or a list of numbers).

  Either form may also be given as `{spec, opacity: opacity}` to attach an
  explicit opacity (an integer `0..255`, a float `0.0..1.0`, or `:opaque` /
  `:transparent`). It is applied only when `image` has an alpha band,
  otherwise it is dropped, since there is no band to carry it. An
  invalid opacity is an error either way.

  In all cases the resolved pixel matches `image`'s number of bands.
  """

  alias Image.Pixel
  alias Vix.Vips.Image, as: Vimage

  @typedoc "A background color specification: the image's average color, or any color, optionally with an explicit opacity."
  @type spec :: Pixel.t() | :average | {Pixel.t() | :average, [opacity: Pixel.opacity()]}

  @doc """
  Resolves a background color `spec` into a pixel matching `image`'s
  interpretation and band layout.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `spec` is `:average` (the image's average color), any color
    accepted by `Image.Pixel.to_pixel/2`, or either of those wrapped
    as `{spec, opacity: opacity}` to attach an explicit opacity.

  ### Returns

  * `{:ok, [number()]}` - the resolved pixel, whose band count matches
    `image` (an opaque alpha component is appended for `:average` when
    the image has alpha), or

  * `{:error, t:Image.Error.t/0}`

  ### Examples

      iex> image = Image.new!(3, 3, color: :red)
      iex> Image.BackgroundColor.resolve(image, :average)
      {:ok, [255, 0, 0]}
      iex> Image.BackgroundColor.resolve(image, :blue)
      {:ok, [0, 0, 255]}
      iex> Image.BackgroundColor.resolve(image, "#00ff00")
      {:ok, [0, 255, 0]}

  """
  @spec resolve(Vimage.t(), spec()) :: {:ok, [number()]} | {:error, Image.Error.t()}
  def resolve(%Vimage{} = image, :average) do
    case Image.average(image) do
      # The average has no alpha component, so an opaque one is appended when
      # the image has alpha.
      {:ok, pixel} ->
        Pixel.put_alpha(pixel, image, :opaque)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # The wrapped `{spec, opacity: opacity}` form: resolve the color part like any
  # other spec, then set the alpha component directly.
  def resolve(%Vimage{} = image, {spec, opts}) when is_list(opts) do
    with {:ok, opacity} <- fetch_opacity(spec, opts),
         {:ok, pixel} <- resolve(image, spec) do
      Pixel.put_alpha(pixel, image, opacity)
    end
  end

  def resolve(%Vimage{} = image, color) do
    case Pixel.to_pixel(image, color) do
      {:ok, pixel} ->
        {:ok, pixel}

      # An invalid color does not say which option it came from.
      {:error, %Image.Error{reason: :invalid_color} = error} ->
        {:error, %{error | message: "Invalid background color #{inspect(color)}: #{error.message}"}}

      {:error, %Image.Error{} = error} ->
        {:error, error}
    end
  end

  # `:opacity` is the only supported key in the wrapped form. A missing or
  # misspelled key is reported as an error rather than raised.
  defp fetch_opacity(_spec, opacity: opacity), do: {:ok, opacity}

  defp fetch_opacity(spec, opts) do
    {:error,
     %Image.Error{
       reason: :invalid_background,
       value: {spec, opts},
       message:
         "Invalid background color #{inspect({spec, opts})}: " <>
           "expected {color, opacity: opacity}"
     }}
  end
end
