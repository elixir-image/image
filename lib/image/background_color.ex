defmodule Image.BackgroundColor do
  @moduledoc """
  Resolves a `Image.Pixel.t()` / `:average` value into a concrete pixel in the
  image's colorspace.

  A background color specification is either the atom `:average` (the average
  color of the image), or any color accepted by
  `Image.Pixel.to_pixel/2` (a `Color` struct, a hex string, a CSS named color,
  an atom or a list of numbers).

  In both cases the resolved pixel matches `image`'s number of bands.
  """

  alias Image.Pixel
  alias Vix.Vips.Image, as: Vimage

  @typedoc "A background color specification: the image's average color, or any color."
  @type spec :: Pixel.t() | :average

  @doc """
  Resolves a background color `spec` into a pixel matching `image`'s
  interpretation and band layout.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `spec` is `:average` (the image's average color) or any color
    accepted by `Image.Pixel.to_pixel/2`.

  ### Returns

  * `{:ok, [number()]}` - the resolved pixel, whose band count matches
    `image` (an opaque alpha band is appended for `:average` when the
    image has alpha), or

  * `{:error, t:Image.Error.t/0}`
  """
  @spec resolve(Vimage.t(), spec()) :: {:ok, [number()]} | {:error, Image.Error.t()}
  def resolve(%Vimage{} = image, :average) do
    case Image.average(image) do
      color when is_list(color) ->
        if Image.has_alpha?(image) do
          # Append an opaque alpha band in the interpretation's own scale via `to_pixel`
          case Pixel.to_pixel(image, :black, alpha: :opaque) do
            {:ok, opaque_pixel} ->
              {:ok, color ++ [List.last(opaque_pixel)]}

            {:error, reason} ->
              {:error, error("Could not construct alpha #{inspect(color)}", reason)}
          end
        else
          {:ok, color}
        end

      {:error, reason} ->
        {:error, error("Could not compute the image average", reason)}
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

  defp error(message, reason) do
    %Image.Error{message: "#{message}: #{inspect(reason)}", reason: reason}
  end
end
