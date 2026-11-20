defmodule Image.Options.Blur do
  @moduledoc """
  Options and option validation for `Image.blur/2`.

  """

  @typedoc """
  Options applicable to Image.blur/2

  """
  @type blur_option ::
          {:sigma, float()}
          | {:min_amplitude, float()}

  @typedoc """
  Options list for Image.blur/2

  """
  @type blur_options :: [blur_option()]

  @default_blur_sigma 5

  @doc false
  def default_blur_sigma do
    @default_blur_sigma
  end

  @doc """
  Validate the options for `Image.blur/2`.

  See `t:Image.Options.Blur.blur_options/0`.

  ### Arguments

  * `options` is a keyword list of options.

  ### Returns

  * `{:ok, validated_options}` where `validated_options` is
    a map of the options with their defaults applied, or

  * `{:error, reason}`.

  ### Examples

      iex> {:ok, options} = Image.Options.Blur.validate_options(sigma: 2)
      iex> options.sigma
      2

  """
  @spec validate_options(options :: blur_options()) ::
          {:ok, map()} | {:error, Image.error()}
  def validate_options(options) when is_list(options) do
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, Map.new(options)}
    end
  end

  defp validate_option({:sigma, sigma}, options) when is_number(sigma) and sigma > 0 do
    {:cont, options}
  end

  defp validate_option({:min_amplitude, min_amplitude}, options) when is_float(min_amplitude) do
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

  defp default_options do
    [
      sigma: @default_blur_sigma,
      min_amplitude: 0.2
    ]
  end
end
