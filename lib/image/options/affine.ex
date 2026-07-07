defmodule Image.Options.Affine do
  @moduledoc """
  Options and option validation for `Image.affine/3`.

  These options are shared by the affine family of
  transformations: `Image.affine/3`, `Image.translate/4`
  and `Image.shear/4`.

  """

  alias Vix.Vips.Image, as: Vimage
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
  The options applicable to an affine transformation.

  """
  @type affine_options :: [
          {:idx, number()}
          | {:idy, number()}
          | {:odx, number()}
          | {:ody, number()}
          | {:interpolate, interpolate()}
          | {:background, Pixel.t() | :average}
          | {:output_area, [integer()]}
          | {:extend_mode, Image.ExtendMode.t()}
        ]

  # The libvips nickname for each interpolator is identical to the
  # public atom, so resolution is a simple `Atom.to_string/1`.
  @valid_interpolators ~w(nearest bilinear bicubic lbb nohalo vsqbs)a

  @displacement_options [:idx, :idy, :odx, :ody]

  @doc """
  Validate the options for `Image.affine/3`.

  The `image` is required to resolve the `:background` option
  into a pixel matching the image's bands and color space.

  See `t:Image.Options.Affine.affine_options/0`.

  """
  @spec validate_options(Vimage.t(), Keyword.t()) ::
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

  # The public option is `:extend_mode`, renamed internally to `:extend` for `libvips`
  defp validate_option({:extend_mode, extend}, _image, options)
       when is_atom(extend) or is_binary(extend) do
    case Image.ExtendMode.validate_extend(extend) do
      {:ok, extend} ->
        options =
          options
          |> Keyword.delete(:extend_mode)
          |> Keyword.put(:extend, extend)

        {:cont, options}

      {:error, reason} ->
        {:halt,
         {:error, %Image.Error{reason: :invalid_extend_mode, value: extend, message: reason}}}
    end
  end

  defp validate_option({:background, background}, image, options) do
    case Image.BackgroundColor.resolve(image, background) do
      {:ok, pixel} -> {:cont, Keyword.put(options, :background, pixel)}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  # The public option is `:output_area`, libvips names it `oarea`.
  defp validate_option({:output_area, [left, top, width, height] = area}, _image, options)
       when is_integer(left) and is_integer(top) and is_integer(width) and is_integer(height) do
    options =
      options
      |> Keyword.delete(:output_area)
      |> Keyword.put(:oarea, area)

    {:cont, options}
  end

  defp validate_option({option, value}, _image, options)
       when option in @displacement_options and is_number(value) do
    {:cont, Keyword.put(options, option, value * 1.0)}
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

  # `:extend_mode` defaults to `:background` rather than `:black`: since
  # extend only governs the antialiased edge fringe (not the canvas fill),
  # `:background` blends the fringe toward the fill color, whereas `:black`
  # would leave a dark fringe on a non-black background.
  defp default_options do
    [extend_mode: :background, interpolate: :bilinear]
  end
end
