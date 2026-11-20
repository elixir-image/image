defmodule Image.Options.Resize do
  @moduledoc """
  Options and option validation for `Image.resize/3`.

  """

  alias Image.Kernel

  @typedoc """
  Options applicable to Image.resize/3

  """
  @type resize_options :: [
          {:center, boolean()}
          | {:interpolate, Image.Kernel.t()}
          | {:vertical_scale, float()}
        ]

  @doc """
  Validate the options for `Image.resize/2`.

  See `t:Image.Options.Resize.resize_options/0`.

  ### Arguments

  * `options` is a keyword list of options.

  ### Returns

  * `{:ok, validated_options}` where `validated_options` is
    a keyword list of the options with their defaults applied, or

  * `{:error, reason}`.

  ### Examples

      iex> Image.Options.Resize.validate_options([])
      {:ok, []}

  """
  @spec validate_options(options :: resize_options()) ::
          {:ok, Keyword.t()} | {:error, Image.error()}
  def validate_options(options) when is_list(options) do
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

  defp validate_option({:interpolate, interpolate}, options) do
    Kernel.validate_kernel(interpolate, options)
  end

  defp validate_option({:vertical_scale, vertical_scale}, options) when is_float(vertical_scale) do
    options =
      options
      |> Keyword.delete(:vertical_scale)
      |> Keyword.put(:vscale, vertical_scale)

    {:cont, options}
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    %Image.Error{
      reason: :invalid_option,
      value: option,
      message: "Invalid option or option value: #{inspect(option)}"
    }
  end
end
