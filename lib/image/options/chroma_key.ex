defmodule Image.Options.ChromaKey do
  @moduledoc """
  Options and option validation for `Image.chroma_key/2`.

  """
  alias Image.Color

  @typedoc """
  Options applicable to Image.chroma_key/2

  """
  @type chroma_key_options ::
          [
            {:color, Color.t() | :auto}
            | {:threshold, non_neg_integer()}
            | {:greater_than, Color.t()}
            | {:less_than, Color.t()}
            | {:sigma, float()}
            | {:min_amplitude, float()}
          ]
          | map()

  @doc """
  Validate the options for `Image.chroma_key/2`.

  """
  def validate_options(options) when is_list(options) do
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        select_strategy(Map.new(options))
    end
  end

  def validate_options(%{} = options) do
    {:ok, options}
  end

  defp validate_option({:color, :auto}, options) do
    {:cont, options}
  end

  defp validate_option({key, color} = option, options)
       when key in [:greater_than, :less_than, :color] do
    case Color.rgb_color(color) do
      {:ok, hex: _hex, rgb: color} -> {:cont, Keyword.put(options, key, color)}
      {:ok, color} -> {:cont, Keyword.put(options, key, color)}
      _other -> {:halt, invalid_option(option)}
    end
  end

  defp validate_option({:threshold, threshold}, options)
       when is_integer(threshold) and threshold >= 0 do
    {:cont, options}
  end

  defp validate_option({:sigma, sigma}, options) when is_number(sigma) and sigma > 0 do
    {:cont, options}
  end

  defp validate_option({:min_amplitude, min_amplitude}, options) when is_float(min_amplitude) do
    {:cont, Keyword.put(options, :min_amplitude, min_amplitude)}
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    "Invalid option or option value: #{inspect(option)}"
  end

  defp select_strategy(%{greater_than: _, less_than: _} = options) do
    options =
      options
      |> Map.delete(:color)
      |> Map.delete(:threshold)

    {:ok, options}
  end

  defp select_strategy(%{color: _, threshold: _} = options) do
    options =
      options
      |> Map.delete(:greater_than)
      |> Map.delete(:less_than)

    {:ok, options}
  end

  defp select_strategy(options) do
    {
      :error,
      "Invalid options #{inspect(options)}. Options need to have either :greater_than " <>
        " and :less_than or :color and :threshold."
    }
  end

  defp default_options do
    [
      color: :auto,
      threshold: 20
    ]
  end
end
