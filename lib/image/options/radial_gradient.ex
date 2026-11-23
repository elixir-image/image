defmodule Image.Options.RadialGradient do
  @moduledoc """
  Options and option validation for `Image.radial_gradient/3`.

  """
  alias Image.Pixel

  @typedoc """
  Options applicable to `Image.radial_gradient/3`.
  """
  @type radial_gradient_option ::
          {:start_color, Pixel.t()}
          | {:finish_color, Pixel.t()}
          | {:feather, 1..10}
          | {:radius, number()}
          | {:x, x_center()}
          | {:y, y_center()}

  @typedoc """
  The horizontal centre of a radial gradient: a pixel offset from the
  left (or, when negative, from the right), a fraction of the width,
  or one of `:left`, `:center` or `:right`.
  """
  @type x_center :: integer() | float() | :left | :center | :right

  @typedoc """
  The vertical centre of a radial gradient: a pixel offset from the
  top (or, when negative, from the bottom), a fraction of the height,
  or one of `:top`, `:middle` or `:bottom`.
  """
  @type y_center :: integer() | float() | :top | :middle | :bottom

  @typedoc """
  Options list for `Image.radial_gradient/3`.
  """
  @type radial_gradient_options :: [radial_gradient_option()]

  @default_start_color [0.0, 0.0, 0.0, 0.0]
  @default_finish_color [0.0, 0.0, 0.0, 255.0]
  @default_feather 1
  @default_radius 2
  @default_x :center
  @default_y :middle

  @doc """
  Validate the options for `Image.radial_gradient/3`.

  ### Arguments

  * `options` is a keyword list of options.

  ### Returns

  * `{:ok, validated_options}` where `validated_options` is
    a map of the options with their defaults applied, or

  * `{:error, reason}`.

  ### Examples

      iex> {:ok, options} = Image.Options.RadialGradient.validate_options([])
      iex> options.radius
      2

  """
  @spec validate_options(options :: radial_gradient_options()) ::
          {:ok, map()} | {:error, Image.error()}
  def validate_options(options) when is_list(options) do
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, Map.new(options)}
    end
  end

  defp validate_option({key, color}, options)
       when key in [:start_color, :finish_color] and is_list(color) and length(color) in [3, 4] do
    if Enum.all?(color, &is_number/1) do
      {:cont, Keyword.put(options, key, ensure_alpha(color))}
    else
      resolve_gradient_color(key, color, options)
    end
  end

  defp validate_option({key, color}, options)
       when key in [:start_color, :finish_color] do
    resolve_gradient_color(key, color, options)
  end

  defp validate_option({:radius, angle}, options) when is_number(angle) do
    {:cont, options}
  end

  defp validate_option({:feather, feather}, options) when feather in 1..10 do
    {:cont, options}
  end

  defp validate_option({:x, x}, options) when is_number(x) or x in [:left, :center, :right] do
    {:cont, options}
  end

  defp validate_option({:y, y}, options) when is_number(y) or y in [:top, :middle, :bottom] do
    {:cont, options}
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp resolve_gradient_color(key, color, options) do
    case Pixel.to_srgb(color) do
      {:ok, pixel} ->
        {:cont, Keyword.put(options, key, ensure_alpha(pixel))}

      _other ->
        {:halt, {:error, invalid_option({key, color})}}
    end
  end

  # Gradient math operates on RGBA, so opaque sRGB inputs need an
  # explicit alpha appended.
  defp ensure_alpha([_, _, _] = rgb), do: rgb ++ [255]
  defp ensure_alpha([_, _, _, _] = rgba), do: rgba

  defp invalid_option(option) do
    %Image.Error{
      reason: :invalid_option,
      value: option,
      message: "Invalid option or option value: #{inspect(option)}"
    }
  end

  defp default_options do
    [
      start_color: @default_start_color,
      finish_color: @default_finish_color,
      feather: @default_feather,
      radius: @default_radius,
      x: @default_x,
      y: @default_y
    ]
  end
end
