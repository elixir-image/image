defmodule Image.Draw do
  @moduledoc """
  Functions to draw directly on a mutable image.

  """

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.{MutableImage, MutableOperation}
  alias Image.Options

  @doc """
  Draw a point on a mutable image.

  """
  @doc since: "0.7.0"

  @spec point(Vimage.t(), non_neg_integer(), non_neg_integer(), Options.Draw.point()) ::
    {:ok, Vimage.t()} | {:error, Image.error_message()}

  def point(image, left, top,  options \\ [])

  def point(%Vimage{} = image, left, top, options)
      when is_integer(left) and is_integer(top) and left >= 0 and top >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:point, options) do
      Vimage.mutate image, fn mut_img ->
        MutableOperation.draw_rect(mut_img, options.color, left, top, 1, 1)
      end
    end
  end

  @spec point(MutableImage.t(), non_neg_integer(), non_neg_integer(), Options.Draw.point()) ::
    :ok | {:error, Image.error_message()}

  def point(%MutableImage{} = image, left, top, options)
      when is_integer(left) and is_integer(top) and left >= 0 and top >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:point, options) do
      MutableOperation.draw_rect(image, options.color, left, top, 1, 1)
    end
    |> maybe_wrap()
  end

  @doc """
  Draw a rectangle on a mutable image.

  """
  @doc since: "0.7.0"

  @spec rect(Vimage.t(), non_neg_integer(), non_neg_integer(), pos_integer(), pos_integer(), Options.Draw.rect()) ::
    {:ok, Vimage.t()} | {:error, Image.error_message()}

  def rect(image, left, top, width, height, options \\ [])

  def rect(%Vimage{} = image, left, top, width, height, options)
      when is_integer(left) and is_integer(top) and left >= 0 and top >= 0
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    with {:ok, options} <- Options.Draw.validate_options(:rect, options) do
      Vimage.mutate image, fn mut_img ->
        MutableOperation.draw_rect(mut_img, options.color, left, top, width, height, fill: options.fill)
      end
    end
    |> maybe_wrap()
  end

  @spec rect(MutableImage.t(), non_neg_integer(), non_neg_integer(), pos_integer(), pos_integer(), Options.Draw.rect()) ::
    :ok | {:error, Image.error_message()}

  def rect(%MutableImage{} = image, left, top, width, height, options)
      when is_integer(left) and is_integer(top) and left >= 0 and top >= 0
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    with {:ok, options} <- Options.Draw.validate_options(:rect, options) do
      MutableOperation.draw_rect(image, options.color, left, top, width, height, fill: options.fill)
    end
    |> maybe_wrap()
  end

  @doc """
  Draw a circle on a mutable image.

  """
  @doc since: "0.7.0"

  @spec circle(Vimage.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), Options.Draw.circle()) ::
    {:ok, Vimage.t()} | {:error, Image.error_message()}

  def circle(image, cx, cy, radius, options \\ [])

  def circle(%Vimage{} = image, cx, cy, radius, options)
      when is_integer(cx) and is_integer(cy) and cx >= 0 and cy >= 0 and is_integer(radius) and radius > 0 do
    with {:ok, options} <- Options.Draw.validate_options(:circle, options) do
      Vimage.mutate image, fn mut_img ->
        MutableOperation.draw_circle(mut_img, options.color, cx, cy, radius, fill: options.fill)
      end
    end
    |> maybe_wrap()
  end

  @spec circle(MutableImage.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), Options.Draw.circle()) ::
    :ok | {:error, Image.error_message()}

  def circle(%MutableImage{} = image, cx, cy, radius, options)
      when is_integer(cx) and is_integer(cy) and cx >= 0 and cy >= 0 and is_integer(radius) and radius > 0 do
    with {:ok, options} <- Options.Draw.validate_options(:circle, options) do
      MutableOperation.draw_circle(image, options.color, cx, cy, radius, fill: options.fill)
    end
    |> maybe_wrap()
  end

  @doc """
  Draw a line on a mutable image.

  """
  @doc since: "0.7.0"

  @spec line(Vimage.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer(), Options.Draw.line()) ::
    {:ok, Vimage.t()} | {:error, Image.error_message()}

  def line(image, x1, y1, x2, y2, options \\ [])

  def line(%Vimage{} = image, x1, y1, x2, y2, options)
      when is_integer(x1) and is_integer(y1) and x1 >= 0 and y1 >= 0 and
           is_integer(x2) and is_integer(y2) and x2 >= 0 and y2 >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:line, options) do
      Vimage.mutate image, fn mut_img ->
        MutableOperation.draw_line(mut_img, options.color, x1, y1, x2, y2, [])
      end
    end
    |> maybe_wrap()
  end

  @spec line(MutableImage.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer(), Options.Draw.line()) ::
    {:ok, Vimage.t()} | {:error, Image.error_message()}

  def line(%MutableImage{} = image, x1, y1, x2, y2, options)
      when is_integer(x1) and is_integer(y1) and x1 >= 0 and y1 >= 0 and
           is_integer(x2) and is_integer(y2) and x2 >= 0 and y2 >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:line, options) do
       MutableOperation.draw_line(image, options.color, x1, y1, x2, y2, [])
    end
    |> maybe_wrap()
  end

  @doc """
  Draw one image over the top of a mutable
  image.

  """
  @doc since: "0.7.0"

  @spec image(Vimage.t(), Vimage.t(), non_neg_integer(), non_neg_integer(), Options.Draw.image()) ::
    {:ok, Vimage.t()} | {:error, Image.error_message()}

  def image(image, sub_image, x, y, options \\ [])

  def image(%Vimage{} = image, %Vimage{} = sub_image, x, y, options)
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:image, options) do
      Vimage.mutate(image, fn mut_img ->
        MutableOperation.draw_image(mut_img, sub_image, x, y, options)
      end)
    end
    |> maybe_wrap()
  end

  @spec image(MutableImage.t(), Vimage.t(), non_neg_integer(), non_neg_integer(), Options.Draw.image()) ::
    {:ok, Vimage.t()} | {:error, Image.error_message()}

  def image(%MutableImage{} = image, %Vimage{} = sub_image, x, y, options)
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:image, options) do
      MutableOperation.draw_image(image, sub_image, x, y, options)
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
        MutableOperation.draw_flood(mut_img, options.color, x, y, equal: options.equal)
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
      MutableOperation.draw_flood(image, options.color, x, y, equal: options.equal)
    end
    |> maybe_wrap()
  end

  @doc """
  Draw mask on the image.

  Mask is a monochrome 8-bit image with the values of `0` or `255` for transparent
  and any other value as a color to be blended into the base image.

  """
  @doc since: "0.7.0"

  @spec mask(Vimage.t(), Vimage.t(), non_neg_integer(), non_neg_integer(), Options.Draw.mask()) ::
    {:ok, {Vimage.t(), [height: integer(), width: integer(), top: integer(), left: integer()]}} |
    {:error, Image.error_message()}

  def mask(image, mask, x, y, options \\ [])

  def mask(%Vimage{} = image, %Vimage{} = mask, x, y, options)
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:mask, options) do
      Vimage.mutate image, fn mut_img ->
        MutableOperation.draw_mask(mut_img, options.color, mask, x, y)
      end
    end
    |> maybe_wrap()
  end

  @spec mask(MutableImage.t(),Vimage.t(), non_neg_integer(), non_neg_integer(), Options.Draw.mask()) ::
    {:ok, {Vimage.t(), [height: integer(), width: integer(), top: integer(), left: integer()]}} |
    {:error, Image.error_message()}

  def mask(%MutableImage{} = image, %Vimage{} = mask, x, y, options)
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    with {:ok, options} <- Options.Draw.validate_options(:mask, options) do
      MutableOperation.draw_mask(image, options.color, mask, x, y)
    end
    |> maybe_wrap()
  end

  @doc """
  Smudge a section of image .

  Each pixel in the area left , top , width , height is
  replaced by the average of the surrounding 3x3 pixels.

  """
  @doc since: "0.7.0"

  @spec smudge(Vimage.t(), non_neg_integer(), non_neg_integer(), pos_integer(), pos_integer(), Options.Draw.smudge()) ::
    {:ok, Vimage.t()} | {:error, Image.error_message()}

  def smudge(image, left, top, width, height, options \\ [])

  def smudge(%Vimage{} = image, left, top, width, height, options)
      when is_integer(left) and is_integer(top) and left >= 0 and top >= 0
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    with {:ok, _options} <- Options.Draw.validate_options(:smudge, options) do
      Vimage.mutate image, fn mut_img ->
        MutableOperation.draw_smudge(mut_img, left, top, width, height)
      end
    end
    |> maybe_wrap()
  end

  @spec smudge(MutableImage.t(), non_neg_integer(), non_neg_integer(), pos_integer(), pos_integer(), Options.Draw.smudge()) ::
    :ok | {:error, Image.error_message()}

  def smudge(%MutableImage{} = image, left, top, width, height, options)
      when is_integer(left) and is_integer(top) and left >= 0 and top >= 0
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    with {:ok, _options} <- Options.Draw.validate_options(:smudge, options) do
      MutableOperation.draw_smudge(image, left, top, width, height)
    end
    |> maybe_wrap()
  end

  ## Helpers

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