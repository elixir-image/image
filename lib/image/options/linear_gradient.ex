defmodule Image.Options.LinearGradient do
  @moduledoc """
  Options and option validation for `Image.linear_gradient/2`.

  """
  alias Image.Color

  @typedoc """
  Options applicable to `Image.linear_gradient/2`.
  """
  @type linear_gradient_option ::
          {:start_color, Color.rgb_color()}
          | {:finish_color, Color.rgb_color()}
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

  defp validate_option({key, color} = option, options)
       when key in [:start_color, :finish_color] do
    case Color.rgb_color(color) do
      {:ok, hex: _hex, rgb: color} -> {:cont, Keyword.put(options, key, color)}
      {:ok, color} -> {:cont, Keyword.put(options, key, color)}
      _other -> {:halt, invalid_option(option)}
    end
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

  defp invalid_option(option) do
    "Invalid option or option value: #{inspect(option)}"
  end

  defp default_options do
    [
      start_color: @default_start_color,
      finish_color: @default_finish_color,
      angle: @default_angle
    ]
  end
end
