defmodule Image.Options.Crop do
  @moduledoc """
  Options and option validation for `Image.crop/5`.

  """

  import Image,
    only: [
      is_size: 1,
      is_percent: 1,
      is_positive_percent: 1,
      is_box: 4
    ]

  @typedoc """
  Options applicable to cropping an
  image.

  Currently there are no options.

  """
  @type crop_options :: []

  @typedoc """
  Indicates how to determine where to crop
  an image to fill a target area.

  * `:none` means the image will be reduced
    to fit the required bounding box and
    no cropping will occur.

  * `:center` means crop from the center of
    the image. The central part of the image
    will be returned, cropped to fill the
    bounding box.

  * `:entropy` uses an entropy measure.

  * `:attention` means crop the image by looking
    for features likely to draw human attention.

  * `:low` means position the crop towards the
    low coordinate. This means the bottom part
    of the image remains after the crop.

  * `:high` means position the crop towards the
    high coordinate. This means the top part
    of the image remains after the crop.

  """
  @type crop_focus :: :none | :center | :entropy | :attention | :low | :high

  # The meaning of :low and :high are deliberately
  # Although the verb is crop (to remove) most
  # would expect this verb to describe what remains
  # after cropping. Indeed that is already the behaviour for
  # :center and :attention.

  # Note too that we use US English spelling as apposed
  # to the libvips British English spelling. The
  # assumption being that most developers expect
  # US English.

  @crop_map %{
    none: :VIPS_INTERESTING_NONE,
    center: :VIPS_INTERESTING_CENTRE,
    entropy: :VIPS_INTERESTING_ENTROPY,
    attention: :VIPS_INTERESTING_ATTENTION,
    low: :VIPS_INTERESTING_HIGH,
    high: :VIPS_INTERESTING_LOW
  }

  @crop Map.keys(@crop_map)
  @inverse_crop Map.values(@crop_map)

  @doc """
  Validates options to `Iamge.crop/5`.

  """
  def validate_options(options) do
    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, options}
    end
  end

  defp validate_option(_other, options) do
    {:cont, options}
  end

  @doc false
  def validate_crop(crop, options) when crop in @crop do
    crop = Map.fetch!(@crop_map, crop)
    {:cont, Keyword.put(options, :crop, crop)}
  end

  def validate_crop(crop, options) when crop in @inverse_crop do
    {:cont, Keyword.put(options, :crop, crop)}
  end

  def validate_crop(crop, _options) do
    {:halt, {:error, invalid_crop(crop)}}
  end

  @doc false

  def normalize_box({w, h}, _left, _top, width, height) when w < width or h < height do
    {:error, "Cannot normalize a box that is larger than the image"}
  end

  def normalize_box({w, _h} = dims, left, top, width, height) when is_percent(left) do
    normalize_box(dims, round(left * w), top, width, height)
  end

  def normalize_box({_w, h} = dims, left, top, width, height) when is_percent(top) do
    normalize_box(dims, left, round(top * h), width, height)
  end

  def normalize_box({w, _h} = dims, left, top, width, height) when is_positive_percent(width) do
    normalize_box(dims, left, top, round(width * w), height)
  end

  def normalize_box({_w, h} = dims, left, top, width, height) when is_positive_percent(height) do
    normalize_box(dims, left, top, width, round(height * h))
  end

  def normalize_box({w, h}, :center, top, width, height) when is_size(width) and is_size(height) do
    left = round((w - width) / 2)
    normalize_box({w, h}, left, top, width, height)
  end

  def normalize_box({w, h}, :left, top, width, height) when is_size(width) and is_size(height) do
    normalize_box({w, h}, 0, top, width, height)
  end

  def normalize_box({w, h}, :right, top, width, height) when is_size(width) and is_size(height) do
    normalize_box({w, h}, w - width, top, width, height)
  end

  def normalize_box({w, h}, left, :middle, width, height) when is_size(width) and is_size(height) do
    top = round((h - height) / 2)
    normalize_box({w, h}, left, top, width, height)
  end

  def normalize_box({w, h}, left, :top, width, height) when is_size(width) and is_size(height) do
    normalize_box({w, h}, left, 0, width, height)
  end

  def normalize_box({w, h}, left, :bottom, width, height) when is_size(width) and is_size(height) do
    normalize_box({w, h}, left, h - height, width, height)
  end

  def normalize_box({w, _h} = dims, left, top, width, height)
      when is_integer(left) and is_integer(top) and left < 0 and top >= 0 do
    left = w + left - width
    normalize_box(dims, left, top, width, height)
  end

  def normalize_box({_w, h} = dims, left, top, width, height)
      when is_integer(left) and is_integer(top) and left >= 0 and top < 0 do
    top = h + top - height
    normalize_box(dims, left, top, width, height)
  end

  def normalize_box({w, h} = dims, left, top, width, height)
      when is_integer(left) and is_integer(top) and left < 0 and top < 0 do
    left = w + left - width
    top = h + top - height
    normalize_box(dims, left, top, width, height)
  end

  def normalize_box(_dims, left, top, width, height) when is_box(left, top, width, height) do
    {left, top, width, height}
  end

  def normalize_box(_dims, _left, _top, width, _height)
      when not is_integer(width) and not is_positive_percent(width) do
    {:error, size_error("width", width)}
  end

  def normalize_box(_dims, _left, _top, _width, height)
      when not is_integer(height) and not is_positive_percent(height) do
    {:error, size_error("height", height)}
  end

  def normalize_box(_dims, left, _top, _width, _height)
      when not is_integer(left) and not is_positive_percent(left) do
    {:error, location_error("left", left)}
  end

  def normalize_box(_dims, _left, top, _width, _height)
      when not is_integer(top) and not is_positive_percent(top) do
    {:error, location_error("top", top)}
  end

  def normalize_box(dims, left, top, width, height) do
    {:error, "Could not normalize box with #{inspect({dims, left, top, width, height})}"}
  end

  @doc false
  def normalize_dims({w, _h} = dims, width, height) when is_positive_percent(width) do
    normalize_dims(dims, round(width * w), height)
  end

  def normalize_dims({_w, h} = dims, width, height) when is_positive_percent(height) do
    normalize_dims(dims, width, round(height * h))
  end

  def normalize_dims(_dims, width, height) when is_size(width) and is_size(height) do
    {width, height}
  end

  def normalize_dims(_dims, width, _height)
      when not is_integer(width) and not is_positive_percent(width) do
    {:error, size_error("width", width)}
  end

  def normalize_dims(_dims, _width, height)
      when not is_integer(height) and not is_positive_percent(height) do
    {:error, size_error("height", height)}
  end

  def normalize_dims(_dims, width, height) do
    {:error, "Could not normalize dimensions within #{width}, #{height}"}
  end

  defp size_error(dim, size) when is_number(size) do
    "#{dim} must be a percentage expressed as a float greater than 0.0 and " <>
      "less than or equal to 1.0. Found #{inspect(size)}"
  end

  defp location_error(dim, size) when is_number(size) do
    "#{dim} must be a percentage expressed as a float beteen -1.0 and 1.0. " <>
      "Found #{inspect(size)}"
  end

  defp invalid_crop(crop) do
    "Invalid crop option #{inspect(crop)}. Valid values are #{inspect(@crop)}"
  end
end
