defmodule Image.Options.Mapim do
  @moduledoc """
  Options shared by transformations implemented with `Vix.Vips.Operation.mapim/3`.

  """

  alias Image.BackgroundColor
  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Interpolate

  @extend_modes [background: :VIPS_EXTEND_BACKGROUND, copy: :VIPS_EXTEND_COPY]

  @typedoc """
  The interpolators that may be selected with the `:interpolate`
  option (descriptions from `vips -l interpolate`):

  * `:nearest` - nearest-neighbour interpolation
  * `:bilinear` - bilinear interpolation
  * `:bicubic` - bicubic interpolation (Catmull-Rom)
  * `:lbb` - reduced halo bicubic
  * `:nohalo` - edge sharpening resampler with halo reduction
  * `:vsqbs` - B-Splines with antialiasing smoothing

  `:bilinear` is the default except for `Image.distort/4`, which
  retains its existing `:bicubic` default.

  """
  @type interpolate ::
          :nearest
          | :bilinear
          | :bicubic
          | :lbb
          | :nohalo
          | :vsqbs

  @typedoc "An interpolation option for a mapim-based transformation."
  @type interpolate_option :: {:interpolate, interpolate()}

  @typedoc "A background fill option for a mapim-based transformation."
  @type background_option :: {:background, BackgroundColor.spec() | nil}

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

  @typedoc "An interpolation-boundary option for a mapim-based transformation."
  @type extend_option :: {:extend_mode, extend_mode()}

  @typedoc "Interpolation and background options for transformations that expose canvas."
  @type background_options :: [interpolate_option() | background_option()]

  @typedoc "Interpolation options for transformations with fixed boundary handling."
  @type interpolate_options :: [interpolate_option()]

  @typedoc "Interpolation, background and boundary options for a mapim-based transformation."
  @type t :: [interpolate_option() | background_option() | extend_option()]

  @typep option_name :: :interpolate | :background | :extend_mode

  @option_names [:interpolate, :background, :extend_mode]

  # The libvips nickname for each interpolator is identical to the
  # public atom, so resolution is a simple `Atom.to_string/1`.
  @valid_interpolators ~w(nearest bilinear bicubic lbb nohalo vsqbs)a

  @doc """
  Validates the allowed options for a mapim-based transformation.

  All mapim options are allowed by default.
  """
  @spec validate_options(Vimage.t(), Keyword.t(), [option_name()]) ::
          {:ok, Keyword.t()} | {:error, Image.error()}
  def validate_options(image, options, allowed_options \\ @option_names) when is_list(options) do
    options =
      Keyword.merge(
        default_options(allowed_options),
        maybe_drop_nil_background(options, allowed_options)
      )

    case Enum.reduce_while(options, options, &validate_option(&1, image, &2, allowed_options)) do
      {:error, value} -> {:error, value}
      options -> {:ok, options}
    end
  end

  defp validate_option(
         {:interpolate, interpolate} = option,
         _image,
         options,
         allowed_options
       )
       when interpolate in @valid_interpolators do
    if :interpolate in allowed_options do
      case Interpolate.new(Atom.to_string(interpolate)) do
        {:ok, interpolator} ->
          {:cont, Keyword.put(options, :interpolate, interpolator)}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    else
      {:halt, {:error, invalid_option(option)}}
    end
  end

  defp validate_option({:background, background} = option, image, options, allowed_options) do
    if :background in allowed_options do
      case BackgroundColor.resolve(image, background) do
        {:ok, pixel} -> {:cont, Keyword.put(options, :background, pixel)}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    else
      {:halt, {:error, invalid_option(option)}}
    end
  end

  defp validate_option({:extend_mode, extend_mode} = option, _image, options, allowed_options) do
    if :extend_mode in allowed_options and Keyword.has_key?(@extend_modes, extend_mode) do
      options =
        options
        |> Keyword.delete(:extend_mode)
        |> Keyword.put(:extend, Keyword.fetch!(@extend_modes, extend_mode))

      {:cont, options}
    else
      {:halt, {:error, invalid_option(option)}}
    end
  end

  defp validate_option(option, _image, _options, _allowed_options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp maybe_drop_nil_background(options, allowed_options) do
    if :background in allowed_options do
      Enum.reject(options, &match?({:background, nil}, &1))
    else
      options
    end
  end

  defp default_options(allowed_options) do
    Keyword.take([interpolate: :bilinear, extend_mode: :background], allowed_options)
  end

  defp invalid_option(option) do
    %Image.Error{
      reason: :invalid_option,
      value: option,
      message: "Invalid option or option value: #{inspect(option)}"
    }
  end
end
