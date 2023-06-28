defmodule Image.Options.ToneCurve do
  @moduledoc """
  Options and option validation for `Image.apply_tone_curve/2`.

  """

  import Image, only: :macros

  @typedoc """
  Options applicable to `Image.apply_tone_curve/2`.
  """
  @type tone_curve_option ::
          {:black_point, set_point()}
          | {:white_point, set_point()}
          | {:shadow_point, positive_percent()}
          | {:mid_point, positive_percent()}
          | {:highlight_point, positive_percent()}
          | {:shadows, tone_adjustment()}
          | {:mid_points, tone_adjustment()}
          | {:highlights, tone_adjustment()}

  @type tone_curve_options :: [tone_curve_option()] | map()

  @typedoc """
  Range for setting the black point and
  white point. The range is 0..100 reflecting
  the values of L* in the `Lab` colorspace.
  """
  @type set_point :: 0..100

  @typedoc """
  A percent expressed as a float in the range
  [0.0..1.0]
  """
  @type positive_percent :: float()

  @typedoc """
  The adjustment range for the shadow,
  midpoint and highlights.
  """
  @type tone_adjustment :: -30..30

  @doc """
  Valid range for setting the black point and
  white point.
  """
  defguard is_set_point(point) when point in 0..100

  @doc """
  The range in which the shadows, mids and highlights
  can be adjusted.
  """
  defguard is_tone_adjustment(tone) when tone in -30..30

  @doc """
  Validate the options for `Image.apply_tone_curve/2`.

  """
  def validate_options(options) when is_list(options) do
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        cond do
          options[:black_point] >= options[:white_point] ->
            {:error, "White_point must be greater than black_point"}

          options[:shadow_point] >= options[:mid_point] ->
            {:error, "Mid_point must be greater than shadow_point"}

          options[:mid_point] >= options[:highlight_point] ->
            {:error, "Highlight_point must be greater than mid_point"}

          {} ->
            {:ok, Map.new(options)}
        end
    end
  end

  defp validate_option({:black_point, black_point}, options) when is_set_point(black_point) do
    {:cont, options}
  end

  defp validate_option({:white_point, white_point}, options) when is_set_point(white_point) do
    {:cont, options}
  end

  defp validate_option({:shadow_point, shadow_point}, options)
       when is_positive_percent(shadow_point) do
    {:cont, options}
  end

  defp validate_option({:mid_point, mid_point}, options) when is_positive_percent(mid_point) do
    {:cont, options}
  end

  defp validate_option({:highlight_point, highlight_point}, options)
       when is_positive_percent(highlight_point) do
    {:cont, options}
  end

  defp validate_option({:shadows, shadow}, options) when is_tone_adjustment(shadow) do
    {:cont, options}
  end

  defp validate_option({:mid_points, mid_points}, options) when is_tone_adjustment(mid_points) do
    {:cont, options}
  end

  defp validate_option({:highlights, highlight}, options) when is_tone_adjustment(highlight) do
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
      black_point: 0,
      white_point: 100,
      shadow_point: 0.2,
      mid_point: 0.5,
      highlight_point: 0.8,
      shadows: 0,
      mid_points: 0,
      highlights: 0
    ]
  end
end
