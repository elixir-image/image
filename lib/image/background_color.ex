defmodule Image.BackgroundColor do
  @moduledoc """
  Resolves an `Image.Pixel.t()` / `:average` value into a concrete pixel in the
  image's colorspace.

  A background color specification is either the atom `:average` (the average
  color of the image), or any color accepted by
  `Image.Pixel.to_pixel/2` (a `Color` struct, a hex string, a CSS named color,
  an atom or a list of numbers).

  Either form may also be given as `{spec, alpha: transparency}` to attach an
  explicit alpha (an integer `0..255`, a float `0.0..1.0`, or `:opaque` /
  `:transparent`). The alpha is applied only when `image` has an alpha band,
  otherwise it is dropped, since there is no band to carry it.

  In all cases the resolved pixel matches `image`'s number of bands.
  """

  alias Image.Pixel
  alias Vix.Vips.Image, as: Vimage

  @typedoc "A background color specification: the image's average color, or any color, optionally with an explicit alpha."
  @type spec :: Pixel.t() | :average | {Pixel.t() | :average, [alpha: Pixel.transparency()]}

  @doc """
  Resolves a background color `spec` into a pixel matching `image`'s
  interpretation and band layout.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `spec` is `:average` (the image's average color), any color
    accepted by `Image.Pixel.to_pixel/2`, or either of those wrapped
    as `{spec, alpha: transparency}` to attach an explicit alpha.

  ### Returns

  * `{:ok, [number()]}` - the resolved pixel, whose band count matches
    `image` (an opaque alpha band is appended for `:average` when the
    image has alpha), or

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
      # The average has no alpha band, so an opaque one is appended when the
      # image has alpha.
      color when is_list(color) ->
        put_alpha_band(image, color, :opaque)

      {:error, reason} ->
        {:error, error("Could not compute the image average", reason)}
    end
  end

  # The wrapped `{spec, alpha: alpha}` form: resolve the color part like any
  # other spec, then set the alpha band directly.
  def resolve(%Vimage{} = image, {spec, opts}) when is_list(opts) do
    with {:ok, alpha} <- fetch_alpha(spec, opts),
         {:ok, pixel} <- resolve(image, spec) do
      apply_alpha(image, pixel, alpha)
    end
  end

  def resolve(%Vimage{} = image, color) do
    case Pixel.to_pixel(image, color) do
      {:ok, pixel} ->
        {:ok, pixel}

      {:error, reason} ->
        {:error, error("Invalid background color #{inspect(color)}", reason)}
    end
  end

  # `:alpha` is the only supported key in the wrapped form. A missing or
  # misspelled key is reported as an error rather than raised.
  defp fetch_alpha(_spec, [alpha: alpha]), do: {:ok, alpha}

  defp fetch_alpha(spec, opts) do
    {:error,
     %Image.Error{
       reason: :invalid_background,
       value: {spec, opts},
       message:
         "Invalid background color #{inspect({spec, opts})}: " <>
           "expected {color, alpha: transparency}"
     }}
  end

  # Set the alpha band of an already-resolved pixel from an alpha spec. The
  # alpha is validated up front so an invalid value errors even on an image
  # without an alpha band.
  defp apply_alpha(image, pixel, alpha) do
    with {:ok, _byte} <- validate_alpha(alpha) do
      put_alpha_band(image, pixel, alpha)
    end
  end

  defp validate_alpha(alpha) do
    case Pixel.transparency(alpha) do
      {:ok, byte} -> {:ok, byte}
      {:error, reason} -> {:error, error("Invalid alpha #{inspect(alpha)}", reason)}
    end
  end

  # Make the pixel's alpha band the given alpha, scaled to the image's
  # interpretation via `to_pixel/3`. The pixel may arrive with or without an
  # alpha band (taking the color bands normalizes both). On an image without
  # an alpha band the alpha is unrepresentable and the pixel is returned
  # unchanged.
  defp put_alpha_band(image, pixel, alpha) do
    if Image.has_alpha?(image) do
      case Pixel.to_pixel(image, :black, alpha: alpha) do
        {:ok, scaled} ->
          color_bands = Image.bands(image) - 1
          {:ok, Enum.take(pixel, color_bands) ++ [List.last(scaled)]}

        {:error, reason} ->
          {:error, error("Could not construct alpha #{inspect(pixel)}", reason)}
      end
    else
      {:ok, pixel}
    end
  end

  defp error(message, reason) do
    %Image.Error{message: "#{message}: #{inspect(reason)}", reason: reason}
  end
end
