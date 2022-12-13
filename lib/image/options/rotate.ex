defmodule Image.Options.Rotate do
  @moduledoc """
  Options and option validation for `Image.rotate/3`.

  """

  @typedoc """
  The options applicable to rotating an
  image.

  """
  @type rotation_options :: [
          {:idy, float()}
          | {:idx, float()}
          | {:ody, float()}
          | {:odx, float()}
          | {:background, Image.pixel()}
        ]

  @valid_options [:idy, :idx, :ody, :odx]

  @doc false
  defguard is_color(color) when is_number(color) and color >= 0

  @doc """
  Validate the options for `Image.rotate/3`.

  See `t:Image.Options.Rotate.rotation_options/0`.

  """
  def validate_options(options) do
    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, options}
    end
  end

  defp validate_option({:background, background}, options) when is_color(background) do
    options = Keyword.put(options, :background, List.wrap(background))
    {:cont, options}
  end

  defp validate_option({:background, [r, g, b]}, options)
       when is_color(r) and is_color(g) and is_color(b) do
    {:cont, options}
  end

  defp validate_option({:background, [c]}, options) when is_color(c) do
    {:cont, options}
  end

  defp validate_option({option, value}, options)
       when option in @valid_options and is_number(value) do
    {:cont, options}
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    "Invalid option or option value: #{inspect(option)}"
  end
end
