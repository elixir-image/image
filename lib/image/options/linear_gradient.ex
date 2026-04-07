defmodule Image.Options.LinearGradient do
  @moduledoc """
  Options and option validation for `Image.linear_gradient/2`.

  """
  alias Image.Pixel

  @typedoc """
  Options applicable to `Image.linear_gradient/2`.
  """
  @type linear_gradient_option ::
          {:start_color, Pixel.t()}
          | {:finish_color, Pixel.t()}
          | {:angle, number()}

  @typedoc """
  Options list or map for `Image.linear_gradient/2`.
  """
  @type linear_gradient_options :: [linear_gradient_option()] | map()

  @default_start_color [0.0, 0.0, 0.0, 0.0]
  @default_finish_color [0.0, 0.0, 0.0, 255.0]
  @default_angle 0.0

  @doc """
  Validate the options for `Image.linear_gradient/2`.

  """
  def validate_options(options) when is_list(options) do
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, Map.new(options)}
    end
  end

  # A pre-encoded RGBA list (e.g. the defaults below) is passed
  # through unchanged so callers can supply integer/float pixel
  # values directly.
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

  # Angle is conformed to be between 0 and 360 degrees
  defp validate_option({:angle, angle}, options)
       when is_number(angle) do
    angle = angle - trunc(angle / 360.0) * 360.0
    {:cont, Keyword.put(options, :angle, angle)}
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

  defp invalid_option(option) do
    "Invalid option or option value: #{inspect(option)}"
  end

  # Gradient math operates on RGBA, so opaque sRGB inputs need an
  # explicit alpha appended.
  defp ensure_alpha([_, _, _] = rgb), do: rgb ++ [255]
  defp ensure_alpha([_, _, _, _] = rgba), do: rgba

  defp default_options do
    [
      start_color: @default_start_color,
      finish_color: @default_finish_color,
      angle: @default_angle
    ]
  end
end
