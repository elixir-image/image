defmodule Image.Options.Sharpen do
  @moduledoc """
  Options and option validation for `Image.sharpen/2`.

  """

  @typedoc """
  Valid options for `Image.sharpen/2`.

  """
  @type sharpen_option ::
          {:jagged_amount, float()}
          | {:flat_amount, float()}
          | {:max_darkening, float()}
          | {:max_brightening, float()}
          | {:threshold, float()}
          | {:sigma, float()}

  @typedoc """
  Options applicable to Image.sharpen/2

  """
  @type sharpen_options :: [sharpen_option()] | map()

  @doc """
  Validate the options for `Image.sharpen/2`.

  See `t:Image.Options.Sharpen.sharpen_options/0`.

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

  def validate_options(%{} = options) do
    {:ok, options}
  end

  defp validate_option({:sigma, sigma}, options)
       when is_number(sigma) and sigma > 0 and sigma <= 10 do
    {:cont, options}
  end

  defp validate_option({:jagged_amount, jagged_amount}, options)
       when is_number(jagged_amount) and jagged_amount >= 0 do
    {:cont, options}
  end

  defp validate_option({:flat_amount, flat_amount}, options)
       when is_number(flat_amount) and flat_amount >= 0 do
    {:cont, options}
  end

  defp validate_option({:threshold, threshold}, options)
       when is_number(threshold) and threshold >= 0 do
    {:cont, options}
  end

  defp validate_option({:max_brightening, max_brightening}, options)
       when is_number(max_brightening) and max_brightening >= 0 do
    {:cont, options}
  end

  defp validate_option({:max_darkening, max_darkening}, options)
       when is_number(max_darkening) and max_darkening >= 0 do
    {:cont, options}
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    "Invalid option or option value: #{inspect(option)}"
  end

  # These defaults are appropriate for screen sharpening
  defp default_options do
    [
      jagged_amount: 3.0,
      flat_amount: 0.0,
      max_darkening: 20.0,
      max_brightening: 10.0,
      threshold: 2.0,
      sigma: 1.0
    ]
  end
end
