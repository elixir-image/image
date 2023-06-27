defmodule Image.Options.LocalContrast do
  @moduledoc """
  Options and option validation for `Image.local_contrast/2`.

  """

  @typedoc """
  Options applicable to `Image.local_contrast/2`.
  """
  @type local_contrast_option ::
          {:window_size, pos_integer()}
          | {:max_slope, non_neg_integer()}

  @typedoc """
  Options list or map for `Image.local_contrast/2`.
  """
  @type local_contrast_options :: [local_contrast_option()] | map()

  # Default window size in pixels over which the
  # local contrast is evaluated
  @default_window_size 3

  # Integral level of brightening, between 0 and
  # 100, where 0 (the default) disables contrast limiting.
  @default_max_slope 0

  @doc """
  Validate the options for `Image.local_contrast/2`.

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

  defp validate_option({:window_size, window_size}, options)
       when is_integer(window_size) and window_size > 0 do
    {:cont, options}
  end

  defp validate_option({:max_slope, max_slope}, options)
       when is_integer(max_slope) and max_slope >= 0 do
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
      window_size: @default_window_size,
      max_slope: @default_max_slope
    ]
  end
end
