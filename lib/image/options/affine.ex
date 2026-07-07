defmodule Image.Options.Affine do
  @moduledoc """
  Options and option validation for `Image.affine/3`.

  These options are shared by the affine family of
  transformations: `Image.affine/3`, `Image.translate/4`
  and `Image.shear/4`.

  """

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Interpolate
  alias Image.BackgroundColor

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
  How the interpolator synthesizes the one-pixel fringe just beyond
  the content edge when resampling boundary pixels.

  * `:background` (the default) blends the fringe toward the
    `:background` color. This is correct whenever the transform
    exposes canvas.
  * `:copy` clamps to the nearest content pixel. Use it when the
    content fills the whole canvas, where the default would leave a
    faint border along the outermost row and column.

  """
  @type extend_mode :: :background | :copy

  @typedoc """
  The options applicable to an affine transformation.

  """
  @type affine_options :: [
          {:idx, number()}
          | {:idy, number()}
          | {:odx, number()}
          | {:ody, number()}
          | {:interpolate, interpolate()}
          | {:background, BackgroundColor.spec() | nil}
          | {:extend_mode, extend_mode()}
          | {:output_area, [integer()]}
        ]

  # The libvips nickname for each interpolator is identical to the
  # public atom, so resolution is a simple `Atom.to_string/1`.
  @valid_interpolators ~w(nearest bilinear bicubic lbb nohalo vsqbs)a

  @displacement_options [:idx, :idy, :odx, :ody]

  # The other libvips extend modes are deliberately not exposed: :repeat
  # samples the opposite edge of the image into the fringe, :mirror is
  # indistinguishable from :copy at one pixel deep, and :black/:white are
  # colors, which belong to :background.
  @extend_modes [background: :VIPS_EXTEND_BACKGROUND, copy: :VIPS_EXTEND_COPY]

  @doc """
  Validate the options for `Image.affine/3`.

  The `image` is required to resolve the `:background` option
  into a pixel matching the image's bands and color space.

  See `t:Image.Options.Affine.affine_options/0`.

  """
  @spec validate_options(Vimage.t(), Keyword.t()) ::
          {:ok, Keyword.t()} | {:error, Image.error()}
  def validate_options(image, options) do
    # A nil `:background` means "unset", i.e. it falls back to the default.
    options = Enum.reject(options, &match?({:background, nil}, &1))
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

  # The public option is `:extend_mode`, renamed to `:extend` for `libvips`.
  defp validate_option({:extend_mode, extend_mode}, _image, options)
       when extend_mode in [:background, :copy] do
    options =
      options
      |> Keyword.delete(:extend_mode)
      |> Keyword.put(:extend, Keyword.fetch!(@extend_modes, extend_mode))

    {:cont, options}
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

  # No default `:background` is injected. When omitted, libvips uses its
  # native all-zeros fill. `:interpolate` defaults to `:bilinear`, also
  # libvips' own default. `:extend_mode` defaults to `:background` so the
  # edge fringe blends into the canvas fill.
  defp default_options do
    [interpolate: :bilinear, extend_mode: :background]
  end
end
