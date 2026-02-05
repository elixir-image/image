defmodule Image.Color do
  @moduledoc """
  Functions to manage image color and color conversion.

  """

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Operation

  @priv_dir :code.priv_dir(:image) |> List.to_string()
  @css_color_path Path.join(@priv_dir, "color/css_colors.csv")
  @additional_color_path Path.join(@priv_dir, "color/additional_colors.csv")
  @external_resource @additional_color_path

  @max_opacity 255
  @min_opacity 0

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

  @css_color Map.keys(@color_map)
             |> Enum.map(&String.to_atom/1)

  @greyscale_color_map @color_map
                       |> Enum.filter(fn {_name, [hex: _hex, rgb: [r, g, b]]} ->
                         if r == b && r == g, do: true, else: false
                       end)
                       |> Map.new()

  # TODO Put back when we validate greyscale colors
  # @greyscale_color Map.keys(@greyscale_color_map)
  # |> Enum.map(&String.to_atom/1)

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
  A transparency value which is one of the atoms `:none`,
  `:transparent` or `:opaque`. Or an integer between `0` and
  `255` where 0 is transparent and 255 is opaque. Or a float
  in the range `0.0` to `1.0` that is converted to the range
  `0` to `255`.

  """
  @type transparency :: :none | :transparent | :opaque | non_neg_integer() | float()

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
  Return max rgb value.

  """
  def max_rgb, do: 255

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
  Returns a mapping from CSS color names to CSS hex values
  and RGB triplets as a list - but only for greyscal colors.

  """
  def greyscale_color_map do
    @greyscale_color_map
  end

  @doc """
  Converts a color name or RGB value
  to a hex string.

  ### Arguments

  * `color` which can be specified as a single integer
    or a list of integers representing the color.
    The color can also be supplied as a CSS color name as a
    string or atom. For example: `:misty_rose`. See
    `Image.Color.color_map/0` and `Image.Color.rgb_color/1`.

  ### Returns

  * `{:ok, #RRGGBB}` string or

  * `{:error, reason}`.

  ### Examples

      iex> Image.Color.rgb_to_hex(:green)
      {:ok, "#008000"}

      iex> Image.Color.rgb_to_hex([10, 20, 30])
      {:ok, "#0A141E"}

      iex> Image.Color.rgb_to_hex([12, 12, 13])
      {:ok, "#0C0C0D"}

  """
  def rgb_to_hex(color) do
    with {:ok, color} <- validate_color(color) do
      case color do
        [color] -> {:ok, convert_to_hex(color, color, color)}
        [r, g, b] -> {:ok, convert_to_hex(r, g, b)}
      end
    end
  end

  @doc """
  Converts a hex color string to an RGB
  list.

  ### Arguments

  `color` is a hex string representing an RGB color. It has
  the form `#RRGGBB`.

  ### Returns

  * `{:ok, [r, g, b]}` or

  * `{:error, reason}`.

  ### Examples

      iex> Image.Color.validate_color "#0000FF"
      {:ok, [0, 0, 255]}

  """
  def hex_to_rgb(<<"#", r::bytes-2, g::bytes-2, b::bytes-2>>) do
    {:ok, [String.to_integer(r, 16), String.to_integer(g, 16), String.to_integer(b, 16)]}
  end

  def hex_to_rgb(invalid_color) do
    {:error, "Invalid hex color. Found #{inspect(invalid_color)}"}
  end

  defp convert_to_hex(r, g, b) do
    "#" <> to_hex(r) <> to_hex(g) <> to_hex(b)
  end

  defp to_hex(i) do
    i
    |> Integer.to_string(16)
    |> String.pad_leading(2, "0")
  end

  @doc """
  Validates a color returning an
  `[r, g, b]` triplet or error.

  ### Arguments

  * `color` which can be specified as a single integer
    or a list of integers representing the color.
    The color can also be supplied as a CSS color name as a
    string or atom. For example: `:misty_rose`. Lastly, the
    color can be supplied as a hex string like `"#ffe4e1"`. See
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

  @doc """
  Returns a transparency value in the range 0 to 255
  where 0 means transparent and 255 means opqque.

  """
  def validate_transparency(float) when float >= 0.0 and float <= 1.0 do
    {:ok, round(@max_opacity * float)}
  end

  def validate_transparency(int) when int in 0..255 do
    {:ok, int}
  end

  def validate_transparency(:transparent), do: {:ok, @min_opacity}
  def validate_transparency(:none), do: {:ok, @min_opacity}
  def validate_transparency(:opaque), do: {:ok, @max_opacity}

  def validate_transparency(other),
    do: {:error, "Invalid transparency value. Found #{inspect(other)}"}

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

  @doc false
  def max_opacity do
    @max_opacity
  end

  @doc false
  def min_opacity do
    @min_opacity
  end

  @doc false
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

  @doc false
  def normalize(color) do
    color
    |> to_string()
    |> String.downcase()
    |> String.replace(["_", "-", " "], "")
  end

  @doc """
  Sorts a list of colors.

  The color sorting is based upon https://www.alanzucconi.com/2015/09/30/colour-sorting/

  ### Arguments

  * `color` which can be specified as a single integer
    or a list of integers representing the color.
    The color can also be supplied as a CSS color name as a
    string or atom. For example: `:misty_rose`. Lastly, the
    color can be supplied as a hex string like `#ffe4e1`. See
    `Image.Color.color_map/0` and `Image.Color.rgb_color/1`.

  * `options` is a keyword list of options.

  ### Options

  There are currently no defined options.

  ### Returns

  * A sorted list of colors.

  """
  @doc since: "0.49.0"

  def sort(colors, options \\ []) do
    Enum.sort(colors, &compare_colors(&1, &2, options))
  end

  @doc false
  def compare_colors(color_1, color_2, options) do
    convert!(color_1, :srgb, :hlv, options) < convert!(color_2, :srgb, :hlv, options)
  end

  @default_repetitions 8

  @doc """
  Converts a color from one color space to another.

  ### Arguments

  * `color` which can be specified as a single integer
    or a list of integers representing the color.
    The color can also be supplied as a CSS color name as a
    string or atom. For example: `:misty_rose`. Lastly, the
    color can be supplied as a hex string like `"#ffe4e1"`. See
    `Image.Color.color_map/0` and `Image.Color.rgb_color/1`.

  * `from` is the colorspace from which `color` is converted.

  * `to` is the colorspace into which the `color` is converted.

  * `options` is a keyword list of options.

  ### Options

  There are currently no defined options.

  ### Returns

  * `{:ok, color}` or

  * `{:error, reason}`

  ### Example

      iex> Image.Color.convert(:misty_rose, :srgb, :hsv)
      {:ok, [4, 30, 255]}

      iex> Image.Color.convert([255, 255, 255], :srgb, :lab)
      {:ok, [100.0, 0.005245208740234375, -0.010609626770019531]}

  """
  @doc since: "0.49.0"

  def convert(color, from, to, options \\ [])

  def convert([r, g, b], :srgb, :srgb, _options) do
    {:ok, [round(r), round(g), round(b)]}
  end

  def convert(color, from, from, _options) do
    {:ok, color}
  end

  def convert(color, :srgb, :hsv, _options) do
    with {:ok, color} <- validate_color(color) do
      Image.new!(1, 1, color: color)
      |> Operation.srgb2hsv!()
      |> Image.get_pixel(0, 0)
    end
  end

  def convert(color, :lab, :srgb, _options) do
    with {:ok, color} <- validate_color(color) do
      Image.new!(1, 1, color: color)
      |> Operation.lab2labq!()
      |> Operation.labq2srgb!()
      |> Image.get_pixel(0, 0)
    end
  end

  def convert(color, :srgb, :lab, _options) do
    with {:ok, color} <- validate_color(color) do
      Image.new!(1, 1, color: color)
      |> Operation.srgb2scrgb!()
      |> Operation.scrgb2xyz!()
      |> Operation.xyz2lab!()
      |> Operation.getpoint(0, 0)
    end
  end

  def convert(color, :srgb, :hlv, options) do
    with {:ok, [r, g, b]} <- validate_color(color),
         {:ok, [h, _s, v]} = convert(color, :srgb, :hsv, options) do
      repetitions = Keyword.get(options, :repetitions, @default_repetitions)
      lum = :math.sqrt(0.241 * r + 0.691 * g + 0.068 * b)

      h2 = trunc(h * repetitions)
      lum2 = trunc(lum * repetitions)
      v2 = trunc(v * repetitions)

      {:ok, [h2, lum2, v2]}
    end
  end

  @doc false
  def convert(%Vimage{} = image, to) do
    from = Image.colorspace(image)
    color = Image.get_pixel!(image, 0, 0)
    convert(color, from, to)
  end

  @doc """
  Converts an color from one color space to another or
  raises an exception.

  ### Arguments

  * `color` which can be specified as a single integer
    which or a list of integers representing the color.
    The color can also be supplied as a CSS color name as a
    string or atom. For example: `:misty_rose`. See
    `Image.Color.color_map/0` and `Image.Color.rgb_color/1`.

  * `from` is the colorspace from which `color` is converted.

  * `to` is the colorspace into which the `color` is converted.

  * `options` is a keyword list of options.

  ### Options

  There are currently no defined options.

  ### Returns

  * `converted_color` or

  * raises an exception.

  ### Example

      iex> Image.Color.convert!(:misty_rose, :srgb, :hsv)
      [4, 30, 255]

      iex> Image.Color.convert!([255, 255, 255], :srgb, :lab)
      [100.0, 0.005245208740234375, -0.010609626770019531]

  """
  @doc since: "0.49.0"

  def convert!(color, from, to, options \\ []) do
    case convert(color, from, to, options) do
      {:ok, color} -> color
      {:error, reason} -> raise Image.Error, reason
    end
  end
end
