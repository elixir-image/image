defmodule Image.Options.Modulate do
  @moduledoc """
  Options and option validation for `Image.modulate/2`.

  """

  import Image, only: :macros

  @typedoc """
  Valid options for `Image.modulate/2`.

  """
  @type modulate_option ::
          {:brightness, float()}
          | {:lightness, float()}
          | {:saturation, float()}
          | {:hue, integer()}

  @typedoc """
  Options applicable to Image.modulate/2

  """
  @type modulate_options :: [modulate_option()] | map()

  @doc """
  Validate the options for `Image.modulate/2`.

  See `t:Image.Options.Modulate.modulate_options/0`.

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

  defp validate_option({:brightness, brightness}, options) when is_multiplier(brightness) do
    {:cont, options}
  end

  defp validate_option({:saturation, saturation}, options) when is_multiplier(saturation) do
    {:cont, options}
  end

  defp validate_option({:hue, hue}, options) when is_integer(hue) do
    {:cont, options}
  end

  defp validate_option({:lightness, threshold}, options) when is_number(threshold) do
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
      brightness: 1.0,
      saturation: 1.0,
      lightness: 0.0,
      hue: 0
    ]
  end
end
