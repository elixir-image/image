defmodule Image.Options.Vibrance do
  @moduledoc """
  Options and option validation for `Image.vibrance/2`.

  """

  @typedoc """
  Options applicable to Image.vibrance/3

  """
  @type vibrance_option :: {:threshold, pos_integer()}

  @typedoc """
  Options list for Image.vibrance/3

  """
  @type vibrance_options :: [vibrance_option()] | map()

  @default_vibrance_threshold 60

  @doc false
  def default_vibrance_threshold do
    @default_vibrance_threshold
  end

  @doc """
  Validate the options for `Image.vibrance/3`.

  See `t:Image.Options.Vibrance.vibrance_options/0`.

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

  defp validate_option({:threshold, threshold}, options)
       when is_integer(threshold) and threshold in 1..100//1 do
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
      threshold: @default_vibrance_threshold
    ]
  end
end
