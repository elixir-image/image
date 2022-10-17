defmodule Image.Options.ChromaKey do
  @moduledoc """
  Options and option validation for `Image.chroma_key/2`.

  """

  @typedoc """
  Options applicable to Image.chroma_key/2

  """
  @type chroma_key_options :: [
          {:sigma, float()} |
          {:min_amplitude, float()}
        ]

  @doc """
  Validate the options for `Image.blur/2`.

  See `t:Image.Options.Resize.resize_options/0`.

  """
  def validate_options(options) do
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {min_ampl, options} = Keyword.pop(options, :min_amplitude)
        options = Keyword.put(options, :"min-ampl", min_ampl)

        {:ok, options}
    end
  end

  defp validate_option({:sigma, sigma}, options) when is_number(sigma) and sigma > 0 do
    {:cont, options}
  end

  defp validate_option({:min_amplitude, min_amplitude}, options) when is_float(min_amplitude) do
    options = Keyword.put(options, :min_amplitude, min_amplitude)

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
      sigma: 1.0,
      min_amplitude: 0.2
    ]
  end
end
