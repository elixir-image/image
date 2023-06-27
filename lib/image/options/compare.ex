defmodule Image.Options.Compare do
  @moduledoc """
  Options and option validation for `Image.compare/3`.

  """
  import Image, only: :macros
  alias Image.Color

  @typedoc """
  Options applicable to `Image.compare/3`.

  """
  @type compare_option ::
          {:color, Color.t() | :auto}
          | {:threshold, non_neg_integer()}
          | {:greater_than, Color.t()}
          | {:less_than, Color.t()}
          | {:sigma, float()}
          | {:min_amplitude, float()}

  @type compare_options :: [compare_option()] | map()

  # Ussed by Image.compare/3 and defines the
  # default metric to be used.
  @default_compare_metric :ae

  # When overlaying the difference on the original image,
  # use this color by default.
  @default_difference_color :red

  # Saturation for the base image when used with the
  # difference overlay.
  @default_saturation 1.0

  # Brightness for the base image when used with the
  # difference overlay.
  @default_brightness 1.0

  # How much to boost the colors of the difference
  # pixels.
  @default_boost 1.5

  # The valid comparison metrics
  @valid_metrics [:ae, :mse, :rmse]

  @doc """
  Validate the options for `Image.compare/3`.

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

  defp validate_option({:metric, metric}, options) when metric in @valid_metrics do
    {:cont, options}
  end

  defp validate_option({:saturation, saturation}, options) when is_multiplier(saturation) do
    {:cont, options}
  end

  defp validate_option({:brightness, brightness}, options) when is_multiplier(brightness) do
    {:cont, options}
  end

  defp validate_option({:difference_boost, difference_boost}, options)
       when is_multiplier(difference_boost) do
    {:cont, options}
  end

  defp validate_option({:difference_color, color} = option, options) do
    case Color.rgb_color(color) do
      {:ok, hex: _hex, rgb: color} -> {:cont, Keyword.put(options, :difference_color, color)}
      {:ok, color} -> {:cont, Keyword.put(options, :difference_color, color)}
      _other -> {:halt, invalid_option(option)}
    end
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    "Invalid option or option value: #{inspect(option)}"
  end

  defp default_options do
    [
      metric: @default_compare_metric,
      difference_color: @default_difference_color,
      brightness: @default_brightness,
      saturation: @default_saturation,
      difference_boost: @default_boost
    ]
  end
end
