defmodule Image.Options.RadialGradient do
  @moduledoc """
  Options and option validation for `Image.radial_gradient/3`.

  """
  alias Image.Color

  @typedoc """
  Options applicable to `Image.radial_gradient/3`.
  """
  @type radial_gradient_option ::
          {:start_color, Color.rgb_color()}
          | {:finish_color, Color.rgb_color()}
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

  defp validate_option({key, color} = option, options)
       when key in [:start_color, :finish_color] do
    case Color.rgb_color(color) do
      {:ok, hex: _hex, rgb: color} -> {:cont, Keyword.put(options, key, color)}
      {:ok, color} -> {:cont, Keyword.put(options, key, color)}
      _other -> {:halt, invalid_option(option)}
    end
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
