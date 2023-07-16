defmodule Image.Options.Histogram do
  @moduledoc """
  Options and option validation for `Image.Histogram.as_svg/2`.

  """

  @typedoc """
  Options applicable to `Image.Histogram.as_svg/2`.
  """
  @type histogram_option ::
          {:width, pos_integer() | :auto}
          | {:height, pos_integer() | :auto}

  @typedoc """
  Options list or map for `Image.Histogram.as_svg/2`.
  """
  @type histogram_options :: [histogram_option()] | map()

  @doc """
  Validate the options for `Image.Histogram.as_svg/2`.

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

  defp validate_option({:width, width}, options)
       when is_integer(width) and width > 0 do
    options = Keyword.put(options, :width, "#{width}px")
    {:cont, options}
  end

  defp validate_option({:height, height}, options)
       when is_integer(height) and height > 0 do
    options = Keyword.put(options, :height, "#{height}px")
    {:cont, options}
  end

  defp validate_option({:width, :auto}, options) do
    options = Keyword.put(options, :width, "auto")
    {:cont, options}
  end

  defp validate_option({:height, :auto}, options) do
    options = Keyword.put(options, :height, "auto")
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
      width: :auto,
      height: :auto
    ]
  end
end
