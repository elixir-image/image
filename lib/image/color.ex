defmodule Image.Color do
  @moduledoc """
  Functions to manage image color and color conversion.

  """

  @priv_dir :code.priv_dir(:image) |> List.to_string()
  @css_color_path Path.join(@priv_dir, "color/css_colors.csv")
  @additional_color_path Path.join(@priv_dir, "color/additional_colors.csv")
  @external_resource @additional_color_path

  @css_colors File.read!(@css_color_path)
  @additional_colors File.read!(@additional_color_path)

  @color_map (@css_colors <> "\n" <> @additional_colors)
             |> String.split("\n", trim: true)
             |> Enum.reject(&String.starts_with?(&1, "#"))
             |> Enum.map(&String.split(&1, ", "))
             |> Enum.map(fn [name, hex] ->
               <<"#", r::bytes-2, g::bytes-2, b::bytes-2>> = hex
               rgb = [String.to_integer(r, 16), String.to_integer(g, 16), String.to_integer(b, 16)]
               {String.downcase(name), hex: hex, rgb: rgb}
             end)
             |> Map.new()

  @css_color Map.keys(@color_map) |> Enum.map(&String.to_atom/1)

  @typedoc """
  An rbg color expressed as a list of numbers.

  The number of list elements and the type
  varies depending on the image format, colorspace
  and dimensions.

  For a common `sRGB` image it will be a list of
  three of four images. If the fourth number is provided
  it will be considered as an alpha transparency band.

  """
  @type rgb_color :: [number()] | number()

  @typedoc """
  A color can be expressed as a list of numbers or
  as a CSS color name in atom or string format.

  """
  @type t :: rgb_color | atom() | String.t()

  @typedoc """
  Reference to an ICC color profile

  * `:none` means no profile
  * `:cmyk`, `:srgb` and `:p3` refer to the built-in color profiles
  * `Path.t()` means any file system path. If the path is a relative
    path then is will be loaded from the systems profile directory.

  """
  @type icc_profile :: :none | :cmyk | :srgb | :p3 | Path.t()

  @inbuilt_profiles [:none, :srgb, :cmyk, :p3]

  @doc """
  Guards whether a given value can be interpreted
  as a color value.

  """
  defguard is_color(color)
           when (is_number(color) and color >= 0) or (is_list(color) and length(color) in 3..5) or
                  color in @css_color

  @doc """
  Guards whether a given profile is one of the inbuilt
  profiles.

  """
  defguard is_inbuilt_profile(profile) when profile in @inbuilt_profiles

  @doc """
  Returns the list of color profiles built into
  `libvips`.

  """
  def inbuilt_profiles, do: @inbuilt_profiles

  @doc """
  Returns a boolean indicating if the given
  profile is known and can be used for image
  operations.

  """
  def known_icc_profile?(profile) when profile in @inbuilt_profiles do
    true
  end

  def known_icc_profile?(path) do
    case Vix.Vips.Operation.profile_load(path) do
      {:ok, _} -> true
      _other -> false
    end
  end

  @doc """
  Returns a mapping from CSS color names to CSS hex values
  and RGB triplets as a list.

  """
  def color_map do
    @color_map
  end

  @doc """
  Validates a color returning an
  `[r, g, b]` triplet or error.

  ### Arguments

  `color` which can be specified as a single integer
  which or a list of integers representing the color.
  The color can also be supplied as a CSS color name as a
  string or atom. For example: `:misty_rose`. See
  `Image.Color.color_map/0` and `Image.Color.rgb_color/1`.

  ### Returns

  * `{:ok, [r, g, b]}` or

  * `{:error, reason}`

  """
  def validate_color(color) do
    case rgb_color(color) do
      {:ok, [hex: _hex, rgb: rgb]} -> {:ok, rgb}
      {:ok, color} when is_list(color) -> {:ok, color}
      {:ok, color} when is_integer(color) -> {:ok, [color, color, color]}
      other -> other
    end
  end

  def rgb_color(color) when is_binary(color) or is_atom(color) do
    case color do
      <<"#", r::bytes-2, g::bytes-2, b::bytes-2>> ->
        {:ok, [String.to_integer(r, 16), String.to_integer(g, 16), String.to_integer(b, 16)]}

      color ->
        case Map.fetch(color_map(), normalize(color)) do
          {:ok, color} -> {:ok, color}
          :error -> {:error, "Invalid color #{inspect(color)}"}
        end
    end
  end

  def rgb_color(color) when is_color(color) do
    {:ok, color}
  end

  def rgb_color!(color) do
    case rgb_color(color) do
      {:ok, color} -> color
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @max_opacity 255
  @min_opacity 0

  @doc false
  def max_opacity do
    @max_opacity
  end

  @doc false
  def min_opacity do
    @min_opacity
  end

  def rgba_color!(color, a \\ @max_opacity)

  def rgba_color!(color, _a) when color in [:none, :transparent] do
    [0, 0, 0, @min_opacity]
  end

  def rgba_color!(color, a) when is_binary(color) and is_integer(a) do
    [r, g, b] =
      case rgb_color!(color) do
        [hex: _hex, rgb: rgb_color] -> rgb_color
        [_r, _g, _b] = rgb_color -> rgb_color
      end

    [r, g, b, a]
  end

  def rgba_color!(color, a)
      when (is_binary(color) or is_atom(color)) and is_float(a) and a >= 0.0 and a <= 1.0 do
    a = round(@max_opacity * a)
    rgba_color!(color, a)
  end

  def rgba_color!(color, a)
      when (is_binary(color) or is_atom(color)) and is_integer(a) and a >= 0 do
    [r, g, b] = Keyword.get(rgb_color!(color), :rgb, color)
    [r, g, b, a]
  end

  def rgba_color!(color, a) when is_integer(color) and color >= 0 do
    rgba_color!([color, color, color], a)
  end

  def rgba_color!([r, g, b], a) when is_integer(a) and a >= 0 do
    [r, g, b, a]
  end

  def rgba_color!([_r, _g, _b, _a] = color, _alpha) do
    color
  end

  def normalize(color) do
    color
    |> to_string()
    |> String.downcase()
    |> String.replace(["_", "-", " "], "")
  end
end
