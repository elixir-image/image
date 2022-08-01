defmodule Image.Draw do
  @moduledoc """
  Functions to draw directly on a mutable image.

  """

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.MutableImage
  alias Image.Options

  @doc """
  Draw a circle on a mutalable image.

  """
  @doc since: "0.7.0"

  @spec circle(Vimage.t(), non_neg_integer(), non_neg_integer(), Options.Draw.circle()) ::
    {:ok, Image.t()} | {:error, Image.error_message()}

  def circle(image, cx, cy, radius, options \\ [])

  def circle(%Vimage{} = image, cx, cy, radius, options)
      when is_integer(cx) and is_integer(cy) and cx >= 0 and cy >= 0 and is_integer(radius) and radius > 0 do
    with {:ok, options} <- Options.Draw.validate_options(:circle, options) do
      Vimage.mutate image, fn mut_img ->
        MutableImage.draw_circle(mut_img, options.color, cx, cy, radius, fill: options.fill)
      end
    end
    |> maybe_wrap()
  end

  @spec circle(MutableImage.t(), non_neg_integer(), non_neg_integer(), Options.Draw.circle()) ::
    :ok | {:error, Image.error_message()}

  def circle(%MutableImage{} = image, cx, cy, radius, options)
      when is_integer(cx) and is_integer(cy) and cx >= 0 and cy >= 0 and is_integer(radius) and radius > 0 do
    with {:ok, options} <- Options.Draw.validate_options(:circle, options) do
      MutableImage.draw_circle(image, options.color, cx, cy, radius, fill: options.fill)
    end
    |> maybe_wrap()
  end


  @doc """
  Draw a line on a mutalable image.

  """
  @doc since: "0.7.0"

  @spec line(Vimage.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer(), Options.Draw.line()) ::
    {:ok, Image.t()} | {:error, Image.error_message()}

  def line(image, x1, y1, x2, y2, options \\ [])

  def line(%Vimage{} = image, x1, y1, x2, y2, options)
      when is_integer(x1) and is_integer(y1) and x1 >= 0 and y1 >= 0 and
           is_integer(x2) and is_integer(y2) and x2 >= 0 and y2 >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:line, options) do
      Vimage.mutate image, fn mut_img ->
        MutableImage.draw_line(mut_img, options.color, x1, y1, x2, y2, [])
      end
    end
    |> maybe_wrap()
  end

  @spec line(MutableImage.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer(), Options.Draw.line()) ::
    {:ok, Image.t()} | {:error, Image.error_message()}

  def line(%MutableImage{} = image, x1, y1, x2, y2, options)
      when is_integer(x1) and is_integer(y1) and x1 >= 0 and y1 >= 0 and
           is_integer(x2) and is_integer(y2) and x2 >= 0 and y2 >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:line, options) do
       MutableImage.draw_line(image, options.color, x1, y1, x2, y2, [])
    end
    |> maybe_wrap()
  end

  @doc """
  Draw one image over the top of a mutable
  image.

  """
  @doc since: "0.7.0"

  @spec image(Vimage.t(), Vimage.t(), non_neg_integer(), non_neg_integer(), Options.Draw.image()) ::
    {:ok, Image.t()} | {:error, Image.error_message()}

  def image(image, sub_image, x, y, options \\ [])

  def image(%Vimage{} = image, %Vimage{} = sub_image, x, y, options)
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    with {:ok, _options} <- Options.Draw.validate_options(:image, options) do
      Vimage.mutate image, fn mut_img ->
        MutableImage.draw_image(mut_img, sub_image, x, y, mode: :VIPS_COMBINE_MODE_ADD)
      end
    end
    |> maybe_wrap()
  end

  @spec image(MutableImage.t(), Vimage.t(), non_neg_integer(), non_neg_integer(), Options.Draw.image()) ::
    {:ok, Image.t()} | {:error, Image.error_message()}

  def image(%MutableImage{} = image, %Vimage{} = sub_image, x, y, options)
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    with {:ok, _options} <- Options.Draw.validate_options(:image, options) do
      MutableImage.draw_image(image, sub_image, x, y, mode: :VIPS_COMBINE_MODE_ADD)
    end
    |> maybe_wrap()
  end

  @doc """
  Flood an area of a mutuable image bounded by the
  given color.

  """
  @doc since: "0.7.0"

  @spec flood(Vimage.t(), non_neg_integer(), non_neg_integer(), Options.Draw.flood()) ::
    {:ok, {Vimage.t(), [height: integer(), width: integer(), top: integer(), left: integer()]}} |
    {:error, Image.error_message()}

  def flood(image, x, y, options \\ [])

  def flood(%Vimage{} = image, x, y, options)
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:flood, options) do
      Vimage.mutate image, fn mut_img ->
        MutableImage.draw_flood(mut_img, options.color, x, y, equal: options.equal)
      end
    end
    |> maybe_wrap()
  end

  @spec flood(MutableImage.t(), non_neg_integer(), non_neg_integer(), Options.Draw.flood()) ::
    {:ok, {Vimage.t(), [height: integer(), width: integer(), top: integer(), left: integer()]}} |
    {:error, Image.error_message()}

  def flood(%MutableImage{} = image, x, y, options)
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:flood, options) do
      MutableImage.draw_flood(image, options.color, x, y, equal: options.equal)
    end
    |> maybe_wrap()
  end

  defp maybe_wrap({:ok, {image, {box}}}) when is_list(box) do
    {:ok, {image, box}}
  end

  defp maybe_wrap({:ok, result}) do
    {:ok, result}
  end

  defp maybe_wrap(error) do
    error
  end
end