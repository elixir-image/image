defmodule Image.Options.Crop do
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

  def validate_options(options) do
    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, options}
    end
  end

  def validate_option(_other, options) do
    {:cont, options}
  end

  @doc false
  def validate_crop(crop, options) when crop in @crop do
    crop = Map.fetch!(@crop_map, crop)
    {:cont, Keyword.put(options, :crop, crop)}
  end

  def validate_crop(crop, _options) do
    {:halt, {:error, invalid_crop(crop)}}
  end

  defp invalid_crop(crop) do
    "Invalid crop option #{inspect(crop)}. Valid values are #{inspect(@crop)}"
  end
end
