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
          | {:feather, pos_integer()}
          | {:radius, number()}

  @typedoc """
  Options list or map for `Image.radial_gradient/3`.
  """
  @type radial_gradient_options :: [radial_gradient_option()] | map()

  @default_start_color [0.0, 0.0, 0.0, 0.0]
  @default_finish_color [0.0, 0.0, 0.0, 255.0]
  @default_feather 1
  @default_radius 2

  @doc """
  Validate the options for `Image.radial_gradient/3`.

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
    "Invalid option or option value: #{inspect(option)}"
  end

  defp default_options do
    [
      start_color: @default_start_color,
      finish_color: @default_finish_color,
      feather: @default_feather,
      radius: @default_radius
    ]
  end
end
