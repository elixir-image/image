defmodule Image.Options.Trim do
  @moduledoc """
  Options and option validation for `Image.trim/2`.

  """
  alias Image.Color

  @typedoc """
  Options applicable to Image.trim/2

  """
  @type trim_options :: [
          {:background, Color.t() | :auto | :alpha}
          | {:threshold, non_neg_integer()}
        ]

  @doc """
  Validate the options for `Image.trim/2`.

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

  defp validate_option({:background, :auto}, options) do
    {:cont, options}
  end

  defp validate_option({:background, color} = option, options) do
    case Color.rgb_color(color) do
      {:ok, hex: _hex, rgb: color} -> {:cont, Keyword.put(options, :background, color)}
      {:ok, color} -> {:cont, Keyword.put(options, :backgrouond, color)}
      _other -> {:halt, invalid_option(option)}
    end
  end

  defp validate_option({:threshold, threshold}, options)
       when is_integer(threshold) and threshold > 0 do
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
      background: :auto,
      threshold: 10
    ]
  end
end
