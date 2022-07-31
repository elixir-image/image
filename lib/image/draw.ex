defmodule Image.Draw do
  @moduledoc """
  Functions to draw directly on a mutable image.

  """

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.MutableImage
  alias Image.Options

  @spec image(Vimage.t(), non_neg_integer(), non_neg_integer(), Options.Draw.circle()) ::
    {:ok, Image.t()} | {:error, Image.error_message()}

  def circle(image, cx, cy, radius, options \\ [])

  def circle(%Vimage{} = image, cx, cy, radius, options)
      when is_integer(cx) and is_integer(cy) and cx >= 0 and cy >= 0 and is_integer(radius) and radius > 0 do
    with {:ok, options} <- Options.Draw.validate_options(:circle, options) do
      Vimage.mutate image, fn mut_img ->
        MutableImage.draw_circle(mut_img, options.color, cx, cy, radius, fill: options.fill)
      end
    end
  end

  @spec image(MutableImage.t(), non_neg_integer(), non_neg_integer(), Options.Draw.circle()) ::
    :ok | {:error, Image.error_message()}

  def circle(%MutableImage{} = image, cx, cy, radius, options)
      when is_integer(cx) and is_integer(cy) and cx >= 0 and cy >= 0 and is_integer(radius) and radius > 0 do
    with {:ok, options} <- Options.Draw.validate_options(:circle, options) do
      MutableImage.draw_circle(image, options.color, cx, cy, radius, fill: options.fill)
    end
  end

  def image(%Vimage{} = image, %Vimage{} = sub_image, x, y, options \\ [])
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    with {:ok, _options} <- Options.Draw.validate_options(:image, options) do
      Vimage.mutate image, fn mut_img ->
        MutableImage.draw_image(mut_img, sub_image, x, y, mode: :VIPS_COMBINE_MODE_ADD)
      end
    end
  end

end