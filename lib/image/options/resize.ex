defmodule Image.Options.Resize do
  @moduledoc """
  Options and option validation for `Image.resize/3`.

  """

  alias Image.Kernel

  @typedoc """
  Options applicable to Image.resize/3

  """
  @type resize_options :: [
          {:center, boolean()} |
          {:kernel, Image.Kernel.t()}
        ]

  @doc """
  Validate the options for `Image.resize/2`.

  See `t:Image.Options.Resize.resize_options/0`.

  """
  def validate_options(options) do
    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, options}
    end
  end

  defp validate_option({:center, center}, options) do
    center = if center, do: true, else: false
    options = Keyword.put(options, :center, center)
    {:cont, options}
  end

  defp validate_option({:kernel, kernel}, options) do
    Kernel.validate_kernel(kernel, options)
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    "Invalid option or option value: #{inspect(option)}"
  end
end
