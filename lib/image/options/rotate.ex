defmodule Image.Options.Rotate do
  @moduledoc """
  Options and option validation for `Image.rotate/3`.

  """

  alias Vix.Vips.Interpolate
  alias Image.Pixel

  @typedoc """
  The interpolators that may be selected with the `:interpolate`
  option (descriptions from `vips -l interpolate`):

  * `:nearest` - nearest-neighbour interpolation
  * `:bilinear` (default) - bilinear interpolation
  * `:bicubic` - bicubic interpolation (Catmull-Rom)
  * `:lbb` - reduced halo bicubic
  * `:nohalo` - edge sharpening resampler with halo reduction
  * `:vsqbs` - B-Splines with antialiasing smoothing

  """
  @type interpolate ::
          :nearest
          | :bilinear
          | :bicubic
          | :lbb
          | :nohalo
          | :vsqbs

  @typedoc """
  The options applicable to rotating an
  image.

  """
  @type rotation_options :: [
          {:idy, number()}
          | {:idx, number()}
          | {:ody, number()}
          | {:odx, number()}
          | {:interpolate, interpolate()}
          | {:background, Pixel.t() | :average}
        ]

  # The libvips nickname for each interpolator is identical to the
  # public atom, so resolution is a simple `Atom.to_string/1`.
  @valid_interpolators ~w(nearest bilinear bicubic lbb nohalo vsqbs)a

  @displacement_options [:idy, :idx, :ody, :odx]

  @doc """
  Validate the options for `Image.rotate/3`.

  The `image` is required to resolve the `:background` option
  into a pixel matching the image's bands and color space.

  See `t:Image.Options.Rotate.rotation_options/0`.

  """
  @spec validate_options(Vix.Vips.Image.t(), Keyword.t()) ::
          {:ok, Keyword.t()} | {:error, Image.error()}
  def validate_options(image, options) do
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, image, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, options}
    end
  end

  defp validate_option({:interpolate, interpolate}, _image, options)
       when interpolate in @valid_interpolators do
    case Interpolate.new(Atom.to_string(interpolate)) do
      {:ok, interpolator} ->
        {:cont, Keyword.put(options, :interpolate, interpolator)}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp validate_option({:background, background}, image, options) do
    case Image.BackgroundColor.resolve(image, background) do
      {:ok, pixel} -> {:cont, Keyword.put(options, :background, pixel)}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp validate_option({option, value}, _image, options)
       when option in @displacement_options and is_number(value) do
    {:cont, Keyword.put(options, option, value)}
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

  # No default `:background` is injected: when the caller omits it,
  # `libvips` keeps its own native fill (transparent for images with
  # an alpha band, black otherwise). `:interpolate` defaults to
  # `:bilinear`, which is also `libvips`' own default.
  defp default_options do
    [interpolate: :bilinear]
  end

  @doc false
  def no_displacement?(options) do
    empty_displacement?(options, :idx) and
      empty_displacement?(options, :idy) and
      empty_displacement?(options, :odx) and
      empty_displacement?(options, :ody)
  end

  defp empty_displacement?(options, key) do
    Keyword.get(options, key, 0) in [nil, 0, 0.0]
  end
end
