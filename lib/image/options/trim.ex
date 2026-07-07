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
          | {:threshold, non_neg_integer()}
        ]

  @doc """
  Validate the options for `Image.trim/2`.

  """
  def validate_options(image, options) when is_list(options) do
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, image, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, Map.new(options)}
    end
  end

  def validate_options(_image, %{} = options) do
    {:ok, options}
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
        {:cont, Keyword.put(options, :background, strip_alpha(pixel, image))}

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

  defp strip_alpha(pixel, image) do
    if Image.has_alpha?(image) and length(pixel) == Image.bands(image) do
      Enum.take(pixel, length(pixel) - 1)
    else
      pixel
    end
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
