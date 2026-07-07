defmodule Image.Options.Join do
  @moduledoc """
  Options and option validation for `Image.join/2`.

  """
  alias Image.BackgroundColor

  @typedoc """
  Options applicable to `Image.join/2`.

  """
  @type join_option ::
          {:vertical_spacing, non_neg_integer()}
          | {:horizontal_spacing, non_neg_integer()}
          | {:vertical_align, :top | :middle | :bottom}
          | {:horizontal_align, :left | :center | :right}
          | {:background, BackgroundColor.spec() | nil}
          | {:shim, non_neg_integer()}
          | {:across, pos_integer()}

  @typedoc """
  Image.join/2 options list.

  """
  @type join_options :: [join_option()]

  # Ussed by Image.join/2 and defines the
  # vertical spacing in pixels between images.
  @default_vertical_spacing 0

  # Ussed by Image.join/2 and defines the
  # horizontal spacing in pixels between images.
  @default_horizontal_spacing 0

  # Default vertical alignment of images.
  @default_vertical_alignment :bottom

  # Default horizontal alignment of images.
  @default_horizontal_alignment :left

  # Default pixels between images.
  @default_shim_in_pixels 0

  # Default umber of images across the grid.
  @default_images_across 1

  # Maps from api values to libvips values
  @alignment_map %{
    bottom: :VIPS_ALIGN_LOW,
    middle: :VIPS_ALIGN_CENTRE,
    center: :VIPS_ALIGN_CENTRE,
    top: :VIPS_ALIGN_HIGH,
    left: :VIPS_ALIGN_LOW,
    centre: :VIPS_ALIGN_CENTRE,
    right: :VIPS_ALIGN_HIGH
  }

  @doc """
  Validate the options for `Image.join/2`.

  """
  def validate_options(image, options) when is_list(options) do
    # A nil `:background` means "unset", i.e. it falls back to the default.
    options = Enum.reject(options, &match?({:background, nil}, &1))
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, image, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, options}
    end
  end

  # Docs say default vertical spacing is 1 but that produces
  # incorrect results. So we delete the option instead.
  defp validate_option({:vertical_spacing, 0}, _image, options) do
    {:cont, Keyword.delete(options, :vertical_spacing)}
  end

  defp validate_option({:vertical_spacing, vertical_spacing}, _image, options)
       when is_integer(vertical_spacing) and vertical_spacing > 0 do
    {:cont, replace_option(options, :vertical_spacing, :vspacing, vertical_spacing)}
  end

  # Docs say default horizontal spacing is 1 but that produces
  # incorrect results. So we delete the option instead.
  defp validate_option({:horizontal_spacing, 0}, _image, options) do
    {:cont, Keyword.delete(options, :horizontal_spacing)}
  end

  defp validate_option({:horizontal_spacing, horizontal_spacing}, _image, options)
       when is_integer(horizontal_spacing) and horizontal_spacing > 0 do
    {:cont, replace_option(options, :horizontal_spacing, :hspacing, horizontal_spacing)}
  end

  defp validate_option({:vertical_align, vertical_align}, _image, options)
       when vertical_align in [:bottom, :middle, :center, :top] do
    {:cont,
     replace_option(options, :vertical_align, :valign, Map.get(@alignment_map, vertical_align))}
  end

  defp validate_option({:horizontal_align, horizontal_align}, _image, options)
       when horizontal_align in [:left, :centre, :center, :right] do
    {:cont,
     replace_option(options, :horizontal_align, :halign, Map.get(@alignment_map, horizontal_align))}
  end

  # Resolved via `Image.BackgroundColor.resolve/2` (colors, `:average`, and the
  # `{color, alpha: a}` form). The alpha band is kept so a gap can be filled with
  # a transparent or semi-transparent color. `arrayjoin` reproduces it exactly.
  defp validate_option({:background, background}, image, options) do
    case BackgroundColor.resolve(image, background) do
      {:ok, pixel} ->
        {:cont, Keyword.put(options, :background, pixel)}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp validate_option({:shim, shim}, _image, options)
       when is_integer(shim) and shim >= 0 do
    {:cont, options}
  end

  defp validate_option({:across, across}, _image, options)
       when is_integer(across) and across > 0 do
    {:cont, options}
  end

  defp validate_option(option, _image, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    %Image.Error{
      reason: :invalid_option,
      value: option,
      message: "Invalid option or option value: #{inspect(option)}"
    }
  end

  defp replace_option(options, from, to, value) do
    options
    |> Keyword.delete(from)
    |> Keyword.put(to, value)
  end

  defp default_options do
    [
      vertical_spacing: @default_vertical_spacing,
      horizontal_spacing: @default_horizontal_spacing,
      vertical_align: @default_vertical_alignment,
      horizontal_align: @default_horizontal_alignment,
      shim: @default_shim_in_pixels,
      across: @default_images_across
    ]
  end
end
