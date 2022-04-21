defmodule Image.Options.Crop do
  @type crop_options :: []

  @typedoc """
  Indicates how to determine where to crop
  an image to fill a target area.

  * `:none` means crop from the top left corner.

  * `:center` means crop from the center of
    the image

  * `:entropy` uses an entropy measure.

  * `:attention` means crop such the object
    by look for features likely to draw human
    attention.

  * `:low` means position the crop towards the
    low coordinate.

  * `:high` means position the crop towards the
    high coordinate.

  """
  @type crop_focus :: :none | :center | :entropy | :attention | :low | :high

  def validate_options(options) do
    case Enum.reduce_while(options, [], &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, options}
    end
  end

  def validate_option(_other, options) do
    {:cont, options}
  end
end
