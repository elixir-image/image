defmodule Image.Options.Blurhash do
  @moduledoc """
  Options and option validation for `Image.Blurhash.encode/2`.

  """

  alias Vix.Vips.Image, as: Vimage

  @typedoc """
  Options applicable to `Image.Blurhash.encode/2`

  """
  @type blurhash_option ::
          {:x_components, 1..9}
          | {:y_components, 1..9}

  @typedoc """
  Options list for Image.Blurhash.encode/2

  """
  @type blurhash_options :: [blurhash_option()]

  @default_x_components 4
  @default_y_components 3

  @doc """
  Validate the options for `Image.Blurhash.encode/2`.

  See `t:Image.Options.Blurhash.blurhash_options/0`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` the options apply to.

  * `options` is a keyword list of options.

  ### Returns

  * `{:ok, validated_options}` where `validated_options` is
    a map of the options with their defaults applied, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(10, 10, color: :red)
      iex> {:ok, options} = Image.Options.Blurhash.validate_options(image, [])
      iex> options.x_components
      4

  """
  @spec validate_options(image :: Vimage.t(), options :: blurhash_options()) ::
          {:ok, map()} | {:error, Image.error()}
  def validate_options(image, options) when is_list(options) do
    options = Keyword.merge(default_options(), options)

    with :ok <- validate_image_bands(Image.bands(image)) do
      case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
        {:error, message} ->
          {:error, message}

        options ->
          {:ok, Map.new(options)}
      end
    end
  end

  defp validate_image_bands(3), do: :ok

  defp validate_image_bands(n),
    do:
      {:error,
       %Image.Error{
         message: "Image must have 3 bands. Found #{inspect(n)} bands in the image",
         reason: "Image must have 3 bands. Found #{inspect(n)} bands in the image"
       }}

  defp validate_option({:x_components, x_components}, options) when x_components in 1..9 do
    {:cont, options}
  end

  defp validate_option({:y_components, y_components}, options) when y_components in 1..9 do
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
      x_components: @default_x_components,
      y_components: @default_y_components
    ]
  end
end
