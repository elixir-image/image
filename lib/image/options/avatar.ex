defmodule Image.Options.Avatar do
  @moduledoc """
  Options and option validation for `Image.avatar/2`.

  """
  alias Image.Options.Crop

  @type avatar_option ::
          {:size, pos_integer()}
          | {:shape, :circle | :square | :squircle}
          | {:crop, Crop.crop_focus()}

  @type avatar_options :: [avatar_option()]

  @valid_shapes [:circle, :square, :squircle]

  # Standard size of an avatar image, at least for
  # this library
  @default_avatar_size 180

  def validate_options(options) do
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, reason} -> {:error, reason}
      options -> {:ok, options}
    end
  end

  defp validate_option({:size, size}, options) when is_integer(size) and size > 0 do
    {:cont, options}
  end

  defp validate_option({:shape, shape}, options) when shape in @valid_shapes do
    {:cont, options}
  end

  # Same as crop options but we default to
  # cropping for attention as the default

  defp validate_option({:crop, crop}, options) do
    Crop.validate_crop(crop, options)
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    "Invalid Image.avatar option or option value: #{inspect(option)}"
  end

  defp default_options do
    [
      shape: :circle,
      crop: :center,
      size: @default_avatar_size
    ]
  end

  @doc false
  def default_avatar_size do
    @default_avatar_size
  end
end
