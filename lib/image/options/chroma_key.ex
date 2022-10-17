defmodule Image.Options.ChromaKey do
  @moduledoc """
  Options and option validation for `Image.chroma_key/2`.

  """

  @hue_range 0..360
  @chroma_green_hue 100..170

  @typedoc """
  Options applicable to Image.chroma_key/2

  """
  @type chroma_key_options :: [
          {:hue, non_neg_integer() | Range.t()} |
          {:sigma, float()} |
          {:min_amplitude, float()}
          ] | map()

  @doc """
  Validate the options for `Image.blur/2`.

  See `t:Image.Options.Resize.resize_options/0`.

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

  defp validate_option({:hue, :green}, options) do
    {:cont, Keyword.put(options, :hue, @chroma_green_hue)}
  end

  defp validate_option({:hue, first..last}, options) when last >= first do
    {:cont, options}
  end

  defp validate_option({:hue, number}, options)
      when is_integer(number) and number in @hue_range do
    {:cont, Keyword.put(options, :hue, number..number)}
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

  defp default_options do
    [
      hue: @chroma_green_hue
    ]
  end
end
