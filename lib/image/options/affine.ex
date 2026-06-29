defmodule Image.Options.Affine do
  @moduledoc """
  Options and option validation for `Image.affine/3`.

  These options are shared by the affine family of
  transformations: `Image.affine/3`, `Image.translate/4`
  and `Image.shear/4`.

  """

  alias Vix.Vips.Interpolate

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
          | {:interpolate, interpolate() | Interpolate.t()}
          | {:background, Image.pixel()}
          | {:output_area, [integer()]}
          | {:extend_mode, Image.ExtendMode.t()}
        ]

  # The libvips nickname for each interpolator is identical to the
  # public atom, so resolution is a simple `Atom.to_string/1`.
  @valid_interpolators ~w(nearest bilinear bicubic lbb nohalo vsqbs)a

  @displacement_options [:idx, :idy, :odx, :ody]

  @doc false
  defguard is_color(color) when is_number(color) and color >= 0

  @doc """
  Validate the options for `Image.affine/3`.

  See `t:Image.Options.Affine.affine_options/0`.

  """
  @spec validate_options(Keyword.t()) :: {:ok, Keyword.t()} | {:error, Image.error()}
  def validate_options(options) do
    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} ->
        {:error, value}

      options ->
        {:ok, options}
    end
  end

  defp validate_option({:interpolate, %Interpolate{}}, options) do
    {:cont, options}
  end

  defp validate_option({:interpolate, interpolate}, options)
       when interpolate in @valid_interpolators do
    case Interpolate.new(Atom.to_string(interpolate)) do
      {:ok, interpolator} ->
        {:cont, Keyword.put(options, :interpolate, interpolator)}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  # The public option is `:extend_mode` (matching `Image.warp_perspective/4`),
  # libvips names the affine parameter `extend`.
  defp validate_option({:extend_mode, extend}, options) do
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

  defp validate_option({:background, background}, options) when is_color(background) do
    options = Keyword.put(options, :background, List.wrap(background))
    {:cont, options}
  end

  defp validate_option({:background, [r, g, b]}, options)
       when is_color(r) and is_color(g) and is_color(b) do
    {:cont, options}
  end

  defp validate_option({:background, [r, g, b, a]}, options)
       when is_color(r) and is_color(g) and is_color(b) and is_color(a) do
    {:cont, options}
  end

  defp validate_option({:background, [c]}, options) when is_color(c) do
    {:cont, options}
  end

  # The public option is `:output_area`, libvips names it `oarea`.
  defp validate_option({:output_area, [left, top, width, height] = area}, options)
       when is_integer(left) and is_integer(top) and is_integer(width) and is_integer(height) do
    options =
      options
      |> Keyword.delete(:output_area)
      |> Keyword.put(:oarea, area)

    {:cont, options}
  end

  defp validate_option({option, value}, options)
       when option in @displacement_options and is_number(value) do
    {:cont, Keyword.put(options, option, value * 1.0)}
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
