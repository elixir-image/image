defmodule Image.Options.Trim do
  @moduledoc """
  Options and option validation for `Image.trim/2`.

  """
  alias Image.Pixel

  @typedoc """
  Options applicable to Image.trim/2

  """
  @type trim_options :: [
          {:background, Pixel.t() | :auto | :alpha}
          | {:threshold, pos_integer()}
        ]

  @doc """
  Validate the options for `Image.trim/2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` the options apply to.

  * `options` is a keyword list of options.

  ### Returns

  * `{:ok, validated_options}` where `validated_options` is
    a map of the options with their defaults applied, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(10, 10, color: :red)
      iex> {:ok, options} = Image.Options.Trim.validate_options(image, [])
      iex> options.threshold
      10

  """
  @spec validate_options(image :: Vimage.t(), options :: trim_options()) ::
          {:ok, map()} | {:error, Image.error()}
  def validate_options(image, options) when is_list(options) do
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, image, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, Map.new(options)}
    end
  end

  defp validate_option({:background, :auto}, _image, options) do
    {:cont, options}
  end

  defp validate_option({:background, :alpha}, _image, options) do
    {:cont, options}
  end

  defp validate_option({:background, color} = option, image, options) do
    case Pixel.to_pixel(image, color) do
      {:ok, pixel} ->
        # libvips find_trim compares against the color bands only, so
        # any alpha band value is dropped from the resolved pixel.
        {:cont, Keyword.put(options, :background, Pixel.strip_alpha(pixel, image))}

      _other ->
        {:halt, {:error, invalid_option(option)}}
    end
  end

  defp validate_option({:threshold, threshold}, _image, options)
       when is_integer(threshold) and threshold > 0 do
    {:cont, options}
  end

  defp validate_option(option, _image, _options) do
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
      background: :auto,
      threshold: 10
    ]
  end
end
