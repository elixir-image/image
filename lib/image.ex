defmodule Image do
  @moduledoc """
  `Image` is based upon the fabulous
  [vix](https://hex.pm/packages/vix) library that provides a [libvips](https://www.libvips.org)
  wrapper for Elixir.

  `Image` is intended to provide well-documented common image processing functions in
  an idiomatic Elixir functional style as a layer above the very comprehensive set
  of functions in `Vix` and `libvips`.

  In a very simple image resizing
  [benchmark](https://github.com/kipcole9/image/blob/main/bench/image_resize.exs),
  `Image` is approximately 2 to 3 times faster than `Mogrify` and uses about 5 times
  less memory.

  """

  alias Vix.Vips.Operation
  alias Vix.Vips.MutableImage
  alias Vix.Vips.Image, as: Vimage

  alias Image.{
    Exif,
    Xmp,
    Complex,
    Options,
    Pixel,
    Interpretation,
    BlendMode,
    BandFormat
  }

  alias Image.Options.{Resize, Thumbnail, Compose, Open, ChromaKey}
  alias Image.Math
  alias Image.Draw

  @typedoc """
  THe structure of an image returned from `Kino.Input.read/1`
  when the input field is a `Kino.Input.image/1` type.
  """
  @type kino_image :: %{
          required(:file_ref) => {:file, binary()} | binary(),
          required(:format) => :rgb | :png,
          optional(:width) => pos_integer(),
          optional(:height) => pos_integer()
        }

  @typedoc """
  A 512 bit binary hash of an image.

  Useful for comparing the similarity of
  two images. See `Image.dhash/1` and
  `Image.hamming_distance/2`.
  """
  @type image_hash :: binary()

  @typedoc """
  The valid sources of image data when opening an
  image.
  """
  @type image_data :: Path.t() | File.Stream.t() | binary() | Enumerable.t()

  @typedoc """
  Represents either an image or a color value used to fill a new
  image. The colour form accepts everything `Image.Pixel.to_pixel/3`
  understands plus a bare numeric value (treated as a uniform grey).
  """
  @type image_or_color :: Vimage.t() | Pixel.t() | number()

  @typedoc """
  The valid rendering intent values. For all
  functions that take an optional intent
  parameter the default is `:perceptual`.

  ## Perceptual Intent

  Perceptual rendering is used to process photographic
  type images. This intent processes the colors so that
  the output reproduction is pleasing. This process
  tends to change the color from the original, so no
  guarantee the reproduction will be accurate against
  the original.

  ## Relative Intent

  Relative colorimetric changes all the colours out
  of gamut to the nearest colour in gamut, so many
  colours change to the same one. It DOES NOT change
  colours in gamut. Perceptual changes ALL the colours
  in the image in a proportional way so that they lie
  in the output device gamut.

  ## Saturation Intent

  Saturation moves in-gamut colors toward the edge of the
  destination gamut for maximum saturation and impact.
  This intent will make an image more colorful by using
  the full gamut of the destination device. This intent
  cares not for the genuine representation of color.

  ## Absolute Intent

  Absolute rendering attempts to reproduce all
  colors numerically (destination = source). This
  can cause unexpected results if the source gamut is
  larger than the destination.

  """
  @type render_intent :: :perceptual | :relative | :saturation | :absolute

  @typedoc """
  The error half of every `{:ok, _} | {:error, _}` tuple returned by
  this library is an `Image.Error` struct. The struct carries a
  structured `:reason` (atom or `{atom, value}` tuple), an optional
  `:operation`, `:path`, and `:value`, plus a derived `:message`.

  See `Image.Error` for the full set of reason atoms and the pattern
  for matching on them.

  """
  @type error :: Image.Error.t()

  @typedoc """
  A pixel is represented as a list of number values or
  a single number (which is then assumed to be the value
  for all bands).

  The number of list elements is determined by
  the colorspace interpretations. For example:

  * `RGB` colorspace would be represented by
    a list of three floats like `[0.0, 0,0, 0.0]` for black.

  * `CMYK` colorspace would be represented by a
    list of four floats.

  * A `PNG` image can be in any appropriate
    colorspace but may also have an `alpha` band
    and therefore have three, four or five floats
    in a list to represent the pixel.

  """
  @type pixel :: [number()] | number()

  @typedoc """
  Representaton of a coordinate in an image.

  The first number is the displacement on the
  x-axis (starting at 0 from the left) and the
  second number is the displacement on the
  y-axis (starting at 0 from the top).

  """
  @type point :: {x :: non_neg_integer(), y :: non_neg_integer()}

  @typedoc """
  The bounding box returned by find_time/2

  """
  @type bounding_box ::
          {left :: non_neg_integer(), top :: non_neg_integer(), width :: non_neg_integer(),
           height :: non_neg_integer()}

  @typedoc """
  Image orientation.

  """
  @type aspect :: :landscape | :portrait | :square

  @typedoc """
  The level of transparency for an alpha band
  where `0` means fully opaque and `255` means
  fully transparent.

  """
  @type transparency :: 0..255 | :opaque | :transparent

  @typedoc """
  An image bounding box being a four element list
  of 2-tuples representing the points of a rectangle
  in the order top left -> top right -> bottom right ->
  bottom left.

  """
  @type quadrilateral :: [{x :: non_neg_integer(), y :: non_neg_integer()}, ...]

  @typedoc """
  The data type of the image, using the same
  type definitions as `t:Nx.Type.t/0`.
  """
  @type format :: {:u | :s | :f | :c | :bf, 8 | 16 | 32 | 64 | 128}

  @typedoc """
  The x location on an image which is either a
  non_negative 0-based integer relative to the image left or
  a negative -1-based integer relative to the image right or
  the symbolic references `:left`, `:center` and
  `:right`.

  """
  @type x_location :: integer() | :left | :center | :right

  @typedoc """
  The y location on an image which is either a
  non_negative 0-based integer relative to the image top or
  a negative -1-based integer relative to the image right or
  the symbolic references `:top`, `:middle` and
  `:bottom`.

  """
  @type y_location :: integer() | :top | :middle | :bottom

  @typedoc """
  A list of images or images with placement options used in
  Image.compose/2.

  """
  @type composition_list :: [composition, ...]

  @typedoc """
  A composition can be a simple image, or an image with
  associated composition options.

  """
  @type composition :: Vimage.t() | {Vimage.t(), Options.Compose.t()}

  # Default radius of rounded corners
  @default_round_corner_radius 50

  # Default squircle radius
  @default_squircle_radius 20

  # When pixelating an image resize to this scale
  # the scale up by the inverse using nearest_neighbour
  # scaling
  @pixelate_scale 0.05

  # The default sigma applied to a gaussian blur.
  # Used by blur/3 and feather/2
  @default_blur_sigma Options.Blur.default_blur_sigma()

  # if the ratio between width and height differs
  # by less than this amount, consider the image
  # to be square
  @square_when_ratio_less_than 0.0

  # The percent from absolute black and
  # absolute white in equalize/2 for
  # :each band option.
  @level_trim_percent 0.3

  # The default window applied to Operation.rank/3
  # when used in Image.reduce_noise/2
  @default_median_window_size 3

  # The percent from range of the tone
  # curve when equalizing luminance.
  @min_luminance 1.0
  @max_luminance 99.0

  # Standard libvips/RGBA convention: alpha 255 = fully
  # opaque (visible), alpha 0 = fully transparent (invisible).
  @opaque_ 255
  @transparent 0

  # How many bins to use to calculate an approximate
  # dominant color. The maximum is 256. Larger numbers
  # significantly slow calculation.
  @dominant_bins 16

  # How many of the most common colors
  # to return in dominant_color/2
  @dominant_top_n 1

  # Default method used by dominant_color/2
  @dominant_method :histogram

  # Default libimagequant effort (1-10) used when method: :imagequant
  @dominant_effort 7

  # Default libimagequant dithering amount used when method: :imagequant.
  # Zero preserves palette colors exactly (no error-diffused output),
  # which is what we want when extracting a palette.
  @dominant_dither 0.0

  # For erode/2 and dilate/2 this is acceptable
  # range for the radius parameter.
  @rank_radius_range 1..100

  @doc """
  Guards whether the given struct is an image type
  either `Vix.Vips.Image` or `Vix.Vips.MutableImage`.
  """
  defguard is_image(image_type) when image_type in [Vimage, MutableImage]

  @doc """
  Guards whether the coordinates can be reasonably
  interpreted as a bounding box.

  `left` and `top` when positive are relative to
  the left and top of the image respectively. When
  negative they are relative to the right and bottom
  of the image.

  """
  @doc subject: "Guard"
  defguard is_box(left, top, width, height)
           when is_integer(left) and is_integer(top) and is_integer(width) and is_integer(height) and
                  width > 0 and height > 0

  @doc """
  Guards whether a parameter is a rectangular bounding box. A
  rectangular bounding box is a list of four 2-tuples that must
  represent a rectangle (not an arbitrary quadrilateral),

  The order of points is top_left -> top right -> bottom
  right -> bottm left.

  """
  @doc subject: "Guard"
  defguard is_rectangle(top_left, top_right, bottom_right, bottom_left)
           when is_tuple(top_left) and
                  is_tuple(top_right) and
                  is_tuple(bottom_right) and
                  is_tuple(bottom_left) and
                  elem(top_left, 0) == elem(bottom_left, 0) and
                  elem(top_right, 0) == elem(bottom_right, 0) and
                  elem(top_left, 1) == elem(top_right, 1) and
                  elem(bottom_right, 1) == elem(bottom_left, 1)

  @doc """
  Guards whether a number can be reasonably interpreted
  as a size (as in size of a crop or mask)

  """
  @doc subject: "Guard"
  defguard is_size(size) when is_integer(size) and size > 0

  @doc """
  Guards whether a term might be reasonably interpreted
  as an image pixel — that is, *not* a `Vix.Vips.Image` or
  `Vix.Vips.MutableImage`, but anything else `Color.new/2`
  (or `Image.Pixel.to_pixel/3`) could turn into a pixel.

  Accepts numbers, lists, atoms (CSS named colours),
  binary inputs (hex strings, named colours), and `Color.*`
  structs. `Vix.Vips.Image` / `Vix.Vips.MutableImage` are
  explicitly excluded so callers can dispatch between
  "image" and "color" arguments cleanly.

  """
  @doc subject: "Guard"
  defguard is_pixel(value)
           when is_number(value) or
                  (is_list(value) and length(value) >= 1 and length(value) <= 5) or
                  is_binary(value) or
                  (is_atom(value) and value not in [nil, true, false]) or
                  (is_struct(value) and
                     not is_struct(value, Vix.Vips.Image) and
                     not is_struct(value, Vix.Vips.MutableImage))

  @doc """
  Guards whether a value is a percentage as representeed
  by a float between `-1.0` and `1.0`.
  """
  @doc subject: "Guard"
  defguard is_percent(value) when is_float(value) and value >= -1.0 and value <= 1.0

  @doc """
  Guards whether a value is a positive percentage as representeed
  by a float greater than `0.0` and less than or equal to `1.0`.
  """
  @doc subject: "Guard"
  defguard is_positive_percent(value) when is_float(value) and value >= 0.0 and value <= 1.0

  @doc """
  Guards whether a value is a multiplier as representeed
  by a float greater than `0.0`.
  """
  @doc subject: "Guard"
  defguard is_multiplier(value) when is_float(value) and value >= 0.0

  @doc """
  Create a new image of the given dimensions.

  ### Arguments

  Either `width` and `height` OR `image` should be
  provided.

  * `width` is the image width as an integer.

  * `height` is the image height as an integer.

  * `image` is an image from which the `width`, `height` are
    derived.

  * `options` is a keyword list of options.

  ### Options

  * `:color` defines the color of the image. This
    can be specified as a single integer which will
    be applied to all bands, or a list of
    integers representing the color for each
    band. The default is `0`, meaning black. The color
    can also be supplied as a CSS color name as a
    string or atom. For example: `:misty_rose`. See
    `Color.new/2` from the Color library.

  * `:bands` defines the number of bands (channels)
    to be created. The default is the number of bands of
    `:color` option or if `:color` is an integer then the
    default value is `3`.

  * `:format` defines the format of the image. The
    default is `{:u, 8}`.

  * `:interpretation` defines the interpretation of
    the image. The default is `:srgb`.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`

  ### Notes

  * Either `width` and `height` OR `image` should
    be provided as arguments but NOT both.

  ### Examples

        # 100x100 pixel image of dark blue slate color
        iex> {:ok, _image} = Image.new(100, 100, color: :dark_slate_blue)

        # 100x100 pixel green image, fully transparent
        iex> {:ok, _image} = Image.new(100, 100, color: [0, 255, 0, 255], bands: 4)

  """
  @doc subject: "Load and save"

  @spec new(width :: pos_integer(), height :: pos_integer()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def new(width, height)
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    new(width, height, [])
  end

  @spec new(image :: %Vimage{}, options :: Options.New.t()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def new(%Vimage{} = image, options) do
    {width, height, bands} = Image.shape(image)
    options = Keyword.put_new(options, :bands, bands)

    new(width, height, options)
  end

  @doc subject: "Load and save"

  @spec new(width :: pos_integer(), height :: pos_integer(), options :: Options.New.t()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def new(width, height, options)
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    with {:ok, options} <- Options.New.validate_options(options) do
      {:ok, pixel} =
        Vix.Vips.Operation.black!(1, 1, bands: options.bands)
        |> Image.Math.add!(options.color)
        |> Operation.cast(options.format)

      {:ok, image} = Operation.embed(pixel, 0, 0, width, height, extend: :VIPS_EXTEND_COPY)

      Operation.copy(image,
        interpretation: options.interpretation,
        xres: options.x_res,
        yres: options.y_res,
        xoffset: options.x_offset,
        yoffset: options.y_offset
      )
    end
  end

  @doc """
  Return a new image of the given dimensions and
  background color or raise an exception.

  ### Arguments

  Either `width` and `height` OR `image` should be
  provided.

  * `width` is the image width as an integer.

  * `height` is the image height as an integer.

  * `image` is an image from which the `width`, `height` re
    derived.

  * `options` is a keyword list of options.

  ### Options

  * `:bands` defines the number of bands (channels)
    to be created. The default is `3`.

  * `:color` defines the color of the image. This
    can be specified as a single integer which will
    be applied to all bands, or a list of
    integers representing the color for each
    band. The default is `0`, meaning black. The color
    can also be supplied as a CSS color name as a
    string or atom. For example: `:misty_rose`. See
    `Color.new/2` from the Color library.

  * `:format` defines the format of the image. The
    default is `{:u, 8}`.

  * `:interpretation` defines the interpretation of
    the image. The default is `:srgb`.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`

  ### Notes

  * Either `width` and `height` OR `image` should
    be provided as arguments but NOT both.

  ### Examples

        # 100x100 pixel image of dark blue slate color
        iex> {:ok, _image} = Image.new(100, 100, color: :dark_slate_blue)

        # 100x100 pixel green image, fully transparent
        iex> {:ok, _image} = Image.new(100, 100, color: [0, 255, 0, 1], bands: 4)

  """
  @doc subject: "Load and save"
  @spec new!(width :: pos_integer(), height :: pos_integer()) ::
          Vimage.t() | no_return()

  def new!(width, height)
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    case new(width, height) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @spec new!(image :: %Vimage{}, options :: Options.New.t()) ::
          Vimage.t() | no_return()

  def new!(%Vimage{} = image, options) do
    case new(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc subject: "Load and save"

  @spec new!(width :: pos_integer(), height :: pos_integer(), options :: Options.New.t()) ::
          Vimage.t() | no_return()

  def new!(width, height, options)
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    case new(width, height, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Create a new image of the same shape as the
  provided image.

  The function creates a new image with the same
  width, height and bands as the image argument and
  a color of `:black`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` from
    which the new images `width` and `height` and
  ` bands` will be derived.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`

  """
  @doc subject: "Load and save", since: "0.1.13"

  @spec new(image :: %Vimage{}) ::
          {:ok, Vimage.t()} | {:error, error()}

  def new(%Vimage{} = image) do
    new(image, [])
  end

  @doc """
  Return a new image of the same shape as the
  provided image or raise an exception.

  The function creates a new image with the same
  width, height and bands as the image argument.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` from
    which the new images `width` and `height` and
  ` bands` will be derived.

  * `options` is a keyword list of options.

  ### Options

  * `:bands` defines the number of bands (channels)
    to be created. The default is the number of bands
    in `image`.

  * `:color` defines the color of the image. This
    can be specified as a single integer which will
    be applied to all bands, or a list of
    integers representing the color for each
    band. The default is `0`, meaning black. The color
    can also be supplied as a CSS color name as a
    string or atom. For example: `:misty_rose`. See
    `Color.new/2` from the Color library.

  * `:format` defines the format of the image. The
    default is `{:u, 8}`.

  * `:interpretation` defines the interpretation of
    the image. The default is `:srgb`.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`

  """
  @doc subject: "Load and save", since: "0.1.13"

  def new!(%Vimage{} = image) do
    case new(image, []) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Opens an image file or stream for image processing.

  ### Arguments

  * `image_path_or_stream_or_binary` is the file system path to an image
    file or a `t:File.Stream.t/0` or any `t:Enumerable.t/0`. It
    can also be any binary `.jpg`, `.png`, `.webp` or `.svg` image.

  * `options` is a keyword list of options. The default is
    `[access: :random]` for all images except images
    derived from binary image data.

  ### Options

  The available options depend upon the image type.

  #### All image types

  * `:access` is the file access mode, either `:random`
    or `:sequential`. The default is `:random`.
    When `:sequential`, `Image` (via `Vix`) is able
    to support streaming transformations and optimise
    memory usage more effectively. However `:sequential`
    also means that some operations cannot be completed
    because they would require non-sequential access to
    the image. In these cases, `:random` access is required.

  * `:fail_on` sets the error level at which image
    loading and decoding will stop. The default is `:none`.
    Each error state implies all the states before it such
    that `:error` implies also `:truncated`.

  #### JPEG image options

  * `:shrink` is an integer factor in the range `1..16` by
    which the image is reduced upon loading. This is an
    optimization that can result in improved performance and
    reduced memory usage if the image is being loaded
    with the intent to resize it to smaller dimensions. The
    default value is `1` meaning no shrink-on-load.

  #### WEBP options

  * `:scale` will scale the image on load. The value is
    a number greater than `0` and less than or equal
    to `1024` with a default of `1` meaning no scaling
    on load. Numbers less than `1.0` scale the image down
    so that a scale of `0.5` will halve the image size on
    load.

  * `:page` indicates the first page to be loaded. The
    value is in the range `0..100_000` with a default
    value of `0`. This parameter is useful on animated images.

  * `:pages` indicates the number of pages to load.
    The value must be between `-1` and `100_000`. The default
    value is `1`.  A value of `-1` would load all the available
    pages which is useful if you want to keep the animation of
    the input image. The atom `:all` can be used in place of
    `-1` to indicate all pages should be loaded.

  #### TIFF options

  * `:page` indicates the first page to be loaded. The
    value is in the range `0..100_000` with a default
    value of `0`. This parameter is useful on animated images.

  * `:pages` indicates the number of pages to load.
    The value must be between `-1` and `100_000`. The default
    value is `1`.  A value of `-1` would load all the available
    pages which is useful if you want to keep the animation of
    the input image. The atom `:all` can be used in place of
    `-1` to indicate all pages should be loaded.

  #### GIF options

  * `:page` indicates the first page to be loaded. The
    value is in the range `0..100_000` with a default
    value of `0`. This parameter is useful on animated images.

  * `:pages` indicates the number of pages to load.
    The value must be between `-1` and `100_000`. The default
    value is `1`.  A value of `-1` would load all the available
    pages which is useful if you want to keep the animation of
    the input image. The atom `:all` can be used in place of
    `-1` to indicate all pages should be loaded.

  #### PNG options

  * There are no PNG-specific image loading
    options.

  ### Returns

  * `{:ok, image}` or

  * `{:error, message}`

  """
  @doc subject: "Load and save"

  @spec open(path_or_stream_or_binary :: image_data(), options :: Open.image_open_options()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def open(path_or_stream_or_binary, options \\ [])

  # JPEG signature
  def open(<<0xFF, 0xD8, 0xFF, _::binary>> = image, options) do
    from_binary(image, options)
  end

  # PNG signature
  png =
    quote do
      <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::size(32), "IHDR", _::binary>>
    end

  def open(unquote(png) = image, options) do
    from_binary(image, options)
  end

  # WEBP signature
  def open(<<"RIFF", _::size(32), "WEBP", _::binary>> = image, options) do
    from_binary(image, options)
  end

  # GIF87a signature
  def open(<<0x47, 0x49, 0x46, 0x38, 0x37, 0x61, _::binary>> = image, options) do
    from_binary(image, options)
  end

  # GIF89a signature
  def open(<<0x47, 0x49, 0x46, 0x38, 0x39, 0x61, _::binary>> = image, options) do
    from_binary(image, options)
  end

  # TIF little endian
  def open(<<0x49, 0x49, 0x2A, 0x00, _::binary>> = image, options) do
    from_binary(image, options)
  end

  # TIF big endian
  def open(<<0x4D, 0x4D, 0x00, 0x2A, _::binary>> = image, options) do
    from_binary(image, options)
  end

  # 'heic': the usual HEIF images
  # 'heix': 10bit images, or anything that uses h265 with range extension
  # 'hevc', 'hevx': brands for image sequences
  # 'heim': multiview
  # 'heis': scalable
  # 'hevm': multiview sequence
  # 'hevs': sc

  @heic_types ["heic", "heix", "hevc", "hevx", "heim", "heis", "hevm", "hevs", "mif1", "avif"]

  def open(<<_::bytes-4, "ftyp", type::bytes-4, _rest::binary>> = image, options)
      when type in @heic_types do
    from_binary(image, options)
  end

  # SVG starting with either svg or xml tag
  def open(<<"<svg ", _::binary>> = image, options) do
    from_binary(image, options)
  end

  def open(<<"<?xml ", _::binary>> = image, options) do
    from_binary(image, options)
  end

  # A file path
  def open(image_path, options) when is_binary(image_path) do
    with {:ok, options} <- Options.Open.validate_options(options) do
      image_path
      |> String.split("[", parts: 2)
      |> do_open(options)
    end
  end

  # A File stream
  def open(%File.Stream{line_or_bytes: bytes} = image_stream, options) when is_integer(bytes) do
    with {:ok, options} <- Options.Open.validate_options(options) do
      options = loader_options(options)
      Vix.Vips.Image.new_from_enum(image_stream, options)
    end
  end

  def open(%File.Stream{}, _options) do
    {:error,
     "File stream must be specify the number of bytes to read. " <>
       "It should be opened as File.stream!(path, options, bytes) where bytes " <>
       "is the number of bytes to read on each iteration."}
  end

  # Any other stream
  def open(image_stream, options) do
    with {:ok, options} <- Options.Open.validate_options(options) do
      options = loader_options(options)
      Vix.Vips.Image.new_from_enum(image_stream, options)
    end
  end

  defp do_open([path], options) do
    if File.exists?(path) do
      vix_open(path, options)
    else
      {:error, Image.Error.wrap(:enoent, operation: :open, path: path)}
    end
  end

  defp do_open([path, _open_options], options) do
    if File.exists?(path) do
      vix_open(path, options)
    else
      {:error, Image.Error.wrap(:enoent, operation: :open, path: path)}
    end
  end

  defp vix_open(path, options) do
    case Vimage.new_from_file(path, options) do
      {:ok, image} -> {:ok, image}
      {:error, reason} -> {:error, Image.Error.wrap(reason, operation: :open, path: path)}
    end
  end

  defp loader_options(options) do
    "[" <> Enum.map_join(options, ",", fn {k, v} -> "#{k}=#{v}" end) <> "]"
  end

  @doc """
  Opens an image file for image processing
  returning an image or raising an exception.

  ### Arguments

  * `image_path_or_stream_or_binary` is the file system path to an image
    file or a `t:File.Stream.t/0` or any `t:Enumerable.t/0`. It
    can also be any binary `.jpg`, `.png`, `.webp` or `.svg` image.

  * `options` is a keyword list of options. The default is
    `[access: :random]` for all images except images
    derived from binary image data.

  ### Options

  The available options depend upon the image type.

  #### All image types

  * `:access` is the file access mode, either `:random`
    or `:sequential`. The default is `:random`.
    When `:sequential`, `Image` (via `Vix`) is able
    to support streaming transformations and optimise
    memory usage more effectively. However `:sequential`
    also means that some operations cannot be completed
    because they would require non-sequential access to
    the image. In these cases, `:random` access is required.

  * `:fail_on` sets the error level at which image
    loading and decoding will stop. The default is `:none`.
    Each error state implies all the states before it such
    that `:error` implies also `:truncated`.

  #### JPEG image options

  * `:shrink` is an integer factor in the range `1..16` by
    which the image is reduced upon loading. This is an
    optimization that can result in improved performance and
    reduced memory usage if the image is being loaded
    with the intent to resize it to smaller dimensions. The
    default value is `1` meaning no shrink-on-load.

  * `:autorotate` is a boolean value indicating if
    the image should be rotated according to the orientation
    data stored in the image metadata. The default is
    `false`.

  #### WEBP options

  * `:scale` will scale the image on load. The value is
    a number greater than `0` and less than or equal
    to `1024` with a default of `1` meaning no scaling
    on load. Numbers less than `1.0` scale the image down
    so that a scale of `0.5` will halve the image size on
    load.

  * `:page` indicates the first page to be loaded. The
    value is in the range `0..100_000` with a default
    value of `0`. This parameter is useful on animated images.

  * `:pages` indicates the number of pages to load.
    The value must be between `-1` and `100_000`. The default
    value is `1`.  A value of `-1` would load all the available
    pages which is useful if you want to keep the animation of
    the input image. The atom `:all` can be used in place of
    `-1` to indicate all pages should be loaded.

  #### TIFF options

  * `:autorotate` is a boolean value indicating if
    the image should be rotated according to the orientation
    data stored in the image metadata. The default is
    `false`.

  * `:page` indicates the first page to be loaded. The
    value is in the range `0..100_000` with a default
    value of `0`. This parameter is useful on animated images.

  * `:pages` indicates the number of pages to load.
    The value must be between `-1` and `100_000`. The default
    value is `1`.  A value of `-1` would load all the available
    pages which is useful if you want to keep the animation of
    the input image. The atom `:all` can be used in place of
    `-1` to indicate all pages should be loaded.

  #### GIF options

  * `:page` indicates the first page to be loaded. The
    value is in the range `0..100_000` with a default
    value of `0`. This parameter is useful on animated images.

  * `:pages` indicates the number of pages to load.
    The value must be between `-1` and `100_000`. The default
    value is `1`.  A value of `-1` would load all the available
    pages which is useful if you want to keep the animation of
    the input image. The atom `:all` can be used in place of
    `-1` to indicate all pages should be loaded.

  #### PNG options

  * There are no PNG-specific image loading
    options.

  ### Returns

  * `image` or

  * raises an exception.

  """
  @doc subject: "Load and save"

  @spec open!(path_or_stream_or_binary :: image_data(), options :: Open.image_open_options()) ::
          Vimage.t() | no_return()
  def open!(path_or_stream_or_binary, options \\ []) do
    case open(path_or_stream_or_binary, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, {reason, path_or_stream_or_binary}
    end
  end

  @doc """
  Returns an image created from an SVG string.

  ### Arguments

  * `svg` is an SVG string.

  * `options` is a keyword list of options.

  ### Options

  * `:access` is the file access mode, either `:random`
    or `:sequential`. The default is `:random`.
    When `:sequential`, `Image` (via `Vix`) is able
    to support streaming transformations and optimise
    memory usage more effectively. However `:sequential`
    also means that some operations cannot be completed
    because they would require non-sequential access to
    the image. In these cases, `:random` access is required.

  * `:fail_on` sets the error level at which image
    loading and decoding will stop. The default is `:none`.
    Each error state implies all the states before it such
    that `:error` implies also `:truncated`.

  * `:scale` will scale the image on load. The value is
    a number greater than `0` and less than or equal
    to `1024` with a default of `1.0` meaning no scaling
    on load. Numbers less than `1.0` scale the image down
    so that a scale of `0.5` will halve the image size on
    load.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`

  """
  @doc subject: "Load and save", since: "0.32.0"

  @spec from_svg(svg :: binary(), options :: Open.image_open_options()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def from_svg(svg, options \\ []) when is_binary(svg) do
    case Operation.svgload_buffer(svg, options) do
      {:ok, {image, _flags}} -> {:ok, image}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns an image created from an SVG string or
  raises an exception.

  ### Arguments

  * `svg` is an SVG string.

  * `options` is a keyword list of options.

  ### Options

  * `:access` is the file access mode, either `:random`
    or `:sequential`. The default is `:random`.
    When `:sequential`, `Image` (via `Vix`) is able
    to support streaming transformations and optimise
    memory usage more effectively. However `:sequential`
    also means that some operations cannot be completed
    because they would require non-sequential access to
    the image. In these cases, `:random` access is required.

  * `:fail_on` sets the error level at which image
    loading and decoding will stop. The default is `:none`.
    Each error state implies all the states before it such
    that `:error` implies also `:truncated`.

  * `:scale` will scale the image on load. The value is
    a number greater than `0` and less than or equal
    to `1024` with a default of `1.0` meaning no scaling
    on load. Numbers less than `1.0` scale the image down
    so that a scale of `0.5` will halve the image size on
    load.

  ### Returns

  * `image` or

  * raises an exception.

  """
  @doc subject: "Load and save", since: "0.32.0"

  @spec from_svg!(svg :: binary(), options :: Open.image_open_options()) ::
          Vimage.t() | no_return()

  def from_svg!(svg, options \\ []) when is_binary(svg) do
    case from_svg(svg, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Returns an image created from an in-memory binary representation
  of an image.

  The binary must be a complete formatted image such as that
  returned from `File.read!/1`.

  ### Arguments

  * `binary` is a binary representation of a formatted image
    including `.jpg`, `.png`, `.webp` and `.svg` binary data.

  * `options` is a keyword list of options. See `Image.open/2`
    for the list of applicable options.

  > #### Note {: .info}
  >
  > This function is typically *not* the best way to open
  > an image. It requires that the entire image
  > is already loaded into memory which, for most use cases,
  > doest not scale well and consumes far more memory than
  > necessary.
  >
  > Since `libvips` is a streaming on-demand architecture,
  > it is most likely that a simple `Image.open/2` call will
  > deliver better resource utilitsation and equal or better
  > performance.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`

  """
  @doc subject: "Load and save", since: "0.7.0"

  @spec from_binary(binary :: binary(), options :: Open.image_open_options()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def from_binary(binary, options \\ []) when is_binary(binary) do
    with {:ok, options} <- Options.Open.validate_options(options) do
      options = Keyword.delete(options, :access)
      Vimage.new_from_buffer(binary, options)
    end
  end

  @doc """
  Returns an image created from an in-memory binary representation
  of an image or raises an exception.

  * `binary` is a binary representation of a formatted image
    including `.jpg`, `.png`, `.webp` and `.svg` binary data.

  ### Arguments

  * `binary` is a binary representation of a formatted image

  * `options` is a keyword list of options. See `Image.open/2`
    for the list of applicable options.

  ### Returns

  * `image` or

  * raises an exception.

  """
  @doc subject: "Load and save", since: "0.25.0"

  @spec from_binary!(binary :: binary(), options :: Open.image_open_options()) ::
          Vimage.t() | no_return()

  def from_binary!(binary, options \\ []) when is_binary(binary) do
    case from_binary(binary, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  if match?({:module, _module}, Code.ensure_compiled(Kino)) do
    @doc """
    Returns an image from a [Kino](https://hex.pm/packages/kino) image
    input.

    ### Arguments

    * `image` is a a map returned from `Kino.Input.read(image)`
      via a `Kino.Input.image/1` input field. The data will have
      the following fields:

      * `:file_ref` which contains a file reference to the image. It can be dereferenced
        into a path with `Kino.Input.file_path/1`
      * `:width` which is the width of the image in pixels
      * `:height` which is the height of the image in pixels
      * `:format` which is the image band format which must be `:rgb` or `:png`.

    * `options` is a keyword list of options that is passed to `Image.open/2`
      in the case of a `:png` image.

    ### Notes

    * This function is only defined when the optional dependency
      `:kino` (v0.11.0 or later) is configured in `mix.exs`.

    * For image type of `:rgb`, the image is required to contain raw pixel data
      that is in unsigned 8-bit rgb format.

    * For image type of `:png`, the image can by any format and it will be
      opened with `Image.open/2`. Any options are passed to `Image.open/2`.

    ### Returns

    * `{:ok, image}` or

    * `{:error, reason}`

    """
    @doc since: "0.27.0"

    @spec from_kino(image :: kino_image(), options :: Keyword.t()) ::
            {:ok, Vimage.t()} | {:error, error()}

    @kino_bands 3
    @kino_format :VIPS_FORMAT_UCHAR

    def from_kino(kino_image, options \\ [])

    def from_kino(%{file_ref: ref, width: width, height: height, format: :rgb}, _options) do
      file_path = Kino.Input.file_path(ref)

      with {:ok, binary} <- File.read(file_path) do
        Vix.Vips.Image.new_from_binary(binary, width, height, @kino_bands, @kino_format)
      end
    end

    def from_kino(%{file_ref: ref, format: :png}, options) do
      file_path = Kino.Input.file_path(ref)
      open(file_path, options)
    end

    @doc """
    Returns an image from a [Kino](https://hex.pm/packages/kino) image
    input or raises an exception.

    ### Arguments

    * `image` is a a map returned from `Kino.Input.read(image)`
      via a `Kino.Input.image/1` input field. The data will have
      the following fields:

      * `:file_ref` which contains a file reference to the image. It can be dereferenced
        into a path with `Kino.Input.file_path/1`
      * `:width` which is the width of the image in pixels
      * `:height` which is the height of the image in pixels
      * `:format` which is the image band format which must be `:rgb` or `:png`.

    * `options` is a keyword list of options

    ### Options

    * `options` is a keyword list of options that is passed to `Image.open/2`
      in the case of a `:png` image.

    ### Notes

    * This function is only defined when the optional dependency
      `:kino` (v0.11.0 or later) is configured in `mix.exs`.

    * For image type of `:rgb`, the image is required to contain raw pixel data
      that is in unsigned 8-bit rgb format.

    * For image type of `:png`, the image can by any format and it will be
      opened with `Image.open/2`. Any options are passed to `Image.open/2`.

    ### Returns

    * `image` or

    * raises an exception.

    """
    @doc since: "0.27.0"

    @spec from_kino!(image :: kino_image(), options :: Keyword.t()) ::
            Vimage.t() | no_return()

    def from_kino!(%{file_ref: _ref, format: format} = image, options \\ [])
        when format in [:rgb, :png] do
      case from_kino(image, options) do
        {:ok, image} -> image
        {:error, reason} -> raise Image.Error, reason
      end
    end
  end

  @doc """
  Write an image to a file, a stream, an enumerable or
  to memory.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `image_path` is the file system path to an image
    file. It may also be a stream created with
    `File.stream!/3` or with `Stream.resource/3`, a
    `t:Plug.Conn.t/0` if `Plug` is configured or lastly,
    it can also be `:memory` in which case the image is
    written to a binary. Currently,`:memory` supports only
    TIFF, JPEG and PNG formats.

  * `options` is a keyword list of options. The default is
    `[]`.

  ### Options

  The available options depends on the type of image
  file being opened.

  #### All image types

  * `:strip_metadata` is a boolean indicating if all metadata
    is to be stripped from the image. The default is `false`.

  * `:background` is the background value to be used
    for any transparent areas of the image. Jpeg does
    not support alpha bands so a color value must be
    assigned.

  * `:quality` which influences image compression and
    is a integer in the range `1..100`. The default for
    most image formats is `75`. For HEIF files the default
    is `50`.For PNG files the `:quality` option is ignored.

  * `:lossy` is a boolean. On WebP and AVIF, `false`
    forces a lossless wire format (`lossless: true`); `true`
    keeps the default lossy encoder. On PNG, `true` enables
    palette quantisation (lossy 8-bit PNG); `false` is the
    default unquantised mode. JPEG, GIF, TIFF, and HEIF do
    not accept this option.

  * `:chroma_subsampling` selects the chroma layout for
    encoders that support sub-sampling. One of `:auto`
    (default), `:on` (4:2:0 — smaller files, fine for
    photographs), or `:off` (4:4:4 — full chroma resolution,
    needed for sharp text or vibrant solid colours).
    Supported on JPEG and AVIF.

  ### Streaming images and :memory images

  * `:suffix` must be specified so that the image is written
    in the correct format. For example: `suffix: ".jpg"`.

  #### JPEG images

  * `:progressive` is a boolean indicating if the image
    should be interleaved rather than baseline. Progressive
    has the advantage of perceived time for the initial
    image load and the cost of multiple decoding passes on
    the client. For many applications `:progressive` is
    to be preferred but validation of this assumption for
    specific use cases is required.

  * `:minimize_file_size` is a boolean indicating whether
    to apply a number of techniques to minimise the file
    size of the jpeg file at the cost of additional time to
    save the image. All metadata will also be removed.

  * `:icc_profile` indicates the icc profile to be attached
    to the output image. The value may be an inbuilt profile
    (`:none`, `:srgb`, `:cmyk`, `:p3`), the name of an icc
    profile in the systems profile directory or a full path
    to an icc profile file. The default is to use the icc
    profile of the input image if there is one.

  #### PNG images

  * `:progressive` which has the same meaning and values
      as for JPEG images.

  * `:minimize_file_size` is a boolean indicating whether
    to apply a number of techniques to minimise the file
    size of the `png` file at the cost of additional time to
    save the image. All metadata will also be removed.

  * `:compression`  is the compression factor which is an
    integer in the range `1..9`. The default is `6`.

  * `:effort` is an integer to adjust the level of CPU
    effort to reduce the file size. The value must be in the
    range `1..10`, the default is `7`.

  * `:icc_profile` indicates the icc profile to be attached
    to the output image. The value may be an inbuilt profile
    (`:none`, `:srgb`, `:cmyk`, `:p3`), the name of an icc
    profile in the systems profile directory or a full path
    to an icc profile file. The default is to use the icc
    profile of the input image if there is one.

  #### WEBP images

  * `:minimize_file_size` is a boolean which is most useful
    on animated `WebP`. It enables mixed encoding and optimise
    the file for minimum size at the cost of additional time
    to save the image. All metadata will also be removed.
    Using this parameter on a non-animated `webp` file will
    only remove the metadata as `:strip_metadata` would do.

  * `:effort` is an integer to adjust the level of CPU
    effort to reduce the file size.
    The value must be in the range `1..10`, the default
    is `7`.

  * `:icc_profile` indicates the icc profile to be attached
    to the output image. The value may be an inbuilt profile
    (`:none`, `:srgb`, `:cmyk`, `:p3`), the name of an icc
    profile in the systems profile directory or a full path
    to an icc profile file. The default is to use the icc
    profile of the input image if there is one.

  #### GIF images

  * `:interframe_maxerror` Maximum inter-frame error for transparency.
    The value must be in the range `0..32`.
    The default is `0`.
    By increasing this value, the encoder will try to take advantage
    from temporal redundancy between neighboring frames by enabling
    higher compression rates.

  * `:effort` is an integer to adjust the level of CPU
    effort to reduce the file size.
    The value must be in the range `1..10`, the default
    is `7`.

  #### HEIF/HEIC and AVIF images

  * `:compression` is the compression strategy to
    be applied. The allowable values are `:hevc`,
    and `:av1` for HEIF/HEIC files, and `:avc`, `:av1`
    and `:jpeg` for AVIF files.

  * `:effort` is an integer to adjust the level of CPU
    effort to reduce the file size.
    The value can be in the range `1..10`, the default is
    `5`.

  * `:minimize_file_size` is a boolean indicating whether
    to apply a number of techniques to minimise the file
    size of the `heif` file at the cost of additional time to
    save the image. All metadata will also be removed.

  ### TIFF options

  * `:pyramid` is a boolean indicating whether to write the
    image as an
    [image pyramid](https://en.wikipedia.org/wiki/Pyramid_(image_processing)).

  ### Merging image type options

  Options can also be grouped under an option key
  for each known image type. For example:

      Image.write(image, image_path, minimize_file_size: true,
        png: [compress: 60, lossy: true],
        jpg: [quality: 70],
        webp: [quality: 5])

  When validating options, the options applicable to the
  image type of `image_path` are merged into the rest of
  the supplied options.

  The valid image type option keys are `:jpg`, `.png`,
  `:gif`, `:tif`, `:webp`, `:heif` and `:avif`.

  This makes it easier to define a general purpose image
  processing pipeline that can still apply specific
  options when writing the image file.

  ### Returns

  * `{:ok, image}`, or `{:ok, binary}` if the destination is
    `:memory`) or `{:ok, conn}` if the destination is a `t:Plug.Connt.t/0` or

  * `{:error, reason}`

  """
  if match?({:module, _module}, Code.ensure_compiled(Plug)) do
    @spec write(
            image :: Vimage.t(),
            image_path :: Path.t() | Plug.Conn.t() | Enumerable.t() | File.Stream.t() | :memory,
            options :: Options.Write.image_write_options()
          ) ::
            {:ok, Vimage.t()} | {:ok, binary()} | {:ok, Plug.Conn.t()} | {:error, error()}
  else
    @spec write(
            image :: Vimage.t(),
            image_path :: Path.t() | Enumerable.t() | File.Stream.t() | :memory,
            options :: Options.Write.image_write_options()
          ) ::
            {:ok, Vimage.t()} | {:ok, binary()} | {:error, error()}
  end

  @doc subject: "Load and save"
  def write(image, image_path, options \\ [])

  def write(%Vimage{} = image, image_path, options) when is_binary(image_path) do
    with {:ok, options} <- Options.Write.validate_options(image_path, options) do
      image_path
      |> String.split("[", parts: 2)
      |> write_path(image, options)
    end
  end

  if match?({:module, _module}, Code.ensure_compiled(Plug)) do
    def write(%Vimage{} = image, %Plug.Conn{} = conn, options) do
      with {:ok, options} <- Options.Write.validate_options(options, :require_suffix) do
        {suffix, options} = Keyword.pop(options, :suffix)
        options = suffix <> loader_options(options)

        result =
          image
          |> Vimage.write_to_stream(options)
          |> Enum.reduce_while(conn, fn chunk, conn ->
            case Plug.Conn.chunk(conn, chunk) do
              {:ok, conn} ->
                {:cont, conn}

              {:error, :closed} = error ->
                {:halt, error}
            end
          end)

        with %Plug.Conn{} <- result do
          {:ok, result}
        end
      end
    end
  end

  def write(%Vimage{} = image, %module{} = stream, options)
      when module in [File.Stream, Stream] do
    with {:ok, options} <- Options.Write.validate_options(options, :require_suffix) do
      case write_stream(image, stream, options) do
        :ok -> {:ok, image}
        other -> other
      end
    end
  end

  def write(%Vimage{} = image, :memory, options) do
    with {:ok, options} <- Options.Write.validate_options(options, :require_suffix) do
      {suffix, options} = Keyword.pop(options, :suffix)
      options = suffix <> loader_options(options)
      Vimage.write_to_buffer(image, options)
    end
  end

  defp write_stream(image, stream, options) do
    {suffix, options} = Keyword.pop(options, :suffix)
    options = suffix <> loader_options(options)

    image
    |> Vimage.write_to_stream(options)
    |> Stream.into(stream)
    |> Stream.run()
  rescue
    e in Vix.Vips.Image.Error ->
      {:error, e.message}
  end

  defp write_path([image_path], image, options) do
    case Vimage.write_to_file(image, image_path, options) do
      :ok -> {:ok, image}
      other -> other
    end
  end

  defp write_path([image_path, _open_options], image, options) do
    case Vimage.write_to_file(image, image_path, options) do
      :ok -> {:ok, image}
      other -> other
    end
  end

  if Code.ensure_loaded?(Req) do
    @default_req_timeout 5000

    @doc """
    Opens an image as a stream from a URL that will be retrieved
    by [Req](https://github.com/wojtekmach/req) request.

    The URL is retrieved by `Req.get!(url, into: :self)` which is then
    wrapped in a `Stream.resource/3` and opened as a streaming image.

    ### Arguments

    * `url` is any URL representing an image or a t:Req.Request.t/1

    * `options` is a keyword list of options.

    ### Options

    * `:timeout` is an integer number of milliseconds upon which
      the next chunk of the image stream is waited. If the timeout is
      exceeded then an error is returned. The default is #{@default_req_timeout}
      milliseconds.

    ### Returns

    * `{:ok, image}` or

    * `{:error reason}`

    ### Notes

    * Due to the nature of the interaction between Req and Vix, error
      responses from the embedded `Reg.get/2` are swallowed and a generic
      `{:error, %Image.Error{message: "Failed to find loader for the source", reason: "Failed to find loader for the source"}}` may be returned instead.

    ### Example

        url = "https://files.amoi.no/dog.webp"
        Image.from_req_stream(url)
        {:ok, %Vix.Vips.Image{ref: #Reference<0.3575018002.2188509222.143025>}}

    """
    @doc since: "0.61.0"

    @spec from_req_stream(url_or_request :: binary() | Req.Request.t()) ::
            {:ok, image :: %Vimage{}} | {:error, error()}

    def from_req_stream(url_or_request, options \\ []) do
      timeout = Keyword.get(options, :timeout, @default_req_timeout)

      body_stream =
        Stream.resource(
          fn ->
            case Req.get(url_or_request, into: :self) do
              {:ok, %Req.Response{status: 200} = resp} -> resp
              other -> other
            end
          end,
          fn
            %Req.Response{status: 200} = resp ->
              case Req.parse_message(resp, get_req_message(timeout)) do
                {:ok, chunks} ->
                  data_chunks =
                    chunks
                    |> Enum.filter(&match?({:data, _}, &1))
                    |> Enum.map(fn {:data, binary} -> binary end)

                  if Enum.any?(chunks, &(&1 == :done)) do
                    {data_chunks, {:done, resp}}
                  else
                    {data_chunks, resp}
                  end
              end

            {:done, resp} ->
              {:halt, resp}

            resp ->
              {:halt, resp}
          end,
          fn
            %Req.Response{} = resp ->
              Req.cancel_async_response(resp)

            other ->
              other
          end
        )

      Vix.Vips.Image.new_from_enum(body_stream)
    end

    defp get_req_message(timeout) do
      receive do
        message -> message
      after
        timeout ->
          {:error, :timed_out}
      end
    end
  end

  @doc """
  Write an image to a file, a stream, an enumerable or
  to memory returning the image or raising an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `image_path` is the file system path to an image
    file. It may also be a stream created with
    `File.stream!/3` or with `Stream.resource/3`. Lastly,
    it can also be `:memory` in which case the image is
    written to a memory buffer.

  * `options` is a keyword list of options.
    See `Image.write/2`.

  ### Returns

  * `image` (or a binary if the destination is `:memory`) or

  * raises an exception.

  """
  @doc subject: "Load and save"

  if match?({:module, _module}, Code.ensure_compiled(Plug)) do
    @spec write!(
            image :: Vimage.t(),
            image_path :: Path.t() | Plug.Conn.t() | Enumerable.t() | File.Stream.t() | :memory,
            options :: Options.Write.image_write_options()
          ) ::
            Vimage.t() | binary() | no_return()
  else
    @spec write!(
            image :: Vimage.t(),
            image_path :: Path.t() | Enumerable.t() | File.Stream.t() | :memory,
            options :: Options.Write.image_write_options()
          ) ::
            Vimage.t() | binary() | no_return()
  end

  def write!(%Vimage{} = image, image_path, options \\ []) do
    case write(image, image_path, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, {reason, image_path}
    end
  end

  @doc """
  Convert an image into an enumerable
  stream.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:buffer_size` is the size in bytes for
    each chunk in the stream being written.
    Some services, like AWS S3, require a minimum
    5 MiB per chunk to be delivered and this option
    can be used to satisfy that requirement.

  For additional options see `Image.write/3`.

  ### Returns

  * An `t:Enumerable.t/0` suitable for
    streaming to an external service such as
    S3, Minio or any other enumerable consumer.

  > #### S3 and Buffer Size {: .info}
  > You may get an error from S3 if you do not specify a buffer size.
  >
  > ```text
  > EntityTooSmall: Your proposed upload is smaller than the minimum allowed object size.
  > ```
  >
  > Since AWS S3 requires multipart uploads to be 5MiB per chunk, we specify
  > the `:buffer_size` option to `Image.stream!/2`.

  ### Example

  In this example an image is resized
  and then streamed into AWS S3:

      "some/image.jpg"
      |> Image.thumbnail!(200)
      |> Image.stream!(suffix: ".jpg", buffer_size: 5_242_880)
      |> ExAws.S3.upload("images", "some_object_name.jpg")
      |> ExAws.request()

  """
  @doc subject: "Load and save"

  @spec stream!(Vimage.t(), options :: Options.Write.image_write_options()) :: Enumerable.t()
  def stream!(%Vimage{} = image, options \\ []) do
    with {:ok, options} <- Options.Write.validate_options(options, :require_suffix) do
      {suffix, options} = Keyword.pop(options, :suffix)
      {buffer_size, options} = Keyword.pop(options, :buffer_size, :unbuffered)
      options = suffix <> loader_options(options)

      stream = Vimage.write_to_stream(image, options)

      if buffer_size == :unbuffered || buffer_size == 0 do
        stream
      else
        buffer!(stream, buffer_size)
      end
    else
      {:error, reason} -> raise Image.Error, reason
    end
  end

  # Rebuffers a stream into chunks of a minimum size.
  # This is useful when streaming to AWS S3 which requires
  # a minimum 5 MiB chunk size for multi-part uploads.

  defp buffer!(stream, buffer_size) do
    chunker = fn bin, acc ->
      acc_size = IO.iodata_length(acc)

      if IO.iodata_length(bin) + acc_size >= buffer_size do
        size = buffer_size - acc_size
        <<chunk::binary-size(^size), rest::binary>> = bin
        {:cont, IO.iodata_to_binary([acc, chunk]), [rest]}
      else
        {:cont, [acc, bin]}
      end
    end

    final = fn
      [] -> {:cont, []}
      acc -> {:cont, IO.iodata_to_binary(acc), []}
    end

    Stream.chunk_while(stream, [], chunker, final)
  end

  @doc """
  Scans the `condition_image` cond and uses it to select
  pixels from either the `if_image` or the `else_image`.

  Non-zero means copy a pixel from `if_image`, `0` means
  copy a pixel from `else_image`.

  ### Arguments

  * `condition_image` is any image. Typically it is an image
    formed by the relation operations such as `Image.Math.greater_than/2`.

  * `if_image_or_color` is either an `t:Vimage.t/0` or
    a `t:Image.Pixel.t/0`. If a color is provided then
    an image is constructed with the same shape as `condition_image`
    filled with the provided color.

  * `else_image_or_color` is either an `t:Vimage.t/0` or
    a `t:Image.Pixel.t/0`. If a color is provided then
    an image is constructed with the same shape as `condition_image`
    filled with the provided color.

  * `options` is a keyword list of options.

  ### Options

  * `:blend` is a boolean indicating if a the operation should blend
    smoothly between `then` and `else` images. The default is `false`.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`.

  ### Notes

  Any image can have either 1 band or `n` bands, where `n`
  is the same for all the non-1-band images. Single band
  images are then effectively copied to make n-band images.

  Images `if_image` and `else_image` are cast up to the
  smallest common format. The `condition_image` is cast to
  `{:u, 8}`.

  If the images differ in size, the smaller images are
  enlarged to match the largest by adding zero pixels along
  the bottom and right.

  The output image is calculated pixel by pixel as:

      (condition_image / 255) * if_image + (1 - condition_image / 255) * else_image

  """
  @doc subject: "Operation", since: "0.13.0"

  @spec if_then_else(
          condition_image :: Vimage.t(),
          if_image :: image_or_color(),
          else_image :: image_or_color(),
          options :: Keyword.t()
        ) ::
          {:ok, Vimage.t()} | {:error, error()}

  def if_then_else(condition_image, if_image_or_color, else_image_or_color, options \\ [])

  def if_then_else(
        %Vimage{} = condition_image,
        %Vimage{} = if_image,
        %Vimage{} = else_image,
        options
      ) do
    blend = Keyword.get(options, :blend, false)
    Operation.ifthenelse(condition_image, if_image, else_image, blend: blend)
  end

  def if_then_else(%Vimage{} = condition_image, if_color, else_image_or_color, options)
      when is_pixel(if_color) do
    # Encode the colour against the other branch if it is an image
    # (so that the synthesised if_image has the right shape and
    # interpretation); otherwise fall back to the condition image.
    target =
      case else_image_or_color do
        %Vimage{} = vimage -> vimage
        _ -> condition_image
      end

    with {:ok, if_color} <- Pixel.to_pixel(target, if_color),
         {:ok, if_image} <- new(target, color: if_color) do
      if_then_else(condition_image, if_image, else_image_or_color, options)
    end
  end

  def if_then_else(%Vimage{} = condition_image, if_image_or_color, else_color, options)
      when is_pixel(else_color) do
    target =
      case if_image_or_color do
        %Vimage{} = vimage -> vimage
        _ -> condition_image
      end

    with {:ok, else_color} <- Pixel.to_pixel(target, else_color),
         {:ok, else_image} <- new(target, color: else_color) do
      if_then_else(condition_image, if_image_or_color, else_image, options)
    end
  end

  @doc """
  Scans the condition image cond and uses it to select
  pixels from either the `if_image` or the `else_image`.
  Raise an exception on error.

  Non-zero means copy a pixel from `if_image`, `0` means
  copy a pixel from `else_image`.

  ### Arguments

  * `condition_image` is any image. Typically it is an image
    formed by the relation operations such as `Image.Math.greater_than/2`.

  * `if_image_or_color` is either an `t:Vimage.t/0` or
    a `t:Image.Pixel.t/0`. If a color is provided then
    an image is constructed with the same shape as `condition_image`
    filled with the provided color.

  * `else_image_or_color` is either an `t:Vimage.t/0` or
    a `t:Image.Pixel.t/0`. If a color is provided then
    an image is constructed with the same shape as `condition_image`
    filled with the provided color.

  ### Returns

  * `image` or

  * raises an exception.

  ### Notes

  Any image can have either 1 band or `n` bands, where `n`
  is the same for all the non-1-band images. Single band
  images are then effectively copied to make n-band images.

  Images `if_image` and `else_image` are cast up to the
  smallest common format. The `condition_image` is cast to
  `{:u, 8}`.

  If the images differ in size, the smaller images are
  enlarged to match the largest by adding zero pixels along
  the bottom and right.

  The output image is calculated pixel by pixel as:

      (condition_image / 255) * if_image + (1 - condition_image / 255) *`else_image`

  """
  @doc subject: "Operation", since: "0.30.0"

  @spec if_then_else!(
          condition_image :: Vimage.t(),
          if_image :: image_or_color(),
          else_image :: image_or_color()
        ) ::
          Vimage.t() | no_return()

  def if_then_else!(%Vimage{} = condition_image, if_color, else_image_or_color) do
    case if_then_else(condition_image, if_color, else_image_or_color) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Automatically determine the chroma key
  color of an image.

  The top left 10x10 pixels of the flattened
  image are averaged to produce a color sample
  that can then be used by `Image.chroma_mask/2`,
  `Image.chroma_key/2` and `Image.trim/2`.

  ### Argument

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * An RGB color as a three-element list of
    integers.

  """

  # Original python code
  #   this will be an RGB triple eg. [10, 10, 240]
  #   key_colour = [i.avg() for i in foreground.crop(0, 0, 10, 10).bandsplit()]

  @doc subject: "Operation", since: "0.13.0"

  @spec chroma_color(image :: Vimage.t()) :: Pixel.t()
  def chroma_color(%Vimage{} = image) do
    with {:ok, flattened} <- flatten(image),
         {:ok, cropped} <- Image.crop(flattened, 0, 0, 10, 10) do
      average(cropped)
    end
  end

  defp max_band_index(image) do
    Image.bands(image) - 1
  end

  defp band_range(image) do
    0..max_band_index(image)
  end

  @doc """
  Return a chroma-based masked image.

  Chroma masking is the process of removing a background color
  from an image and returning the remaining content as an alpha
  mask.

  The masking is done in the LCh color space since it's perceptually
  more uniform.  The returned mask in reverted to the interpretation
  of the original image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  There are two masking strategies available: the
  thresholding strategy (default) and the color
  range strategy.

  #### Threshold strategy

  * `:color` is an RGB color which represents the the
    chroma key to be masked. The color can be an
    integer between `0..255`, a three-element list of
    integers representing an RGB color or an atom
    representing a CSS color name. The default is
    `:auto` in which the average of the top left `10x10`
    pixels of the image is used.

  * `:threshold` is a positive integer to indicate the
    threshold around `:color` when calculating the mask.
    The default is `20`.

  #### Color range strategy

  * `:greater_than` is an RGB color which represents the upper
     end of the color range to be masked. The color can be an
     integer between `0..255`, a three-element list of
     integers representing an RGB color or an atom
     representing a CSS color name.

  * `:less_than` is an RGB color which represents the lower
     end of the color range to be masked. The color can be an
     integer between `0..255`, a three-element list of
     integers representing an RGB color or an atom
     representing a CSS color name.

  """

  # Original python code for thresholding from: https://github.com/libvips/libvips/discussions/3097#discussioncomment-3892994
  #    threshold = 20
  #    mask = ((foreground - key_colour) ** 2).bandmean() > (3 * threshold ** 2)

  @doc subject: "Mask", since: "0.13.0"

  @spec chroma_mask(image :: Vimage.t(), options :: ChromaKey.chroma_key_options() | map()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def chroma_mask(image, options \\ [])

  def chroma_mask(%Vimage{} = image, options) when is_list(options) do
    with {:ok, options} <- Options.ChromaKey.validate_options(image, options) do
      chroma_mask(image, options)
    end
  end

  def chroma_mask(%Vimage{} = image, %{color: color, threshold: threshold}) do
    alias Image.Math

    color = maybe_calculate_color(image, color)

    image
    |> Math.subtract!(color)
    |> Math.pow!(2)
    |> Operation.bandmean!()
    |> Math.greater_than!(3 * threshold ** 2)
    |> wrap(:ok)
  end

  def chroma_mask(%Vimage{} = image, %{greater_than: greater_than, less_than: less_than}) do
    alias Image.Math

    with {:ok, greater} <- Math.greater_than(image, greater_than),
         {:ok, less} = Math.less_than(image, less_than),
         {:ok, color_mask} = Math.boolean_and(greater, less),
         {:ok, mask} = Vix.Vips.Operation.bandbool(color_mask, :VIPS_OPERATION_BOOLEAN_AND) do
      Vix.Vips.Operation.invert(mask)
    end
  end

  defp maybe_calculate_color(image, :auto), do: chroma_color(image)
  defp maybe_calculate_color(_image, color), do: color

  @doc """
  Return a chroma-based masked image or raises
  an exception.

  Chroma masking is the process of removing a background color
  from an image and returning the remaining content as an alpha
  mask.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  There are two masking strategies available: the
  thresholding strategy (default) and the color
  range strategy.

  #### Threshold strategy

  * `:color` is an RGB color which represents the the
    chroma key to be masked. The color can be an
    integer between `0..255`, a three-element list of
    integers representing an RGB color or an atom
    representing a CSS color name. The default is
    `:auto` in which the average of the top left `10x10`
    pixels of the image is used.

  * `:threshold` is a positive integer to indicate the
    threshold around `:color` when calculating the mask.
    The default is `20`.

  #### Color range strategy

  * `:greater_than` is an RGB color which represents the upper
     end of the color range to be masked. The color can be an
     integer between `0..255`, a three-element list of
     integers representing an RGB color or an atom
     representing a CSS color name.

   * `:less_than` is an RGB color which represents the lower
     end of the color range to be masked. The color can be an
     integer between `0..255`, a three-element list of
     integers representing an RGB color or an atom
     representing a CSS color name.

  """
  @doc subject: "Mask", since: "0.13.0"

  @spec chroma_mask!(image :: Vimage.t(), options :: ChromaKey.chroma_key_options()) ::
          Vimage.t() | no_return()

  def chroma_mask!(%Vimage{} = image, options \\ []) do
    case chroma_mask(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Chroma key an image.

  Chroma keying is the process of removing a background color
  from an image resulting in a foreground image that may
  be composited over another image.

  If the image already has an alpha band then the
  image is flattened before adding the image mask
  as a new alpha band.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  There are two masking strategies available: the
  thresholding strategy (default) and the color
  range strategy.

  #### Threshold strategy

  * `:color` is an RGB color which represents the the
    chroma key to be masked. The color can be an
    integer between `0..255`, a three-element list of
    integers representing an RGB color or an atom
    representing a CSS color name. The default is
    `:auto` in which the average of the top left `10x10`
    pixels of the image is used.

  * `:threshold` is a positive integer to indicate the
    threshold around `:color` when calculating the mask.
    The default is `20`.

  #### Color range strategy

  * `:greater_than` is an RGB color which represents the upper
     end of the color range to be masked. The color can be an
     integer between `0..255`, a three-element list of
     integers representing an RGB color or an atom
     representing a CSS color name.

  *  `:less_than` is an RGB color which represents the lower
     end of the color range to be masked. The color can be an
     integer between `0..255`, a three-element list of
     integers representing an RGB color or an atom
     representing a CSS color name.

  """
  @doc subject: "Operation", since: "0.13.0"

  @spec chroma_key(image :: Vimage.t(), options :: ChromaKey.chroma_key_options()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def chroma_key(%Vimage{} = image, options \\ []) do
    with {:ok, options} <- Options.ChromaKey.validate_options(image, options),
         {:ok, mask} <- chroma_mask(image, options),
         {:ok, flattened} <- flatten(image) do
      Operation.bandjoin([flattened, mask])
    end
  end

  @doc """
  Chroma key an image and return an image or
  raise an exception.

  Chroma keying is the process of removing a background color
  from an image resulting in a foreground image that may
  be composited over another image.

  If the image already has an alpha band then the
  image is flattened before adding the image mask
  as a new alpha band.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  There are two masking strategies available: the
  thresholding strategy (default) and the color
  range strategy.

  #### Threshold strategy

  * `:color` is an RGB color which represents the the
    chroma key to be masked. The color can be an
    integer between `0..255`, a three-element list of
    integers representing an RGB color or an atom
    representing a CSS color name. The default is
    `:auto` in which the average of the top left `10x10`
    pixels of the image is used.

  * `:threshold` is a positive integer to indicate the
    threshold around `:color` when calculating the mask.
    The default is `20`.

  #### Color range strategy

  * `:greater_than` is an RGB color which represents the upper
     end of the color range to be masked. The color can be an
     integer between `0..255`, a three-element list of
     integers representing an RGB color or an atom
     representing a CSS color name.

  *  `:less_than` is an RGB color which represents the lower
     end of the color range to be masked. The color can be an
     integer between `0..255`, a three-element list of
     integers representing an RGB color or an atom
     representing a CSS color name.

  """
  @doc subject: "Operation", since: "0.13.0"

  @spec chroma_key!(image :: Vimage.t(), options :: ChromaKey.chroma_key_options()) ::
          Vimage.t() | no_return()

  def chroma_key!(%Vimage{} = image, options \\ []) do
    case chroma_key(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Applies a gaussian blur to an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:sigma` is the `float` size of the mask
    to use. A larger number makes the image more
    blurry. A range between `1.0` and `10.0`
    is normally appropriate. The default is
    `#{@default_blur_sigma}`.

  * `:min_amplitude` is a `float` that determines
    the accuracy of the mask. The default is `0.2`.
    A smaller number will generate a larger, more
    accurate mask,

  ### Returns

  * `{:ok, blurred_image}` or

  * `{:error reason}`

  """
  @doc subject: "Operation", since: "0.13.0"

  @spec blur(image :: Vimage.t(), options :: Options.Blur.blur_options()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def blur(%Vimage{} = image, options \\ []) do
    with {:ok, options} <- Options.Blur.validate_options(options) do
      Operation.gaussblur(image, options.sigma, "min-ampl": options.min_amplitude)
    end
  end

  @doc """
  Applies a gaussian blur to an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:sigma` is the `float` size of the mask
    to use. A larger number makes the image more
    blurry. A range between `1.0` and `10.0`
    is normally appropriate. The default is
    `#{@default_blur_sigma}`.

  * `:min_amplitude` is a `float` that determines
    the accuracy of the mask. The default is `0.2`.
    A smaller number will generate a larger, more
    accurate mask,

  ### Returns

  * `blurred_image` or

  * raises an exception.

  """
  @doc subject: "Operation", since: "0.13.0"

  @spec blur!(image :: Vimage.t(), options :: Options.Blur.blur_options()) ::
          Vimage.t() | no_return()

  def blur!(%Vimage{} = image, options \\ []) do
    case blur(image, options) do
      {:ok, blurred_image} -> blurred_image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Sharpens an image.

  Selectively sharpens the `L` channel of a LAB image. `image`
  is converted to `:labs` for sharpening and the converted back
  to its original interpretation.

  The operation performs a gaussian blur and subtracts from `image` to generate a
  high-frequency signal. This signal is passed through a lookup table formed
  from the five parameters and then added back to `image`.

  The lookup table is formed like this:

  ```
                      ^
                   y2 |          -----------
                      |         /
                      |        / slope m2
                      |    .../
              -x1     | ...   |
  -------------------...---------------------->
              |   ... |      x1
              |... slope m1
              /       |
             / m2     |
            /         |
           /          |
          /           |
         /            |
  ______/             | -y3
                      |
  ```

  Where:

  * `m1` is `:flat_amount`
  * `m2` is `:jagged_amount`
  * `x1` is `:threshold`
  * `y2` is `:max_brightening`
  * `y3` is `:max_darkening`

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:jagged_amount` is the primary means of specifing how much
    sharpening to apply. Shaprening is applied to the jagged areas
    of the image. It is a float greater or equal to `0.0`
    with a default of `3.0`.

  * `:flat_amount` is the specifies how much
    sharpening to apply to flat areas of the image. It is a float
    greater or equal to `0.0` with a default of `0.0`.

  * `:threshold` indicates where the transition from the flat
    part of the image to the jaggy part of the image is to be
    considered on the curve. It is a float amount greater than
    or equal to `0.0` with a default of `2.0`.

  * `:max_brightening` specifies how much the image may be
    brightened as part of the sharpening process. It is a positive
    integer greater than or equal to `0`. The default is `10`.

  * `:max_darkening` specifies how much the image may be
    darkened as part of the sharpening process. It is a positive
    integer greater than or equal to `0`. The default is `20`.

  * `:sigma` changes the width of the sharpening fringe and can be
    adjusted according to the output printing resolution. As an approximate
    guideline, use `0.5` for 4 pixels/mm (display resolution),
    `1.0` for 12 pixels/mm and `1.5` for 16 pixels/mm (300 dpi == 12
    pixels/mm). These figures refer to the image raster, not the half-tone
    resolution. The default is `0.5`.

  ### Returns

  * `{:ok, sharpened_image}` or

  * `{:error reason}`

  ### Output sharpening

  For screen output sharpening the default options are recommended.
  Adjust `:sigma` for other output devices as required.

  """
  @doc subject: "Operation"
  @doc since: "0.35.0"

  @spec sharpen(image :: Vimage.t(), options :: Options.Sharpen.sharpen_options()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def sharpen(image, options \\ []) do
    with {:ok, options} <- Options.Sharpen.validate_options(options) do
      Operation.sharpen(image,
        sigma: options.sigma,
        x1: options.threshold,
        y2: options.max_brightening,
        y3: options.max_darkening,
        m1: options.flat_amount,
        m2: options.jagged_amount
      )
    end
  end

  @doc """
  Sharpens an image or raises an exception.

  Selectively sharpens the `L` channel of a LAB image. `image`
  is converted to `:labs` for sharpening and the converted back
  to its original interpretation.

  The operation performs a gaussian blur and subtracts from `image` to generate a
  high-frequency signal. This signal is passed through a lookup table formed
  from the five parameters and then added back to `image`.

  The lookup table is formed like this:

  ```
                      ^
                   y2 |          -----------
                      |         /
                      |        / slope m2
                      |    .../
              -x1     | ...   |
  -------------------...---------------------->
              |   ... |      x1
              |... slope m1
              /       |
             / m2     |
            /         |
           /          |
          /           |
         /            |
  ______/             | -y3
                      |
  ```

  Where:

  * `m1` is `:flat_amount`
  * `m2` is `:jagged_amount`
  * `x1` is `:threshold`
  * `y2` is `:max_brightening`
  * `y3` is `:max_darkening`

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:jagged_amount` is the primary means of specifing how much
    sharpening to apply. Shaprening is applied to the jagged areas
    of the image. It is a float greater or equal to `0.0`
    with a default of `3.0`.

  * `:flat_amount` is the specifies how much
    sharpening to apply to flat areas of the image. It is a float
    greater or equal to `0.0` with a default of `0.0`.

  * `:threshold` indicates where the transition from the flat
    part of the image to the jaggy part of the image is to be
    considered on the curve. It is a float amount greater than
    or equal to `0.0` with a default of `2.0`.

  * `:max_brightening` specifies how much the image may be
    brightened as part of the sharpening process. It is a positive
    integer greater than or equal to `0`. The default is `10`.

  * `:max_darkening` specifies how much the image may be
    darkened as part of the sharpening process. It is a positive
    integer greater than or equal to `0`. The default is `20`.

  * `:sigma` changes the width of the sharpening fringe and can be
    adjusted according to the output printing resolution. As an approximate
    guideline, use `0.5` for 4 pixels/mm (display resolution),
    `1.0` for 12 pixels/mm and `1.5` for 16 pixels/mm (300 dpi == 12
    pixels/mm). These figures refer to the image raster, not the half-tone
    resolution. The default is `0.5`.

  ### Returns

  * `sharpened_image` or

  * raises an exception.

  ### Output sharpening

  For screen output sharpening the default options are recommended.
  Adjust `:sigma` for other output devices as required.

  """
  @doc subject: "Operation"
  @doc since: "0.35.0"

  @spec sharpen!(image :: Vimage.t(), options :: Options.Sharpen.sharpen_options()) ::
          Vimage.t() | no_return()

  def sharpen!(image, options \\ []) do
    case sharpen(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Feather (blur the edges) of an image
  mask.

  Applies a gaussian blur to a one-band image
  or the alpha band of a multi-band image
  that can be used to smooth the blending of
  one image into another.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` that is either
    a single band image or an image with an alpha band.

  * `options` is a keyword list of options.

  ### Options

  * `:sigma` is the `float` size of the mask
    to use. A larger number makes the image more
    blurry. A range between `1.0` and `10.0`
    is normally appropriate. The default is
    `#{@default_blur_sigma}`.

  * `:min_amplitude` is a `float` that determines
    the accuracy of the mask. The default is `0.2`.
    A smaller number will generate a larger, more
    accurate mask,

  ### Returns

  * `{:ok, blurred_mask_image}` or

  * `{:error, reason}`

  """
  @doc subject: "Operation", since: "0.13.0"

  @spec feather(image :: Vimage.t(), options :: Options.Blur.blur_options()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def feather(%Vimage{} = image, options \\ []) do
    with {:ok, options} <- Options.Blur.validate_options(options) do
      cond do
        has_alpha?(image) ->
          {image, alpha} = split_alpha(image)
          {:ok, feathered} = feather(alpha, options)
          Operation.bandjoin([image, feathered])

        bands(image) == 1 ->
          margin = options.sigma * 2

          crop!(image, margin, margin, width(image) - 2 * margin, height(image) - 2 * margin)
          |> Operation.embed!(margin, margin, width(image), height(image))
          |> blur!(options)
          |> wrap(:ok)

        true ->
          {:error,
           %Image.Error{
             message: "Image has no alpha band and is not a single band image",
             reason: "Image has no alpha band and is not a single band image"
           }}
      end
    end
  end

  @doc """
  Feather (blur the edges) of an image
  mask returning an image or raising an
  exception.

  Applies a gaussian blur to a one-band image
  or the alpha band of a multi-band image
  that can be used to smooth the blending of
  one image into another.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` that is either
    a single band image or an image with an alpha band.

  * `options` is a keyword list of options.

  ### Options

  * `:sigma` is the `float` size of the mask
    to use. A larger number makes the image more
    blurry. A range between `1.0` and `10.0`
    is normally appropriate. The default is
    `#{@default_blur_sigma}`.

  * `:min_amplitude` is a `float` that determines
    the accuracy of the mask. The default is `0.2`.
    A smaller number will generate a larger, more
    accurate mask,

  ### Returns

  * `blurred_mask_image` or

  * raises an exception.

  """
  @doc subject: "Operation", since: "0.13.0"

  @spec feather!(image :: Vimage.t(), options :: Options.Blur.blur_options()) ::
          Vimage.t() | no_return()

  def feather!(%Vimage{} = image, options \\ []) do
    case feather(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Returns the average color of an image.

  The average is calculated for each band
  of an image and then combined.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * A list of average pixel values which can
    be interpreted as the average color of the
    image.

  ### Example

        iex> Image.open!("./test/support/images/Hong-Kong-2015-07-1998.jpg")
        ...> |> Image.average()
        [66, 86, 106]

  """
  @doc since: "0.27.0"

  @spec average(Vimage.t()) :: Pixel.t() | {:error, error()}
  def average(%Vimage{} = image) do
    with {:ok, flattened} <- flatten(image) do
      for i <- band_range(flattened) do
        image[i]
        |> Operation.avg!()
        |> round()
      end
    end
  end

  @doc """
  Returns the average color of an image or
  raises and exception.

  The average is calculated for each band
  of an image and then combined.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * A list of average pixel values which can
    be interpreted as the average color of the
    image.

  ### Example

        iex> Image.open!("./test/support/images/Hong-Kong-2015-07-1998.jpg")
        ...> |> Image.average!()
        [66, 86, 106]

  """
  @doc since: "0.27.0"

  @spec average!(Vimage.t()) :: Pixel.t() | no_return()
  def average!(%Vimage{} = image) do
    case average(image) do
      {:error, reason} -> raise Image.Error, reason
      color -> color
    end
  end

  @doc """
  Add an alpha band to an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `alpha_image` is any single-band image
    that will be added as an alpha image to
    `image`

  OR

  * an integer in the range `0..255` representing the
    alpha-band fill value, using the standard libvips / RGBA
    convention: `255` is fully opaque, `0` is fully
    transparent. The atoms `:opaque` and `:transparent` may
    also be provided in place of `255` and `0` respectively.

  ### Returns

  * `{:ok, image_with_added_alpha_band}` or

  * `{:error, reason}`

  """
  @doc subject: "Operation", since: "0.13.0"

  @spec add_alpha(image :: Vimage.t(), alpha_image :: Vimage.t() | transparency()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def add_alpha(%Vimage{} = image, %Vimage{} = alpha_image) do
    cond do
      has_alpha?(image) ->
        {:error,
         %Image.Error{
           message: "Image already has an alpha band",
           reason: "Image already has an alpha band"
         }}

      bands(alpha_image) > 1 ->
        {:error,
         %Image.Error{
           message: "Alpha image has more than one band",
           reason: "Alpha image has more than one band"
         }}

      true ->
        Operation.bandjoin([image, alpha_image])
    end
  end

  def add_alpha(%Vimage{} = image, transparency) when transparency in 0..255 do
    with {:ok, alpha_image} <- Image.new(image, bands: 1, color: transparency) do
      add_alpha(image, alpha_image)
    end
  end

  def add_alpha(%Vimage{} = image, :transparent) do
    add_alpha(image, @transparent)
  end

  def add_alpha(%Vimage{} = image, :opaque) do
    add_alpha(image, @opaque_)
  end

  @doc """
  Add an alpha band to an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `alpha_image` is any single-band image
    that will be added as an alpha image to
    `image`

  OR

  * `:color` which defines the color of the alpha
    image. This can be specified as a single integer
    which will be applied to all bands, or a list of
    integers representing the color for each
    band. The default is `0`, meaning black. The color
    can also be supplied as a CSS color name as a
    string or atom. For example: `:misty_rose`. See
    `Color.new/2` from the Color library.

  ### Note

  If `color` is provided then the alpha layer determines
  the level of transparency of `image`.

  White (RGB color 255) means that `image` will be opaque.
  Black (the default, RGB 0) means that `image` will be transparent.
  Other colors will determine the level of transparency
  between the two.

  ### Returns

  * `image_with_added_alpha_band` or

  * raises an exception.

  """
  @doc subject: "Operation", since: "0.13.0"

  @spec add_alpha!(image :: Vimage.t(), alpha_image :: Vimage.t() | Image.Pixel.t()) ::
          Vimage.t() | no_return()

  def add_alpha!(%Vimage{} = image, alpha_image) do
    case add_alpha(image, alpha_image) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Split an image to separate the alpha band
  from the other image bands.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{image_without_alpha, alpha_band}` or

  * `{image, nil}` if there is no
    alpha band detected.

  """
  @doc subject: "Operation", since: "0.13.0"

  @spec split_alpha(image :: Vimage.t()) :: {bands :: Vimage.t(), alpha :: Vimage.t() | nil}
  def split_alpha(%Vimage{} = image) do
    if has_alpha?(image) do
      alpha_band = image[alpha_band(image)]
      image = Operation.extract_band!(image, 0, n: Image.bands(image) - 1)
      {image, alpha_band}
    else
      {image, nil}
    end
  end

  @doc """
  Compose two images together, or an image and a list of
  images compositions, to form a new image.

  ### Arguments

  * `base_image` is any `t:Vix.Vips.Image.t/0`.

  * `overlay_image` is any `t:Vix.Vips.Image.t/0` that will
    be composed over the top of `base_image`. It can also
    be a list of `t:composition/0`s that allow for multiple
    images to be composed in a single call.

  * `options` is a keyword list of options.

  ### Options for a single overlay image

  * `:blend_mode` is the manner in which the two
    images are composited. See `t:Image.BlendMode.t/0`.
    The default is `:over` which is the most common blend
    mode.

  * `:x` is the offset (0-based) which, if zero or positive,
    from the *left* of the `base_image`. If negative is is
    the offset from the *right* of the `base_image`.
    where the `overlay_image` will be placed. It may also be
    one of the keywords `:left`, `:right` or `:center`. The
    default is `:center`.

  * `:y` is the offset (0-based) which, if zero or positive,
    from the *top* of the `base_image`. If negative is is
    the offset from the *bottom* of the `base_image`.
    where the `overlay_image` will be placed.  It may also be
    one of the keywords `:top`, `:bottom` or `:middle`. The
    default is `:middle`.

  ### Composition list options

  When `overlay_image` is an `image_list`, each entry in
  the list is either a `t:Vix.Vips.Image.t/0` or a
  `t:Image.composition_list/0`. A composition supports the specification
  of how a particular image is composed onto the base image.

  * `:x` describes the absolute `x` offset on the
    base image where this image will be placed. If
    this option is set to `:left`, `:center` or
    `:right` then the `x` position will be calculated
    relative to the base image. If `:x` is nil
    (the default) then the image will be placed according
    to the relative offset of the previously composed
    image using `:dx`.

  * `:y` describes the absolute `y` offset on the
    base image where this image will be placed. If
    this option is set to `:top`, `:middle` or
    `:bottom` then the `y` position will be calculated
    relative to the base image. If `:y` is nil
    (the default) then the image will be placed according
    to the relative offset of the previously composed
    image using `:dy`.

  * `:dx` describes the relative offset used to calculate
    the `x` value. `:dx` is an integer offset from the
    edge of the previously composed image. Which edge is
    determined by the `:x_baseline` option. If `:x` is also
    specified then `:x` is first calculated, then `:dx` is
    added to it. In this case, `:x_baseline` is ignored.

  * `:dy` describes the relative offset used to calculate
    the `y` value. `:dy` is an integer offset from the
    edge of the previously composed image. Which edge is
    determined by the `:y_baseline` option. If `:y` is also
    specified then `:y` is first calculated, then `:dy` is
    added to it. In this case, `:x_baseline` is ignored.

  * `:blend_mode` is the `t:Image.BlendMode.t/0` used when
    composing this image over its base image. The default
    is `:over` which is appropriate for most use cases.

  * `:x_baseline` establishes the baseline on the
    previously composed image from which `:dx` is
    calculated. The default is `:right`.

  * `:y_baseline` establishes the baseline on the
    previously composed image from which `:dy` is
    calculated. The default is `:bottom`.

  ### Returns

  * `{:ok, composed_image}` or

  * `{:error, reason}`

  ### Examples

      # Compose images over a base image using
      # absolute coordinates from the base image
      # to place each overlay image.

      #=> {:ok, image} = Image.compose(base_image, polygon, x: :middle, y: :top)
      #=> {:ok, image} = Image.compose(image, explore_new, x: 260, y: 200)
      #=> {:ok, image} = Image.compose(image, places, x: 260, y: 260)
      #=> {:ok, image} = Image.compose(image, blowout, x: 260, y: 340)
      #=> {:ok, image} = Image.compose(image, start_saving, x: 260, y: 400)

      # Compose images over a base image
      # using a composition list and coordinates
      # that are either absolute with respect to the
      # base image or relative to the previously
      # composed image.

      #=> Image.compose(base_image, [
      ..>   {polygon, x: :center, y: :top},
      ..>   {explore_new, y_baseline: :top, x_baseline: :left, dx: 20, dy: 200},
      ..>   {places, dy: 10},
      ..>   {blowout, dy: 20},
      ..>   {start_saving, dy: 50}
      ..> ])

  """
  @doc subject: "Operation"

  @spec compose(
          base_image :: Vimage.t(),
          overlay_image :: Vimage.t(),
          options :: Options.Compose.t()
        ) ::
          {:ok, Vimage.t()} | {:error, error()}

  def compose(base_image, overlay_image_or_images, options \\ [])

  def compose(%Vimage{} = base_image, %Vimage{} = overlay_image, options) do
    x = Keyword.get(options, :x, :center)
    y = Keyword.get(options, :y, :middle)
    blend_mode = Keyword.get(options, :blend_mode)

    with {:ok, blend_mode} <- Image.BlendMode.validate_blend_mode(blend_mode) do
      {x, y} = xy_offset(base_image, overlay_image, x, y)
      Operation.composite2(base_image, overlay_image, blend_mode, x: x, y: y)
    end
  end

  @spec compose(
          base_image :: Vimage.t(),
          image_list :: composition_list(),
          options :: Options.Compose.t()
        ) ::
          {:ok, Vimage.t()} | {:error, error()}

  def compose(%Vimage{} = base_image, image_list, _options) when is_list(image_list) do
    width = Image.width(base_image)
    height = Image.height(base_image)

    zipped =
      Enum.reduce_while(image_list, {0, 0, width, height, []}, fn
        %Vimage{} = image, {prev_x, prev_y, prev_width, prev_height, acc} ->
          build_composition(image, prev_x, prev_y, prev_width, prev_height, acc, Map.new())

        {%Vimage{} = image, options}, {prev_x, prev_y, prev_width, prev_height, acc} ->
          build_composition(image, prev_x, prev_y, prev_width, prev_height, acc, Map.new(options))
      end)

    case zipped do
      {:error, reason} ->
        {:error, reason}

      {_x, _y, _height, _width, list} ->
        {overlay_images, x_list, y_list, blend_modes} = unzip_composition(list)
        Operation.composite([base_image | overlay_images], blend_modes, x: x_list, y: y_list)
    end
  end

  defp build_composition(image, prev_x, prev_y, prev_width, prev_height, acc, options) do
    import Compose, only: [get_x: 6, get_y: 6]

    options = Map.merge(Compose.default_composit_options(), options)

    with {:ok, x} <- get_x(image, prev_x, prev_width, options.x, options.dx, options.x_baseline),
         {:ok, y} <- get_y(image, prev_y, prev_height, options.y, options.dy, options.y_baseline),
         {:ok, blend_mode} <- BlendMode.validate_blend_mode(options.blend_mode) do
      {:ok, [image, x, y, blend_mode]}
    end
    |> accumulate_compositions(image, acc)
  end

  defp unzip_composition(list) do
    Enum.reduce(list, {[], [], [], []}, fn
      [image, x, y, blend_mode], {images, xs, ys, blend_modes} ->
        {[image | images], [x | xs], [y | ys], [blend_mode | blend_modes]}
    end)
  end

  defp accumulate_compositions(composition, image, acc) do
    case composition do
      {:ok, composition} ->
        [_image, x, y | _rest] = composition
        {:cont, {x, y, Image.width(image), Image.height(image), [composition | acc]}}

      {:error, reason} ->
        {:halt, reason}
    end
  end

  @doc """
  Compose two images together to form a new image or
  raise an exception.

  ### Arguments

  * `base_image` is any `t:Vix.Vips.Image.t/0`.

  * `overlay_image` is any `t:Vix.Vips.Image.t/0` that will
    be composed over the top of `base_image`.

  * `options` is a keyword list of options.

  ### Options

  * `:blend_mode` is the manner in which the two
    images are composited. See `t:Image.BlendMode.t/0`.
    The default is `:over` which is the most common blend
    mode.

  * `:x` is the offset (0-based) which, if zero or positive,
    from the *left* of the `base_image`. If negative is is
    the offset from the *right* of the `base_image`.
    where the `overlay_image` will be placed. It may also be
    one of the keywords `:left`, `:right` or `:center`. The
    default is `:center`.

  * `:y` is the offset (0-based) which, if zero or positive,
    from the *top* of the `base_image`. If negative is is
    the offset from the *bottom* of the `base_image`.
    where the `overlay_image` will be placed.  It may also be
    one of the keywords `:top`, `:bottom` or `:middle`. The
    default is `:middle`.

  ### Composition list options

  When `overlay_image` is an `image_list`, each entry in
  the list is either a `t:Vix.Vips.Image.t/0` or a
  `t:Image.composition_list/0`. A composition supports the specification
  of how a particular image is composed onto the base image.

  * `:x` describes the absolute `x` offset on the
    base image where this image will be placed. If
    this option is set to `:left`, `:center` or
    `:right` then the `x` position will be calculated
    relative to the base image. If `:x` is nil
    (the default) then the image will be placed according
    to the relative offset of the previously composed
    image using `:dx`.

  * `:y` describes the absolute `y` offset on the
    base image where this image will be placed. If
    this option is set to `:top`, `:middle` or
    `:bottom` then the `y` position will be calculated
    relative to the base image. If `:y` is nil
    (the default) then the image will be placed according
    to the relative offset of the previously composed
    image using `:dy`.

  * `:dx` describes the relative offset used to calculate
    the `x` value. `:dx` is an integer offset from the
    edge of the previously composed image. Which edge is
    determined by the `:x_baseline` option. If `:x` is also
    specified then `:x` is first calculated, then `:dx` is
    added to it. In this case, `:x_baseline` is ignored.

  * `:dy` describes the relative offset used to calculate
    the `y` value. `:dy` is an integer offset from the
    edge of the previously composed image. Which edge is
    determined by the `:y_baseline` option. If `:y` is also
    specified then `:y` is first calculated, then `:dy` is
    added to it. In this case, `:x_baseline` is ignored.

  * `:blend_mode` is the `t:Image.BlendMode.t/0` used when
    composing this image over its base image. The default
    is `:over` which is appropriate for most use cases.

  * `:x_baseline` establishes the baseline on the
    previously composed image from which `:dx` is
    calculated. The default is `:right`.

  * `:y_baseline` establishes the baseline on the
    previously composed image from which `:dy` is
    calculated. The default is `:bottom`.

  ### Returns

  * `composed_image` or

  * raises an exception

  ### Examples

      # Compose images over a base image using
      # absolute  coordinates from the base image
      # to place each overlay image
      #=> base_image
      ..> |> Image.compose!(polygon, x: :middle, y: :top)
      ..> |> Image.compose!(explore_new, x: 260, y: 200)
      ..> |> Image.compose!(places, x: 260, y: 260)
      ..> |> Image.compose!(blowout, x: 260, y: 340)
      ..> |> Image.compose!(start_saving, x: 260, y: 400)

      # Compose images over a base image
      # using a composition list and coordinates
      # that are either absolute with respect to the
      # base image or relative to the previously
      # composed image
      #=> base_image
      ..> |> Image.compose!([
      ..>   {polygon, x: :center, y: :top},
      ..>   {explore_new, y_baseline: :top, x_baseline: :left, dx: 20, dy: 200},
      ..>   {places, dy: 10},
      ..>   {blowout, dy: 20},
      ..>   {start_saving, dy: 50}
      ..> ])

  """
  @doc subject: "Operation"

  @spec compose!(
          base_image :: Vimage.t(),
          overlay_image :: Vimage.t(),
          options :: Options.Compose.t()
        ) ::
          Vimage.t() | no_return()

  def compose!(base_image, image_or_image_list, options \\ [])

  def compose!(%Vimage{} = base_image, %Vimage{} = overlay_image, options) do
    case compose(base_image, overlay_image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @spec compose!(
          base_image :: Vimage.t(),
          image_list :: composition_list(),
          options :: Options.Compose.t()
        ) ::
          Vimage.t() | no_return()

  def compose!(%Vimage{} = base_image, image_list, options) when is_list(image_list) do
    case compose(base_image, image_list, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Join a list of images into a single image.

  ### Arguments

  * `image_list` is a non-empty list of `t:Vimage.t/0`
    images.

  * `options` is a keyword list of options.

  ### Options

  * `:across` is an integer number of images in the
    horizontal direction of the grid. The default is `1`.

  * `:vertical_spacing` determines the height in pixels of
    each image row. The default, `0`, means that the row
    height is the maximum height of the
    images in `image_list`.

  * `:horizontal_spacing` determines the width in pixels of
    each image in a row. The default, `0`, means
    that the width is the maximum width of the
    images in `image_list`.

  * `:vertical_align` is `:bottom`, `:middle` or `:top`.
    The default is `:bottom`.

  * `:horizontal_align` is `:left`, `:center` or `:right`.
    The default is `:left`.

  * `:background_color` is the color of any pixels generated
    between images. This can be specified as a single integer
    which will be applied to all bands, or a list of
    integers representing the color for each
    band. The default is `0`, meaning black. The color
    can also be supplied as a CSS color name as a
    string or atom. For example: `:misty_rose`. See
    `Color.new/2` from the Color library.

  * `:shim` is the number of pixels of spacing between
    images in the grid. The default is `0`.

  ### Returns

  * `{:ok, joined_image}` or

  * `{:error, reason}`

  ### Notes

  `Image.join/2` lays out the list of images in a grid.
  The grid is `:across` images across and however high
  is necessary to use up all of `image_list`.  Images are
  set down left-to-right and top-to-bottom.

  Each input image is placed with a box of size `:horizontal_spacing`
  by `:vertical_spacing` pixels and cropped. These default
  to the largest width and largest height of the input images.

  Space between images is filled with `:background_color` .
  This defaults to black.

  Images are positioned within their `:horizontal_spacing` by
  `:vertical_spacing` box at `:vertical_align` of `:bottom`,
  `:middle` or `:top` and by `:horizontal_align` of `:left`,
  `:center` or `:right`. The defaults are `:bottom`, `:left`.

  """
  @spec join(image_list :: list(Vimage.t()), options :: Options.Join.join_options()) ::
          {:ok, joined_image :: Vimage.t()} | {:error, error()}

  def join(image_list, options \\ []) when is_list(image_list) do
    with {:ok, options} <- Options.Join.validate_options(hd(image_list), options) do
      Operation.arrayjoin(image_list, options)
    end
  end

  @doc """
  Join a list of images into a single image or raises
  an exception.

  ### Arguments

  * `image_list` is a non-empty list of `t:Vimage.t/0`
    images.

  * `options` is a keyword list of options.

  ### Options

  * `:across` is an integer number of images in the
    horizontal direction of the grid. The default is `1`.

  * `:vertical_spacing` determines the height in pixels of
    each image row. The default, `0`, means that the row
    height is the maximum height of the
    images in `image_list`.

  * `:horizontal_spacing` determines the width in pixels of
    each image in a row. The default, `0`, means
    that the width is the maximum width of the
    images in `image_list`.

  * `:vertical_align` is `:bottom`, `:middle` or `:top`.
    The default is `:bottom`.

  * `:horizontal_align` is `:left`, `:center` or `:right`.
    The default is `:left`.

  * `:background_color` is the color of any pixels generated
    between images. This can be specified as a single integer
    which will be applied to all bands, or a list of
    integers representing the color for each
    band. The default is `0`, meaning black. The color
    can also be supplied as a CSS color name as a
    string or atom. For example: `:misty_rose`. See
    `Color.new/2` from the Color library.

  * `:shim` is the number of pixels of spacing between
    images in the grid. The default is `0`.

  ### Returns

  * `{:ok, joined_image}` or

  * `{:error, reason}`

  ### Notes

  `Image.join/2`Lay out the list of images in a grid.
  The grid is `:across` images across and however high
  is necessary to use up all of `image_list`.  Images are
  set down left-to-right and top-to-bottom.

  Each input image is placed with a box of size `:horizontal_spacing`
  by `:vertical_spacing` pixels and cropped. These default
  to the largest width and largest height of the input images.

  Space between images is filled with `:background_color` .
  This defaults to black.

  Images are positioned within their `:horizontal_spacing` by
  `:vertical_spacing` box at `:vertical_align` of `:bottom`,
  `:middle` or `:top``and by `:horizontal_align` of `:left`,
  `:center` or `:righ`. The defaults are `:bottom`, `:left.

  """
  @spec join!(image_list :: list(Vimage.t()), options :: Options.Join.join_options()) ::
          joined_image :: Vimage.t() | no_return()

  def join!(image_list, options \\ []) when is_list(image_list) do
    case join(image_list, options) do
      {:ok, joined_image} -> joined_image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Create a meme image from a base image and
  one or two lines of text.

  The size of the text is determined by the size
  of the base image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` over which
    the meme text will be composed.

  * `headline` is the top line of the meme text.

  * `options` is a keyword list of options.

  ### Options

  * `:text` is the second line of text at the bottom of the
    meme image. The default is `""`.

  * `:text_size` is the size of the bottom text in points.
    The default is calculated proportional to the size of the
    image.

  * `:headline_size` is the size of the headline text in points.
    The default is calculated proportional to the size of the
    image.

  * `:font` is the name of the font family to be applied.
    The default is `Impact`.

  * `:font_file` is the path name to a font file that will be
    loaded. The default is `:default` which will load the included
    `Impact` font if the font family is `Impact`. If the font family
    is not `Impact` and the `:font_file` is `:default` then the
    font displayed is resolved by the underlying operating system.
    If `:font_file` is a string, then it is expected to be a valid
    font file. If `:font_file` is set to a path then the `:font` option
    should also be set to the correct font name.

  * `:weight` is the font weight to be rendered. The options
    are `:ultralight`, `:light`, `:normal`, `:bold`, `:ultrabold`,
    and `:heavy`. The default `:bold`.

  * `:transform` determines how the text is presented. The
    options are `:upcase`, `:downcase`, `:capitalize` and `:none`.
    The default is `:upcase`.

  * `:color` is an RGB color of the text. The color can be an
    integer between `0..255`, a three-element list of
    integers representing an RGB color or an atom
    representing a CSS color name. The default is `:white`.

  * `:outline_color` is an RGB color of the text outline. The
    color can be an integer between `0..255`, a three-element list of
    integers representing an RGB color or an atom
    representing a CSS color name. The default is `:black`.

  * `:margin` is the width of the margin in pixels. The margin is
    applied to both the left and right sides of the image. The
    default is calculated proportional to the size of the
    image.

  """
  @doc subject: "Generator", since: "0.13.0"

  @spec meme(image :: Vimage.t(), headline :: String.t(), options :: Options.Meme.meme_options()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def meme(%Vimage{} = image, headline, options \\ []) when is_binary(headline) do
    with {:ok, options} <- Options.Meme.validate_options(image, options),
         {:ok, width} <- text_box_width(image, options),
         {:ok, headline} <- text_overlay(headline, options.headline_size, width, options),
         {:ok, text} <- text_overlay(options.text, options.text_size, width, options) do
      image
      |> compose!(headline, headline_location(image, headline))
      |> compose(text, text_location(image, text))
    end
  end

  @doc """
  Return a meme image from a base image and
  one or two lines of text or raise an exception.

  The size of the text is determined by the size
  of the base image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` over which
    the meme text will be composed.

  * `headline` is the top line of the meme text.

  * `options` is a keyword list of options.

  ### Options

  * `:text` is the second line of text at the bottom of the
    meme image. The default is `""`.

  * `:text_size` is the size of the bottom text in points.
    The default is calculated proportional to the size of the
    image.

  * `:headline_size` is the size of the headline text in points.
    The default is calculated proportional to the size of the
    image.

  * `:font` is the name of the font family to be applied.
    The default is `Impact`. If the font family name is `"Impact"`
    then the included `unicode.impact.ttf` font file will also be
    loaded. This ensures that the `Impact` font is available on all
    systems.

  * `:font_file` is the path name to a font file that will be
    loaded. The default is `:default` which will load the included
    `Impact` font if the font family is `Impact`. If the font family
    is not `Impact` and the `:font_file` is `:default` then the
    font displayed is resolved by the underlying operating system.
    If `:font_file` is a string, then it is expected to be a valid
    font file. If `:font_file` is set to a path then the `:font` option
    should also be set to the correct font name.

  * `:weight` is the font weight to be rendered. The options
    are `:ultralight`, `:light`, `:normal`, `:bold`, `:ultrabold`,
    and `:heavy`. The default `:bold`.

  * `:justify` is a boolean indicating if the headline and text
    are to be justified. If `true` then space is added between
    words so that both edges of each line are aligned with both
    margins. The default is `false`.

  * `:transform` determines how the text is presented. The
    options are `:upcase`, `:downcase`, `:capitalize` and `:none`.
    The default is `:upcase`.

  * `:color` is an RGB color of the text. The color can be an
    integer between `0..255`, a three-element list of
    integers representing an RGB color or an atom
    representing a CSS color name. The default is `:white`.

  * `:outline_color` is an RGB color of the text outline. The
    color can be an integer between `0..255`, a three-element list of
    integers representing an RGB color or an atom
    representing a CSS color name. The default is `:black`.

  * `:margin` is the width of the margin in pixels. The margin is
    applied to both the left and right sides of the image. The
    default is calculated proportional to the size of the
    image.

  """
  @doc subject: "Generator", since: "0.13.0"

  @spec meme!(image :: Vimage.t(), headline :: String.t(), options :: Options.Meme.meme_options()) ::
          Vimage.t() | no_return()

  def meme!(%Vimage{} = image, headline, options \\ []) when is_binary(headline) do
    case meme(image, headline, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  defp text_box_width(image, %{margin: margin}) do
    {:ok, width(image) - 2 * margin}
  end

  defp text_overlay("", _size, _width, _options) do
    Operation.black(1, 1)
  end

  defp text_overlay(text, size, width, %{font: font} = options) do
    text = "<b>" <> transform(text, options.transform) <> "</b>"
    font = "#{font} #{size}"

    text_options =
      [font: font, width: width, align: :VIPS_ALIGN_CENTRE]
      |> maybe_add_fontfile(options[:fontfile])

    with {:ok, {text, _}} <- Operation.text(text, text_options) do
      outline(text, options)
    end
  end

  @doc false
  def maybe_add_fontfile(options, nil) do
    options
  end

  def maybe_add_fontfile(options, font_file) do
    Keyword.put(options, :fontfile, font_file)
  end

  defp outline(image, %{color: color, outline_color: outline_color} = options) do
    radius = round(options.headline_size / 10)
    width = width(image) + 2 * radius
    height = height(image) + 2 * radius

    {:ok, text} = Operation.embed(image, radius, radius, width, height)

    {:ok, circle_mask} =
      Operation.black!(radius * 2 + 1, radius * 2 + 1)
      |> Math.add!(128)
      |> Draw.circle(radius, radius, radius, fill: true, color: :white)

    {:ok, outlined} =
      text
      |> Operation.morph!(circle_mask, :VIPS_OPERATION_MORPHOLOGY_DILATE)
      |> blur(sigma: 0.5, min_amplitude: 0.1)

    {:ok, background_text} =
      outlined
      |> new!(color: outline_color, bands: 3)
      |> bandjoin!(outlined)
      |> Operation.copy(interpretation: :VIPS_INTERPRETATION_sRGB)

    {:ok, foreground_text} =
      text
      |> new!(color: color, bands: 3)
      |> bandjoin!(text)
      |> Operation.copy(interpretation: :VIPS_INTERPRETATION_sRGB)

    compose(background_text, foreground_text)
  end

  defp transform(text, :none), do: text
  defp transform(text, :capitalize), do: String.capitalize(text)
  defp transform(text, :upcase), do: String.upcase(text)
  defp transform(text, :downcase), do: String.downcase(text)

  # defp bandjoin(a, nil), do: {:ok, a}
  defp bandjoin(a, b), do: Operation.bandjoin([a, b])

  defp bandjoin!(a, nil), do: a
  defp bandjoin!(a, b), do: Operation.bandjoin!([a, b])

  @headline_distance_from_top 0.03
  @text_distance_from_bottom 0.03

  defp headline_location(image, text) do
    x = ((width(image) - width(text)) / 2) |> round()
    y = (height(image) * @headline_distance_from_top) |> round()
    [x: x, y: y]
  end

  defp text_location(image, text) do
    x = ((width(image) - width(text)) / 2) |> round()
    y = (height(image) - height(text) - height(image) * @text_distance_from_bottom) |> round()
    [x: x, y: y]
  end

  @doc """
  Returns the filename for an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * The pathname from which the image was opened or
    `nil` if there is no associated path. This can
    happen in the case of a streamed image or an image
    created from a memory buffer.

  """
  @doc subject: "Image info"

  @spec filename(image :: Vimage.t()) :: Path.t() | nil
  def filename(%Vimage{} = image) do
    Vix.Vips.Image.filename(image)
  rescue
    e in RuntimeError ->
      if e.message == "null_value" do
        nil
      else
        reraise e, __STACKTRACE__
      end
  end

  @doc """
  Returns the EXIF data for an image as a
  map.

  Only a subset of EXIF data is returned but
  its a substantial subset.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`

  ### Returns

  * `{:ok, exif_map}` where `exif_map` is a map
    of selected EXIF data.

  * `{:error, reason}`

  """
  @doc subject: "Metadata"

  @spec exif(Vimage.t()) :: {:ok, map()} | {:error, error()}
  def exif(%Vimage{} = image) do
    with {:ok, exif_blob} <- Vimage.header_value(image, "exif-data"),
         <<"Exif"::binary, 0::16, exif::binary>> <- exif_blob do
      exif
      |> Exif.extract_exif()
      |> wrap(:ok)
    else
      false ->
        {:error, %Image.Error{reason: :invalid_exif, message: "Invalid Exif data"}}

      {:error, raw} ->
        {:error, Image.Error.wrap(raw, operation: :exif)}
    end
  end

  @doc """
  Returns the XMP data for an image as a
  keyword list.

  Only a selected set of XMP data is returned.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`

  ### Returns

  * `{:ok, xmp_map}` where `xmp_map` is a map
    of selected XMP data.

  """
  @doc subject: "Metadata"

  @spec xmp(Vimage.t()) :: {:ok, map()} | {:error, error()}
  def xmp(%Vimage{} = image) do
    with {:ok, xmp_blob} <- Vimage.header_value_as_string(image, "xmp-data"),
         {:ok, xmp_binary} <- Base.decode64(xmp_blob) do
      xmp_binary
      |> SweetXml.parse(dtd: :none)
      |> Xmp.extract_xmp()
      |> wrap(:ok)
    else
      :error ->
        {:error, %Image.Error{reason: :invalid_xmp, message: "XMP payload is not base64-encoded"}}

      {:error, raw} ->
        {:error, Image.Error.wrap(raw, operation: :xmp)}
    end
  end

  @doc """
  Returns the width of an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * The image width as an integer.

  """
  @doc subject: "Image info"

  @spec width(image :: Vimage.t()) :: pos_integer()
  def width(%Vimage{} = image) do
    Vimage.width(image)
  end

  @doc """
  Returns the height of an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * The image height as an integer.

  """
  @doc subject: "Image info"

  @spec height(image :: Vimage.t()) :: pos_integer()
  def height(%Vimage{} = image) do
    Vimage.height(image)
  end

  @doc """
  Returns the band format of an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * The band format of the image in `Nx` notation.

  ### Examples

        iex> image = Image.open!("./test/support/images/Singapore-2016-09-5887.jpg")
        iex> Image.band_format(image)
        {:u, 8}

  """
  @doc subject: "Image info"
  @doc since: "0.35.0"

  @spec band_format(image :: Vimage.t()) :: Image.BandFormat.t()
  def band_format(%Vimage{} = image) do
    image
    |> Vix.Vips.Image.format()
    |> Image.BandFormat.nx_format!()
  end

  @doc """
  Returns the range of permissable values
  as a tuple for each pixel in an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{min_value, max_value}` where `min_value` and
    `max_value` are integers for unsigned images and
    floats for signed images.

  ### Examples

        iex> image = Image.open!("./test/support/images/Singapore-2016-09-5887.jpg")
        iex> Image.range(image)
        {0, 255}

  """
  @doc since: "0.35.0"
  @doc subject: "Image info"

  @spec range(image :: Vimage.t()) :: {non_neg_integer() | float(), non_neg_integer() | float()}
  def range(%Vimage{} = image) do
    case band_format(image) do
      {:u, bits} -> {0, 2 ** bits - 1}
      {:s, bits} -> {-1.0 * 2 ** (bits - 1), 2 ** (bits - 1) - 1.0}
    end
  end

  @doc """
  Return the number of bands in an image.

  A band is sometimes referred to as a
  channel.

  Note than bands are 0-indexed. That is, the
  first band is band 0, the second band is
  band 1 and so on.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * An integer number of bands in the image.

  """
  @doc subject: "Image info"

  @spec bands(image :: Vimage.t()) :: pos_integer()
  def bands(%Vimage{} = image) do
    Vimage.bands(image)
  end

  @doc """
  Returns the number of pages in an image.

  Animated images will return an integer representing
  the number of animated frames. Normal images will
  return `1`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `integer` number of pages in the `image`.

  ### Example

      iex> image = Image.open!("./test/support/images/animated.webp")
      iex> Image.pages(image)
      12

      iex> image = Image.open!("./test/support/images/Kamchatka-2019-8754.jpg")
      iex> Image.pages(image)
      1

  """
  @doc subject: "Image info", since: "0.38.0"

  @spec pages(image :: Vimage.t()) :: pos_integer()
  def pages(%Vimage{} = image) do
    case Vix.Vips.Image.header_value(image, "n-pages") do
      {:ok, pages} -> pages
      {:error, _reason} -> 1
    end
  end

  @doc """
  Returns the shape of an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * The image shape as a tuple of
    `{width, height, bands}`.

  ### Example

      iex> image = Image.open!("./test/support/images/Kamchatka-2019-8754.jpg")
      iex> Image.shape(image)
      {1000,542, 3}

  """
  @doc subject: "Image info", since: "0.9.0"

  @spec shape(image :: Vimage.t() | MutableImage.t()) ::
          {width :: pos_integer(), height :: pos_integer(), bands :: pos_integer()}

  def shape(%image_type{} = image) when is_image(image_type) do
    {width(image), height(image), bands(image)}
  end

  @doc """
  Returns the image colorspace.

  The colorspace is how `Image` understands
  the image data. For example, `:srgb`, `:cmyk` or
  `:bw`.

  For most common web applications, the
  colorspace will be `:srgb`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * The image colorspace as an atom.

  ### Notes

  * See also `Image.Interpretation.known_interpretations/0`

  ### Example

      iex> image = Image.open!("./test/support/images/Kamchatka-2019-8754.jpg")
      iex> Image.colorspace(image)
      :srgb

  """
  @doc subject: "Image info", since: "0.9.0"

  @spec colorspace(image :: Vimage.t()) :: Image.Interpretation.t()
  def colorspace(%Vimage{} = image) do
    image
    |> Vix.Vips.Image.interpretation()
    |> Image.Interpretation.decode_interpretation()
  end

  @doc """
  Flip an image horizontally or vertically.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `direction` is either `:horizontal` or
    `:vertical`.

  ### Returns

  * `{:ok, flipped_image}` or

  * `{:error, reason}`

  """
  @doc subject: "Operation"

  @spec flip(image :: Vimage.t(), direction :: :vertical | :horizontal) ::
          {:ok, Vimage.t()} | {:error, error()}

  def flip(%Vimage{} = image, :vertical) do
    Operation.flip(image, :VIPS_DIRECTION_VERTICAL)
  end

  def flip(%Vimage{} = image, :horizontal) do
    Operation.flip(image, :VIPS_DIRECTION_HORIZONTAL)
  end

  def flip(%Vimage{} = _image, direction) do
    {:error,
     "Invalid flip direction. Must be :vertical or :horizontal.  Found #{inspect(direction)}"}
  end

  @doc """
  Flip an image horizontally or vertically returning
  a flipped image or raising an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `direction` is either `:horizontal` or
    `:vertical`.

  ### Returns

  * `flipped_image` or

  * raises an exception.

  """
  @doc subject: "Operation"

  @spec flip!(image :: Vimage.t(), direction :: :vertical | :horizontal) ::
          Vimage.t() | no_return()

  def flip!(%Vimage{} = image, direction) do
    case flip(image, direction) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Resize an image.

  If the intent is to thumbnail an image then `Image.thumbnail/3`
  is recommended since it applies a very efficient downsizing
  algorithm for that use case.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `scale` is a float scale factor.

  * `options` is a keyword list of options.

  ### Options

  * `:centre` is a boolean indicating whether to use
    the centre downsampling convention. The default is
    `false`.

  * `:interpolate` defines which resampling kernel to apply.
    The options are `:nearest`, `:linear`, `:cubic`,
    `:mitchell`, `:lanczos2` or `:lanczos3` (the default).

  * `:vertical_scale` is a float indicating the scaling
    factor of the vertical axis. In specified, then `scale`
    is applied only to the horizontal axis.

  ### Returns

  * `{:ok, resized_image}` or

  * raises an exception

  """

  @doc subject: "Resize", since: "0.13.0"

  @spec resize(Vimage.t(), scale :: number(), options :: Resize.resize_options()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def resize(%Vimage{} = image, scale, options \\ []) when scale >= 0 do
    with {:ok, options} <- Resize.validate_options(options) do
      do_resize(image, scale, options, has_alpha?(image))
    end
  end

  @dialyzer {:nowarn_function, {:do_resize, 4}}

  defp do_resize(image, scale, options, false = _has_alpha?) do
    Operation.resize(image, scale, options)
  end

  defp do_resize(image, scale, options, true = _has_alpha?) do
    band_format = Vix.Vips.Image.format(image)
    premultiplied = Operation.premultiply!(image)

    with {:ok, resized} <- Operation.resize(premultiplied, scale, options) do
      resized
      |> Operation.unpremultiply!()
      |> Operation.cast(band_format)
    end
  end

  @doc """
  Resize an image or raise an exception.

  If the intent is to thumbnail an image then `Image.thumbnail/3`
  is recommended since it applies a very efficient downsizing
  algorithm for that use case.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `scale` is a float scale factor.

  * `options` is a keyword list of options.

  ### Options

  * `:centre` is a boolean indicating whether to use
    the centre downsampling convention. The default is
    `false`.

  * `:interpolate` defines which resampling kernel to apply.
    The options are `:nearest`, `:linear`, `:cubic`,
    `:mitchell`, `:lanczos2` or `:lanczos3` (the default).

  * `:vertical_scale` is a float indicating the scaling
    factor of the vertical axis. In specified, then `scale`
    is applied only to the horizontal axis.

  ### Returns

  * `resized_image` or

  * raises an exception

  """

  @doc subject: "Resize", since: "0.14.0"

  @spec resize!(Vimage.t(), scale :: number(), options :: Resize.resize_options()) ::
          Vimage.t() | no_return()

  def resize!(%Vimage{} = image, scale, options \\ []) when scale >= 0 do
    case resize(image, scale, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Pixelates an image.

  Pixelation is the process of reducing the image
  resolution while retaining the image dimensions.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `scale` is the scale factor to apply to
    the image when it is pixelated. This means that
    one "pixel" is `image width * scale`. The default
    is `#{@pixelate_scale}`.

  ### Returns

  * `{:ok, pixelated_image}` or

  * `{:error, reason}`

  """
  @doc subject: "Operation", since: "0.14.0"

  @spec pixelate(image :: Vimage.t(), scale :: number()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def pixelate(%Vimage{} = image, scale \\ @pixelate_scale) when is_number(scale) and scale > 0 do
    image
    |> resize!(scale)
    |> resize(1 / scale, interpolate: :nearest)
  end

  @doc """
  Pixelates an image or raise an exception.

  Pixelation is the process of reducing the image
  resolution while retaining the image dimensions.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `scale` is the scale factor to apply to
    the image when it is pixelated. This means that
    one "pixel" is `image width * scale`. The default
    is `#{@pixelate_scale}`.

  ### Returns

  * `pixelated_image` or

  * raises an exception

  """
  @doc subject: "Operation", since: "0.14.0"

  @spec pixelate!(image :: Vimage.t(), scale :: number()) ::
          Vimage.t() | no_return()

  def pixelate!(%Vimage{} = image, scale \\ @pixelate_scale)
      when is_number(scale) and scale > 0 do
    case pixelate(image, scale) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Thumbnail an image to fit or fill a bounding box.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` or a
    pathname to an image file.

  * `length` is the integer length of the longest
    side of the resulting image after resizing. It can
    also be of the form "<width>x<height>". That
    is, a string with the width and height separated
    by an `x`. The `<height>` may be omitted in which
    case it is the same as providing an integer length.

  * `options` is a keyword list of options.

  ### Options

  * `:crop` determines if the strategy is "resize to fit"
    (crop is `:none`) or "resize to fill" (when the crop
    option is not `:none`). The value may be one of
    `:none`, `:center`, `:entropy`, `:attention`, `:low`
    or `:high`. The default is `:none`. See also `t:Image.Options.Crop.crop_focus/0`.

  * `:height` - Size to this height. Default is to maintain
    the image aspect ratio unless `resize: :force` is set. If
    `resize; :force` is set then the default `:height` is the
    height of `image`.

  * `:fit` sets the `:crop` and `:resize` options to align
    with the CSS [object-fit](https://www.w3schools.com/css/css3_object-fit.asp)
    property. Note that using the `:fit` option overwrites the
    options `:crop` and `:resize`. Since options are processed in
    the order in which they are presented, `:crop` and `:resize`
    may still be force set if they are after the `:fit` option.
    `:fit` takes one of the following values:

    * `:fill` - the image is resized to fill the given dimension.
      If necessary, the image will be stretched or squished to fit.
      This is the same as setting `resize: :force`. Note that is
      `:height` is not specified it will be the same height as `image`.

    * `:contain` - the image keeps its aspect ratio, but is resized
      to fit within the given dimension. This is the same as
      setting `crop: :none` and `resize: :both`.

    * `:cover` - the image keeps its aspect ratio and fills the given
      dimensions. The image will be clipped to fit. Clipping will default to
      `:center` unless `:crop` is already set to a value other
      than `:none`. This is the same as setting `crop: :center`
      (if `:crop` is not already set) and `resize: :both`.

  * `:autorotate` is a boolean indicating if the image should
    be autorotated based upon the image metadata. The default
    is `true`.

  * `:intent` indicates the rendering intent. The default
    is `:relative`. See also `t:Image.render_intent/0`.

  * `:export_icc_profile` indicates the icc profile to be attached
    to the resized image. The value may be an inbuilt profile (`:srgb`,
    `:p3` or `:cmyk`), the name of an icc profile in the systems
    profile directory or a full path to an icc profile file. The
    default is to export the icc profile of the resized image if
    there is one.

  * `:import_icc_profile` indicates the icc profile to be attached
    to the input image. The value may be an inbuilt profile (`:srgb`,
    `:p3` or `:cmyk`), the name of an icc profile in the systems
    profile directory or a full path to an icc profile file. The
    default is to use the icc profile of the input image if
    there is one.

  * `:linear` is a boolean indicating of the image should
    be resized in linear space. The default `false`. Shrinking is
    normally done in sRGB colourspace. Set linear to shrink in
    linear light colourspace instead. This can give better results,
    but can also be far slower, since tricks like JPEG shrink-on-load
    cannot be used in linear space.

  * `:resize` determines if an image may be only upsized, only
    downsized, both or a forced aspect ratio is applied. The value
    may be one of `:up`, `:down`, `:both` or `:force`. The default
    is `:both`.

  ### Returns

  * `{:ok, thumbnailed_image}` or

  * `{:error, reason}`

  """
  @doc subject: "Resize"

  @spec thumbnail(Vimage.t(), length :: pos_integer(), options :: Thumbnail.thumbnail_options()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def thumbnail(image_or_path, length, options \\ [])

  def thumbnail(%Vimage{} = image, length, options) when is_size(length) do
    with {:ok, options} <- Thumbnail.validate_options(options) do
      Operation.thumbnail_image(image, length, options)
    end
  end

  @spec thumbnail(Path.t(), length :: pos_integer(), options :: Thumbnail.thumbnail_options()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def thumbnail(image_path, length, options) when is_binary(image_path) and is_size(length) do
    with {:ok, options} <- Thumbnail.validate_options(options),
         {:ok, _path} <- file_exists?(image_path) do
      Operation.thumbnail(image_path, length, options)
    else
      {:error, _reason} = error -> error
    end
  end

  @spec thumbnail(
          Vimage.t() | Path.t(),
          dimensions :: binary(),
          options :: Thumbnail.thumbnail_options()
        ) ::
          {:ok, Vimage.t()} | {:error, error()}

  def thumbnail(image_or_path, dimensions, options) when is_binary(dimensions) do
    with {:ok, length, options} <- Thumbnail.validate_dimensions(dimensions, options) do
      thumbnail(image_or_path, length, options)
    end
  end

  @doc """
  Thumbnail an image to fit or fill a bounding box
  returning an image or raising an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` or a
    pathname to an image file.

  * `length` is the integer length of the longest
    side of the resulting image after resizing. It c
    an also be of the form "<width>x<height>". That
    is, a string with the width and height separated
    by an `x`. The `<height>` may be omitted in which
    case it is the same as providing an integer length.

  * `options` is a keyword list of options.
    See `Image.thumbnail/3`.

  ### Returns

  * `image` or

  * raises an exception.

  """
  @doc subject: "Resize"

  @spec thumbnail!(Vimage.t(), length :: pos_integer(), options :: Thumbnail.thumbnail_options()) ::
          Vimage.t() | no_return()

  def thumbnail!(image_or_path, length, options \\ [])

  def thumbnail!(%Vimage{} = image, length_or_dimensions, options) do
    case thumbnail(image, length_or_dimensions, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @spec thumbnail!(Path.t(), length :: pos_integer(), options :: Thumbnail.thumbnail_options()) ::
          Vimage.t() | no_return()

  def thumbnail!(image_path, length, options) when is_binary(image_path) and is_size(length) do
    with {:ok, options} <- Thumbnail.validate_options(options),
         {:ok, _path} <- file_exists?(image_path) do
      Operation.thumbnail!(image_path, length, options)
    else
      {:error, %Image.Error{} = error} -> raise error
    end
  end

  @spec thumbnail!(
          Vimage.t() | Path.t(),
          dimensions :: binary(),
          options :: Thumbnail.thumbnail_options()
        ) ::
          Vimage.t() | no_return()

  def thumbnail!(image_or_path, dimensions, options) when is_binary(dimensions) do
    with {:ok, length, options} <- Thumbnail.validate_dimensions(dimensions, options) do
      thumbnail!(image_or_path, length, options)
    end
  end

  @doc """
  Make a circular, squircular or square image intended to be used
  as an avatar image.

  The image is resized and all metadata is removed
  from the image. The image will be cropped to a square
  shape and then depending on the `:shape` option
  a circular or squircular mask may be applied.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options. The
    default is `[shape: :circle, crop: :none, size: #{Image.Options.Avatar.default_avatar_size()}]`.

  ### Options

  * `:size` is the diameter in pixels of the avatar (in the case of
    `shape: :circle` or `shape; :squircle`. It is the width/height in
    pixels in the case of a `shape: :square` avatar.
    The default value is `#{Image.Options.Avatar.default_avatar_size()}`.

  * `:shape` defines shape of the avatar
    which can be either `:circle` (the default), `:squircle`
    or `:square`.  In each case the image is first
    cropped to a square shape. Then if the
    format is `:circle` or `:squircle` an appropriate image
    mask is applied.

  * `:crop_focus` is one of `:center`, `:entropy`,
    `:attention`, `:low`, `:high`. The default is `:center`.
    For details see `t:Image.Options.Crop.crop_focus/0`.

  ### Returns

  * `{:ok, avatar_image}` or

  * `{:error, reason}`

  """
  @doc subject: "Generator"

  @spec avatar(Vimage.t(), options :: Options.Avatar.avatar_options()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def avatar(image, options \\ [])

  def avatar(%Vimage{} = image, options) do
    with {:ok, options} <- Options.Avatar.validate_options(options),
         {:ok, size} <- calculate_size_from_option(image, options[:size]),
         {:ok, image} <- thumbnail(image, size, thumbnail_options(options)),
         {:ok, flattened} <- flatten(image) do
      do_avatar(flattened, size, options[:shape])
    end
  end

  def avatar(image_path, options) when is_binary(image_path) do
    with {:ok, options} <- Options.Avatar.validate_options(options),
         {:ok, image_path} <- file_exists?(image_path),
         {:ok, thumbnail} <- thumbnail(image_path, options[:size], thumbnail_options(options)),
         {:ok, image} <- maybe_resize(thumbnail, options[:size]),
         {:ok, flattened} <- flatten(image) do
      do_avatar(flattened, options[:size], options[:shape])
    end
  end

  @doc """
  Make a circular, squircular or square image intended to be used
  as an avatar image or raise an exception.

  The image is resized and all metadata is removed
  from the image. The image will be cropped to a square
  shape and then depending on the `:shape` option
  a circular or squirclar mask may be applied.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options. The
    default is `[shape: :circle, crop: :none, size: #{Image.Options.Avatar.default_avatar_size()}]`.

  ### Options

  * `:size` is the diameter in pixels of the avatar (in the case of
    `shape: :circle` or `shape; :squircle`. It is the width/height in
    pixels in the case of a `shape: :square` avatar.
    The default value is `#{Image.Options.Avatar.default_avatar_size()}`.

  * `:shape` defines shape of the avatar
    which can be either `:circle` (the default), `:squircle`
    or `:square`.  In each case the image is first
    cropped to a square shape. Then if the
    format is `:circle` or `:squircle` an appropriate image
    mask is applied.

  * `:crop_focus` is one of `:center`, `:entropy`,
    `:attention`, `:low`, `:high`. The default is `:center`.
    For details see `t:Image.Options.Crop.crop_focus/0`.

  ### Returns

  * `avatar_image` or

  * raises an exception.

  """
  @doc subject: "Generator"

  @spec avatar!(Vimage.t(), options :: Options.Avatar.avatar_options()) ::
          Vimage.t() | no_return()

  def avatar!(image, options \\ []) do
    case avatar(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  # All avatars start out square then a mask is
  # applied to form the final shape.

  defp do_avatar(image, size, :square) do
    {:ok, squared} = center_crop(image, size, size)
    remove_metadata(squared)
  end

  defp do_avatar(image, size, :squircle) do
    {:ok, squared} = center_crop(image, size, size)
    {:ok, image} = squircle(squared)
    remove_metadata(image)
  end

  defp do_avatar(image, size, :circle) do
    {:ok, squared} = center_crop(image, size, size)
    {:ok, image} = circle(squared)
    remove_metadata(image)
  end

  # thumbnail/2 takes a size argument but its to establish the
  # length of the *maxixum** side. We need the size of the *minimum*
  # size

  defp calculate_size_from_option(image, size) do
    width = Image.width(image)
    height = Image.height(image)

    if width < size || height < size do
      {:ok, round(size * max(width, height) / min(width, height))}
    else
      {:ok, size}
    end
  end

  # when thumnailing an image froma a file path we cannot
  # know the length of the small size so we have to potentially
  # resize the image after thumbnailing.

  defp maybe_resize(image, size) do
    width = Image.width(image)
    height = Image.height(image)

    if width < size || height < size do
      scale = max(width, height) / min(width, height)
      resize(image, scale)
    else
      {:ok, image}
    end
  end

  defp thumbnail_options(options) do
    options
    |> Keyword.delete(:shape)
    |> Keyword.delete(:size)
  end

  @doc """
  Crop an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `left` is the top edge of crop area as an
    integer or a float in the range `-1.0..1.0`.
    If `left` is an integer it is the absolute number
    of pixels. If `left` is a float it's a fraction of the width
    of the image. If `left` is positive it is relative to
    the left edge of the image. If it's negative it's
    relative to the right edge of the image. `left` may
    also be one of `:left`, `:center` and `:right`
    indicating the crop is relative to the left, center
    or right of the image.

  * `top` is the top edge of crop area as an
    integer or a float in the range `-1.0..1.0`.
    If `top` is an integer it is the absolute number of
    pixels. If `top` is a float it's a fraction of the height
    of the image. If `top` is positive it is relative to
    the top edge of the image. If it's negative it's
    relative to the bottom edge of the image. `top` may
    also be one of `:top`, `:middle` and `:bottom`
    indicating the crop is relative to the top, middle
    or bottom of the image.

  * `width` is the width of area remaining as a
    positive integer or float in the range `0.0..1.0`.
    If `width` is an integer it is the absolute number
    of pixels. If `width` is a float it's the fraction
    of the original image width.

  * `height` is the width of area remaining as a
    positive integer or float in the range `0.0..1.0`.
    If `height` is an integer it's the absolute number
    of pixels. If `height` is a float it's the fraction
    of the original image height.

  ### Notes

  * `left` is 0-indexed. That is, the leftmost
    edge of the image starts at `0`.

  * `top` is 0-indexed. That is, the topmost
    edge of the image starts at `0`.

  * If the image has multiple pages, like an animated
    `.gif` or `.webp` then each page is extracted,
    cropped and then the image reassembled.

  ### Returns

  * `{:ok, cropped_image}` or

  * `{:error, reason}`

  """

  # The shenanigans below is to avoid infinite recursion or
  # hard-to-explain errors if `Image.map_pages/2` is called with
  # `Image.crop/5` as its function argument.

  @doc subject: "Crop"

  @spec crop(
          image :: Vimage.t(),
          left :: x_location(),
          top :: y_location(),
          width :: pos_integer(),
          height :: pos_integer()
        ) ::
          {:ok, Vimage.t()} | {:error, error()}

  def crop(%Vimage{} = image, left, top, width, height) do
    total_height = height(image)
    dims = {width(image), total_height}

    with {left, top, width, height} <- Options.Crop.normalize_box(dims, left, top, width, height) do
      case page_height(image) do
        {:ok, page_height} ->
          if total_height == page_height do
            Operation.extract_area(image, left, top, width, height)
          else
            pages = pages(image)
            map_join_pages(image, &Operation.extract_area(&1, left, top, width, height), pages)
          end

        {:error, _} ->
          Operation.extract_area(image, left, top, width, height)
      end
    end
  end

  @doc """
  Crop an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `quadrilateral` is a list of four 2-tuples
    representing the points of the bounding rectangle. The
    points must be ordered as `[top_left, top_right, bottom_right, bottom_left]`
    Each point is of the form `{x, y}` where `x` is the
    0-based offset from the left of the image and `y` is
    the 0-based offset from the top of the image.

  ### Returns

  * `{:ok, cropped_image}` or

  * `{:error, reason}`

  ### Note

  The bounding box must be a rectangle, not an
  arbitrary quadrilateral. If required, use `Image.warp_perspective/4`
  prior to cropping.

  """
  @doc subject: "Crop", since: "0.28.0"

  @spec crop(Vimage.t(), quadrilateral()) :: {:ok, Vimage.t()} | {:error, error()}
  def crop(%Vimage{} = image, [top_left, top_right, bottom_right, bottom_left] = quadrilateral)
      when is_rectangle(top_left, top_right, bottom_right, bottom_left) do
    [{left, top}, _, {bottom_right_x, bottom_right_y}, _] = quadrilateral
    width = bottom_right_x - left + 1
    height = bottom_right_y - top + 1
    crop(image, left, top, width, height)
  end

  def crop(%Vimage{} = _image, quadrilateral) do
    {:error,
     %Image.Error{
       message: "Invalid crop bounding box. Found #{inspect(quadrilateral)}",
       reason: "Invalid crop bounding box. Found #{inspect(quadrilateral)}"
     }}
  end

  @doc """
  Crop an image or raises an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `quadrilateral` is a list of four 2-tuples
    representing the points of the bounding rectangle. The
    points must be ordered as `[top_left, top_right, bottom_right, bottom_left]`
    Each point is of the form `{x, y}` where `x` is the
    0-based offset from the left of the image and `y` is
    the 0-based offset from the top of the image.

  ### Returns

  * `cropped_image` or

  * raises an exception.

  ### Note

  The bounding box must be a rectangle, not an
  arbitrary quadrilateral. If required, use `Image.warp_perspective/4`
  prior to cropping.

  """
  @doc subject: "Crop", since: "0.28.0"

  @spec crop!(Vimage.t(), quadrilateral()) :: Vimage.t() | no_return()
  def crop!(%Vimage{} = image, quadrilateral) do
    case crop(image, quadrilateral) do
      {:ok, cropped} -> cropped
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Crop an image returning a cropped image
  or raising an exception.

  ### Arguments

  * `left` is the top edge of crop area as an
    integer or a float in the range `-1.0..1.0`.
    If `left` is an integer it is the absolute number
    of pixels. If `left` a float is fraction of the width
    of the image. If `left` is positive it is relative to
    the left edge of the image. If it is negative it is
    relative to the right edge of the image. `left` may
    also be one of `:left`, `:center` and `:right`
    indicating the crop is relative to the left, center
    or right of the image.

  * `top` is the top edge of crop area as an
    integer or a float in the range `-1.0..1.0`.
    If `top` is an integer it is the absolute number of
    pixels. If `top` is a float is fraction of the height
    of the image. If `top` is positive it is relative to
    the top edge of the image. If it is negative it is
    relative to the bottom edge of the image. `top` may
    also be one of `:top`, `:middle` and `:bottom`
    indicating the crop is relative to the top, middle
    or bottom of the image.

  * `width` is the width of area remaining as a
    positive integer or float in the range `0.0..1.0`.
    If `width` is an integer it is the absolute number
    of pixels. If `width` is a float it is the fraction
    of the original image width.

  * `height` is the width of area remaining as a
    positive integer or float in the range `0.0..1.0`.
    If `height` is an integer it is the absolute number
    of pixels. If `height` is a float it is the fraction
    of the original image height.

  ### Returns

  * `cropped_image` or

  * raises an exception.

  """
  @doc subject: "Crop"

  @spec crop!(
          image :: Vimage.t(),
          left :: x_location(),
          top :: y_location(),
          width :: pos_integer(),
          height :: pos_integer()
        ) ::
          Vimage.t() | no_return

  def crop!(%Vimage{} = image, left, top, width, height) do
    case crop(image, left, top, width, height) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Crops the center from an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `width` is the width of area remaining as a
    positive integer or float in the range `0.0..1.0`.
    If `width` is an integer it is the absolute number
    of pixels. If `width` is a float it is the fraction
    of the original image width.

  * `height` is the width of area remaining as a
    positive integer or float in the range `0.0..1.0`.
    If `height` is an integer it is the absolute number
    of pixels. If `height` is a float it is the fraction
    of the original image height.

  ### Notes

  * An error will be returned if `width` and `height` are
    not equal to or smaller than the `image` dimensions.

  * This function is a convenience function equivalent to
    calling `Image.crop(image, :center, :middle, width, height)`.

  ### Returns

  * `{:ok, cropped_image}` or

  * `{:error, reason}`.

  """
  @doc subject: "Crop", since: "0.27.0"

  @spec center_crop(image :: Vimage.t(), width :: pos_integer(), height :: pos_integer()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def center_crop(%Vimage{} = image, width, height) do
    crop(image, :center, :middle, width, height)
  end

  @doc """
  Crops the center from an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `width` is the width of area remaining as a
    positive integer or float in the range `0.0..1.0`.
    If `width` is an integer it is the absolute number
    of pixels. If `width` is a float it is the fraction
    of the original image width.

  * `height` is the width of area remaining as a
    positive integer or float in the range `0.0..1.0`.
    If `height` is an integer it is the absolute number

    of pixels. If `height` is a float it is the fraction
    of the original image height.

  ### Notes

  * An error will be returned if `width` and `height` are
    not equal to or smaller than the `image` dimensions.

  * This function is a convenience function equivalent to
    calling `Image.crop!(image, :center, :middle, width, height)`.

  ### Returns

  * `cropped_image` or

  * raises an exception.

  """
  @doc subject: "Crop", since: "0.27.0"

  @spec center_crop!(Vimage.t(), pos_integer(), pos_integer()) ::
          Vimage.t() | no_return()

  def center_crop!(%Vimage{} = image, crop_width, crop_height) do
    case center_crop(image, crop_width, crop_height) do
      {:ok, cropped} -> cropped
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Embeds an image in a larger image canvas, generating
  addition border pixels if required.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `width` is the width in pixels of the canvas
    image.

  * `height` is the height in pixels of the canvas
    image.

  * `options` is a keyword list of options.

  ### Options

  * `:x` is the x-offset into the canvas image
    where `image` will be embedded. The value may be
    a positive integer indicating a 0-based offset from
    the left of the canvas or a negative integer indicating
    a 1-based offset from the right side of the image.
    It may also be `:center` (the default) in which case the
    image will be centered horizontally within the canvas.

  * `:y` is the y-offset into the canvas image
    where `image` will be embedded. The value may be
    a positive integer indicating a 0-based offset from
    the top of the canvas or a negative integer indicating
    a 1-based offset from the bottom of the image.
    It may also be `:center` (the default) in which case the
    image will be centered vertically within the canvas.

  * `:background_color` defines the color of the generated background
    pixels. This can be specified as a single integer which will
    be applied to all bands, or a list of integers representing
    the color for each band. The color can also be supplied as a
    CSS color name as a string or atom. For example: `:misty_rose`.
    It can also be supplied as a hex string of
    the form `#rrggbb`. The default is `:black`. `:background` can
    also be set to `:average` in which case the background will be
    the average color of the base image. See also `Color.new/2`
    from the Color library.

  * `:background_transparency` defines the transparency of the
    `:background` pixels when `image` has an alpha band.
    The default is `:opaque`. The values are an integer in the
    range `0..255` where `0` is transparent and `255` is opaque.
    The number can also be a float in the range `0.0` to `1.0`.
    In this case the float is converted to an integer in the range
    `0..255`. Lastly, the atoms `:transparent` and `:opaque` can
    also be used.

  * `:extend_mode` determines how any additional pixels
    are generated. The values are:

    * `:black` (the default if no `background_color` is specified)
      meaning the generated pixels are black.
    * `:white` meaning the generated pixels are white.
    * `:copy` means the generated pixels take the value of the
      nearest edge pixel of the base image.
    * `:repeat` means the generated pixels are tiles from the
      base image.
    * `:mirror` means the generated pixels are reflected tiles of
      the base image.
    * `:background` means the generated pixels are the `:background_color`
      color set in `options`. This is the default if a `background_color`
      is specified.

  ### Returns

  * `{:ok, embedded_image}` or

  * `{:error, reason}`

  """
  @doc subject: "Resize", since: "0.27.0"

  @spec embed(
          image :: Vimage.t(),
          width :: non_neg_integer(),
          height :: non_neg_integer(),
          options :: Options.Embed.embed_options()
        ) ::
          {:ok, Vimage.t()} | {:error, error()}

  def embed(image, width, height, options \\ []) do
    with {:ok, options} <- Options.Embed.validate_options(image, width, height, options) do
      embed_options = [background: options.background_color, extend: options.extend_mode]
      Operation.embed(image, options.x, options.y, width, height, embed_options)
    end
  end

  @doc """
  Embeds an image in a larger image canvas, generating
  addition border pixels if required.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `width` is the width in pixels of the canvas
    image.

  * `height` is the height in pixels of the canvas
    image.

  * `options` is a keyword list of options.

  ### Options

  See `Image.embed/4`.

  ### Returns

  * `embedded_image` or

  * raises an exception.

  """
  @doc subject: "Operation", since: "0.27.0"

  @spec embed!(Vimage.t(), non_neg_integer(), non_neg_integer(), Options.Embed.embed_options()) ::
          Vimage.t() | no_return

  def embed!(image, width, height, options \\ []) do
    case embed(image, width, height, options) do
      {:ok, embedded} -> embedded
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Replace one color in an image with another.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  With the exception of the option `:replace_with`, the
  options for specifying the color or color range
  to be replaced are passed to `Image.chroma_mask/2`.

  * `:blend` is a boolean indicating if a the replacement
    should blend at the border of the color replacement.
    The default is `false`.

  * `:replace_with` is the replacement color.  This can be specified as
    a single integer which wil be applied to all bands, or a
    list of integers representing the color for each band. The
    color can also be supplied as a CSS color name as a string or
    atom. For example: `:misty_rose`. It can also be supplied as a
    hex string of the form `#rrggbb`. The default is `:black`.
    See also `Color.new/2` from the Color library.

  There are two strategies available for selecting the
  color or color range to be replaced: the
  thresholding strategy (default) and the color
  range strategy.

  #### Threshold strategy

  * `:color` is an RGB color which represents the the
    chroma key to be selected. The color can be an
    integer between `0..255`, a three-element list of
    integers representing an RGB color or an atom
    representing a CSS color name. The default is
    `:auto` in which the average of the top left `10x10`
    pixels of the image is used.

  * `:threshold`is a positive integer to indicate the
    threshold around `:color` when calculating the mask.
    The default is `20`.

  #### Color range strategy

  * `:greater_than` is an RGB color which represents the upper
     end of the color range to be selected. The color can be an
     integer between `0..255`, a three-element list of
     integers representing an RGB color or an atom
     representing a CSS color name.

  * `:less_than` is an RGB color which represents the lower
     end of the color range to be selected. The color can be an
     integer between `0..255`, a three-element list of
     integers representing an RGB color or an atom
     representing a CSS color name.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`.

  """
  @doc since: "0.30.0", subject: "Color"

  @spec replace_color(Vimage.t(), ChromaKey.chroma_key_options() | [{:replace_with, Pixel.t()}]) ::
          {:ok, Vimage.t()} | {:error, error()}

  def replace_color(%Vimage{} = image, options \\ []) do
    {to_color, options} = Keyword.pop(options, :replace_with, :black)
    {blend, options} = Keyword.pop(options, :blend, false)
    xres = Vix.Vips.Image.xres(image)
    yres = Vix.Vips.Image.yres(image)

    with {:ok, to_color} <- Pixel.to_pixel(image, to_color),
         {:ok, chroma_mask} <- chroma_mask(image, options),
         {:ok, inverted} <- Operation.invert(chroma_mask),
         {:ok, blend} = if_then_else(inverted, to_color, image, blend: blend) do
      Operation.copy(blend, xres: xres, yres: yres)
    end
  end

  @doc """
  Replace one color in an image with another or
  raises an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  With the exception of the option `:replace_with`, the
  options for specifying the color or color range
  to be replaced are passed to `Image.chroma_mask/2`.

  * `:replace_with` is the replacement color.  This can be specified as
    a single integer which wil be applied to all bands, or a
    list of integers representing the color for each band. The
    color can also be supplied as a CSS color name as a string or
    atom. For example: `:misty_rose`. It can also be supplied as a
    hex string of the form `#rrggbb`. The default is `:black`.
    See also `Color.new/2` from the Color library.

  There are two strategies available for selecting the
  color or color range to be replaced: the
  thresholding strategy (default) and the color
  range strategy.

  #### Threshold strategy

  * `:color` is an RGB color which represents the the
    chroma key to be selected. The color can be an
    integer between `0..255`, a three-element list of
    integers representing an RGB color or an atom
    representing a CSS color name. The default is
    `:auto` in which the average of the top left `10x10`
    pixels of the image is used.

  * `:threshold`is a positive integer to indicate the
    threshold around `:color` when calculating the mask.
    The default is `20`.

  #### Color range strategy

  * `:greater_than` is an RGB color which represents the upper
     end of the color range to be selected. The color can be an
     integer between `0..255`, a three-element list of
     integers representing an RGB color or an atom
     representing a CSS color name.

  * `:less_than` is an RGB color which represents the lower
     end of the color range to be selected. The color can be an
     integer between `0..255`, a three-element list of
     integers representing an RGB color or an atom
     representing a CSS color name.

  ### Returns

  * `image` or

  * raises an exception.

  """
  @doc since: "0.30.0", subject: "Color"

  @spec replace_color!(Vimage.t(), ChromaKey.chroma_key_options() | [{:replace_with, Pixel.t()}]) ::
          Vimage.t() | no_return()

  def replace_color!(%Vimage{} = image, options \\ []) do
    case replace_color(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Trims an image to the bounding box of the non-background
  area.

  The image is median-filtered, all the row and column sums
  of the absolute difference from background are calculated
  in a single pass.

  Then the first row or column in each of the four directions
  where the sum is greater than threshold gives the bounding
  box that is used to define the crop area.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:background` is the color to be considered
    the background color. The default is automatically
    detected by averaging the pixels at the top
    left of the image. If background is set to
    `:alpha` then the image is trimmed to the size
    of the alpha mask.

  * `:threshold` is the integer threshold (or color
    similarity) that is applied when determining the
    bounds of the non-background area. The default is
    `10`. The default value means only a small color
    background color range is considered.  Increasing
    the threshold value maybe required.

  ### Returns

  * `{:ok, cropped_image}` which is the image
    cropped to the bounding box of the non-background
    area.

  * `{:error, reason}`.  Reason may be
    `:uncropped` which means the image was
    considered to be only the background color.

  """
  @doc subject: "Resize", since: "0.23.0"

  @spec trim(image :: Vimage.t(), options :: Options.Trim.trim_options()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def trim(%Vimage{} = image, options \\ []) do
    case find_trim(image, options) do
      {:ok, {left, top, width, height}} ->
        crop(image, left, top, width, height)

      error ->
        error
    end
  end

  @doc """
  Trims an image to the bounding box of the non-background
  area or raises an exception.

  The image is median-filtered, all the row and column sums
  of the absolute difference from background are calculated
  in a single pass.

  Then the first row or column in each of the four directions
  where the sum is greater than threshold gives the bounding
  box that is used to define the crop area.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:background` is the color to be considered
    the background color. The default is automatically
    detected by averaging the pixels at the top
    left of the image. If background is set to
    `:alpha` then the image is trimmed to the size
    of the alpha mask.

  * `:threshold` is the integer threshold (or color
    similarity) that is applied when determining the
    bounds of the non-background area. The default is
    `10`. The default value means only a small color
    background color range is considered.  Increasing
    the threshold value maybe required.

  ### Returns

  * `cropped_image` which is the image
    cropped to the bounding box of the non-background
    area or

  * raises an exception.

  """
  @doc subject: "Resize", since: "0.23.0"

  @spec trim!(image :: Vimage.t(), options :: Options.Trim.trim_options()) ::
          Vimage.t() | no_return()

  def trim!(%Vimage{} = image, options \\ []) do
    case trim(image, options) do
      {:ok, trimmed} -> trimmed
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Finds the bounding box of the non-background
  area.

  The image is median-filtered, all the row and column sums
  of the absolute difference from background are calculated
  in a single pass.

  Then the first row or column in each of the four directions
  where the sum is greater than threshold gives the bounding
  box.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:background` is the color to be considered
    the background color. The default is automatically
    detected by averaging the pixels at the top
    left of the image. If background is set to
    `:alpha` then the image is trimmed to the size
    of the alpha mask.

  * `:threshold` is the integer threshold (or color
    similarity) that is applied when determining the
    bounds of the non-background area. The default is
    `10`. The default value means only a small color
    background color range is considered.  Increasing
    the threshold value maybe required.

  ### Returns

  * `{:ok, {left, top, width, height}}` which is the bounding box
    of the non-background area or

  * `{:error, reason}`.

  """
  @doc subject: "Resize", since: "0.56.0"

  @spec find_trim(image :: Vimage.t(), options :: Options.Trim.trim_options()) ::
          {:ok, bounding_box()} | {:error, error()}

  def find_trim(%Vimage{} = image, options \\ []) do
    case Keyword.pop(options, :background) do
      {:alpha, other_options} ->
        find_trim_to_alpha(image, other_options)

      _other ->
        find_trim_to_color(image, options)
    end
  end

  defp find_trim_to_color(image, options) do
    with {:ok, options} <- Options.Trim.validate_options(image, options) do
      background = maybe_calculate_color(image, options.background)
      threshold = options.threshold

      case Operation.find_trim(image, background: background, threshold: threshold) do
        {:ok, {_left, _top, 0, 0}} ->
          {:error, nothing_to_trim_error()}

        {:ok, {left, top, width, height}} ->
          {:ok, {left, top, width, height}}

        error ->
          error
      end
    end
  end

  defp find_trim_to_alpha(%Vimage{} = image, options) do
    image
    |> split_alpha()
    |> find_trim_to_alpha(image, options)
  end

  defp find_trim_to_alpha({_other_bands, alpha}, _image, options) when not is_nil(alpha) do
    # find_trim runs against the (1-band) alpha channel itself, so the
    # background must be encoded for that single-band image, not the
    # original multi-band one.
    options = Keyword.put(options, :background, :black)

    with {:ok, options} <- Options.Trim.validate_options(alpha, options) do
      case Operation.find_trim(alpha,
             background: options.background,
             threshold: options.threshold
           ) do
        {:ok, {_left, _top, 0, 0}} ->
          {:error, nothing_to_trim_error()}

        {:ok, {left, top, width, height}} ->
          {:ok, {left, top, width, height}}

        error ->
          error
      end
    end
  end

  defp find_trim_to_alpha({_other_bands, nil}, _image, _options) do
    {:error, {Image.Error, "Image has no alpha band"}}
  end

  defp nothing_to_trim_error do
    {Image.Error, "Could not find anything to trim"}
  end

  @doc """
  Finds the bounding box of the non-background
  area or raises an error.

  The image is median-filtered, all the row and column sums
  of the absolute difference from background are calculated
  in a single pass.

  Then the first row or column in each of the four directions
  where the sum is greater than threshold gives the bounding
  box.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:background` is the color to be considered
    the background color. The default is automatically
    detected by averaging the pixels at the top
    left of the image. If background is set to
    `:alpha` then the image is trimmed to the size
    of the alpha mask.

  * `:threshold` is the integer threshold (or color
    similarity) that is applied when determining the
    bounds of the non-background area. The default is
    `10`. The default value means only a small color
    background color range is considered.  Increasing
    the threshold value maybe required.

  ### Returns

  * `{left, top, width, height}` which is the bounding box
    of the non-background area or

  * raises an exception.

  """
  @doc subject: "Resize", since: "0.56.0"

  @spec find_trim!(image :: Vimage.t(), options :: Options.Trim.trim_options()) ::
          bounding_box() | no_return()

  def find_trim!(%Vimage{} = image, options \\ []) do
    case find_trim(image, options) do
      {:ok, bounding_box} -> bounding_box
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Flatten an alpha layer out of an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:background_color` is an RGB color which is used
    to fill the transparent parts of the image.. The color
    can be an integer between `0..255`, a three-element list of
    integers representing an RGB color or an atom
    representing a CSS color name. The default is `:black`.

  ### Returns

  * `{:ok, flattened_image}` or

  * `{:error, reason}`

  """
  @doc subject: "Operation", since: "0.23.0"

  @spec flatten(image :: Vimage.t(), options :: Keyword.t()) ::
          {:ok, Vimage.t()} | {:error, error()}
  def flatten(%Vimage{} = image, options \\ []) do
    background_color = Keyword.get(options, :background_color, :black)

    with {:ok, background_color} <- Pixel.to_pixel(image, background_color) do
      if has_alpha?(image) do
        # Flatten strips alpha and replaces it with the background; the
        # background must therefore be the opaque colour part only.
        bands = Vix.Vips.Image.bands(image) - 1
        Vix.Vips.Operation.flatten(image, background: Enum.take(background_color, bands))
      else
        {:ok, image}
      end
    end
  end

  @doc """
  Flatten an alpha layer out of an image
  or raises an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:background_color` is an RGB color which is used
    to fill the transparent parts of the image.. The color
    can be an integer between `0..255`, a three-element list of
    integers representing an RGB color or an atom
    representing a CSS color name. The default is `:black`.

  ### Returns

  * `flattened_image` or

  * raises an exception

  """
  @doc subject: "Operation", since: "0.23.0"

  @spec flatten!(image :: Vimage.t(), options :: Keyword.t()) :: Vimage.t() | no_return()
  def flatten!(%Vimage{} = image, options \\ []) do
    case flatten(image, options) do
      {:ok, flattened} -> flattened
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Dilate an image mask, adding a pixels to the
  edge of the mask.

  Mask is used in the sense of an image, potentially
  wuth an alpha band. The results on
  other image types is undefined.

  The added pixels are the same color as the edge
  pixels in the mask.

  ### Arguments

  * `image` is any non-complex `t:Vix.Vips.Image.t/0`.

  * `radius` is an integer in the range `#{inspect(@rank_radius_range)}`
    representing the approximate number of
    pixels to dilate. The default is `1`.

  ### Returns

  * `{:ok, dilated_mask}` or

  * `{:error, reason}`

  ### Notes

  * Dilate works for any non-complex image type, with any
    number of bands. The input is dilated by copying
    edge pixels before performing the operation so that
    the output image has the same size as the input.

  * Edge pixels in the output image are only
    approximate.

  * The dilation is implemented as a [rank filter](https://www.sciencedirect.com/science/article/abs/pii/S0031320301000474?via%3Dihub).

  """

  # A rank filter is used since it will operate on a
  # greyscale image such as a mask.

  # The libvips morphological operators work on binary
  # images only (pixel is either black or white).

  # See also the discussions at:
  #  https://github.com/libvips/libvips/discussions/2345
  #  https://github.com/libvips/libvips/discussions/3108
  #  https://github.com/libvips/libvips/discussions/2123
  #  https://github.com/libvips/ruby-vips/issues/159

  @doc subject: "Operation", since: "0.23.0"

  @spec dilate(image :: Vimage.t(), radius :: pos_integer) ::
          {:ok, Vimage.t()} | {:error, error()}

  def dilate(image, radius \\ 1) when is_integer(radius) and radius in @rank_radius_range do
    radius = radius + radius * 2
    index = radius * radius - 1
    Vix.Vips.Operation.rank(image, radius, radius, index)
  end

  @doc """
  Dilate an image mask, adding a pixels to the
  edge of the mask or raising an exception.

  Mask is used in the sense of an image, potentially
  wuth an alpha band. The results on
  other image types is undefined.

  The added pixels are the same color as the edge
  pixels in the mask.

  ### Arguments

  * `image` is any non-complex `t:Vix.Vips.Image.t/0`.

  * `radius` is an integer in the range `#{inspect(@rank_radius_range)}`
    representing the approximate number of
    pixels to dilate. The default is `1`.

  ### Returns

  * `dilated_mask` or

  * raises an exception.

  ### Notes

  * Dilate works for any non-complex image type, with any
    number of bands. The input is dilated by copying
    edge pixels before performing the operation so that
    the output image has the same size as the input.

  * Edge pixels in the output image are only
    approximate.

  * The dilation is implemented as a [rank filter](https://www.sciencedirect.com/science/article/abs/pii/S0031320301000474?via%3Dihub).

  """
  @doc subject: "Operation", since: "0.23.0"

  @spec dilate!(image :: Vimage.t(), radius :: pos_integer) :: Vimage.t() | no_return()
  def dilate!(%Vimage{} = image, radius \\ 1)
      when is_integer(radius) and radius in @rank_radius_range do
    case dilate(image, radius) do
      {:ok, dilated} -> dilated
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Erode an image mask, removing pixels from the
  edge of the mask.

  Mask is used in the sense of an image, potentially
  with an alpha band. The results on
  other image types is undefined.

  ### Arguments

  * `image` is any non-complex-number `t:Vix.Vips.Image.t/0`.

  * `radius` is an integer in the range `#{inspect(@rank_radius_range)}`
    representing the approximate number of
    pixels to erode. The default is `1`.

  ### Returns

  * `{:ok, eroded_mask}` or

  * `{:error, reason}`

  ### Notes

  * Erode works for any non-complex-number image type with any
    number of bands. The input is eroded by copying
    edge pixels before performing the operation so that
    the output image has the same size as the input.

  * Edge pixels in the output image are only
    approximate.

  * The erosion is implemented as a [rank filter](https://www.sciencedirect.com/science/article/abs/pii/S0031320301000474?via%3Dihub).

  """
  @doc subject: "Operation", since: "0.23.0"

  @spec erode(image :: Vimage.t(), radius :: pos_integer()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def erode(image, radius \\ 1) when is_integer(radius) and radius in @rank_radius_range do
    radius = radius + radius * 2
    Vix.Vips.Operation.rank(image, radius, radius, 0)
  end

  @doc """
  Erode an image mask, removing pixels from the
  edge of the mask or raising an exception.

  Mask is used in the sense of an image, potentially
  with an alpha band. The results on
  other image types is undefined.

  ### Arguments

  * `image` is any non-complex-number `t:Vix.Vips.Image.t/0`.

  * `radius` is an integer in the range `#{inspect(@rank_radius_range)}`
    representing the approximate number of
    pixels to erode. The default is `1`.

  ### Returns

  * `eroded_mask` or

  * raises an exception

  ### Notes

  * Erode works for any non-complex-number image type with any
    number of bands. The input is eroded by copying
    edge pixels before performing the operation so that
    the output image has the same size as the input.

  * Edge pixels in the output image are only
    approximate.

  * The erosion is implemented as a [rank filter](https://www.sciencedirect.com/science/article/abs/pii/S0031320301000474?via%3Dihub).

  """
  @doc subject: "Operation", since: "0.23.0"

  @spec erode!(image :: Vimage.t(), radius :: pos_integer()) :: Vimage.t() | no_return()
  def erode!(%Vimage{} = image, radius \\ 1)
      when is_integer(radius) and radius in @rank_radius_range do
    case erode(image, radius) do
      {:ok, eroded} -> eroded
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Rotate an image clockwise (to the
  right) by a number of degrees.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `angle` is a `float` number of degrees
    to rotate in a clockwise direction.

  * `options` is a keyword list of options.

  ### Options

  * `:idy` is the vertical input displacement which
    defaults to `0.0`

  * `:idx` is the horizontal input displacement which
    defaults to `0.0`

  * `:ody` is the vertical output displacement
    which defaults to `0.0`

  * `:odx` is the horizontal output displacement
    which defaults to `0.0`

  * `:background` is the background color to be used for filling
    the blank areas of the image. The background is specified as
    a list of 3 or 4 float values depending on the image
    color space.

  ## Notes

  The displacement parameters cause the image canvas to be
  expanded and the image displaced, relative to the top left
  corner of the image, by the amount specified.

  The rules defining how the image canvas is expanded
  is not known to the author of `Image`. Experimentation will
  be required if you explore these options.

  ### Returns

  * `{:ok, rotated_image}` or

  * `{:error, reason}`

  """
  @doc subject: "Operation"

  @spec rotate(
          image :: Vimage.t(),
          angle :: float(),
          options :: Options.Rotate.rotation_options()
        ) ::
          {:ok, Vimage.t()} | {:error, error()}

  def rotate(%Vimage{} = image, angle, options \\ []) when is_number(angle) do
    with {:ok, options} <- Options.Rotate.validate_options(options) do
      Operation.rotate(image, angle, options)
    end
  end

  @doc """
  Rotate an image clockwise (to the
  right) by a number of degrees.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `angle` is a `float` number of degrees
    to rotate in a clockwise direction.

  * `options` is a keyword list of options.
    See `Image.rotate/3`.

  ## Notes

  The displacement parameters cause the image canvas to be
  expanded and the image displaced, relative to the top left
  corner of the image, by the amount specified.

  The rules defining how the image canvas is expanded
  is not known to the author of `Image`. Experimentation will
  be required if you explore these options.

  ### Returns

  * `rotated_image` or

  * raises an exception.

  """
  @doc subject: "Operation"

  @spec rotate!(
          image :: Vimage.t(),
          angle :: float(),
          options :: Options.Rotate.rotation_options()
        ) ::
          Vimage.t() | no_return()

  def rotate!(%Vimage{} = image, angle, options \\ []) when is_number(angle) do
    case rotate(image, angle, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Rotate an image based upon the orientation
  information in an image's EXIF data.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, {auto_rotated_image, flags}}` or

  * `{:error, reason}`

  ### Flags

  A two-entry `Keyword.t` is returned indicating what actions
  were taken:

  * `:flip` which is a boolean indicating if the image
    was flipped or not and

  * `:angle` through which the image was rotated.
    This value will be one of `0`, `90`, `180` or
    `270` representing the degrees of rotation.

  """
  @doc subject: "Operation"

  @spec autorotate(image :: Vimage.t()) ::
          {:ok, {Vimage.t(), map()}} | {:error, error()}

  def autorotate(%Vimage{} = image) do
    case Operation.autorot(image) do
      {:ok, {image, flags}} ->
        {:ok, {image, decode_rotation_flags(flags)}}

      other ->
        other
    end
  end

  @rotation_encoding %{
    VIPS_ANGLE_D0: 0,
    VIPS_ANGLE_D90: 90,
    VIPS_ANGLE_D180: 180,
    VIPS_ANGLE_D270: 270
  }

  defp decode_rotation_flags(flags) do
    angle = Map.fetch!(flags, :angle)
    angle = Map.fetch!(@rotation_encoding, angle)

    Map.put(flags, :angle, angle)
  end

  @doc """
  Rotate an image based upon the orientation
  information in an image's EXIF data. Returns
  a potentially rotated image or raises and
  exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `auto_rotated_image` or

  * raises an exception.

  """
  @doc subject: "Operation"

  @spec autorotate!(image :: Vimage.t()) ::
          Vimage.t() | no_return()

  def autorotate!(image) do
    case autorotate(image) do
      {:ok, {image, _flags}} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Overrides an image's EXIF orientation tag without rotating
  the underlying pixel data.

  EXIF orientation is a 1–8 enum that tells viewers how to
  display the stored pixels (1 = no transform, 3 = rotate 180°,
  6 = rotate 90° clockwise, 8 = rotate 90° counter-clockwise,
  even values mirror as well). `set_orientation/2` rewrites
  this metadata field in place. Combine with `Image.open/2`'s
  default `autorotate: false` to keep the image orientation
  under your control across the load → process → write
  pipeline.

  Imgix's `or=<n>` and similar CDN parameters use this to let
  callers ignore or override the orientation a camera burned
  into a JPEG.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `orientation` is an integer in `1..8`. See the [EXIF
    orientation reference](https://magnushoff.com/articles/jpeg-orientation/)
    for the visual meaning of each value.

  ### Returns

  * `{:ok, image_with_orientation}` or

  * `{:error, reason}`.

  ### Example

      iex> image = Image.open!("./test/support/images/Hong-Kong-2015-07-1998.jpg")
      iex> {:ok, rotated_metadata} = Image.set_orientation(image, 6)
      iex> Vix.Vips.Image.header_value(rotated_metadata, "orientation")
      {:ok, 6}

  """
  @doc since: "0.67.0"
  @doc subject: "Metadata"

  @spec set_orientation(image :: Vimage.t(), orientation :: 1..8) ::
          {:ok, Vimage.t()} | {:error, error()}
  def set_orientation(%Vimage{} = image, orientation)
      when is_integer(orientation) and orientation in 1..8 do
    Vimage.mutate(image, fn mut_img ->
      Vix.Vips.MutableImage.set(mut_img, "orientation", :gint, orientation)
    end)
  end

  @doc """
  Overrides an image's EXIF orientation tag, or raises on
  error.

  See `set_orientation/2` for argument documentation.

  """
  @doc since: "0.67.0"
  @doc subject: "Metadata"

  @spec set_orientation!(image :: Vimage.t(), orientation :: 1..8) :: Vimage.t() | no_return()
  def set_orientation!(%Vimage{} = image, orientation) do
    case set_orientation(image, orientation) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Adds a concentric ripple effect to an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, image_with_ripple}` or

  * `{:error, reason}`

  """
  @dialyzer {:nowarn_function, {:ripple, 1}}
  @doc subject: "Operation"

  @spec ripple(Vimage.t()) :: {:ok, Vimage.t()} | {:error, error()}
  def ripple(%Vimage{} = image) do
    use Image.Math

    width = width(image)
    height = height(image)

    # this makes an image where pixel (0, 0) (at the top-left) has value [0, 0],
    # and pixel (image.width, image.height) at the bottom-right has value
    # [image.width, image.height]
    {:ok, index} = Operation.xyz(width, height)

    # make a version with (0, 0) at the centre, negative values up and left,
    # positive down and right
    center = index - [width / 2, height / 2]

    # to polar space, so each pixel is now distance and angle in degrees
    {:ok, polar} = Complex.polar(center)

    # scale sin(distance) by 1/distance to make a wavey pattern
    d = 10_000 * sin!(polar[0] * 3) / (1 + polar[0])

    # and back to rectangular coordinates again to make a set of vectors we can
    # apply to the original index image
    {:ok, joined} = Operation.bandjoin([d, polar[1]])
    {:ok, rectangular} = Complex.rectangular(joined)
    index = index + rectangular

    # finally, use our modified index image to distort the input!
    Operation.mapim(image, index)
  end

  @doc """
  Adds a concentric ripple effect to an image
  returning an image or raising an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `image_with_ripple` or

  * raises an exception.

  """
  @dialyzer {:nowarn_function, {:ripple!, 1}}
  @doc subject: "Operation"

  @spec ripple!(Vimage.t()) :: Vimage.t() | no_return()
  def ripple!(%Vimage{} = image) do
    case ripple(image) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Apply a circular mask to an image.

  The returned image has an alpha
  band masking the circular image.

  As a result, it is best saved to a
  format, like `.png` that supports
  alpha transparency.

  Note that `.jpg` files do not support
  alpha transparency.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, circular_image}` or

  * `{:error, reason}`

  """
  @doc subject: "Mask"

  @spec circle(Vimage.t(), Keyword.t()) :: {:ok, Vimage.t()} | {:error, error()}
  def circle(%Vimage{} = image, _options \\ []) do
    width = width(image)
    height = height(image)
    size = min(width, height)

    {:ok, mask} = mask(:circle, size, size)
    Operation.bandjoin([image, mask])
  end

  @doc """
  Apply a circular mask to an image
  returning an image or raising an
  exception.

  The returned image has an alpha
  band masking the circular image.

  As a result, it is best saved to a
  format, like `.png` that supports
  alpha transparency.

  Note that `.jpg` files do not support
  alpha transparency.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `circular_image` or

  * raises an exception.

  """
  @doc subject: "Mask"

  @spec circle!(Vimage.t(), Keyword.t()) :: Vimage.t() | no_return()
  def circle!(%Vimage{} = image, options \\ []) do
    case circle(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Apply rounded corners to an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:radius` is the desired corner radius.
    The default is #{@default_round_corner_radius}.

  ### Returns

  * `{:ok, rounded_corner_image}` or

  * `{:error, reason}`

  """
  @doc subject: "Mask"

  @spec rounded(Vimage.t(), Keyword.t()) :: {:ok, Vimage.t()} | {:error, error()}
  def rounded(%Vimage{} = image, options \\ []) do
    use Image.Math

    options = Keyword.put_new(options, :radius, @default_round_corner_radius)
    width = width(image)
    height = height(image)

    {:ok, mask} = mask(:rounded_corners, width, height, options)

    case split_alpha(image) do
      {base_image, nil} ->
        Operation.bandjoin([base_image, mask])

      {base_image, alpha} ->
        alpha = if_then_else!(mask == 0, mask, alpha)
        Operation.bandjoin([base_image, alpha])
    end
  end

  @doc """
  Apply rounded corners to an image. Returns
  an image or raises an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:radius` is the desired corner radius.
    The default is #{@default_round_corner_radius}.

  ### Returns

  * `rounded_corner_image` or

  * raises an exception.

  """
  @doc subject: "Mask"

  @spec rounded!(Vimage.t(), Keyword.t()) :: Vimage.t() | no_return()
  def rounded!(%Vimage{} = image, options \\ []) do
    case rounded(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Apply squircle mask to an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:radius` is the desired squircle radius.
    The default is #{@default_squircle_radius}.

  ### Returns

  * `{:ok, squircle_image}` or

  * `{:error, reason}`

  """
  @doc subject: "Generator"

  @spec squircle(Vimage.t(), Keyword.t()) :: {:ok, Vimage.t()} | {:error, error()}
  def squircle(%Vimage{} = image, options \\ []) do
    use Image.Math

    options = Keyword.put_new(options, :radius, @default_squircle_radius)
    width = width(image)
    height = height(image)

    {:ok, mask} = mask(:squircle, width, height, options)

    case split_alpha(image) do
      {base_image, nil} ->
        Operation.bandjoin([base_image, mask])

      {base_image, alpha} ->
        alpha = if_then_else!(mask == 0, mask, alpha)
        Operation.bandjoin([base_image, alpha])
    end
  end

  @doc """
  Apply a squircle mask to an image. Returns
  an image or raises an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:radius` is the desired squircle radius.
    The default is #{@default_squircle_radius}.

  ### Returns

  * `squircle_image` or

  * raises an exception.

  """
  @doc subject: "Mask"

  @spec squircle!(Vimage.t(), Keyword.t()) :: Vimage.t() | no_return()
  def squircle!(%Vimage{} = image, options \\ []) do
    case squircle(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  # Create an image mask (alpha transparency) that can
  # then be applied to an image.

  # At some point this will become a public API.

  defp mask(type, width, height, options \\ [])

  defp mask(:circle, diameter, diameter, _options) do
    centre = div(diameter, 2)

    svg = """
    <svg viewBox="0 0 #{diameter} #{diameter}">
      <circle style="fill: black; stroke: none" cx="#{centre}" cy="#{centre}" r="#{centre}"/>
    </svg>
    """

    {:ok, {circle, _flags}} = Operation.svgload_buffer(svg)
    Operation.extract_band(circle, alpha_band(circle))
  end

  defp mask(:rounded_corners, width, height, options) do
    radius = Keyword.get(options, :radius, @default_round_corner_radius)

    svg = """
    <svg viewBox="0 0 #{width} #{height}">
      <rect rx="#{radius}" ry="#{radius}" x="0" y="0" width="#{width}" height="#{height}" fill="black" />
    </svg>
    """

    {:ok, {mask, _flags}} = Operation.svgload_buffer(svg)
    Operation.extract_band(mask, alpha_band(mask))
  end

  defp mask(:squircle, width, height, options) do
    r = Keyword.get(options, :radius, @default_squircle_radius)
    h2 = div(height, 2)
    w2 = div(width, 2)
    hr = height - r
    wr = width - r

    svg = """
    <svg viewBox="0 0 #{width} #{height}">
      <path d="M 0 #{h2} C 0 #{r}, #{r} 0, #{w2} 0 S #{width} #{r}, #{width} #{h2}, #{wr} #{height} #{w2} #{height}, 0 #{hr}, 0 #{h2}" fill="black" />
    </svg>
    """

    {:ok, {mask, _flags}} = Operation.svgload_buffer(svg)
    Operation.extract_band(mask, alpha_band(mask))
  end

  @doc """
  Minimize metadata by keeping only the artist
  and copyright (if available).

  Removing metadata from an image can greatly reduce
  the overall size of an image. The proportional
  reduction is most noticeable with smaller images
  which are very common in web applications.

  Removing all metadata is a common option however
  with intellectual property concerns in mind
  this function will keep the artist and
  copyright fields if they exist in the original
  image EXIF. Creator/Author/Artist and Copyright in
  other fields like IPTC and XMP are not considered
  in the current implementation.

  On a 1000x500px image exported from Adobe Lightroom
  with metadata intact, removing the metadata
  results in am approximately 50% saving in file
  size due to the removal of most EXIF and all
  IPTC and XMP metadata.

  > #### Note {: .info}
  >
  > the minimized metadata is only materialized when the minimized image is saved.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`

  ### Returns

  * `{:ok, image_with_minimal_metadata}` or

  * `{:error, reason}`

  """
  @doc subject: "Metadata"

  @spec minimize_metadata(image :: Vimage.t()) :: {:ok, Vimage.t()} | {:error, error()}
  def minimize_metadata(%Vimage{} = image) do
    case exif(image) do
      {:ok, exif} ->
        image
        |> remove_metadata!()
        |> put_copyright_and_artist(exif)

      {:error, %Image.Error{reason: "No such field"}} ->
        remove_metadata(image)

      other ->
        other
    end
  end

  defp put_copyright_and_artist(image, exif) do
    Vimage.mutate(image, fn mut_img ->
      if exif[:copyright], do: Exif.put_metadata(mut_img, :copyright, exif[:copyright])
      if exif[:artist], do: Exif.put_metadata(mut_img, :artist, exif[:artist])
      :ok
    end)
  end

  @doc """
  Minimize metadata while keeping a caller-selected subset of
  EXIF fields. Same as `minimize_metadata/1` but lets the
  caller control exactly which fields survive — useful when a
  CDN-style `metadata=copyright` flag should preserve only the
  copyright tag, for example.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:keep` is a list of EXIF field atoms to preserve. Any
    field present on the source image *and* listed in `:keep`
    is rewritten onto the minimised image; everything else is
    stripped. Default `[:copyright, :artist]` (matches
    `minimize_metadata/1`). Pass `[]` to strip every EXIF
    field.

  ### Returns

  * `{:ok, image_with_minimal_metadata}` or

  * `{:error, reason}`.

  ### Example

      iex> image = Image.open!("./test/support/images/Hong-Kong-2015-07-1998.jpg")
      iex> {:ok, _stripped} = Image.minimize_metadata(image, keep: [:copyright])

  """
  @doc subject: "Metadata"
  @doc since: "0.67.0"

  @spec minimize_metadata(image :: Vimage.t(), options :: Keyword.t()) ::
          {:ok, Vimage.t()} | {:error, error()}
  def minimize_metadata(%Vimage{} = image, options) when is_list(options) do
    keep = Keyword.get(options, :keep, [:copyright, :artist])

    case exif(image) do
      {:ok, exif} ->
        image
        |> remove_metadata!()
        |> put_kept_metadata(exif, keep)

      {:error, %Image.Error{reason: "No such field"}} ->
        remove_metadata(image)

      other ->
        other
    end
  end

  @doc """
  Minimize metadata by keeping only the artist
  and copyright (if available).

  See also `Image.minimize_metadata/1`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`

  ### Returns

  * ` image_with_minimal_metadata` or

  * raises an exception.

  """
  @doc subject: "Metadata"

  @spec minimize_metadata!(image :: Vimage.t()) :: Vimage.t() | no_return()
  def minimize_metadata!(%Vimage{} = image) do
    case minimize_metadata(image) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Minimize metadata while keeping a caller-selected subset of
  EXIF fields. Raises on error. See `minimize_metadata/2` for
  argument and option documentation.

  """
  @doc subject: "Metadata"
  @doc since: "0.67.0"

  @spec minimize_metadata!(image :: Vimage.t(), options :: Keyword.t()) ::
          Vimage.t() | no_return()
  def minimize_metadata!(%Vimage{} = image, options) when is_list(options) do
    case minimize_metadata(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  defp put_kept_metadata(image, _exif, []), do: {:ok, image}

  defp put_kept_metadata(image, exif, keep) when is_list(keep) do
    Vimage.mutate(image, fn mut_img ->
      Enum.each(keep, fn field ->
        if value = Map.get(exif, field) do
          Exif.put_metadata(mut_img, field, value)
        end
      end)

      :ok
    end)
  end

  @metadata_fields %{
    exif: "exif-data",
    xmp: "xmp-dataa",
    iptc: "iptc-data"
  }

  @metadata_names Map.keys(@metadata_fields)

  @doc """
  Remove metadata from an image returning
  an updated image or raising an exception.

  This can significantly reduce the size of
  an image file.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`

  * `fields` is a list of metadata field names
    as strings. The default is all known
    field names. There are some special field
    names interpreted by `Image` to simplify
    metadata removal these are:

    * `:exif` which means remove all
      [EXIF](https://en.wikipedia.org/wiki/Exif) metadata
    * `:iptc` which means remove all
      [IPTC](https://en.wikipedia.org/wiki/IPTC_Information_Interchange_Model) metadata
    * `:xmp` which means remove all
      [xmp](https://en.wikipedia.org/wiki/Extensible_Metadata_Platform) data

  ## Notes

  * The available field names (ie. metadata fields)
    in an image can be returned with a call to
    `Vix.Vips.Image.header_field_names/1`.

  * Errors removing metadata fields are not propagated
    into the return for this function. Errors might occur
    when attempting to remove metadata fields that
    do not exist in the image.

  ### Returns

    * `{:ok, image_without_metadata_fields}` or

    * `{:error, reason}`

  """
  @doc subject: "Metadata"

  @spec remove_metadata(Vimage.t(), list(binary() | atom())) ::
          {:ok, Vimage.t()} | {:error, error()}

  def remove_metadata(image, fields \\ [])

  def remove_metadata(image, field) when not is_list(field) do
    remove_metadata(image, List.wrap(field))
  end

  def remove_metadata(image, []) do
    {:ok, fields} = Vimage.header_field_names(image)
    remove_metadata(image, fields)
  end

  def remove_metadata(%Vimage{} = image, fields) when is_list(fields) do
    Vimage.mutate(image, fn mut_img ->
      Enum.each(fields, &remove_meta(mut_img, &1))
    end)
  end

  @doc """
  Remove metadata from an image returning
  an image or raising an exception.

  This can significant;y reduce the size of
  an image file.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`

  * `fields` is a list of metadata field names
    as strings. The default is all known
    field names. There are some special field
    names interpreted by `Image` to simplify
    metadata removal these are:

    * `:exif` which means remove all
      [EXIF](https://en.wikipedia.org/wiki/Exif) metadata
    * `:iptc` which means remove all
      [IPTC](https://en.wikipedia.org/wiki/IPTC_Information_Interchange_Model) metadata
    * `:xmp` which means remove all
      [xmp](https://en.wikipedia.org/wiki/Extensible_Metadata_Platform) data

  ## Notes

  * The available field names (ie. metadata fields)
    in an image can be returned with a call to
    `Vix.Vips.Image.header_field_names/1`.

  * Errors removing metadata fields are not propagated
    into the return for this function. Errors might occur
    when attempting to remove metadata fields that
    do not exist in the image.

  ### Returns

    * `image_without_metadata_fields` or

    * raises an exception.

  """
  @doc subject: "Metadata"

  @spec remove_metadata!(Vimage.t(), list(binary() | atom())) :: Vimage.t() | no_return()
  def remove_metadata!(image, fields \\ []) do
    case remove_metadata(image, fields) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  defp remove_meta(image, field) when is_atom(field) and field in @metadata_names do
    field = Map.fetch!(@metadata_fields, field)
    remove_meta(image, field)
  end

  defp remove_meta(image, field) do
    MutableImage.remove(image, field)
  end

  @doc """
  Create an image gradient the size of a given
  image, or the size of the given dimenssion.

  The gradient will be interpolated from the `start_color`
  value to the `finish_color` value.

  ### Arguments using a template image

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Arguments supplying a width and height

  * `width` is the width in pixels of the gradient image.

  * `height` is the height in pixels of the gradient image.

  * `options` is a keyword list of options. See
    `t:Image.Options.LinearGradient.linear_gradient_option/0`.

  ### Options

  * `:start_color` is an sRGB color which represents the starting
    color of the gradient. The color can be an
    integer between `0..255`, a three-or-four-element list of
    integers representing an RGB color, or an atom
    representing a CSS color name. The default is `:black`
    with 100% transparency.

  * `:finish_color` is an sRGB color which represents the the
    chroma key to be selected. The color can be an
    integer between `0..255`, a three-or-four-element list of
    integers representing an RGB color or an atom
    representing a CSS color name. The default is
    `:black` with 100% opacity.

  * `:angle` is a float or integer number of degrees of
    clockwise rotation applied to the gradient. The default
    is `0.0`. The number is normalized into the range `0..360`.

  ### Returns

  * `{:ok, gradient_image}` or

  * `{:error, reason}`

  ### Example

      # transparent_black and opaque_black are the default
      # start and finish values
      iex> transparent_black = [0, 0, 0, 0]
      iex> opaque_black = [0, 0, 0, 255]
      iex> Image.linear_gradient(100, 100, start_color: transparent_black, finish_color: opaque_black)
      iex> Image.linear_gradient(100, 100, start_color: :red, finish_color: :blue, angle: 42)

  """

  @y_band 1
  @x_band 0

  @doc subject: "Generator"

  @spec linear_gradient(Vimage.t()) :: {:ok, Vimage.t()} | {:error, error()}

  def linear_gradient(%Vimage{} = image) do
    linear_gradient(image, [])
  end

  @spec linear_gradient(Vimage.t(), options :: Keyword.t()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def linear_gradient(%Vimage{} = image, options) do
    width = Image.width(image)
    height = Image.height(image)

    linear_gradient(width, height, options)
  end

  @spec linear_gradient(width :: pos_integer(), height :: pos_integer()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def linear_gradient(width, height) do
    linear_gradient(width, height, [])
  end

  @spec linear_gradient(width :: pos_integer(), height :: pos_integer(), options :: Keyword.t()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def linear_gradient(width, height, options)
      when is_number(width) and width > 0 and is_number(height) and height > 0 do
    with {:ok, options} <- Image.Options.LinearGradient.validate_options(options) do
      linear_gradient(width, height, options.start_color, options.finish_color, options.angle)
    end
  end

  # Three basic transforms are defined for 90, 180 and 270 degrees
  # and then a further adjustment with a 90 degree range to make
  # up the full requested angle.

  # Note that this implementation is a linear interpolation.
  # In a future release it may be possible to impleement a quadratic
  # curve fit (see https://www.youtube.com/watch?v=vEvbNG-kRyY)

  # Vertical gradient
  defp linear_gradient(width, height, start, finish, angle) when angle == 0 or angle == 360 do
    use Image.Math

    {:ok, xyz} = Operation.xyz(width, height)
    {:ok, y} = Operation.extract_band(xyz, @y_band)

    # the distance image: 0 - 1 for the start to the end of the gradient
    d = y / height

    # and use it to fade the quads ... we need to tag the result as an RGB
    # image
    (d * finish + (1 - d) * start)
    |> Operation.copy(interpretation: :VIPS_INTERPRETATION_sRGB)
  end

  # Horizontal gradient
  defp linear_gradient(width, height, start, finish, angle) when angle == 90 do
    use Image.Math

    {:ok, xyz} = Operation.xyz(width, height)
    {:ok, x} = Operation.extract_band(xyz, @x_band)

    # the distance image: 0 - 1 for the start to the end of the gradient
    d = x / width

    # and use it to fade the quads ... we need to tag the result as an RGB
    # image
    (d * start + (1 - d) * finish)
    |> Operation.copy(interpretation: :VIPS_INTERPRETATION_sRGB)
  end

  # 180 degree rotation is a synomym for a vertical gradient from finish to start
  defp linear_gradient(width, height, start, finish, angle) when angle == 180 do
    linear_gradient(width, height, finish, start, 0.0)
  end

  # 180 degree rotation is a synomym for a horizontal gradient from finish to start
  defp linear_gradient(width, height, start, finish, angle) when angle == 270 do
    linear_gradient(width, height, finish, start, 90.0)
  end

  # When creating a linear gradient on an angle we create the linear
  # vertical grdient and then rotate it. Since rotation will result in
  # the effective image area being smaller than the original image (and
  # will also be surrounded by black space pixels) we need to size the
  # gradient to be that size which, when center cropped, returns a gradient
  # of the required size.
  #
  # See: https://blog.webp.se/govips-gradient-en/

  defp linear_gradient(width, height, start, finish, angle) when angle < 360 do
    {angle, base_rotation} = adjust_angle(angle)

    r = angle / 180 * :math.pi()
    r2 = (90.0 - angle) / 180 * :math.pi()

    gradient_height = ceil(width * :math.cos(r2) + height * :math.cos(r))
    gradient_width = ceil(width * :math.sin(r2) + height * :math.sin(r))

    with {:ok, gradient} <-
           linear_gradient(gradient_width, gradient_height, start, finish, base_rotation),
         {:ok, rotated} = rotate(gradient, angle) do
      crop(rotated, :center, :middle, width, height)
    end
  end

  defp adjust_angle(angle) when angle < 90, do: {angle, 0.0}
  defp adjust_angle(angle) when angle < 180, do: {angle - 90.0, 90.0}
  defp adjust_angle(angle) when angle < 270, do: {angle - 180.0, 180.0}
  defp adjust_angle(angle) when angle < 360, do: {angle - 270.0, 270.0}

  @doc """
  Create an image gradient the size of a given
  image, or the size of the given dimenssion or
  raises an exception.

  The gradient will be interpolated from the `start_color`
  value to the `finish_color` value.

  ### Arguments using a template image

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Arguments supplying a width and height

  * `width` is the width in pixels of the gradient image.

  * `height` is the height in pixels of the gradient image.

  * `options` is a keyword list of options. See
    `t:Image.Options.LinearGradient.linear_gradient_option/0`.

  ### Options

  * `:start_color` is an sRGB color which represents the starting
    color of the gradient. The color can be an
    integer between `0..255`, a three-or-four-element list of
    integers representing an RGB color, or an atom
    representing a CSS color name. The default is `:black`
    with 100% transparency.

  * `:finish_color` is an sRGB color which represents the the
    chroma key to be selected. The color can be an
    integer between `0..255`, a three-or-four-element list of
    integers representing an RGB color or an atom
    representing a CSS color name. The default is
    `:black` with 100% opacity.

  * `:angle` is a float or integer number of degrees of
    clockwise rotation applied to the gradient. The default
    is `0.0`. The number is normalized into the range `0..360`.

  ### Returns

  * `gradient_image` or

  * raises an exception.

  ### Example

      # transparent_black and opaque_black are the default
      # start and finish values
      iex> transparent_black = [0, 0, 0, 0]
      iex> opaque_black = [0, 0, 0, 255]
      iex> Image.linear_gradient!(100, 100, start_color: transparent_black, finish_color: opaque_black)

  """

  @doc subject: "Generator"

  @spec linear_gradient!(Vimage.t(), options :: Keyword.t()) ::
          Vimage.t() | no_return()

  def linear_gradient!(%Vimage{} = image) do
    linear_gradient!(image, [])
  end

  def linear_gradient!(%Vimage{} = image, options) do
    case linear_gradient(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  def linear_gradient!(width, height)
      when is_number(width) and is_number(height) and width > 0 and height > 0 do
    linear_gradient!(width, height, [])
  end

  def linear_gradient!(width, height, options \\ [])
      when is_number(width) and is_number(height) and width > 0 and height > 0 do
    case linear_gradient(width, height, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Returns a radial gradient as an image.

  This image might then be composited over
  another image.

  ### Arguments

  * `width` is the width of the gradient in
    pixels.

  * `height` is the height of the gradient in
    pixels.

  * `options` is a keyword list of options. See
    `t:Image.Options.RadialrGradient.radial_gradient_option/0`.

  ### Options

  * `:start_color` is an sRGB color which represents the starting
    color of the gradient. The color can be an
    integer between `0..255`, a three-or-four-element list of
    integers representing an RGB color, or an atom
    representing a CSS color name. The default is `:black`
    with 100% transparency.

  * `:finish_color` is an sRGB color which represents the the
    chroma key to be selected. The color can be an
    integer between `0..255`, a three-or-four-element list of
    integers representing an RGB color or an atom
    representing a CSS color name. The default is
    `:black` with 100% opacity.

  * `:feather` is the slope of the gradient. That is,
    how quickly the gradient moves from the `:start_color`
    color to the `:finish_color`. The valid range is
    `1..10` representing the smallest amount of feather
    (harshest transition) to the largest amount of
    feather (smoothest transition). The default is `1`.

  * `:radius` is the radius of the gradient in the range `1..5`
    where `1` fully fills the space and `5` fills a small section
    of the center of the space.  The default is `2`.

  ### Returns

  * `{:ok, gradient_image}` or

  * `{:error, reason}`

  """
  @doc subject: "Generator", since: "0.6.0"

  @spec radial_gradient(
          width :: pos_integer(),
          height :: pos_integer(),
          options :: Options.RadialGradient.radial_gradient_options()
        ) ::
          {:ok, %Vimage{}} | {:error, error()}

  def radial_gradient(width, height, options \\ []) do
    use Image.Math

    with {:ok, options} <- Options.RadialGradient.validate_options(options) do
      max = max(width, height)
      xyz = Operation.xyz!(width, height) - [width / 2, height / 2]

      d =
        (xyz[0] ** 2 + xyz[1] ** 2) ** 0.5 / (2 ** (options.feather * 0.05) * max / options.radius)

      radial_gradient = d * options.finish_color + (d * -1 + 1) * options.start_color

      Operation.copy(radial_gradient, interpretation: :VIPS_INTERPRETATION_sRGB)
    end
  end

  @doc """
  Returns a radial gradient as an image.

  This image might then be composited over
  another image.

  ### Arguments

  * `width` is the width of the gradient in
    pixels.

  * `height` is the height of the gradient in
    pixels.

  * `options` is a keyword list of options. See
    `t:Image.Options.RadialrGradient.radial_gradient_option/0`.

  ### Options

  * `:start_color` is an sRGB color which represents the starting
    color of the gradient. The color can be an
    integer between `0..255`, a three-or-four-element list of
    integers representing an RGB color, or an atom
    representing a CSS color name. The default is `:black`
    with 100% transparency.

  * `:finish_color` is an sRGB color which represents the the
    chroma key to be selected. The color can be an
    integer between `0..255`, a three-or-four-element list of
    integers representing an RGB color or an atom
    representing a CSS color name. The default is
    `:black` with 100% opacity.

  * `:feather` is the slope of the gradient. That is,
    how quickly the gradient moves from the `:start_color`
    color to the `:finish_color`. The valid range is
    `1..10` representing the smallest amount of feather
    (harshest transition) to the largest amount of
    feather (smoothest transition). The default is `1`.

  * `:radius` is the radius of the gradient in the range `1..5`
    where `1` fully fills the space and `5` fills a small section
    of the center of the space.  The default is `2`.

  ### Returns

  * `{:ok, gradient_image}` or

  * `{:error, reason}`

  """
  @doc subject: "Generator", since: "0.43.0"

  @spec radial_gradient!(
          width :: pos_integer(),
          height :: pos_integer(),
          options :: Options.RadialGradient.radial_gradient_options()
        ) ::
          %Vimage{} | no_return()

  def radial_gradient!(width, height, options \\ []) do
    case radial_gradient(width, height, options) do
      {:ok, gradient} -> gradient
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Returns the dominant sRGB color(s) of an image.

  Two methods are supported for identifying dominant
  colors:

  * `:histogram` (default) uses a coarse 3D RGB histogram
    (via `vips_hist_find_ndim`) and returns the centre of
    the most populated bins. It is fast and has no external
    dependencies beyond libvips itself.

  * `:imagequant` asks libvips to quantise the image with
    `libimagequant` (via `vips_gifsave_buffer`) and returns
    the resulting palette ordered by perceptual importance.
    This generally yields visually better dominant colors
    on photographic images, at the cost of running the
    quantiser.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:method` is either `:histogram` or `:imagequant`.
    The default is `#{inspect(@dominant_method)}`.

  * `:bins` is an integer number of color
    frequency bins the image is divided into.
    Only used when `method: :histogram`.
    The default is `#{@dominant_bins}`.

  * `:top_n` returns the top `n` most
    dominant colors in the image. The default
    is `#{@dominant_top_n}`. When `method: :imagequant`,
    `:top_n` is rounded up to the next power of two
    (clamped to the range `2..256`) to select the GIF
    palette bitdepth; the returned list is then truncated
    to `:top_n` entries.

  * `:effort` is an integer in the range `1..10` that
    controls the libimagequant CPU effort. Only used when
    `method: :imagequant`. The default is `#{@dominant_effort}`.

  * `:dither` is a float in the range `0.0..1.0` that
    controls the libimagequant dithering amount. Only used
    when `method: :imagequant`. The default is `#{@dominant_dither}`
    (no dithering, which preserves the palette colors exactly).

  ### Returns

  * `{:ok, [r, g, b]}` when `method: :histogram` and `top_n: 1`, or

  * `{:ok, [[r, g, b], ...]}` when `method: :histogram` and `top_n > 1`, or

  * `{:ok, [{r, g, b}, ...]}` when `method: :imagequant`, or

  * `{:error, reason}`.

  ### Notes

  * `image` will be converted to the `:srgb` colorspace
    and the dominant color will be returned as an sRGB
    value.

  ### Examples

      iex> image = Image.open!("./test/support/images/Hong-Kong-2015-07-1998.jpg")
      iex> Image.dominant_color(image)
      {:ok, [8, 8, 24]}

      iex> image = Image.open!("./test/support/images/image_with_alpha2.png")
      iex> Image.dominant_color(image)
      {:ok, [88, 88, 88]}

      iex> image = Image.open!("./test/support/images/Hong-Kong-2015-07-1998.jpg")
      iex> {:ok, palette} = Image.dominant_color(image, method: :imagequant, top_n: 4)
      iex> length(palette)
      4
      iex> Enum.all?(palette, fn {r, g, b} -> r in 0..255 and g in 0..255 and b in 0..255 end)
      true

  """
  @doc subject: "Image info", since: "0.3.0"

  @spec dominant_color(image :: Vimage.t(), options :: Keyword.t()) ::
          {:ok, Pixel.t() | [Pixel.t()] | [{0..255, 0..255, 0..255}]}
          | {:error, error()}

  def dominant_color(%Vimage{} = image, options \\ []) do
    method = Keyword.get(options, :method, @dominant_method)
    count = Keyword.get(options, :top_n, @dominant_top_n)

    with {:ok, image} <- to_colorspace(image, :srgb) do
      case method do
        :histogram ->
          bins = Keyword.get(options, :bins, @dominant_bins)

          if has_alpha?(image) do
            dominant_color_alpha(image, bins, count)
          else
            dominant_color_no_alpha(image, bins, count)
          end

        :imagequant ->
          effort = Keyword.get(options, :effort, @dominant_effort)
          dither = Keyword.get(options, :dither, @dominant_dither)
          dominant_color_imagequant(image, count, effort, dither)

        other ->
          {:error,
           %Image.Error{
             message:
               "Invalid :method option. Expected :histogram or :imagequant. Got #{inspect(other)}.",
             reason:
               "Invalid :method option. Expected :histogram or :imagequant. Got #{inspect(other)}."
           }}
      end
    end
  end

  @doc """
  Returns the dominant sRGB color of an image
  or raises an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  See `dominant_color/2` for the full list of options,
  including `:method` for selecting between the `:histogram`
  and `:imagequant` backends.

  ### Returns

  * The dominant color (see `dominant_color/2` for the
    shape of the return value), or

  * raises an exception.

  ### Notes

  * `image` will be converted to the `:srgb` colorspace
    and the dominant color will be returned as an sRGB
    list.

  ### Example

      iex> image = Image.open!("./test/support/images/Hong-Kong-2015-07-1998.jpg")
      iex> Image.dominant_color!(image)
      [8, 8, 24]

      iex> image = Image.open!("./test/support/images/image_with_alpha2.png")
      iex> Image.dominant_color!(image)
      [88, 88, 88]

  """

  @doc subject: "Image info", since: "0.43.0"

  @spec dominant_color!(image :: Vimage.t(), options :: Keyword.t()) ::
          Pixel.t() | [Pixel.t()] | [{0..255, 0..255, 0..255}] | no_return()
  def dominant_color!(%Vimage{} = image, options \\ []) do
    case dominant_color(image, options) do
      {:ok, dominant_color} -> dominant_color
      {:error, reason} -> raise Image.Error, reason
    end
  end

  # hist_find_ndim returns the following per https://github.com/libvips/libvips/discussions/3537
  # It's just a 5 x 5 x 5 matrix, so a cube. Maybe imagine a Rubik's cube, except 5x5x5, not 3x3x3?

  # If you hold the cube with one face towards you, you'll see a 5x5 grid. That's the (x, y) you pass
  # to get_pixel(). The five numbers you get back are the five tiny cubes behind the one you picked at (x, y).

  # Each cube holds a number, and that's the number of pixels which fell into that RGB bucket.
  # So (for example) the first number from the five at (0, 0) is the number of pixels w
  # here R, G and B are all between 0 and 51, so blackish pixels.

  defp dominant_color_no_alpha(image, bins, count) do
    {:ok, histogram} = Operation.hist_find_ndim(image, bins: bins)
    {:ok, unfolded} = Operation.bandunfold(histogram)
    find_maximum(unfolded, bins, count)
  end

  # Suggestion by @jcupitt from https://github.com/libvips/libvips/discussions/3692
  # Take just the alpha and count the number of 0 pixels.
  # Flatten the RGBA image with 0 as the background colour and count significant colours as before
  # Subtract the number of alpha zeros from the bin at (0, 0, 0), since all the alpha 0 pixels will have gone into that bin
  # Find the max position.  Thanks to @akash-akya for the assist.

  defp dominant_color_alpha(image, bins, count) do
    alpha_black_pixel_count =
      alpha_black_pixel_count(image[-1])

    {:ok, histogram} =
      Operation.hist_find_ndim(flatten!(image), bins: bins)

    [black | remaining_pixels] =
      Operation.getpoint!(histogram, 0, 0)

    {:ok, histogram} =
      Image.mutate(histogram, fn img ->
        pixel = [min(black - alpha_black_pixel_count, 0) | remaining_pixels]
        Vix.Vips.MutableOperation.draw_rect!(img, pixel, 0, 0, 1, 1)
      end)

    {:ok, unfolded} =
      Operation.bandunfold(histogram)

    find_maximum(unfolded, bins, count)
  end

  # Max value for an sRGB image
  @max_rgb_band_value 256

  defp find_maximum(histogram, bins, count) do
    bin_size = @max_rgb_band_value / bins

    {_c, %{"out-array": v, "x-array": x, "y-array": y}} =
      Operation.max!(histogram, size: count)

    colors =
      [v, x, y]
      |> Enum.zip()
      |> Enum.map(fn {v, x, y} ->
        r = bin_size / 2 + bin_size * Integer.floor_div(x, bins)
        b = bin_size / 2 + bin_size * Integer.mod(x, bins)
        g = bin_size / 2 + bin_size * y
        {v, [round(r), round(g), round(b)]}
      end)

    if length(colors) == 1 do
      {:ok, elem(hd(colors), 1)}
    else
      sorted_by_descending_frequency =
        colors
        |> Enum.sort()
        |> Enum.map(&elem(&1, 1))
        |> Enum.reverse()

      {:ok, sorted_by_descending_frequency}
    end
  end

  # Extract dominant colors using libimagequant via vips_gifsave_buffer.
  #
  # libvips does not expose vips_quantise as a standalone operation, so we
  # ask it to write a quantised GIF to an in-memory buffer and then read the
  # resulting Global Color Table back out. libimagequant orders palette
  # entries by perceptual importance, so the returned list is already sorted
  # from most to least dominant.
  defp dominant_color_imagequant(image, count, effort, dither) do
    image =
      if has_alpha?(image) do
        flatten!(image)
      else
        image
      end

    bitdepth = dominant_bitdepth(count)

    with {:ok, buffer} <-
           Operation.gifsave_buffer(image,
             bitdepth: bitdepth,
             effort: effort,
             dither: dither
           ),
         {:ok, palette} <- parse_gif_global_color_table(buffer) do
      {:ok, Enum.take(palette, count)}
    end
  end

  # Map a desired number of colors to a GIF bitdepth (1..8), rounding up to
  # the next power of two. libvips rejects bitdepth 0, so we clamp to 1.
  defp dominant_bitdepth(count) when is_integer(count) and count > 0 do
    count
    |> max(2)
    |> min(256)
    |> :math.log2()
    |> :math.ceil()
    |> trunc()
    |> max(1)
    |> min(8)
  end

  # Parse the Global Color Table from a GIF buffer produced by vips_gifsave.
  # See https://www.w3.org/Graphics/GIF/spec-gif89a.txt §18 (Logical Screen
  # Descriptor) for the header layout used here.
  defp parse_gif_global_color_table(
         <<"GIF", _version::binary-size(3), _w::16-little, _h::16-little, packed::8, _bg::8,
           _aspect::8, rest::binary>>
       ) do
    gct_flag = Bitwise.bsr(packed, 7) |> Bitwise.band(1)
    gct_size_code = Bitwise.band(packed, 0x07)

    if gct_flag == 1 do
      gct_entries = Bitwise.bsl(1, gct_size_code + 1)
      gct_bytes = gct_entries * 3
      <<gct::binary-size(^gct_bytes), _::binary>> = rest
      {:ok, for(<<r::8, g::8, b::8 <- gct>>, do: {r, g, b})}
    else
      {:error,
       %Image.Error{
         message: "GIF buffer does not contain a Global Color Table",
         reason: "GIF buffer does not contain a Global Color Table"
       }}
    end
  end

  defp parse_gif_global_color_table(_other) do
    {:error,
     %Image.Error{
       message: "Could not parse GIF buffer produced by libvips",
       reason: "Could not parse GIF buffer produced by libvips"
     }}
  end

  defp alpha_black_pixel_count(alpha) do
    {count, _} =
      alpha
      |> Operation.relational_const!(:VIPS_OPERATION_RELATIONAL_EQUAL, [0.0])
      |> Operation.hist_find!()
      |> Operation.max!()

    round(count)
  end

  @doc """
  Returns the histogram for an image.

  The histogram is returned as a `t:Vimage.t/0`
  that is a 255 by 1 pixel image with the same numbers of
  bands as the source image.

  ### Argument

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, histogram_image}` or

  * `{:error, reason}`

  ### Notes

  The returned image is is organized
  as a 256x1 pixel image with
  the same number of bands as the original
  image.

  Each pixel on the image returns the *count*
  of pixels in the original image that are
  in that 1/256th part of the image.

  Each band is separated into 1/256ths individually.
  For an RGB image the first number of the
  pixel element of the histogram is the count of the
  number of pixels in the red band, the second the count
  of pixels in the green band and the third a count of
  the pixels in the blue band.

  ### Example

      iex> image = Image.new!(3, 3, color: [0, 128, 0])
      iex> {:ok, _histogram} = Image.histogram(image)

      # Here is the returned list (which is just a way of
      # visualing the histogram). The first entry of `[9, 0, 9]`
      # is saying "in the first 1/256th of values, there are 9 pixels
      # in the red band and 9 pixels in the blue band". Later on,
      # in the 128th entry, we can see there are 9 pixels in the green
      # band and none in the red and blue bands.

      histogram |> Image.to_nx!() |> Nx.to_list()
      [
        [
          [9, 0, 9],
          [0, 0, 0],
          ...
          [0, 9, 0],
          ...
          [0, 0, 0],
          [0, 0, 0]
        ]
      ]

  """
  @doc subject: "Clusters", since: "0.3.0"

  @spec histogram(Vimage.t()) :: {:ok, Vimage.t()} | {:error, error()}
  def histogram(%Vimage{} = image) do
    Operation.hist_find(image)
  end

  @delta_e_versions [:de76, :de00, :decmc]
  @default_delta_e_version :de00

  @doc """
  Returns the [color difference](https://en.wikipedia.org/wiki/Color_difference)
  between two colors calculated using the
  [CIE](https://cie.co.at) [ΔE*](https://en.wikipedia.org/wiki/Color_difference#CIELAB_ΔE*)
  algorithms.

  The available difference algorithms are:

  * [CIDE2000](https://en.wikipedia.org/wiki/Color_difference#CIEDE2000)
  * [CIE CMC](https://en.wikipedia.org/wiki/Color_difference#CMC_l:c_(1984))
  * [CIE 1976](https://en.wikipedia.org/wiki/Color_difference#CIE76)

  ### Arguments

  * `color_1` which can be specified as a single integer
    or a list of integers representing the color.
    The color can also be supplied as a CSS color name as a
    string or atom. For example: `:misty_rose`. Lastly, the
    color can be supplied as a hex string like `#ffe4e1`. See
    `Color.new/2` from the Color library.

  * `color_2` which is specified in the same manner as `color_1`.

  * `version` is one of `:de00` (the default), `:decmc` or `:de76`.

  ### Returns

  * `{:ok, int_distance}` where `int_distance` is `0`
    when the colors are identical and `100` when they are completely
    different.

  * `{:error, reason}`.

  ### Examples

      iex> Image.delta_e([0,0,0], [0,0,0])
      {:ok, 0.0}

      iex> Image.delta_e([0,0,0], [255,255,255])
      {:ok, 100.0}

  """
  @doc subject: "Color Difference", since: "0.49.0"
  @spec delta_e(
          color_1 :: Vimage.t() | Pixel.t(),
          color_2 :: Vimage.t() | Pixel.t(),
          version :: :de76 | :de00 | :cmc
        ) :: {:ok, float()} | {:error, error()}
  def delta_e(color_1, color_2, version \\ @default_delta_e_version)

  def delta_e(%Vimage{} = image_1, color_2, version) do
    color_1 = get_pixel!(image_1, 0, 0)
    delta_e(color_1, color_2, version)
  end

  def delta_e(color_1, %Vimage{} = image_2, version) do
    color_2 = get_pixel!(image_2, 0, 0)
    delta_e(color_1, color_2, version)
  end

  def delta_e(color_1, color_2, version) do
    with {:ok, version} <- validate_delta_e_version(version),
         {:ok, color_1} <- Pixel.to_srgb(color_1),
         {:ok, color_2} <- Pixel.to_srgb(color_2) do
      color_1_image = new!(1, 1, color: color_1)
      color_2_image = new!(1, 1, color: color_2)

      delta_e =
        case version do
          :de00 -> Operation.de00!(color_1_image, color_2_image)
          :de76 -> Operation.de76!(color_1_image, color_2_image)
          :decmc -> Operation.decmc!(color_1_image, color_2_image)
        end
        |> Operation.getpoint!(0, 0)
        |> hd

      {:ok, delta_e}
    end
  end

  @doc """
  Returns the [color difference](https://en.wikipedia.org/wiki/Color_difference)
  between two colors calculated using the
  [CIE](https://cie.co.at) [ΔE*](https://en.wikipedia.org/wiki/Color_difference#CIELAB_ΔE*)
  algorithms or raises an exception.

  The available difference algorithms are:

  * [CIDE2000](https://en.wikipedia.org/wiki/Color_difference#CIEDE2000)
  * [CIE CMC](https://en.wikipedia.org/wiki/Color_difference#CMC_l:c_(1984))
  * [CIE 1976](https://en.wikipedia.org/wiki/Color_difference#CIE76)

  ### Arguments

  * `color_1` which can be specified as a single integer
    or a list of integers representing the color.
    The color can also be supplied as a CSS color name as a
    string or atom. For example: `:misty_rose`. Lastly, the
    color can be supplied as a hex string like `#ffe4e1`. See
    `Color.new/2` from the Color library.

  * `color_2` which is specified in the same manner as `color_1`.

  * `version` is one of `:de00` (the default), `:decmc` or `:de76`.

  ### Returns

  * `{:ok, int_distance}` where `int_distance` is `0`
    when the colors are identical and `100` when they are completely
    different.

  * `{:error, reason}`.

  ### Examples

      iex> Image.delta_e!([0,0,0], [0,0,0])
      0.0

      iex> Image.delta_e!([0,0,0], [255,255,255])
      100.0

      iex> Image.delta_e!([0,0,0], :misty_rose)
      iex> |> Float.round(3)
      90.155

      iex> Image.delta_e!(:green, :misty_rose)
      iex> |> Float.round(3)
      52.937

      iex> Image.delta_e!(:green, :misty_rose, :de76)
      iex> |> Float.round(4)
      88.5516

  """
  @doc subject: "Color Difference", since: "0.51.0"
  def delta_e!(color_1, color_2, version \\ @default_delta_e_version) do
    case delta_e(color_1, color_2, version) do
      {:ok, delta_e} -> delta_e
      {:error, reason} -> raise Image.Error, reason
    end
  end

  defp validate_delta_e_version(version) when version in @delta_e_versions,
    do: {:ok, version}

  defp validate_delta_e_version(version) do
    {:error,
     "Invalid delta_e version #{inspect(version)}. " <>
       "Version must be one of #{inspect(@delta_e_versions)}"}
  end

  # The Scholar-backed k-means and reduce-colors functions also
  # rely on `Image.to_nx!/1` (defined inside the `Nx` fence below)
  # and on `Nx.to_list/1`, so we require Nx to be loaded as well.
  if Code.ensure_loaded?(Scholar.Cluster.KMeans) and Code.ensure_loaded?(Nx) do
    @default_clusters 16

    @doc """
    Applies [K-means](https://en.wikipedia.org/wiki/K-means_clustering) clustering
    to an image using the [scholar](https://hex.pm/packages/scholar)
    library. The returned result is a list of colors resulting from
    partioning the colors in an image.

    This function is only available if [Scholar](https://hex.pm/packages/scholar)
    is configured.

    ### Arguments

    * `image` is any `t:Vix.Vips.Image.t/0`.

    * `options` is a keyword list of options.

    ### Options

    * See `Scholar.Cluster.KMeans.fit/2` for the
      available options.

    ### Returns

    * `{:ok, list_of_colors}` or

    * `{:error, reason}`

    ### Notes

    * The current implementation is performed in the
      sRGB colorspace. This may not produce the most
      perceptually appropriate clusters. This limitation
      will be removed in a future release.

    * The option `:num_clusters` determines the
      number of clusters into which image colors are
      partioned. The default is `num_clusters: #{@default_clusters}`.

    * The default options mean that the results are
      not deterministic. Different calls to `Image.k_means/2`
      can return different - but equally valid - results. Use
      the `:key` option to return deterministic results.

    * Performance is very correlated with image size.
      Where possible, resize the image to be under a 1_000_000
      pixels or even less before invoking `Image.k_means/2`.

    * Performance is primarily determined by the vector
      performance of the system and specifically by the
      GPU configuration and EXLAs support of that GPU.
      In most cases it is recommended that the following
      be added to `config.exs`:

    ```elixir
    config :nx,
      default_backend: EXLA.Backend

    config :nx, :default_defn_options,
      compiler: EXLA
    ```

    ### Example

        iex> key = Nx.Random.key(40)
        iex> image = Image.open!("./test/support/images/Hong-Kong-2015-07-1998.jpg")
        iex> Image.k_means(image, key: key)
        {:ok,
         [
           [35, 112, 151],
           [36, 70, 89],
           [38, 36, 33],
           [39, 187, 56],
           [96, 93, 108],
           [97, 148, 178],
           [107, 70, 39],
           [144, 119, 151],
           [153, 117, 89],
           [171, 179, 200],
           [173, 168, 134],
           [180, 113, 35],
           [217, 131, 137],
           [225, 223, 223],
           [226, 163, 80],
           [232, 198, 155]
         ]}

    """
    @doc subject: "Clusters", since: "0.49.0"

    @spec k_means(image :: Vimage.t(), options :: Keyword.t()) ::
            {:ok, list(Pixel.t())} | {:error, error()}

    def k_means(%Vimage{} = image, options \\ []) do
      options = Keyword.put_new(options, :num_clusters, @default_clusters)
      original_colorspace = Image.colorspace(image)

      with {:ok, srgb_image} <- Image.to_colorspace(image, :srgb),
           {:ok, target_image} <-
             Image.new(1, 1, color: :black, interpretation: original_colorspace) do
        k_means =
          srgb_image
          |> Image.Scholar.k_means(options)
          |> Map.fetch!(:clusters)
          |> Nx.to_list()
          |> Enum.map(fn rgb -> Enum.map(rgb, &round/1) end)
          |> Enum.sort()
          |> Enum.map(fn rgb -> Pixel.to_pixel!(target_image, rgb) end)

        {:ok, k_means}
      end
    end

    @doc """
    Applies [K-means](https://en.wikipedia.org/wiki/K-means_clustering) clustering
    to an image using the [scholar](https://hex.pm/packages/scholar)
    library. The returned result is a list of colors resulting from
    partioning the colors in an image.

    This function is only available if [Scholar](https://hex.pm/packages/scholar)
    is configured.

    ### Arguments

    * `image` is any `t:Vix.Vips.Image.t/0`.

    * `options` is a keyword list of options.

    ### Options

    * See `Scholar.Cluster.KMeans.fit/2` for the
      available options.

    ### Returns

    * `{:ok, list_of_colors}` or

    * `{:error, reason}`

    ### Notes

    * The current implementation is targetted towards
      sRGB images Results for images in other colorspaces
      is undefined. It is planned this limitation be
      removed in a future release.

    * The option `:num_clusters` determines the
      number of clusters into which image colors are
      partioned. The default is `num_clusters: #{@default_clusters}`.

    * The default options mean that the results are
      not deterministic. Different calls to `Image.k_means/2`
      can return different - but equally valid - results. Use
      the `:key` option to return deterministic results.

    * Performance is very correlated with image size.
      Where possible, resize the image to be under a 1_000_000
      pixels or even less before invoking `Image.k_means/2`.

    * Performance is primarily determined by the vector
      performance of the system and specifically by the
      GPU configuration and EXLAs support of that GPU.
      In most cases it is recommended that the following
      be added to `config.exs`:

    ```elixir
    config :nx,
      default_backend: EXLA.Backend

    config :nx, :default_defn_options,
      compiler: EXLA
    ```

    ### Example

        iex> key = Nx.Random.key(40)
        iex> image = Image.open!("./test/support/images/Hong-Kong-2015-07-1998.jpg")
        iex> Image.k_means!(image, key: key)
        [
          [35, 112, 151],
          [36, 70, 89],
          [38, 36, 33],
          [39, 187, 56],
          [96, 93, 108],
          [97, 148, 178],
          [107, 70, 39],
          [144, 119, 151],
          [153, 117, 89],
          [171, 179, 200],
          [173, 168, 134],
          [180, 113, 35],
          [217, 131, 137],
          [225, 223, 223],
          [226, 163, 80],
          [232, 198, 155]
        ]

    """
    @doc subject: "Clusters", since: "0.49.0"

    @spec k_means!(image :: Vimage.t(), options :: Keyword.t()) ::
            list(Pixel.t()) | no_return()

    def k_means!(%Vimage{} = image, options \\ []) do
      case k_means(image, options) do
        {:ok, k_means} -> k_means
        {:error, reason} -> raise Image.Error, reason
      end
    end

    @doc """
    Reduces the number of colors in an image.

    Takes the `k_means/2` of the image and then
    re-colors the image using the returned cluster
    colors.

    ### Arguments

    * `image` is any `t:Vix.Vips.Image.t/0`.

    * `options` is a keyword list of options.

    ### Options

    * `:colors` is the number of distinct colors to be
      used in the returned image. The default is `#{@default_clusters}`.

    * See also `Scholar.Cluster.KMeans.fit/2` for the
      available options.

    ### Note

    * Note the performance considerations described in
      `Image.k_means/2` since they also apply to this function.

    * If the intent is to reduce colors in order to
      reduce the size of an image file it is strongly advised to
      use the appropriate arguments when calling `Image.write/2`.

    ### Returns

    * `{:ok, reduced_colors_image}` or

    * `{:error, reason}`

    """
    @doc subject: "Clusters", since: "0.50.0"

    def reduce_colors(%Vimage{} = image, options \\ []) do
      with {:ok, image} <- to_colorspace(image, :srgb) do
        kmeans_num_clusters =
          Keyword.get(options, :colors, @default_clusters)

        options =
          options
          |> Keyword.put(:num_clusters, kmeans_num_clusters)
          |> Keyword.delete(:colors)

        {height, width, bands} =
          Image.shape(image)

        nx_reshaped =
          image
          |> to_nx!()
          |> Nx.reshape({height * width, bands})

        model =
          Scholar.Cluster.KMeans.fit(nx_reshaped, options)

        indicies =
          Nx.as_type(model.labels, :u8)

        model.clusters
        |> Nx.take(indicies)
        |> Nx.reshape({height, width, bands})
        |> Image.from_nx()
      end
    end

    @doc """
    Reduces the number of colors in an image or
    raises an exception.

    Takes the `k_means/2` of the image and then
    re-colors the image using the returned cluster
    colors.

    ### Arguments

    * `image` is any `t:Vix.Vips.Image.t/0`.

    * `options` is a keyword list of options.

    ### Options

    * `:colors` is the number of distinct colors to be
      used in the returned image. The default is `#{@default_clusters}`.

    * See also `Scholar.Cluster.KMeans.fit/2` for the
      available options.

    ### Note

    * Note the performance considerations described in
      `Image.k_means/2` since they also apply to this function.

    * If the intent is to reduce colors in order to
      reduce the size of an image file it is strongly advised to
      use the appropriate arguments when calling `Image.write/2`.

    ### Returns

    * `reduced_colors_image` or

    * raises an exception.

    """
    @doc subject: "Clusters", since: "0.51.0"

    def reduce_colors!(%Vimage{} = image, options \\ []) do
      case reduce_colors(image, options) do
        {:ok, image} -> image
        {:error, reason} -> raise Image.Error, reason
      end
    end
  end

  @doc """
  Returns the pixel value at the given image location.

  The returned pixel is a list of numbers where
  the length of the list is equal to the number
  of bands in the image.

  If the colorspace of the image is `:srgb` then
  the values are rounded.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `x` is an integer offset from the top
    left of the image along the `x` (width) axis.
    The number must be in the range `0..width - 1`.

  * `y` is an integer offset from the top
    left of the image along the `y` (height) axis.
    The number must be in the range `0..height - 1`.

  ### Returns

  * `{:ok, pixel_value}` or

  * `{:error, reason}`

  """
  @doc subject: "Operation", since: "0.3.0"

  @spec get_pixel(Vimage.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, Pixel.t()} | {:error, error()}

  def get_pixel(%Vimage{} = image, x, y) do
    band_format = Image.band_format(image)

    with {:ok, values} <- Operation.getpoint(image, x, y) do
      values =
        case band_format do
          {:u, _} ->
            Enum.map(values, &round/1)

          _other ->
            values
        end

      {:ok, values}
    end
  end

  @doc """
  Returns the pixel value at the given image location
  or raises an exception.

  The returned pixel is a list of numbers where
  the length of the list is equal to the number
  of bands in the image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `x` is an integer offset from the top
    left of the image along the `x` (width) axis.
    The number must be in the range `0..width - 1`.

  * `y` is an integer offset from the top
    left of the image along the `y` (height) axis.
    The number must be in the range `0..height - 1`.

  ### Returns

  * `pixel_value` or

  * raises an exception

  """
  @doc subject: "Operation", since: "0.26.0"

  @spec get_pixel!(Vimage.t(), non_neg_integer(), non_neg_integer()) ::
          Pixel.t() | no_return()

  def get_pixel!(%Vimage{} = image, x, y) do
    case get_pixel(image, x, y) do
      {:ok, pixel} -> pixel
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Mutate an image with through the given
  function.

  Mutations, like those functions in the
  `Image.Draw`, module are operations on
  a *copy* of the base image and operations
  are serialized through a gen_server in order
  to maintain thread safety.

  In order to perform multiple mutations without
  coopying for each each mutation,`Image.mutate/2` takes
  a function argument `fun` that is passed a
  `t:Vix.Vips.MutableImage.t/0` as a parameter. In that
  way several mutations can be safely applied withouout
  copying the image prior to each mutation.

  Although the image is not copied before each mutuation,
  each mutable operation is still serialized behind
  a genserver to ensure thread safety.

  The functions in `Image.Draw` all support either
  a `t:Vix.Vips.Image.t/0` or a `t:Vix.Vips.MutableImage.t/0`
  as the image parameter.

  When the parameter `fun` returns, the mutation
  process is ended and a normal `t:Vix.Vips.Image.t/0`
  is returned.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `fun` is any 1-arity function that receives
    a `t:Vix.Vips.MutableImage.t/0` parameter. This function
    *must* return either `:ok` or `{:ok, term}`.

  ### Returns

  * `{:ok, mutated_image}` or

  * `{:error, reason}`

  ### Notes

  The image is copied and operations are serialized behind a gen_server.
  Only one copy is made but all operations will be serialized behind the
  gen_server. When the function returns, the gen_server is broken down and
  the underlying mutated `t:Vix.Vips.Image.t/0` is returned.

  ### Example

      iex> {:ok, image} = Image.open("./test/support/images/puppy.webp")
      iex> {:ok, _mutated_copy} =
      ...>   Image.mutate(image, fn mut_image ->
      ...>     cx = cy = div(Image.height(image), 2)
      ...>     {:ok, _image} = Image.Draw.circle(mut_image, cx, cy, 100, color: :green)
      ...>   end)

  """
  @doc subject: "Operation", since: "0.7.0"

  @spec mutate(Vimage.t(), (MutableImage.t() -> any())) ::
          {:ok, Vimage.t()} | {:ok, {Vimage.t(), term()}} | {:error, error()}

  def mutate(%Vimage{} = image, fun) when is_function(fun, 1) do
    case Vimage.mutate(image, fun) do
      {:error, reason} -> {:error, reason}
      {:ok, {%Vimage{} = image, {%MutableImage{} = _mut, term}}} -> {:ok, {image, term}}
      {:ok, {%Vimage{} = image, %MutableImage{} = _mut}} -> {:ok, image}
      {:ok, %Vimage{} = image} -> {:ok, image}
    end
  end

  @doc """
  Converts an image to the given colorspace.

  Available colorspaces are returned from
  `Image.Interpretation.known_interpretations/0`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`

  * `colorspace` is any known colorspace. See
    `Image.Interpretation.known_interpretations/0`
    for a list of the known colorspaces.

  ### Returns

  * `{;ok, image_in_new_colorspace}` or

  * `{:error, reason}`

  ### Example

      Image.to_colorspace(image, :bw)

  """
  @doc subject: "Color"

  @spec to_colorspace(Vimage.t(), Interpretation.t()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def to_colorspace(%Vimage{} = image, colorspace) do
    with {:ok, colorspace} <- Interpretation.validate_interpretation(colorspace) do
      Vix.Vips.Operation.colourspace(image, colorspace)
    end
  end

  @doc """
  Converts an image to the given colorspace returning
  an image or raising an exception.

  Available colorspaces are returned from
  `Image.Interpretation.known_interpretations/0`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`

  * `colorspace` is any known colorspace. See
    `Image.Interpretation.known_interpretations/0`
    for a list of the known colorspaces.

  ### Returns

  * `image_in_new_colorspace` or

  * raises an exception

  ### Example

      Image.to_colorspace!(image, :bw)

  """
  @doc subject: "Color"

  @spec to_colorspace!(Vimage.t(), Interpretation.t()) ::
          Vimage.t() | no_return()

  def to_colorspace!(%Vimage{} = image, colorspace) do
    case to_colorspace(image, colorspace) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Convert image to polar coordinates.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, image_in_polar_coordinates}` or

  * `{:error, reason}`

  """
  @dialyzer {:nowarn_function, {:to_polar_coordinates, 1}}
  @doc subject: "Operation"

  @spec to_polar_coordinates(Vimage.t()) :: {:ok, Vimage.t()} | {:error, error()}
  def to_polar_coordinates(%Vimage{} = image) do
    use Image.Math

    width = width(image)
    height = height(image)
    min = min(width, height)
    scale = Kernel./(min, width)

    xy = Operation.xyz!(width, height)
    xy = xy - [width / 2.0, height / 2.0]
    xy = xy * 2.0 / scale

    {:ok, index} = Complex.polar(xy)
    index = index * [1.0, height / 360.0]

    Operation.mapim(image, index)
  end

  @doc """
  Convert image to polar coordinates returning
  an image or raising an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `image_in_polar_coordinates` or

  * raises an exception.

  """
  @dialyzer {:nowarn_function, {:to_polar_coordinates!, 1}}
  @doc subject: "Operation"

  @spec to_polar_coordinates!(Vimage.t()) :: Vimage.t() | no_return()
  def to_polar_coordinates!(%Vimage{} = image) do
    case to_polar_coordinates(image) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Convert image to rectangular coordinates.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ## Notes

  Roundtrip to polar and back to rectangular
  coordinates displays some image distortion,
  likely due to rounding errors in float
  arithmetic. Further study is required.

  ### Returns

  * `{:ok, image_in_rectangular_coordinates}` or

  * `{:error, reason}`

  """
  @dialyzer {:nowarn_function, {:to_rectangular_coordinates, 1}}
  @doc subject: "Operation"

  @spec to_rectangular_coordinates(Vimage.t()) :: {:ok, Vimage.t()} | {:error, error()}
  def to_rectangular_coordinates(%Vimage{} = image) do
    use Image.Math

    width = width(image)
    height = height(image)
    min = min(width, height)
    scale = Kernel./(min, width)

    xy = Operation.xyz!(width, height)
    xy = xy * [1.0, 360.0 / height]

    {:ok, index} = Complex.rectangular(xy)

    index = index * scale / 2.0
    index = index + [width / 2.0, height / 2.0]

    Operation.mapim(image, index)
  end

  @doc """
  Convert image to rectangular coordinates
  returning an image or raising an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ## Notes

  Roundtrip to polar and back to rectangular
  coordinates displays some image distortion,
  likely due to rounding errors in float
  arithmetic. Further study is required.

  ### Returns

  * `image_in_rectangular_coordinates` or

  * raises an exception.

  """
  @dialyzer {:nowarn_function, {:to_rectangular_coordinates!, 1}}
  @doc subject: "Operation"

  @spec to_rectangular_coordinates!(Vimage.t()) :: Vimage.t() | no_return()
  def to_rectangular_coordinates!(%Vimage{} = image) do
    case to_rectangular_coordinates(image) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Apply a percentage adjustment to an image's brightness
  (luminance).

  The image is converted to the [LCh color space](https://en.wikipedia.org/wiki/HCL_color_space),
  multiplies the luminance band by the provided float percentage and converts
  the image back to its original color space.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `brightness` is any float greater than `0.0`. A number less
    than `1.0` means reduce brightness. A number greater than `1.0`
    means increas brightness.

  ### Returns

  * `{:ok, adjusted_image}` or

  * `{:error, reason}`.

  ### Example

      iex> image = Image.open!("./test/support/images/cat.png")
      iex> {:ok, _brighter_image} = Image.brightness(image, 1.5)

  """
  @doc since: "0.34.0"
  @doc subject: "Basic Adjustments"

  @spec brightness(image :: Vimage.t(), brightness :: float()) ::
          {:ok, Vimage.t()} | {:error, error()}
  def brightness(%Vimage{} = image, brightness) when is_multiplier(brightness) do
    without_alpha_band(image, fn image ->
      with_colorspace(image, :lch, fn i ->
        Image.Math.multiply(i, [brightness, 1.0, 1.0])
      end)
    end)
  end

  @doc """
  Apply a percentage adjustment to an image's brightness
  (luminance) or raises an exception.

  The image is converted to the [LCh color space](https://en.wikipedia.org/wiki/HCL_color_space),
  multiplies the luminance band by the provided float percentage and converts
  the image back to its original color space.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `brightness` is any float greater than `0.0`. A number less
    than `1.0` means reduce brightness. A number greater than `1.0`
    means increas brightness.

  ### Returns

  * `adjusted_image` or

  * raises an exception.

  ### Example

      iex> image = Image.open!("./test/support/images/cat.png")
      iex> _brighter_image = Image.brightness!(image, 1.5)

  """
  @doc since: "0.34.0"
  @doc subject: "Basic Adjustments"

  @spec brightness!(image :: Vimage.t(), brightness :: float()) :: Vimage.t() | no_return()
  def brightness!(%Vimage{} = image, brightness) when is_multiplier(brightness) do
    case brightness(image, brightness) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Apply a percentage adjustment to an image's contrast.

  This is a simple implementation that applies a linear
  function to the image. In most cases, `Image.apply_tone_curve/2`
  should be preferred for making constrast adjustments.

  Small increments can have a dramatic affect on the image;
  contrast in the range of approximately `0.5` to `1.5` are
  likely to meet most requirement.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `contrast` is any float greater than `0.0`. A number less
    than `1.0` means reduce contrast. A number greater than `1.0`
    means increase contrast.

  ### Returns

  * `{:ok, adjusted_image}` or

  * `{:error, reason}`.

  ### Example

      iex> image = Image.open!("./test/support/images/cat.png")
      iex> {:ok, _image_with_more_contrast} = Image.contrast(image, 1.2)

  """

  # Implementation is based upon
  # https://stackoverflow.com/questions/73601395/adjusting-contrast-in-vips-the-same-way-as-the-matching-css-filter

  @doc since: "0.35.0"
  @doc subject: "Basic Adjustments"

  @spec contrast(image :: Vimage.t(), contrast :: float()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def contrast(%Vimage{} = image, contrast) when is_multiplier(contrast) do
    use Image.Math

    without_alpha_band(image, fn image ->
      with_colorspace(image, :scrgb, fn scrgb ->
        {:ok, scrgb * contrast - (0.5 * contrast - 0.5)}
      end)
    end)
  end

  def contrast(%Vimage{} = _image, contrast) do
    {:error,
     "Invalid contrast value. Contrast must be a float greater that 0.0. Found #{inspect(contrast)}"}
  end

  @doc """
  Apply a percentage adjustment to an image's contrast or
  raises and exception.

  This is a simple implementation that applies a linear
  function to the image. In most cases, `Image.apply_tone_curve/2`
  should be preferred for making constrast adjustments.

  Small increments can have a dramatic affect on the image;
  contrast in the range of approximately `0.5` to `1.5` are
  likely to meet most requirement.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `contrast` is any float greater than `0.0`. A number less
    than `1.0` means reduce contrast. A number greater than `1.0`
    means increase contrast.

  ### Returns

  * `adjusted_image` or

  * raises an exception.

  ### Example

      iex> image = Image.open!("./test/support/images/cat.png")
      iex> _image_with_more_contrast = Image.contrast!(image, 1.2)

  """
  @doc since: "0.35.0"
  @doc subject: "Basic Adjustments"

  @spec contrast!(image :: Vimage.t(), contrast :: float()) :: Vimage.t() | no_return()
  def contrast!(%Vimage{} = image, contrast) when is_multiplier(contrast) do
    case contrast(image, contrast) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Inverts an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, inverted_image}` or

  * `{:error, reason}`.

  ### Notes

  * For unsigned formats, this operation calculates
    `(max_value - pixel_value)`, eg. `(255 - pixel_value)` for
    typical 8-bit sRGB images.

  * For signed and float formats, this operation calculates
    `(-1 * pixel_value)`.

  * For complex images, only the real part is inverted.

  """
  @doc since: "0.42.0"
  @doc subject: "Basic Adjustments"

  @spec invert(image :: Vimage.t()) :: {:ok, Vimage.t()} | {:error, error()}
  def invert(%Vimage{} = image) do
    Vix.Vips.Operation.invert(image)
  end

  @doc """
  Inverts an image or raises an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `inverted_image` or

  * raises an exception.

  ### Notes

  * For unsigned formats, this operation calculates
    `(max_value - pixel_value)`, eg. `(255 - pixel_value)` for
    typical 8-bit sRGB images.

  * For signed and float formats, this operation calculates
    `(-1 * pixel_value)`.

  * For complex images, only the real part is inverted.

  """
  @doc since: "0.42.0"
  @doc subject: "Basic Adjustments"

  @spec invert!(image :: Vimage.t()) :: Vimage.t() | no_return()
  def invert!(%Vimage{} = image) do
    case invert(image) do
      {:ok, inverted} -> inverted
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Transforms an image using brightness, saturation,
  hue rotation, and lightness.

  Brightness and lightness both operate on luminance,
  with the difference being that brightness is multiplicative
  whereas lightness is additive.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:brightness` is any float greater than `0.0`. A number less
    than `1.0` means reduce brightness. A number greater than `1.0`
    means increas brightness.  The default is `1.0` meaning no
    brightness adjustment.

  * `:lightness` is any float. This value is added to the luminance
    of an image. This is different to `:brightness` which is *multuplied*
    by the luminance. The default is `0.0` meaning no lightness
    adjustment.

  * `:saturation` is any float greater than `0.0`. A number less
    than `1.0` means reduce saturation. A number greater than `1.0`
    means increas saturation. The default is `1.0` meaning no
    saturation adjustment.

  * `:hue` is an integer angle in degrees added to the hue. This is often
    referred to as the *hug angle* and the operation as adjusting
    the *hue rotation*. The value should typically be in the range `0..360`.
    The default is `0` meaning no hue adjustment.

  ### Returns

  * `{:ok, modulated_image}` or

  * `{:error, reason}`.

  """
  @doc since: "0.35.0"
  @doc subject: "Basic Adjustments"

  @spec modulate(image :: Vimage.t(), options :: Options.Modulate.modulate_options()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def modulate(%Vimage{} = image, options \\ []) do
    with {:ok, options} <- Options.Modulate.validate_options(options) do
      without_alpha_band(image, fn image ->
        with_colorspace(image, :lch, fn image ->
          multipliers = [options.brightness, options.saturation, 1.0]
          addends = [options.lightness, 0.0, options.hue]
          Operation.linear(image, multipliers, addends)
        end)
      end)
    end
  end

  @doc """
  Transforms an image using brightness, saturation,
  hue rotation, and lightness or raises an exception.

  Brightness and lightness both operate on luminance,
  with the difference being that brightness is multiplicative
  whereas lightness is additive.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:brightness` is any float greater than `0.0`. A number less
    than `1.0` means reduce brightness. A number greater than `1.0`
    means increas brightness.  The default is `1.0` meaning no
    brightness adjustment.

  * `:lightness` is any float. This value is added to the luminance
    of an image. This is different to `:brightness` which is *multuplied*
    by the luminance. The default is `0.0` meaning no lightness
    adjustment.

  * `:saturation` is any float greater than `0.0`. A number less
    than `1.0` means reduce saturation. A number greater than `1.0`
    means increas saturation. The default is `1.0` meaning no
    saturation adjustment.

  * `:hue` is an integer angle in degrees added to the hue. This is often
    referred to as the *hug angle* and the operation as adjusting
    the *hue rotation*. The value should typically be in the range `0..360`.
    The default is `0` meaning no hue adjustment.

  ### Returns

  * `modulated_image` or

  * raises an exception.

  """
  @doc since: "0.35.0"
  @doc subject: "Basic Adjustments"

  @spec modulate!(image :: Vimage.t(), options :: Options.Modulate.modulate_options()) ::
          Vimage.t() | no_return()

  def modulate!(%Vimage{} = image, options \\ []) do
    case modulate(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Adds a radial vignette to an image, darkening the corners
  smoothly relative to the centre.

  This is the photographic forward of the lens-vignetting
  correction implemented by `Image.LensCorrection.vignette_correction/4`
  in the `:image_lens_correction` package: this function multiplies
  pixel values by the lensfun "pa" model

      Cd = Cs * (1 + k1*r² + k2*r⁴ + k3*r⁶)

  where `r = 0` at the image centre and `r = 1` at the corner.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:strength` is a number controlling how dark the corners become.
    `0.0` is no vignette; `1.0` darkens the corners almost to black;
    negative values brighten the corners (an inverse vignette).
    The default is `#{Image.Options.Vignette.default_strength()}`.
    Ignored if any of `:k1`, `:k2`, `:k3` is supplied.

  * `:k1`, `:k2`, `:k3` are the polynomial coefficients of the
    lensfun "pa" vignetting model. Supply these for full control —
    typically with negative values for darkening (and positive
    values for brightening). When any of these is supplied, the
    `:strength` shortcut is ignored and any unsupplied coefficient
    defaults to `0.0`.

  ### Returns

  * `{:ok, vignetted_image}` or
  * `{:error, reason}`.

  ### Examples

      iex> image = Image.open!("./test/support/images/Kip_small.jpg")
      iex> {:ok, _} = Image.vignette(image)
      iex> {:ok, _} = Image.vignette(image, strength: 0.8)
      iex> {:ok, _} = Image.vignette(image, k1: -0.4, k2: 0.1, k3: -0.05)

  """
  @doc subject: "Operation", since: "0.67.0"

  @spec vignette(image :: Vimage.t(), options :: Options.Vignette.vignette_options()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def vignette(%Vimage{} = image, options \\ []) do
    use Image.Math

    with {:ok, options} <- Options.Vignette.validate_options(options) do
      format = Image.band_format(image)
      width = Image.width(image)
      height = Image.height(image)

      centre_x = (width - 1) / 2.0
      centre_y = (height - 1) / 2.0
      corner_radius = :math.sqrt(centre_x * centre_x + centre_y * centre_y)

      index = Operation.xyz!(width, height) - [centre_x, centre_y]
      r = Image.Complex.polar!(index)[0] / corner_radius

      r2 = r ** 2
      r4 = r2 ** 2
      r6 = r4 * r2

      multiplier = 1.0 + options.k1 * r2 + options.k2 * r4 + options.k3 * r6
      Image.cast(image * multiplier, format)
    end
  end

  @doc """
  Adds a radial vignette to an image, darkening the corners
  smoothly relative to the centre, or raises an exception.

  See `vignette/2` for the supported options.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Returns

  * `vignetted_image` or
  * raises an exception.

  """
  @doc subject: "Operation", since: "0.67.0"

  @spec vignette!(image :: Vimage.t(), options :: Options.Vignette.vignette_options()) ::
          Vimage.t() | no_return()

  def vignette!(%Vimage{} = image, options \\ []) do
    case vignette(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Equalizes the histogram of an imaage.

  Equalization is the process of expanding the
  tone range of an image by stretching the darkest
  tones towards black and the lightest tones towards
  white. As a result, equalization affects overall
  image contrast.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `bands` determines which bands are equalized. The
    value may be one of:

    * `:all` (defaalt) means that all bands are eqalized
      such that the darkest tones are expanded to black and the
      lightest tones are expanded to white.

    * `:each` means that each band is equalized individually
      such that each band is expanded to fill the range
      between 5% and 95% of the available tone range. Since
      each band is equalized separately there may be some
      color shifts detected.

    * `:luminance` means that only the luminance band is
      equqlized to fill between 1% and 99% of the tone range.
      The image is converted to the `:lab` color space, the
      `l` band is equalized and the image is converted back to
      its origianal color space.

  ### Returns

  * `{:ok, adjusted_image}` or

  * `{:error, reason}`.

  """
  @doc since: "0.35.0"
  @doc subject: "Basic Adjustments"

  @spec equalize(image :: Vimage.t(), bands :: Options.Equalize.equalize_option()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def equalize(image, bands \\ :all)

  def equalize(%Vimage{} = image, :all) do
    without_alpha_band(image, fn image ->
      Operation.hist_equal(image)
    end)
  end

  def equalize(%Vimage{} = image, :each) do
    use Image.Math

    band_format = Vix.Vips.Image.format(image)

    without_alpha_band(image, fn image ->
      with_colorspace(image, :srgb, fn image ->
        bands =
          image
          |> Operation.hist_find!()
          |> split_bands()

        low = Enum.map(bands, &level_percent(&1, @level_trim_percent))
        high = Enum.map(bands, &level_percent(&1, 100 - @level_trim_percent))
        scale = for {h, l} <- Enum.zip(high, low), do: 255.0 / (h - l)
        scaled = (image - low) * scale

        Operation.cast(scaled, band_format)
      end)
    end)
  end

  def equalize(%Vimage{} = image, :luminance) do
    without_alpha_band(image, fn image ->
      with_colorspace(image, :lab, fn lab_image ->
        luminance = lab_image[0]
        min = Operation.percent!(luminance, @min_luminance)
        max = Operation.percent!(luminance, @max_luminance)

        normalize_if_possible(lab_image, luminance, min, max)
      end)
    end)
  end

  def equalize(%Vimage{} = _image, bands) do
    {:error,
     "Invalid bands parameter. Valid parameters are :all, :each and :luminance. Found #{inspect(bands)}."}
  end

  defp level_percent(hist, percentage) do
    use Image.Math

    norm =
      hist
      |> Operation.hist_cum!()
      |> Operation.hist_norm!()

    {:ok, {_c, r}} = Operation.profile(norm > width(norm) * percentage / 100)

    Operation.avg!(r)
  end

  defp normalize_if_possible(lab_image, luminance, min, max) when abs(max - min) >= 1 do
    f = 100.0 / (max - min)
    a = -(min * f)

    luminance
    |> Operation.linear!([f], [a])
    |> bandjoin(lab_image[1..2])
  end

  defp normalize_if_possible(lab_image, _luminance, _min, _max) do
    {:ok, lab_image}
  end

  @doc """
  Apply a global contrast adjustment to an image
  or raises an exception.

  Equalization is the process of expanding the
  tone range of an image by stretching the darkest
  tones towards black and the lightest tones towards
  white. As a result, equalization affects overall
  image contrast.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `bands` determines which bands are equalized. The
    value may be one of:

    * `:all` (defaalt) means that all bands are eqalized
      such that the darkest tones are expanded to black and the
      lightest tones are expanded to white.

    * `:each` means that each band is equalized individually
      such that each band is expanded to fill the range
      between 5% and 95% of the available tone range. Since
      each band is equalized separately there may be some
      color shifts detected.

    * `:luminance` means that only the luminance band is
      equqlized to fill between 1% and 99% of the tone range.
      The image is converted to the `:lab` color space, the
      `l` band is equalized and the image is converted back to
      its origianal color space.

  ### Returns

  * `adjusted_image` or

  * raises an exception.

  """
  @doc since: "0.35.0"
  @doc subject: "Basic Adjustments"

  @spec equalize!(image :: Vimage.t(), bands :: Options.Equalize.equalize_option()) ::
          Vimage.t() | no_return()

  def equalize!(%Vimage{} = image, bands \\ :all) do
    case equalize(image, bands) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Applies a tone curve to an image.

  A [tone curve](https://en.wikipedia.org/wiki/Curve_(tonality))
  is typically used to affect overall image contrast. It
  is a function to adjust brightness and contrast by controlling the
  input-output density curve for each band of an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:black_point` is an integer between `0`
    (the default) and `100` indicating the darkest
    and most dense black area of the image will
    lie in the overall range of the image.

  * `:white_point` is an integer between `0`
    and `100` (the default) indicating the lightest
    area of the image will lie in the overall range
    of the image.

  * `:shadow_point` is the point on the tone curve
    around which the shadow values are tone mapped. The
    value is between `0.0` and `1.0`. The default is
    `0.2`.

  * `:mid_point` is the point on the tone curve
    around which the mid tone values are tone mapped. The
    value is between `0.0` and `1.0`. The default is
    `0.5`.

  * `:highlight_point` is the point on the tone curve
    around which the highlight values are tone mapped. The
    value is between `0.0` and `1.0`. The default is
    `0.8`.

  * `:shadows` indicates by how much the shadows should be
    adjusted. The value is in the range `-30` to `30`.
    The default is `0`.

  * `:mid_points` indicates by how much the mid tones should be
    adjusted. The value is in the range `-30` to `30`.
    The default is `0`.

  * `:highlights` indicates by how much the highlights should be
    adjusted. The value is in the range `-30` to `30`.
    The default is `0`.

  ### Returns

  * `{:ok, tone_mapped_image}` or

  * `{:error, reason}`.

  """
  @doc since: "0.35.0"
  @doc subject: "Basic Adjustments"

  @spec apply_tone_curve(image :: Vimage.t(), options :: Options.ToneCurve.tone_curve_options()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def apply_tone_curve(%Vimage{} = image, options \\ []) do
    with {:ok, lut} <- tone_curve(image, options) do
      without_alpha_band(image, fn base_image ->
        Operation.maplut(base_image, lut)
      end)
    end
  end

  @doc """
  Applies a tone curve to an image or raises
  an exception.

  A [tone curve](https://en.wikipedia.org/wiki/Curve_(tonality))
  is typically used to affect overall image contrast. It
  is a function to adjust brightness and contrast by controlling the
  input-output density curve for each band of an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:black_point` is an integer between `0`
    (the default) and `100` indicating the darkest
    and most dense black area of the image will
    lie in the overall range of the image.

  * `:white_point` is an integer between `0`
    and `100` (the default) indicating the lightest
    area of the image will lie in the overall range
    of the image.

  * `:shadow_point` is the point on the tone curve
    around which the shadow values are tone mapped. The
    value is between `0.0` and `1.0`. The default is
    `0.2`.

  * `:mid_point` is the point on the tone curve
    around which the mid tone values are tone mapped. The
    value is between `0.0` and `1.0`. The default is
    `0.5`.

  * `:highlight_point` is the point on the tone curve
    around which the highlight values are tone mapped. The
    value is between `0.0` and `1.0`. The default is
    `0.8`.

  * `:shadows` indicates by how much the shadows should be
    adjusted. The value is in the range `-30` to `30`.
    The default is `0`.

  * `:mid_points` indicates by how much the mid tones should be
    adjusted. The value is in the range `-30` to `30`.
    The default is `0`.

  * `:highlights` indicates by how much the highlights should be
    adjusted. The value is in the range `-30` to `30`.
    The default is `0`.

  ### Returns

  * `tone_mapped_image` or

  * raises an exception.

  """
  @doc since: "0.35.0"
  @doc subject: "Basic Adjustments"

  @spec apply_tone_curve!(image :: Vimage.t(), options :: Options.ToneCurve.tone_curve_options()) ::
          Vimage.t() | no_return()

  def apply_tone_curve!(%Vimage{} = image, options \\ []) do
    case apply_tone_curve(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  defp tone_curve(%Vimage{} = image, options) do
    {_min, _max} = range(image)

    with {:ok, options} <- Options.ToneCurve.validate_options(options),
         {_min, max} <- range(image),
         {:ok, lut} <-
           Operation.tonelut(
             Lb: options.black_point,
             Lw: options.white_point,
             Ps: options.shadow_point,
             Pm: options.mid_point,
             Ph: options.highlight_point,
             S: options.shadows,
             M: options.mid_points,
             H: options.highlights,
             "in-max": max,
             "out-max": max
           ) do
      cast(lut, band_format(image))
    end
  end

  @doc """
  Apply a local contrast adjustment to an image.

  This function applies a [Constrast Limited Adaptive histogram equalization (CLAHE)](https://en.wikipedia.org/wiki/Adaptive_histogram_equalization#Contrast_Limited_AHE)
  to improve contrast in images. It differs from ordinary histogram
  equalization in the respect that the adaptive method computes several
  histograms, each corresponding to a distinct section of the image, and
  uses them to redistribute the lightness values of the image.

  It is therefore suitable for improving the local contrast and
  enhancing the definitions of edges in each region of an image,
  hence the name of the function.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * :`window_size` is an integer indicating the size of
    the window (in pixels) into the image in which the contrast adjustment
    is calculated. The default is `3`.

  * `:max_slope` is the integral level of brightening, between 0 and
    100, where 0 (the default) disables contrast limiting.

  ### Returns

  * `{:ok, adjusted_image}` or

  * `{:error, reason}`.

  """
  @doc since: "0.35.0"
  @doc subject: "Basic Adjustments"

  @spec local_contrast(
          image :: Vimage.t(),
          options :: Options.LocalContrast.local_contrast_options()
        ) ::
          {:ok, Vimage.t()} | {:error, error()}

  def local_contrast(%Vimage{} = image, options \\ []) do
    with {:ok, options} <- Options.LocalContrast.validate_options(options) do
      window = options.window_size
      Operation.hist_local(image, window, window, "max-slope": options.max_slope)
    end
  end

  @doc """
  Apply a local contrast adjustment to an image
  or raises an exception.

  This function applies a [Constrast Limited Adaptive histogram equalization (CLAHE)](https://en.wikipedia.org/wiki/Adaptive_histogram_equalization#Contrast_Limited_AHE)
  to improve contrast in images. It differs from ordinary histogram
  equalization in the respect that the adaptive method computes several
  histograms, each corresponding to a distinct section of the image, and
  uses them to redistribute the lightness values of the image.

  It is therefore suitable for improving the local contrast and
  enhancing the definitions of edges in each region of an image,
  hence the name of the function.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * :`window_size` is an integer indicating the size of
    the window (in pixels) into the image in which the contrast adjustment
    is calculated. The default is `3`.

  * `:max_slope` is the integral level of brightening, between 0 and
    100, where 0 (the default) disables contrast limiting.

  ### Returns

  * `adjusted_image` or

  * raises an exception.

  """
  @doc since: "0.35.0"
  @doc subject: "Operation"

  @spec local_contrast!(
          image :: Vimage.t(),
          options :: Options.LocalContrast.local_contrast_options()
        ) ::
          Vimage.t() | no_return()

  def local_contrast!(%Vimage{} = image, options \\ []) do
    case local_contrast(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Apply an adjustment to an image's saturation
  (chroma).

  The image is converted to the [LCh color space](https://en.wikipedia.org/wiki/HCL_color_space),
  multiplies the chroma band by the provided float and converts
  the image back to its original color space.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `saturation` is any float greater than `0.0`. A number less
    than `1.0` means reduce saturation. A number greater than `1.0`
    means increase saturation.

  ### Returns

  * `{:ok, adjusted_image}` or

  * `{:error, reason}`.

  """
  @doc since: "0.34.0"
  @doc subject: "Basic Adjustments"

  @spec saturation(image :: Vimage.t(), saturation :: float()) ::
          {:ok, Vimage.t()} | {:error, error()}
  def saturation(%Vimage{} = image, saturation) when is_multiplier(saturation) do
    with_colorspace(image, :lch, fn i ->
      Image.Math.multiply(i, [1.0, saturation, 1.0])
    end)
  end

  @doc """
  Apply an adjustment to an image's saturation
  (chroma) or raises an exception.

  The image is converted to the [LCh color space](https://en.wikipedia.org/wiki/HCL_color_space),
  multiplies the chroma band by the provided float and converts
  the image back to its original color space.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `saturation` is any float greater than `0.0`. A number less
    than `1.0` means reduce saturation. A number greater than `1.0`
    means increase saturation.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `saturation` is any float greater than `0.0`. A number less
    than `1.0` means reduce saturation. A number greater than `1.0`
    means increas saturation.

  ### Returns

  * `adjusted_image` or

  * raises an exception.

  """
  @doc since: "0.34.0"
  @doc subject: "Basic Adjustments"

  @spec saturation!(image :: Vimage.t(), saturation :: float()) :: Vimage.t() | no_return()
  def saturation!(%Vimage{} = image, saturation) when is_multiplier(saturation) do
    case saturation(image, saturation) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Applies a gamma adjustment to an image.

  Each band's value is raised to the power of `1 / exponent`.
  The default `exponent` of `1.0` is a no-op; values greater
  than `1.0` brighten the midtones (a "lift"); values less than
  `1.0` darken them (a "crush").

  Gamma is a simple per-band curve and does not change the
  image's working color space. Alpha bands are preserved.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `exponent` is a positive float. The default is `1.0`.
    Values in `(0.0, 1.0)` darken; values in `(1.0, ∞)`
    brighten. Imgix's `gam=`, Cloudflare's `gamma=`, and
    Cloudinary's `e_gamma:` all use this convention.

  ### Returns

  * `{:ok, adjusted_image}` or

  * `{:error, reason}`.

  ### Example

      iex> image = Image.open!("./test/support/images/cat.png")
      iex> {:ok, _brighter} = Image.gamma(image, 1.4)

  """
  @doc since: "0.67.0"
  @doc subject: "Basic Adjustments"

  @spec gamma(image :: Vimage.t(), exponent :: float()) ::
          {:ok, Vimage.t()} | {:error, error()}
  def gamma(%Vimage{} = image, exponent \\ 1.0) when is_multiplier(exponent) and exponent > 0.0 do
    Vix.Vips.Operation.gamma(image, exponent: exponent)
  end

  @doc """
  Applies a gamma adjustment to an image or raises on error.

  See `gamma/2` for argument and option documentation.

  ### Example

      iex> image = Image.open!("./test/support/images/cat.png")
      iex> _brighter = Image.gamma!(image, 1.4)

  """
  @doc since: "0.67.0"
  @doc subject: "Basic Adjustments"

  @spec gamma!(image :: Vimage.t(), exponent :: float()) :: Vimage.t() | no_return()
  def gamma!(%Vimage{} = image, exponent \\ 1.0) when is_multiplier(exponent) and exponent > 0.0 do
    case gamma(image, exponent) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  # The standard Microsoft / Adobe sepia matrix. Applied via
  # libvips `recomb`, which multiplies each pixel by a 3x3
  # matrix. `Image.sepia/2` blends this matrix with the
  # identity according to the requested strength.
  @sepia_matrix [
    [0.393, 0.769, 0.189],
    [0.349, 0.686, 0.168],
    [0.272, 0.534, 0.131]
  ]

  @doc """
  Applies a sepia tone to an image.

  Sepia is a single-pass per-pixel colour-matrix transform — no
  colour-space conversion happens. Alpha bands are preserved.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `strength` is a float in `[0.0, 1.0]`. The default is
    `1.0` (full sepia). `0.0` is the identity (no change);
    intermediate values blend the sepia matrix with the
    identity, matching imgix's `sepia=N` 0–100 percentage
    convention divided by 100.

  ### Returns

  * `{:ok, sepia_image}` or

  * `{:error, reason}`.

  ### Example

      iex> image = Image.open!("./test/support/images/cat.png")
      iex> {:ok, _toned} = Image.sepia(image)
      iex> {:ok, _half} = Image.sepia(image, 0.5)

  """
  @doc since: "0.67.0"
  @doc subject: "Basic Adjustments"

  @spec sepia(image :: Vimage.t(), strength :: float()) ::
          {:ok, Vimage.t()} | {:error, error()}
  def sepia(%Vimage{} = image, strength \\ 1.0)
      when is_multiplier(strength) and strength <= 1.0 do
    matrix = blend_with_identity(@sepia_matrix, strength)

    without_alpha_band(image, fn srgb ->
      with {:ok, m} <- Vix.Vips.Image.new_matrix_from_array(3, 3, matrix) do
        Vix.Vips.Operation.recomb(srgb, m)
      end
    end)
  end

  @doc """
  Applies a sepia tone to an image or raises on error.

  See `sepia/2` for argument and option documentation.

  """
  @doc since: "0.67.0"
  @doc subject: "Basic Adjustments"

  @spec sepia!(image :: Vimage.t(), strength :: float()) :: Vimage.t() | no_return()
  def sepia!(%Vimage{} = image, strength \\ 1.0)
      when is_multiplier(strength) and strength <= 1.0 do
    case sepia(image, strength) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Applies a single-colour tint to an image.

  The image is converted to greyscale and the resulting
  luminance is multiplied by the supplied tint colour. White
  source pixels become the tint colour, black source pixels
  remain black, and intermediate luminances scale linearly.
  Alpha bands are preserved unchanged.

  Useful for the imgix `monochrome=#hex` /
  ImageKit `e-monochrome` family of CDN options, where a
  photograph is rendered as a coloured monochrome.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `color` is any value `Image.Pixel.to_pixel/3` accepts —
    a hex string, a CSS named colour atom, an `[r, g, b]`
    list (0–255), or any `Color.*` struct.

  ### Returns

  * `{:ok, tinted_image}` or

  * `{:error, reason}`.

  ### Example

      iex> image = Image.open!("./test/support/images/cat.png")
      iex> {:ok, _gold} = Image.tint(image, "#a08020")

  """
  @doc since: "0.67.0"
  @doc subject: "Basic Adjustments"

  @spec tint(image :: Vimage.t(), color :: Image.Pixel.t() | binary() | atom()) ::
          {:ok, Vimage.t()} | {:error, error()}
  # ITU-R BT.601 luma weights — the standard "perceived
  # lightness" projection from sRGB to greyscale.
  @luma_r 0.299
  @luma_g 0.587
  @luma_b 0.114

  def tint(%Vimage{} = image, color) do
    with {:ok, [r, g, b | _]} <- Image.Pixel.to_pixel(image, color) do
      # Build a 3x3 matrix where each output channel is the
      # source luminance scaled by the corresponding tint
      # channel: out_r = luma * r/255, etc. One libvips
      # `recomb` pass replaces a `to_colorspace(:bw) →
      # bandjoin → linear` chain that would produce a
      # 3-band image with a stale B&W interpretation flag.
      matrix = [
        [@luma_r * r / 255, @luma_g * r / 255, @luma_b * r / 255],
        [@luma_r * g / 255, @luma_g * g / 255, @luma_b * g / 255],
        [@luma_r * b / 255, @luma_g * b / 255, @luma_b * b / 255]
      ]

      without_alpha_band(image, fn srgb ->
        with {:ok, m} <- Vix.Vips.Image.new_matrix_from_array(3, 3, matrix) do
          Vix.Vips.Operation.recomb(srgb, m)
        end
      end)
    end
  end

  @doc """
  Applies a single-colour tint to an image or raises on error.

  See `tint/2` for argument documentation.

  """
  @doc since: "0.67.0"
  @doc subject: "Basic Adjustments"

  @spec tint!(image :: Vimage.t(), color :: Image.Pixel.t() | binary() | atom()) ::
          Vimage.t() | no_return()
  def tint!(%Vimage{} = image, color) do
    case tint(image, color) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @valid_fade_edges [:top, :bottom, :left, :right]

  @doc """
  Applies an alpha-gradient fade-out to one or more edges of
  an image.

  Each requested edge gets a linear alpha ramp from `0` at the
  outer pixel to `255` at `:length` pixels in. The resulting
  per-edge masks are combined with a per-pixel minimum (the
  most-faded value wins at corners), and the combined mask is
  multiplied into the image's alpha band. If the image has no
  alpha band, an opaque one is added first.

  Useful for the Cloudinary `e_fade:N` family of CDN options.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:edges` is an atom or a list of atoms drawn from
    `:top`, `:bottom`, `:left`, `:right`. The atom `:all`
    is shorthand for all four edges. The default is
    `:bottom`.

  * `:length` is the fade distance. Either an integer number
    of pixels, or a float in `(0.0, 1.0]` interpreted as a
    fraction of the relevant dimension (image height for
    `:top` / `:bottom`, width for `:left` / `:right`). The
    default is `0.2` (20% of the dimension).

  ### Returns

  * `{:ok, faded_image}` or

  * `{:error, reason}`.

  ### Example

      iex> image = Image.open!("./test/support/images/Hong-Kong-2015-07-1998.jpg")
      iex> {:ok, _faded} = Image.fade(image, edges: [:bottom, :right], length: 0.15)

  """
  @doc since: "0.67.0"
  @doc subject: "Operation"

  @spec fade(image :: Vimage.t(), options :: Keyword.t()) ::
          {:ok, Vimage.t()} | {:error, error()}
  def fade(%Vimage{} = image, options \\ []) do
    edges = options |> Keyword.get(:edges, :bottom) |> normalise_fade_edges()
    length_opt = Keyword.get(options, :length, 0.2)

    with :ok <- validate_fade_edges(edges),
         {:ok, masks} <- build_fade_masks(image, edges, length_opt) do
      combined = combine_masks_min(masks)
      apply_fade_mask(image, combined)
    end
  end

  @doc """
  Applies an alpha-gradient fade-out to an image, or raises on
  error. See `fade/2` for argument and option documentation.

  """
  @doc since: "0.67.0"
  @doc subject: "Operation"

  @spec fade!(image :: Vimage.t(), options :: Keyword.t()) :: Vimage.t() | no_return()
  def fade!(%Vimage{} = image, options \\ []) do
    case fade(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  defp normalise_fade_edges(:all), do: @valid_fade_edges
  defp normalise_fade_edges(edge) when is_atom(edge), do: [edge]
  defp normalise_fade_edges(edges) when is_list(edges), do: edges

  defp validate_fade_edges(edges) do
    invalid = Enum.reject(edges, &(&1 in @valid_fade_edges))

    if invalid == [] do
      :ok
    else
      {:error,
       %Image.Error{
         message: "Invalid fade edge(s): #{inspect(invalid)}. " <>
                    "Allowed: #{inspect(@valid_fade_edges)} or :all",
         reason: "Invalid fade edges"
       }}
    end
  end

  # Build one full-image-sized greyscale mask per edge. Each
  # mask is white (255) where the image is fully visible and
  # ramps to black (0) at the edge over the configured length.
  defp build_fade_masks(image, edges, length_opt) do
    width = width(image)
    height = height(image)

    Enum.reduce_while(edges, {:ok, []}, fn edge, {:ok, acc} ->
      length_px = fade_length(edge, length_opt, width, height)

      case build_fade_edge_mask(width, height, edge, length_px) do
        {:ok, mask} -> {:cont, {:ok, [mask | acc]}}
        other -> {:halt, other}
      end
    end)
  end

  defp fade_length(edge, length, _width, height) when edge in [:top, :bottom] and is_float(length),
    do: round(length * height)

  defp fade_length(edge, length, width, _height) when edge in [:left, :right] and is_float(length),
    do: round(length * width)

  defp fade_length(_edge, length, _width, _height) when is_integer(length) and length > 0,
    do: length

  # Render a single SVG gradient that's white in the body and
  # ramps to black on the requested edge. Returns a 1-band
  # u8 image the same size as the source.
  defp build_fade_edge_mask(width, height, edge, length_px) do
    {x1, y1, x2, y2, stop} = fade_gradient_geometry(edge, width, height, length_px)

    svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}">
      <defs>
        <linearGradient id="g" gradientUnits="userSpaceOnUse"
          x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}">
          <stop offset="0" stop-color="black"/>
          <stop offset="#{stop}" stop-color="white"/>
          <stop offset="1" stop-color="white"/>
        </linearGradient>
      </defs>
      <rect width="#{width}" height="#{height}" fill="url(#g)"/>
    </svg>
    """

    with {:ok, {svg_image, _flags}} <- Operation.svgload_buffer(svg) do
      # SVG render emits an RGBA image; collapse to a 1-band
      # luminance mask so the per-pixel `min` combine across
      # edges is straightforward.
      to_colorspace(Operation.extract_band!(svg_image, 0, n: 3), :bw)
    end
  end

  # Geometry of the gradient axis. The gradient runs *into* the
  # image perpendicular to the edge, length `length_px`, and
  # the inner stop is `length_px / dim` of the way along the
  # full SVG axis (which spans the whole image).
  defp fade_gradient_geometry(:top, width, height, length_px) do
    {div(width, 2), 0, div(width, 2), height, safe_stop(length_px, height)}
  end

  defp fade_gradient_geometry(:bottom, width, height, length_px) do
    {div(width, 2), height, div(width, 2), 0, safe_stop(length_px, height)}
  end

  defp fade_gradient_geometry(:left, width, height, length_px) do
    {0, div(height, 2), width, div(height, 2), safe_stop(length_px, width)}
  end

  defp fade_gradient_geometry(:right, width, height, length_px) do
    {width, div(height, 2), 0, div(height, 2), safe_stop(length_px, width)}
  end

  defp safe_stop(length_px, dim) do
    fraction = length_px / max(dim, 1)
    fraction |> max(0.0) |> min(1.0) |> Float.round(6)
  end

  @doc """
  Composites a soft drop shadow underneath the image's
  alpha-shaped silhouette.

  Useful for the ImageKit `e-shadow` and Cloudinary
  `e_shadow` CDN options, and for general UI use.

  The output is the same size as the input. Shadow content
  that would fall outside the input bounds is clipped — pad
  the input with `Image.embed/3` first if you need shadow
  spill-out.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`. If the image has
    no alpha band, an opaque one is added first so the
    shadow takes the rectangular shape of the image.

  * `options` is a keyword list of options.

  ### Options

  * `:color` is the shadow colour. Any value
    `Image.Pixel.to_pixel/3` accepts. Default `:black`.

  * `:opacity` is a float in `[0.0, 1.0]` controlling the
    shadow's overall intensity. Default `0.5`.

  * `:sigma` is the Gaussian blur sigma applied to the
    shadow's alpha to soften its edges. A larger value
    produces a softer, more diffuse shadow. Default `5.0`.

  * `:dx` is the horizontal shadow offset in pixels.
    Positive values shift the shadow to the right. Default
    `0`.

  * `:dy` is the vertical shadow offset in pixels. Positive
    values shift the shadow down. Default
    `round(sigma * 2)`.

  ### Returns

  * `{:ok, image_with_shadow}` or

  * `{:error, reason}`.

  ### Example

      iex> image = Image.open!("./test/support/images/cat.png")
      iex> {:ok, _shadowed} = Image.drop_shadow(image, sigma: 8.0, dy: 12)

  """
  @doc since: "0.67.0"
  @doc subject: "Operation"

  @spec drop_shadow(image :: Vimage.t(), options :: Keyword.t()) ::
          {:ok, Vimage.t()} | {:error, error()}
  def drop_shadow(%Vimage{} = image, options \\ []) do
    color = Keyword.get(options, :color, :black)
    opacity = Keyword.get(options, :opacity, 0.5)
    sigma = Keyword.get(options, :sigma, 5.0)
    dx = Keyword.get(options, :dx, 0)
    dy = Keyword.get(options, :dy, round(sigma * 2))

    with :ok <- validate_drop_shadow_args(opacity, sigma) do
      image = if has_alpha?(image), do: image, else: add_alpha!(image, :opaque)
      width = width(image)
      height = height(image)
      {_colour_bands, alpha} = split_alpha(image)

      # Shadow alpha = source alpha × opacity, blurred to
      # soften the silhouette's edges.
      use Image.Math
      shadow_alpha_f = alpha * opacity

      with {:ok, shadow_alpha} <- Operation.cast(shadow_alpha_f, :VIPS_FORMAT_UCHAR),
           {:ok, blurred} <- Operation.gaussblur(shadow_alpha, sigma),
           {:ok, [r, g, b | _]} <- Image.Pixel.to_pixel(image, color),
           {:ok, shadow_rgb} <- Image.new(width, height, color: [r, g, b]),
           {:ok, shadow} <- add_alpha(shadow_rgb, blurred),
           {:ok, base} <- Image.new(width, height, color: [0, 0, 0, 0]),
           {:ok, base_with_shadow} <- Operation.composite2(base, shadow, :VIPS_BLEND_MODE_OVER, x: dx, y: dy) do
        Operation.composite2(base_with_shadow, image, :VIPS_BLEND_MODE_OVER, x: 0, y: 0)
      end
    end
  end

  @doc """
  Composites a soft drop shadow under an image, or raises on
  error. See `drop_shadow/2` for argument and option
  documentation.

  """
  @doc since: "0.67.0"
  @doc subject: "Operation"

  @spec drop_shadow!(image :: Vimage.t(), options :: Keyword.t()) :: Vimage.t() | no_return()
  def drop_shadow!(%Vimage{} = image, options \\ []) do
    case drop_shadow(image, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  defp validate_drop_shadow_args(opacity, sigma) do
    cond do
      not (is_number(opacity) and opacity >= 0.0 and opacity <= 1.0) ->
        {:error,
         %Image.Error{
           message: ":opacity must be a number in [0.0, 1.0]",
           reason: ":opacity must be a number in [0.0, 1.0]"
         }}

      not (is_number(sigma) and sigma > 0.0) ->
        {:error,
         %Image.Error{
           message: ":sigma must be a positive number",
           reason: ":sigma must be a positive number"
         }}

      true ->
        :ok
    end
  end

  defp combine_masks_min([single]), do: single

  defp combine_masks_min([first | rest]) do
    use Image.Math

    Enum.reduce(rest, first, fn mask, acc ->
      # Per-pixel min via the standard libvips idiom: a where
      # a < b, otherwise b.
      if_then_else!(acc < mask, acc, mask)
    end)
  end

  # Multiply the combined fade mask into the image's alpha
  # band. Adds an opaque alpha band first if the image has
  # none.
  defp apply_fade_mask(image, mask_u8) do
    image =
      if has_alpha?(image), do: image, else: add_alpha!(image, :opaque)

    {colour_bands, alpha} = split_alpha(image)

    use Image.Math
    scaled_alpha = alpha * mask_u8 / 255.0

    with {:ok, scaled_alpha} <- Operation.cast(scaled_alpha, :VIPS_FORMAT_UCHAR) do
      add_alpha(colour_bands, scaled_alpha)
    end
  end

  # Blend a 3x3 colour matrix with the 3x3 identity by
  # `strength`. Result is row-major nested lists ready for
  # `Vix.Vips.Image.new_matrix_from_array/3`.
  defp blend_with_identity(matrix, 1.0), do: matrix

  defp blend_with_identity(matrix, strength) do
    inv = 1.0 - strength

    matrix
    |> Enum.with_index()
    |> Enum.map(fn {row, i} ->
      row
      |> Enum.with_index()
      |> Enum.map(fn {value, j} ->
        identity = if i == j, do: 1.0, else: 0.0
        inv * identity + strength * value
      end)
    end)
  end

  @doc """
  Reduces an image's tonal range to `levels` distinct values
  per band ("posterize").

  Each band is quantized into `levels` evenly-spaced bands; the
  result is a flat-shaded, comic-strip rendering of the source.

  Alpha bands are preserved unchanged. The image is processed
  in its current colour space — call `to_colorspace/2` first
  to posterize against a different working space.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `levels` is an integer in `2..256`. Lower values produce
    flatter output; `2` is a strict two-tone per band.

  ### Returns

  * `{:ok, posterized_image}` or

  * `{:error, reason}`.

  ### Example

      iex> image = Image.open!("./test/support/images/cat.png")
      iex> {:ok, _flat} = Image.posterize(image, 4)

  """
  @doc since: "0.67.0"
  @doc subject: "Operation"

  @spec posterize(image :: Vimage.t(), levels :: pos_integer()) ::
          {:ok, Vimage.t()} | {:error, error()}
  def posterize(%Vimage{} = image, levels)
      when is_integer(levels) and levels >= 2 and levels <= 256 do
    use Image.Math

    band_format = Vix.Vips.Image.format(image)
    step = 256.0 / levels

    without_alpha_band(image, fn srgb ->
      # Quantize each band: floor(value / step) * step.
      # Cast to integer first to perform the floor — the band
      # format is restored at the end so the output matches the
      # input pixel type.
      quantized =
        srgb
        |> Operation.linear!([1.0 / step], [0.0])
        |> Operation.cast!(:VIPS_FORMAT_UCHAR)
        |> Operation.linear!([step], [0.0])

      Operation.cast(quantized, band_format)
    end)
  end

  @doc """
  Reduces an image's tonal range to `levels` distinct values
  per band, or raises on error.

  See `posterize/2` for argument documentation.

  """
  @doc since: "0.67.0"
  @doc subject: "Operation"

  @spec posterize!(image :: Vimage.t(), levels :: pos_integer()) :: Vimage.t() | no_return()
  def posterize!(%Vimage{} = image, levels) do
    case posterize(image, levels) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Multiplies an image's alpha channel by `factor`.

  If the image has no alpha band, an opaque one is added first
  so that `factor < 1.0` produces a translucent result. The
  colour bands are not changed; this is intentional — opacity
  is an *alpha* operation, distinct from a brightness or
  saturation curve.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `factor` is a float in `[0.0, 1.0]`. `1.0` is a no-op (the
    image is returned unchanged when it already has alpha);
    `0.0` makes the entire image fully transparent;
    intermediate values produce proportional translucency.
    Cloudinary's `o_<n>` and ImageKit's `e-opacity` both use
    this `0..1` (or `0..100` percentage) convention.

  ### Returns

  * `{:ok, alpha_adjusted_image}` or

  * `{:error, reason}`.

  ### Example

      iex> image = Image.open!("./test/support/images/cat.png")
      iex> {:ok, _half} = Image.opacity(image, 0.5)

  """
  @doc since: "0.67.0"
  @doc subject: "Operation"

  @spec opacity(image :: Vimage.t(), factor :: float()) ::
          {:ok, Vimage.t()} | {:error, error()}
  def opacity(%Vimage{} = image, factor)
      when is_multiplier(factor) and factor <= 1.0 do
    image =
      if has_alpha?(image), do: image, else: add_alpha!(image, :opaque)

    {colour_bands, alpha} = split_alpha(image)

    with {:ok, scaled_alpha} <- Operation.linear(alpha, [factor], [0.0]),
         {:ok, scaled_alpha} <- Operation.cast(scaled_alpha, :VIPS_FORMAT_UCHAR) do
      add_alpha(colour_bands, scaled_alpha)
    end
  end

  @doc """
  Multiplies an image's alpha channel by `factor`, or raises on
  error.

  See `opacity/2` for argument documentation.

  """
  @doc since: "0.67.0"
  @doc subject: "Operation"

  @spec opacity!(image :: Vimage.t(), factor :: float()) :: Vimage.t() | no_return()
  def opacity!(%Vimage{} = image, factor) do
    case opacity(image, factor) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Apply an curve adjustment to an image's saturation
  (chroma) such that less saturated colors are more
  affected than more saturated colors.

  This operation is similar to the vibrance function
  in Adobe Lightroom. However this implementation does
  not account for skin tones.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `vibrance` is any float greater than `0.0`. A number less
    than `1.0` means reduce vibrance. A number greater than `1.0`
    means increase vibrance.

  * `options` is a keyword list of options.

  ### Options

  * `:threshold` is the saturation level above which no
    adjustment is made. The range is `1..100` with a default
    of `70`.

  ### Returns

  * `{:ok, adjusted_image}` or

  * `{:error, reason}`.

  """

  # See https://github.com/libvips/libvips/discussions/4039

  @doc since: "0.54.0"
  @doc subject: "Operation"

  @spec vibrance(
          image :: Vimage.t(),
          vibrance :: float(),
          options :: Options.Vibrance.vibrance_options()
        ) ::
          {:ok, Vimage.t()} | {:error, error()}

  def vibrance(%Vimage{} = image, vibrance, options \\ []) when is_multiplier(vibrance) do
    use Image.Math

    with {:ok, options} <- Options.Vibrance.validate_options(options) do
      threshold = options.threshold * 1.0
      curve = logistic_curve_rhs(vibrance)

      with_colorspace(image, :lch, fn image ->
        g5 = 255 * image[1] / threshold
        chroma = threshold * Operation.maplut!(g5, curve)
        Image.join_bands([image[0], chroma, image[2]])
      end)
    end
  end

  @doc """
  Apply an curve adjustment to an image's saturation
  (chroma) such that less saturated colors are more
  affected than more saturated colors. Raises on
  error.

  This operation is similar to the vibrance function
  in Adobe Lightroom. However this implementation does
  not account for skin tones.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `vibrance` is any float greater than `0.0`. A number less
    than `1.0` means reduce vibrance. A number greater than `1.0`
    means increase vibrance.

  * `options` is a keyword list of options.

  ### Options

  * `:threshold` is the saturation level above which no
    adjustment is made. The range is `1..100` with a default
    of `60`.

  ### Returns

  * `adjusted_image` or

  * raises an exception.

  """

  # See https://github.com/libvips/libvips/discussions/4039

  @doc since: "0.54.0"
  @doc subject: "Operation"

  @spec vibrance!(
          image :: Vimage.t(),
          vibrance :: float(),
          options :: Options.Vibrance.vibrance_options()
        ) ::
          Vimage.t() | no_return()

  def vibrance!(%Vimage{} = image, vibrance, options \\ []) do
    case vibrance(image, vibrance, options) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Returns a single band image representing the
  right hand side (positive range) of the
  [logistic function](https://en.wikipedia.org/wiki/Logistic_function).

  ### Arguments

  * `k` is a float in the range `-1.0` to `1.0` representing
    the logistic growth rate (slope of the curve).

  ### Returns

  * A single band `t:Vimage.t/0` representing the right hand side
    (positive numbers) of the logistic curve.

  ### Notes

  * This is not a general purpose curve generator. It is used by
    `Image.vibrance/3` and may, in the future, be developed into a more
    general purpose logistic curve function.

  """
  # See https://github.com/libvips/libvips/discussions/4039
  @doc since: "0.54.0"
  @doc subject: "Histogram"

  @spec logistic_curve_rhs(k :: float()) :: Vimage.t()
  def logistic_curve_rhs(k) when is_multiplier(k) do
    use Image.Math
    k = k - 1.0
    h1 = Operation.identity!() * 1.0
    h2 = 255
    h3 = 6.0 * h1 / h2
    h4 = 2.0 / (1.0 + exp!(-h3)) - 1.0

    h5 = h3 / 6.0
    h6 = h4 - h5
    h7 = k
    h8 = h5 + h7 * h6
    h8
  end

  @doc """
  Reduces noise in an image by applying a median
  filter.

  The implementation uses a [median rank filter](https://en.wikipedia.org/wiki/Median_filter)
  based on ordering the pixel values under a convolution kernel of a given
  window size and extracting the median value.

  The result is appropriate for removing
  [salt and pepper noise](https://en.wikipedia.org/wiki/Salt-and-pepper_noise) and
  may be useful for smoothing gaussian noise in some cases.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `window_size` is the integer size of the convolution kernel used
    in the median rank filter. The default is `3`.

  ### Returns

  * `{:ok, reduced_noise_image}` or

  * `{:error, reason}`

  """
  @doc since: "0.35.0"
  @doc subject: "Operation"

  @spec reduce_noise(image :: Vimage.t(), window_size :: pos_integer()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def reduce_noise(%Vimage{} = image, window_size \\ @default_median_window_size) do
    Operation.rank(image, window_size, window_size, div(window_size * window_size, 2))
  end

  @doc """
  Reduces noise in an image by applying a median
  filter or raises an exception.

  The implementation uses a [median rank filter](https://en.wikipedia.org/wiki/Median_filter)
  based on ordering the pixel values under a convolution kernel of a given
  window size and extracting the median value.

  The result is appropriate for removing
  [salt and pepper noise](https://en.wikipedia.org/wiki/Salt-and-pepper_noise) and
  may be useful for smoothing gaussian noise in some cases.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `window_size` is the integer size of the convolution kernel used
    in the median rank filter. The default is `3`.

  ### Returns

  * `reduced_noise_image` or

  * raises an exception.

  """
  @doc since: "0.35.0"
  @doc subject: "Operation"

  @spec reduce_noise!(image :: Vimage.t(), window_size :: pos_integer()) ::
          Vimage.t() | no_return()

  def reduce_noise!(%Vimage{} = image, window_size \\ @default_median_window_size) do
    case reduce_noise(image, window_size) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Returns an image as a nested list of pixels.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, list}` where `list` is a list of rows where is row is a list
    of pixels and each pixel is a list of numbers. Each pixel will have
    1 to 4 numbers depending on the number of bands in the image.

  * `{:error, reason}`

  ### Notes

  This function is intended primary for debugging purposes.

  It renders the image to memory as a binary (therefore executing a full
  image pipeline) and then decomposes the binary into a list of lists.

  As a result it can consume considerable amounst of memory and time
  for anything other than small images.

  ### Example

      iex> image = Image.new!(3, 4, color: :green)
      iex> Image.to_list(image)
      {:ok,
       [
         [[0, 128, 0], [0, 128, 0], [0, 128, 0]],
         [[0, 128, 0], [0, 128, 0], [0, 128, 0]],
         [[0, 128, 0], [0, 128, 0], [0, 128, 0]],
         [[0, 128, 0], [0, 128, 0], [0, 128, 0]]
       ]}

  """
  @doc subject: "Matrix", since: "0.62.0"

  @spec to_list(image :: Vimage.t()) ::
          {:ok, list()} | {:error, error()}

  def to_list(%Vimage{} = image) do
    with {:ok, tensor} <- Vix.Vips.Image.write_to_tensor(image),
         %{data: binary, type: type, shape: {_height, width, bands}} = tensor,
         {:ok, pixels} <- Image.Pixels.pixels_from_binary(binary, type, bands) do
      rows = Enum.chunk_every(pixels, width)
      {:ok, rows}
    end
  end

  if match?({:module, _module}, Code.ensure_compiled(Nx)) do
    @doc """
    Converts an image into an [Nx](https://hex.pm/packages/nx)
    tensor.

    ### Arguments

    * `image` is any `t:Vimage.t/0`

    * `options` is a keyword list of options

    ### Options

    * `:shape` determines how the tensor is shaped. The valid
      values are:

      * `:hwb` or `:hwc` which leaves the tensor unchanged with
        the underlying data in `{height, width, bands}` shape.
        This is the default action.

      * `:whc` or `:whb` which reshapes the tensor to
        `width, height, bands`.

    ### Returns

    * `{:ok, tensor)` where tensor is an `t:Nx.Tensor.t/0` tensor
      suitable for use in the `Nx` library or

    * `{:error, reason}`.

    ### Note

    * The image type, `t:Vix.Vips.Image.t/0` stores data in
      `{width, height, band}` format. However when the data is conerted
      into an `t:Nx.Tensor.t/0` the data is written in `{height, width, band}`
      format.

    ### Example

        iex> {:ok, image} = Vix.Vips.Operation.black(3, 3)
        iex> Image.to_nx(image, backend: Nx.BinaryBackend)
        {:ok,
          Nx.tensor([[[0], [0], [0]], [[0], [0], [0]], [[0], [0], [0]]],
            type: {:u, 8}, names: [:height, :width, :bands], backend: Nx.BinaryBackend)}

    """

    # For some reason dialyzer thinks Vix.Vips.Image.write_to_tensor/1
    # can only return `{:error, _}`.
    @dialyzer {:nowarn_function, {:to_nx, 1}}
    @dialyzer {:nowarn_function, {:to_nx, 2}}

    @default_shape :hwb

    @doc subject: "Matrix", since: "0.5.0"

    @spec to_nx(image :: Vimage.t(), options :: Keyword.t()) ::
            {:ok, Nx.Tensor.t()} | {:error, error()}

    def to_nx(%Vimage{} = image, options \\ []) do
      {to_shape, options} = Keyword.pop(options, :shape, @default_shape)

      with {:ok, tensor} <- Vix.Vips.Image.write_to_tensor(image),
           {:ok, shape, names} <- maybe_reshape_tensor(tensor, to_shape) do
        %Vix.Tensor{data: binary, type: type} = tensor

        binary
        |> Nx.from_binary(type, options)
        |> Nx.reshape(shape, names: names)
        |> wrap(:ok)
      end
    end

    # Because of the dialyzer issue for to_nx/2, dialyzer then
    # thinks this function won't be called.
    @dialyzer {:nowarn_function, {:maybe_reshape_tensor, 2}}

    # write_to_tensor writes in height, widght, bands format. No reshape
    # is required.
    defp maybe_reshape_tensor(%Vix.Tensor{shape: shape}, :hwc),
      do: {:ok, shape, [:height, :width, :bands]}

    defp maybe_reshape_tensor(%Vix.Tensor{shape: shape}, :hwb),
      do: {:ok, shape, [:height, :width, :bands]}

    defp maybe_reshape_tensor(%Vix.Tensor{} = tensor, :whb),
      do: maybe_reshape_tensor(tensor, :whc)

    # We need to reshape the tensor since the default is
    # :hwc
    defp maybe_reshape_tensor(%Vix.Tensor{shape: {x, y, bands}}, :whc),
      do: {:ok, {y, x, bands}, [:width, :height, :bands]}

    defp maybe_reshape_tensor(_tensor, shape) do
      {:error,
       "Invalid shape. Allowable shapes are :whb, :whc, :hwc and :hwb. Found #{inspect(shape)}"}
    end

    @doc """
    Converts an image into an [Nx](https://hex.pm/packages/nx)
    tensor.

    ### Arguments

    * `image` is any `t:Vimage.t/0`

    * `options` is a keyword list of options

    ### Options

    * `:shape` determines how the tensor is shaped. The valid
      values are:

      * `:hwb` or `:hwc` which leaves the tensor unchanged with
        the underlying data in `{height, width, bands}` shape.
        This is the default action.

      * `:whc` or `:whb` which reshapes the tensor to
        `width, height, bands`.

    ### Returns

    * `tensor` where tensor is an `t:Nx.Tensor.t/0` tensor
      suitable for use in the `Nx` library or

    * raises an exception.

    ### Note

    * The image type, `t:Vix.Vips.Image.t/0` stores data in
      `{width, height, band}` format. However when the data is conerted
      into an `t:Nx.Tensor.t/0` the data is written in `{height, width, band}`
      format.

    ### Example

        iex> {:ok, image} = Vix.Vips.Operation.black(3, 3)
        iex> Image.to_nx!(image, backend: Nx.BinaryBackend)
        Nx.tensor([[[0], [0], [0]], [[0], [0], [0]], [[0], [0], [0]]],
          type: {:u, 8}, names: [:height, :width, :bands], backend: Nx.BinaryBackend)

    """
    @doc subject: "Matrix", since: "0.27.0"

    # Because of the dialyzer issue for to_nx/2, dialyzer then
    # thinks this function has no local return.
    @dialyzer {:nowarn_function, {:to_nx!, 1}}
    @dialyzer {:nowarn_function, {:to_nx!, 2}}

    @spec to_nx!(image :: Vimage.t(), options :: Keyword.t()) ::
            Nx.Tensor.t() | no_return()

    def to_nx!(%Vimage{} = image, options \\ []) do
      case to_nx(image, options) do
        {:ok, tensor} -> tensor
        {:error, reason} -> raise Image.Error, reason
      end
    end

    @doc """
    Converts an [Nx](https://hex.pm/packages/nx) tensor
    into an image.

    ### Arguments

    * `tensor` is any three dimensional `t:Nx.Tensor.t/0`.

    * `options` is a keyword list of options. For valid
      options see `Nx.from_binary/2`.

    ### Returns

    * `{:ok, image}` or

    * `{:error, reason}`

    ### Notes

    In order to convert a tensor into an image it must
    satisfy these constraints:

    * It must have three dimensions.

    * It must have a tensor type that is compatible
      with `libvips` (most tensors will satisfy this
      requirement other than tensors whose type is complex).

    * The names of the axes must be `[:width, :height, any_other]`
      or `[:height, :width, any_other]`.

    ### Example

        iex> {:ok, image} = Vix.Vips.Operation.black(3, 3)
        iex> {:ok, tensor} = Image.to_nx(image)
        iex> {:ok, _image_2} = Image.from_nx(tensor)

    """
    @doc subject: "Matrix", since: "0.5.0"

    @spec from_nx(tensor :: Nx.Tensor.t()) :: {:ok, Vimage.t()} | {:error, error()}
    def from_nx(tensor) when is_struct(tensor, Nx.Tensor) do
      with {:ok, tensor_format} <- Image.BandFormat.image_format_from_nx(tensor) do
        case Nx.shape(tensor) do
          {x, y, bands} when bands in 1..5 ->
            {width, height} = dimensions_from_tensor(tensor, x, y)
            binary = Nx.to_binary(tensor)
            Vix.Vips.Image.new_from_binary(binary, width, height, bands, tensor_format)

          shape ->
            shape_error(shape)
        end
      end
    end

    @doc """
    Converts an [Nx](https://hex.pm/packages/nx) tensor
    into an image or raises an exception.

    ### Arguments

    * `tensor` is any three dimensional `t:Nx.Tensor.t/0`.

    * `options` is a keyword list of options. For valid
      options see `Nx.from_binary/2`.

    ### Returns

    * `image` or

    * `{:error, reason}`

    ### Notes

    In order to convert a tensor into an image it must
    satisfy these constraints:

    * It must have three dimensions.

    * It must have a tensor type that is compatible
      with `libvips` (most tensors will satisfy this
      requirement other than tensors whose type is complex).

    * The names of the axes must be `[:width, :height, any_other]`
      or `[:height, :width, any_other]`.

    ### Example

        iex> {:ok, image} = Vix.Vips.Operation.black(3, 3)
        iex> {:ok, tensor} = Image.to_nx(image)
        iex> _image_2 = Image.from_nx(tensor)

    """
    @doc subject: "Matrix", since: "0.47.0"

    @spec from_nx!(tensor :: Nx.Tensor.t()) :: Vimage.t() | no_return()
    def from_nx!(tensor) when is_struct(tensor, Nx.Tensor) do
      case from_nx(tensor) do
        {:ok, image} -> image
        {:error, reason} -> raise Image.Error, reason
      end
    end

    defp dimensions_from_tensor(tensor, x, y) do
      case Nx.names(tensor) do
        [:height, _, _] -> {y, x}
        _other -> {x, y}
      end
    end

    defp shape_error(shape) do
      {:error,
       "The tensor must have the shape {height, width, bands} with bands between " <>
         "1 and 5. Found shape #{inspect(shape)}."}
    end

    @doc """
    Performs a warp perspective transformation on an
    image.

    Requires `Nx` to be configured as a dependency.

    ### Arguments

    * `image` is any `t:Vimage.t/0`

    * `source` is a list of four 2-tuples representing the
      four corners of the subject-of-interest in `image`.

    * `destination` is a list of four 2-tuples representing the
      four corners of the destination image into which the
      subject-of-interest is transformed.

    * `options` is a keyword list of options. The default
      is `[]`.

    ### Options

    * `:background` defines the color of any generated background
      pixels. This can be specified as a single integer which will
      be applied to all bands, or a list of integers representing
      the color for each band. The color can also be supplied as a
      CSS color name as a string or atom. For example: `:misty_rose`.
      It can also be supplied as a hex string of the form `#rrggbb`.
      The default is `:black`. `:background` can also be set to `:average`
      in which case the background will be the average color of the base
      image. See also `Color.new/2` from the Color library.

    * `:extend_mode` determines how any additional pixels
      are generated. The values are:

      * `:black` (the default) meaning the generated pixels are
        black.
      * `:white` meaning the generated pixels are white.
      * `:copy` means the generated pixels take the value of the
        nearest edge pixel of the base image.
      * `:repeat` means the generated pixels are tiles from the
        base image.
      * `:mirror` means the generated pixels are a reflected tiles of
        the base image.
      * `:background` means the generated pixels are the background
        color setin `options`.

    ### Notes

    * The image is flattened before warping and therefore any
      alpha band will be multiplied into to the image data and
      removed.

    ### Returns

    * `{:ok, warped_image}` or

    * `{:error, reason}`

    """
    @doc subject: "Distortion", since: "0.28.0"

    @spec warp_perspective(
            Vimage.t(),
            source :: quadrilateral(),
            destination :: quadrilateral(),
            Options.WarpPerspective.t()
          ) ::
            {:ok, Vimage.t()} | {:error, error()}

    def warp_perspective(%Vimage{} = image, source, destination, options \\ []) do
      with {:ok, flattened} <- flatten(image),
           {:ok, options} <- Options.WarpPerspective.validate_options(flattened, options),
           {:ok, transform_map} <- transform_matrix(flattened, source, destination) do
        Operation.mapim(flattened, transform_map, options)
      end
    end

    @doc """
    Performs a warp perspective transformation on an
    image or raises an exception.

    Requires `Nx` to be configured as a dependency.

    ### Arguments

    * `image` is any `t:Vimage.t/0`

    * `source` is a list of four 2-tuples representing the
      four corners of the subject-of-interest in `image`.

    * `destination` is a list of four 2-tuples representing the
      four corners of the destination image into which the
      subject-of-interest is transformed.

    * `options` is a keyword list of options. The default
      is `[]`.

    ### Options

    * `:background` defines the color of any generated background
      pixels. This can be specified as a single integer which will
      be applied to all bands, or a list of integers representing
      the color for each band. The color can also be supplied as a
      CSS color name as a string or atom. For example: `:misty_rose`.
      It can also be supplied as a hex string of
      the form `#rrggbb`. The default is `:black`. `:background` can
      also be set to `:average` in which case the background will be
      the average color of the base image. See also `Color.new/2` from the Color library.

    * `:extend_mode` determines how any additional pixels
      are generated. The values are:

      * `:black` (the default) meaning the generated pixels are
        black.
      * `:white` meaning the generated pixels are white.
      * `:copy` means the generated pixels take the value of the
        nearest edge pixel of the base image.
      * `:repeat` means the generated pixels are tiles from the
        base image.
      * `:mirror` means the generated pixels are a reflected tiles of
        the base image.
      * `:background` means the generated pixels are the background
        color setin `options`.

    ### Returns

    * `warped_image` or

    * raises an exception.

    ### Notes

    * The image is flattened before warping and therefore any
      alpha band will be multiplied into to the image data and
      removed.

    """
    @doc subject: "Distortion", since: "0.28.0"

    @spec warp_perspective!(
            Vimage.t(),
            source :: quadrilateral(),
            destination :: quadrilateral(),
            Options.WarpPerspective.t()
          ) ::
            Vimage.t() | no_return()

    def warp_perspective!(image, from, to, options \\ []) do
      case warp_perspective(image, from, to, options) do
        {:ok, image} -> image
        {:error, reason} -> raise Image.Error, reason
      end
    end

    @doc """
    Performs a warp perspective transformation on an
    image to straighten its perspective.

    Requires `Nx` to be configured as a dependency.

    ### Arguments

    * `image` is any `t:Vimage.t/0`.

    * `source` is a list of four 2-tuples representing the
      four corners of the subject-of-interest in `image`.

    * `options` is a keyword list of options. The default
      is `[]`.

    ### Options

    * `:background` defines the color of any generated background
      pixels. This can be specified as a single integer which will
      be applied to all bands, or a list of integers representing
      the color for each band. The color can also be supplied as a
      CSS color name as a string or atom. For example: `:misty_rose`.
      It can also be supplied as a hex string of
      the form `#rrggbb`. The default is `:black`. `:background` can
      also be set to `:average` in which case the background will be
      the average color of the base image. See also `Color.new/2` from the Color library.

    * `:extend_mode` determines how any additional pixels
      are generated. The values are:

      * `:black` (the default) meaning the generated pixels are
        black.
      * `:white` meaning the generated pixels are white.
      * `:copy` means the generated pixels take the value of the
        nearest edge pixel of the base image.
      * `:repeat` means the generated pixels are tiles from the
        base image.
      * `:mirror` means the generated pixels are a reflected tiles of
        the base image.
      * `:background` means the generated pixels are the background
        color setin `options`.

    ### Returns

    * `{:ok, destination, straightened_image}` or

    * `{:error, reason}`

    ### Notes

    * The image is flattened before warping and therefore any
      alpha band will be multiplied into to the image data and
      removed.

    * The returned `destination` is a four element list of
      2-tuples representing the four points to which the `source`
      points were transformed. `destination` can be passed as
      a parameter to `Image.crop/2` to crop the transformed image
      to the subject-of-interest that was warped.

    """
    @doc subject: "Distortion", since: "0.28.0"

    @spec straighten_perspective(
            Vimage.t(),
            source :: quadrilateral(),
            Options.WarpPerspective.t()
          ) ::
            {:ok, quadrilateral(), Vimage.t()} | {:error, error()}

    def straighten_perspective(%Vimage{} = image, source, options \\ []) do
      with [{sx1, sy1}, {sx2, _sy2}, {_sx3, _sy3}, {_sx4, sy4}] <- source do
        destination = [{sx1, sy1}, {sx2, sy1}, {sx2, sy4}, {sx1, sy4}]

        case warp_perspective(image, source, destination, options) do
          {:ok, warped} -> {:ok, destination, warped}
          other -> other
        end
      end
    end

    @doc """
    Performs a warp perspective transformation on an
    image to straighten its perspective or raises an
    exception.

    Requires `Nx` to be configured as a dependency.

    ### Arguments

    * `image` is any `t:Vimage.t/0`.

    * `source` is a list of four 2-tuples representing the
      four corners of the subject-of-interest in `image`.

    * `options` is a keyword list of options. The default
      is `[]`.

    ### Options

    * `:background` defines the color of any generated background
      pixels. This can be specified as a single integer which will
      be applied to all bands, or a list of integers representing
      the color for each band. The color can also be supplied as a
      CSS color name as a string or atom. For example: `:misty_rose`.
      It can also be supplied as a hex string of
      the form `#rrggbb`. The default is `:black`. `:background` can
      also be set to `:average` in which case the background will be
      the average color of the base image. See also `Color.new/2` from the Color library.

    * `:extend_mode` determines how any additional pixels
      are generated. The values are:

      * `:black` (the default) meaning the generated pixels are
        black.
      * `:white` meaning the generated pixels are white.
      * `:copy` means the generated pixels take the value of the
        nearest edge pixel of the base image.
      * `:repeat` means the generated pixels are tiles from the
        base image.
      * `:mirror` means the generated pixels are a reflected tiles of
        the base image.
      * `:background` means the generated pixels are the background
        color setin `options`.

    ### Returns

    * `straightened_image` or

    * `{:error, reason}`

    ### Notes

    * The image is flattened before warping and therefore any
      alpha band will be multiplied into to the image data and
      removed.

    * The returned `destination` is a four element list of
      2-tuples representing the four points to which the `source`
      points were transformed. `destination` can be passed as
      a parameter to `Image.crop/2` to crop the transformed image
      to the subject-of-interest that was warped.

    """
    @doc subject: "Distortion", since: "0.28.0"

    @spec straighten_perspective!(
            Vimage.t(),
            source :: quadrilateral(),
            Options.WarpPerspective.t()
          ) ::
            Vimage.t() | no_return()

    def straighten_perspective!(%Vimage{} = image, source, options \\ []) do
      with [{sx1, sy1}, {sx2, _sy2}, {_sx3, _sy3}, {_sx4, sy4}] <- source do
        destination = [{sx1, sy1}, {sx2, sy1}, {sx2, sy4}, {sx1, sy4}]

        case warp_perspective(image, source, destination, options) do
          {:ok, warped} -> warped
          {:error, reason} -> raise Image.Error, reason
        end
      end
    end

    @doc """
    Distorts an image using [Shepards algorithm](https://legacy.imagemagick.org/Usage/distorts/#shepards).

    Shepard’s distortion moves (or smudges) a given
    source point to a destination point.

    ### Arguments

    * `image` is any `t:Vimage.t/0`.

    * `source` is a list of 2-tuples representing the source
       points in `image`.

    * `destination` is a list of 2-tuples representing the
      the destination points into which the
      image is transformed.

    ### Example

    In this example the points around `{30,11}` are distorted to `{20,11}` and
    `{48, 29}` to `{58,29}`.

          iex> koala = Image.open!("./test/support/images/koala.gif")
          iex> {:ok, _distorted} = Image.distort(koala, [{30, 11}, {48, 29}], [{20,11}, {58,29}])

    """
    @doc subject: "Distortion", since: "0.57.0"

    @spec distort(image :: Vimage.t(), source :: list(point()), destination :: list(point())) ::
            {:ok, Vimage.t()} | {:error, error()}

    def distort(%Vimage{} = image, [{_x1, _y1} | _] = source, [{_x2, _y2} | _] = destination)
        when length(source) == length(destination) do
      use Image.Math

      index = Vix.Vips.Operation.xyz!(Image.width(image), Image.height(image))
      couples = Enum.zip(source, destination)

      {deltas, weights} =
        Enum.reduce(couples, {[], []}, fn {p1, p2}, {deltas, weights} ->
          {p1x, p1y} = p1
          {p2x, p2y} = p2

          diff = index - Tuple.to_list(p2)
          distance = diff[0] ** 2 + diff[1] ** 2

          weight = Image.if_then_else!(distance < 1.0, 1.0, 1.0 / distance)
          delta = weight * [p1x - p2x, p1y - p2y]

          {[delta | deltas], [weight | weights]}
        end)

      index = index + Vix.Vips.Operation.sum!(deltas) / Vix.Vips.Operation.sum!(weights)
      bicubic_interpolator = Vix.Vips.Interpolate.new!("bicubic")
      Vix.Vips.Operation.mapim(image, index, interpolate: bicubic_interpolator)
    end

    @doc """
    Returns a transformation matrix for a given
    image, source quadrilateral and desintation quadrilateral.

    A transformation matrix when applied to an image
    (using, for example, `Image.map/2`) maps pixels from
    the source persecptive to the destination perspective.

    Requires `Nx` to be configured as a dependency.

    ### Arguments

    * `image` is any `t:Vimage.t/0`

    * `source` is a list of four 2-tuples representing the
      four corners of the subject-of-interest in `image`.

    * `destination` is a list of four 2-tuples representing the
      four corners of the destination image into which the
      subject-of-interest is transformed.

    ### Returns

    * `{:ok, transform_matrix}` or

    * `{:error, reason}`.

    """
    @doc subject: "Distortion", since: "0.28.0"

    @spec transform_matrix(
            Vimage.t(),
            source :: quadrilateral(),
            destination :: quadrilateral()
          ) ::
            {:ok, transform_matrix :: Vimage.t()} | {:error, error()}

    def transform_matrix(image, source, destination) do
      with [{sx1, sy1}, {sx2, sy2}, {sx3, sy3}, {sx4, sy4}] <- source,
           [{dx1, dy1}, {dx2, dy2}, {dx3, dy3}, {dx4, dy4}] <- destination do
        source =
          Nx.tensor([
            [dx1, dy1, 1, 0, 0, 0, -dx1 * sx1, -dy1 * sx1],
            [dx2, dy2, 1, 0, 0, 0, -dx2 * sx2, -dy2 * sx2],
            [dx3, dy3, 1, 0, 0, 0, -dx3 * sx3, -dy3 * sx3],
            [dx4, dy4, 1, 0, 0, 0, -dx4 * sx4, -dy4 * sx4],
            [0, 0, 0, dx1, dy1, 1, -dx1 * sy1, -dy1 * sy1],
            [0, 0, 0, dx2, dy2, 1, -dx2 * sy2, -dy2 * sy2],
            [0, 0, 0, dx3, dy3, 1, -dx3 * sy3, -dy3 * sy3],
            [0, 0, 0, dx4, dy4, 1, -dx4 * sy4, -dy4 * sy4]
          ])

        destination = Nx.tensor([sx1, sx2, sx3, sx4, sy1, sy2, sy3, sy4])

        transform_matrix = Nx.LinAlg.solve(source, destination)
        {:ok, generate_map(Image.width(image), Image.height(image), transform_matrix)}
      else
        _error ->
          {:error,
           "Invalid source or destination quadrilateral. " <>
             "Found source #{inspect(source)} and destination #{inspect(destination)}."}
      end
    end

    defp generate_map(width, height, tensor) do
      use Image.Math

      [t0, t1, t2, t3, t4, t5, t6, t7] = Nx.to_list(tensor)
      index = Operation.xyz!(width, height)

      x =
        (
          t = index * [t0, t1]
          x_a = t[0] + t[1] + t2

          t = index * [t6, t7]
          x_b = t[0] + t[1] + 1

          x_a / x_b
        )

      y =
        (
          t = index * [t3, t4]
          y_a = t[0] + t[1] + t5

          t = index * [t6, t7]
          y_b = t[0] + t[1] + 1

          y_a / y_b
        )

      Operation.bandjoin!([x, y])
    end

    # TODO Needs to respect the image type when doing the
    # color channel order conversion (ie when its an RGB-A etc etc)
    # Same for interpretation (not every image is srgb!)

    if Code.ensure_loaded?(Evision) do
      @doc """
      Converts an `Image` image to an `t:Evision.Mat.t/0` image.

      Note that only images with 3 bands can be transferred
      to `eVision`.

      ### Arguments

      * `image` is any `t:Vimage.t/0`.

      * `convert_to_bgr` is a boolean indicating if the
        color order should be converted from `RGB` to `BGR`
        which is the normal channel layout for OpenCV. The
        default is `true`.

      ### Returns

      * `{:ok, evision_image}`

      * `{:error, reason}`

      ### Notes

      * `Image` images have the shape `{width, height, bands}`
        whereas `Evision` images have the shape `{height, width, bands}`
        so this function transposes the dimensions to match.

      * `Image` data is arranged as `rgb` data elements whereas
        `Evision` requires the data to be in `bgr` order. This function
        also reorders the data appropriately.

      """
      @dialyzer {:nowarn_function, {:to_evision, 2}}

      @doc subject: "Matrix", since: "0.9.0"

      def to_evision(%Vimage{} = image, convert_to_bgr \\ true) do
        with {:ok, tensor} <- to_nx(image),
             {width, height, bands} <- validate_transferable_image(image),
             %Evision.Mat{} = mat <- Evision.Mat.from_nx(tensor, {height, width, bands}),
             %Evision.Mat{} = mat <- Evision.Mat.last_dim_as_channel(mat) do
          mat =
            if convert_to_bgr,
              do: Evision.cvtColor(mat, Evision.Constant.cv_COLOR_RGB2BGR()),
              else: mat

          {:ok, mat}
        end
      end

      @doc """
      Converts to an `Image` image from an `t:Evision.Mat.t/0` image.

      ### Arguments

      * `evision_image` is any `t:Evision.Mat.t/0` image.

      ### Returns

      * `{:ok, image}`

      ### Notes

      * `Image` images have the shape `{width, height, bands}`
        whereas `Evision` images have the shape `{height, width, bands}`
        so this function transposes the dimensions to match.

      * `Image` data is arranged as `rgb` data elements whereas
        `Evision` requires the data to be in `bgr` order. This function
        also reorders the data appropriately.

      """
      @dialyzer {:nowarn_function, {:from_evision, 1}}

      @doc subject: "Matrix", since: "0.9.0"

      def from_evision(%Evision.Mat{} = evision_image) do
        with %Evision.Mat{} = mat <-
               Evision.cvtColor(evision_image, Evision.Constant.cv_COLOR_BGR2RGB()) do
          tensor = Evision.Mat.to_nx(mat)

          case Nx.shape(tensor) do
            {x, y, bands} when bands in 1..5 ->
              {width, height} = dimensions_from_tensor(tensor, x, y)

              tensor
              |> Nx.reshape({width, height, bands}, names: [:height, :width, :bands])
              |> from_nx()

            shape ->
              shape_error(shape)
          end
        end
      end
    end

    if Code.ensure_loaded?(Kino) do
      @doc """
      Transfers an image to Kino for display
      in a livebook.

      ### Arguments

      * `image` is any `t:Vimage.t/0`.

      ### Returns

      * a Kino image struct.

      ### Example

          iex> image = Image.open!("./test/support/images/Hong-Kong-2015-07-1998.jpg")
          iex> %Kino.Image{} = Image.to_kino(image)
          iex> match?(%Kino.Image{}, Image.to_kino(image))
          true

      """
      @doc subject: "Kino", since: "0.51.0"

      def to_kino(%Vimage{} = image) do
        with {:ok, srgb_image} <- Image.to_colorspace(image, :srgb),
             {:ok, u8_image} <- Image.cast(srgb_image, {:u, 8}),
             {:ok, nx_image} <- Image.to_nx(u8_image) do
          Kino.Image.new(nx_image)
        end
      end
    end
  end

  @doc """
  Applies a transformation matrix to an image.

  A transformation matrix is returned by
  `Image.transform_matrix/3`.

  `Image.warp_perspective/4` uses this function to
  apply a perspective transform to an image.

  ### Arguments

  * `image` is any `t:Vimage.t/0`

  * `transform_matrix` is a matrix returned by
    `Image.transform_matrix/3`.

  ### Returns

  * `{:ok, mapped_image}` or

  * `{:error, reason}`

  """
  @doc subject: "Operation", since: "0.28.0"

  @spec map(Vimage.t(), Vimage.t(), Keyword.t()) :: {:ok, Vimage.t()} | {:error, error()}
  def map(%Vimage{} = image, %Vimage{} = transformation_matrix, options \\ []) do
    with {:ok, options} <- Options.WarpPerspective.validate_options(image, options) do
      Operation.mapim(image, transformation_matrix, options)
    end
  end

  @doc """
  Compare two images using a particular comparison metric
  returning a score indicating the similarity of the images and
  an image highlighting the differences between the two images.

  ### Arguments

  * `image_1` is any `t:Vix.Vips.Image.t/0`.

  * `image_2` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:metric` indicates which comparison metric to use. The default
    is `:ae`. The valid metrics are:

    * [:ae](https://en.wikipedia.org/wiki/Sum_of_absolute_differences) which returns
      the absolute nuber of pixels that are different between the two images.
      The returned value is conformed to the range of the underlying image format.
      Therefore the returned value is between `0.0` (images appear to be the same)
      and `1.0` (meaning the images appear completely different).

    * [:rmse](https://en.wikipedia.org/wiki/Root-mean-square_deviation) is the root
      mean square error. The returned value is conformed to the range of
      the underlying image format. Therefore the returned value is between `0.0`
      (images appear to be the same) and `1.0` (meaning the images appear
      completely different),

    * [:mse](https://en.wikipedia.org/wiki/Mean_squared_error) which
      is the mean squared error (default). The returned value is a float
      indicating how similar the images are. A value of
      `0.0` means the images are the same. The number itself it simply a
      measure of the error difference between images. A larger number means
      the two images are less similar but the number itself cannot be
      interpreted as a percentage value.

  * `:saturation` is a float between `0.0` and `1.0` that is applied to the
    base image when overlaying the difference image. This may help the difference
    pixels become more obvious. The default ia `1.0` meaning no change in
    saturation.

  * `:brightness` is a float between `0.0` and `1.0` that is applied to the
    base image when overlaying the difference image. This may help the difference
    pixels become more obvious. The default ia `1.0` meaning no change in
    brightness.

  * `:difference_color` is the color to be used for the pixels that are
    different between the two images. This can be specified as a single integer
    which will be applied to all bands, or a list of integers representing
    he color for each band. The color can also be supplied as a
    CSS color name as a string or atom. For example: `:misty_rose`.
    It can also be supplied as a hex string of the form `#rrggbb`. The default
    is `:red`.

  * `:difference_boost` is a float multiplier that is applied to the difference
    image. This has the effect of boosting the overall brightness of the difference
    pixels making them stand out more against the background image. The default
    is `1.5`.

  ### Notes

  * The images are conformed to the band format of the
    first image before comparison and cast up to the smallest common
    format.

  * If the images differ in size, the smaller image is enlarged
    to match the larger by adding zero pixels along the bottom and right.

  * If the number of bands differs, one of the images must have one band.
    In this case, an n-band image is formed from the one-band image by joining
    `n` copies of the one-band image together, and then the two n-band images
    are operated upon.

  * The two input images are cast up to the smallest common format.

  ### Returns

  * `{:ok, comparison_metric, difference_image}` or

  * `{:error, reason}`

  """
  @doc since: "0.34.0"
  @doc subject: "Operation"

  @spec compare(Vimage.t(), Vimage.t(), Keyword.t()) ::
          {:ok, number, Vimage.t()} | {:error, error()}
  def compare(%Vimage{} = image_1, %Vimage{} = image_2, options \\ []) when is_list(options) do
    with {:ok, options} <- Options.Compare.validate_options(image_1, options),
         {:ok, image_1} <- Image.flatten(image_1),
         {:ok, image_2} <- Image.flatten(image_2),
         {:ok, difference} <- image_difference(image_1, image_2),
         {:ok, metric} <- compare_by_metric(image_1, image_2, difference, options.metric),
         {:ok, composed_difference} <- compose_difference(image_1, difference, options) do
      {:ok, metric, composed_difference}
    end
  end

  @dialyzer {:nowarn_function, {:compare_by_metric, 4}}

  # Mean square error
  # mse = ((a - b) ** 2).avg()

  defp compare_by_metric(_image_1, _image_2, difference, :mse) do
    difference
    |> Math.pow!(2)
    |> Operation.avg()
  end

  # Root mean square error, fit to the range of
  # the band format and therefore in the range 0.0 to 1.0
  defp compare_by_metric(image_1, image_2, diff, :rmse) do
    with {:ok, mse} <- compare_by_metric(image_1, image_2, diff, :mse),
         {:ok, format_size} <- format_size(image_1) do
      rmse =
        mse
        |> :math.sqrt()
        |> Kernel./(format_size)

      {:ok, rmse}
    end
  end

  # Absolute error. Count the number of pixels that are
  # different between the two images forced into a 0,0 to
  # 1.0 range

  defp compare_by_metric(image_1, image_2, difference, :ae) do
    with {:ok, non_zero} <- Image.Math.not_equal(difference, 0),
         {:ok, binary} <- Vimage.write_to_binary(non_zero[0]),
         {:ok, non_zero_pixel_count} <- non_zero_pixel_count(binary) do
      image_1_size = Image.width(image_1) * Image.height(image_1)
      image_2_size = Image.width(image_2) * Image.height(image_2)

      {:ok, non_zero_pixel_count / max(image_1_size, image_2_size)}
    end
  end

  defp compare_by_metric(_image_1, _image_2, _difference, metric) do
    {:error,
     %Image.Error{
       message: "Invalid metric #{inspect(metric)}. Value metrics are :ae, :mse and :rmse",
       reason: "Invalid metric #{inspect(metric)}. Value metrics are :ae, :mse and :rmse"
     }}
  end

  defp image_difference(image_1, image_2) do
    with {:ok, image_2} <- Operation.cast(image_2, Vix.Vips.Image.format(image_1)),
         {:ok, difference} <- Image.Math.subtract(image_1, image_2) do
      Operation.abs(difference)
    end
  end

  defp compose_difference(image, difference, options) do
    with {:ok, color_difference} <-
           if_then_else(difference, options.difference_color, :transparent),
         {:ok, color_difference} <-
           Image.Math.multiply(color_difference, options.difference_boost),
         {:ok, bw_difference} <- to_colorspace(difference, :bw),
         {:ok, alpha_difference} <- add_alpha(color_difference, bw_difference),
         {:ok, saturated} <- saturation(image, options.saturation),
         {:ok, brightened} <- brightness(saturated, options.brightness),
         {:ok, composed} <- compose(brightened, alpha_difference) do
      Operation.cast(composed, Vix.Vips.Image.format(image))
    end
  end

  @dialyzer {:nowarn_function, {:format_size, 1}}

  defp format_size(image) do
    case Image.BandFormat.nx_format(image) do
      {:ok, {:u, size}} -> {:ok, round(:math.pow(2, size))}
      {:ok, {:f, size}} -> {:ok, round(:math.pow(2, trunc(size)))}
    end
  end

  defp non_zero_pixel_count(binary) do
    count_of_different_pixels =
      for <<byte::integer-8-native <- binary>>, byte != 0, reduce: 0 do
        acc -> acc + 1
      end

    {:ok, count_of_different_pixels}
  end

  @doc """
  Returns a 64-bit (for a hash size of the default 64) difference hash as a
  binary.

  Image hashes can be used to compare the similarity
  of images. See `Image.hamming_distance/2`.

  A `dhash` is a "difference hash" for a given image. This
  is a perceptual hash based on Neal Krawetz's dHash algorithm in
  a [Hacker Factor](http://www.hackerfactor.com/blog/index.php?/archives/529-Kind-of-Like-That.html)
  blog entry.

  The code is adapted from the Ruby implementation in
  [dhash-vips](https://github.com/Nakilon/dhash-vips).

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `hash_size_bits` is the size in bits of the returned hash.
    The default is `64`. The returned binary is only
    guaranteed to be the provided size if `sqrt(hash_size_bits)` is
    an integer.

  ### Returns

  * `{:ok, 64-bit binary}` or

  * `{:error, reason}`

  ### Example

        iex> {:ok, image} = Image.open("./test/support/images/Kamchatka-2019-8754.jpg")
        iex> Image.dhash(image)
        {:ok, <<227, 127, 61, 34, 206, 143, 156, 122>>}

  """
  @doc subject: "Metadata", since: "0.6.0"

  @spec dhash(image :: Vimage.t(), hash_size :: pos_integer()) ::
          {:ok, image_hash()} | {:error, error()}

  def dhash(%Vimage{} = image, hash_size_bits \\ 64)
      when is_integer(hash_size_bits) and hash_size_bits > 0 do
    hash_size = round(:math.sqrt(hash_size_bits))

    with {:ok, convolution} <- Image.Matrix.image_from_matrix([[1.0, -1.0]]),
         {:ok, pixels} <- dhash_pixels(image, convolution, hash_size) do
      dhash = for <<_::7, v::1 <- pixels>>, into: <<>>, do: <<v::1>>
      {:ok, dhash}
    end
  end

  defp dhash_pixels(image, convolution, hash_size) do
    image
    |> pixelate_for_hash(hash_size)
    |> Operation.cast!(:VIPS_FORMAT_INT)
    |> Operation.conv!(convolution)
    |> crop!(1, 0, hash_size, hash_size)
    |> Math.greater_than!(0)
    |> Math.divide!(255.0)
    |> Operation.cast!(:VIPS_FORMAT_UCHAR)
    |> Vimage.write_to_binary()
  end

  defp pixelate_for_hash(%Vimage{} = image, hash_size) do
    image
    |> thumbnail!(hash_size + 1, height: hash_size, resize: :force)
    |> flatten!()
    |> to_colorspace!(:bw)
    |> Operation.extract_band!(0)
  end

  @doc false
  def convert_binary_to_hash(binary) do
    for <<byte::integer-8-native <- binary>>, reduce: <<>> do
      acc ->
        <<_rest::bitstring-7, bit::bitstring>> = <<byte::integer-8-native>>
        <<acc::bitstring, bit::bitstring>>
    end
  end

  @doc """
  Returns the hamming distance of two images
  or two image hashes.

  A [hamming distance](https://en.wikipedia.org/wiki/Hamming_distance)
  gives an indication of the similarity of two images.

  In general, a hamming distance of less than `10` indicates
  that the images are very similar.  A distance of
  less than `20` suggests the images are quite similar. Any
  other distance suggests the images have little in common.

  ### Arguments

  * `image_1` is any `t:Vix.Vips.Image.t/0`.

  * `image_2` is any `t:Vix.Vips.Image.t/0`.

  Alternatively, both arguments may be image hashes
  returned by `Image.dhash/1`. Both arguments must
  be of the same type.

  ### Returns

  * `{:ok, hamming_distance}` where hamming distance is
    a positive integer or

  * `{:error, reason}`.

  """
  @doc subject: "Operation", since: "0.6.0"

  @spec hamming_distance(image_1 :: Vimage.t(), image_2 :: Vimage.t(), hash_size :: pos_integer()) ::
          {:ok, non_neg_integer()} | {:error, error()}

  def hamming_distance(image_1, image_2, hash_size \\ 64)

  def hamming_distance(%Vimage{} = image_1, %Vimage{} = image_2, hash_size)
      when is_integer(hash_size) and hash_size > 0 do
    with {:ok, hash_1} <- dhash(image_1, hash_size),
         {:ok, hash_2} <- dhash(image_2, hash_size) do
      hamming_distance(hash_1, hash_2)
    end
  end

  @spec hamming_distance(image_hash(), image_hash()) ::
          {:ok, non_neg_integer()} | {:error, error()}

  def hamming_distance(hash_1, hash_2, hash_size)
      when is_binary(hash_1) and is_binary(hash_2) and is_integer(hash_size) and hash_size > 0 do
    hash_1
    |> :crypto.exor(hash_2)
    |> count_ones()
    |> wrap(:ok)
  end

  defp count_ones(binary) when is_binary(binary) do
    for(<<bit::1 <- binary>>, do: bit) |> Enum.sum()
  end

  # Prebuilt binaries may not have this function because
  # libvips may not have the dependencies required.

  if Code.ensure_loaded?(Vix.Vips.Operation) && function_exported?(Vix.Vips.Operation, :fwfft!, 1) do
    @doc """
    Returns the fast fourier transform (fft) of
    the given image.

    ### Arguments

    * `image` is any `t:Vix.Vips.Image.t/0`.

    ### Returns

    * `{:ok, fft_image}` or

    * `{:error, reason}`

    ### Example

        Image.fft(image)

    """
    @doc subject: "Operation"

    @spec fft(Vimage.t()) :: {:ok, Vimage.t()} | {:error, error()}
    def fft(%Vimage{} = image) do
      image
      |> to_colorspace!(:bw)
      |> Operation.fwfft!()
      |> Operation.wrap!()
      |> Operation.abs()
    end

    @doc """
    Returns the fast fourier transform (fft) of
    the given image returning an image or
    raising an exception.

    ### Arguments

    * `image` is any `t:Vix.Vips.Image.t/0`.

    ### Returns

    * `fft_image` or

    * raises an exception

    ### Example

        iex> "./test/support/images/Hong-Kong-2015-07-1998.jpg"
        iex> |> Image.open!()
        iex> |> Image.fft!()

    """
    @doc subject: "Operation"

    @spec fft!(Vimage.t()) :: Vimage.t() | no_return()
    def fft!(%Vimage{} = image) do
      case fft(image) do
        {:ok, image} -> image
        {:error, reason} -> raise Image.Error, reason
      end
    end

    @doc """
    Attempts top determine the distance
    from the perpendicular for a given image.

    The principle is that rotating the image
    by the skew angle should return an image
    in the upright position.

    The results are very image sensitive and
    perfect results are not guaranteed.

    The algorithm is an implementation of
    [this stackoverflow post](https://stackoverflow.com/questions/52474645/improve-a-picture-to-detect-the-characters-within-an-area/52502597#52502597).

    ### Arguments

    * `image` is any `t:Vix.Vips.Image.t/0`.

    ### Returns

    * `skew_angle` which is an estimated float number
      of degrees the image is tilted from the
      upright.

    """
    @dialyzer {:nowarn_function, {:skew_angle, 1}}
    @doc subject: "Operation"

    @spec skew_angle(Vimage.t()) :: float()

    def skew_angle(%Vimage{} = image) do
      {_columns, rows} =
        image
        |> fft!()
        |> to_rectangular_coordinates!()
        |> Operation.project!()

      {_v, _x, y, _max_coordinates} =
        rows
        |> Operation.gaussblur!(10.0)
        |> Math.top_n(1)

      # and turn to an angle in degrees we should counter-rotate by
      270 - 360 * y / height(rows)
    end
  end

  @doc """
  Convert an image alpha band into a mask.

  Takes an image, extracts its alpha band
  which holds the opacity information and
  inverts the content to produce a mask.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, mask}` or

  * `{:error, reason}`

  """
  @doc subject: "Mask"

  @spec convert_alpha_to_mask(Vimage.t()) :: {:ok, Vimage.t()} | {:error, error()}
  def convert_alpha_to_mask(%Vimage{} = image) do
    if alpha_band = alpha_band(image) do
      {:ok, mask} = Operation.extract_band(image, alpha_band)
      Operation.invert(mask)
    else
      {:error, %Image.Error{message: "Image has no alpha band", reason: "Image has no alpha band"}}
    end
  end

  @doc """
  Convert an image alpha band into a mask returning
  an image or raising an exception.

  Takes an image, extracts its alpha band
  which holds the opacity information and
  inverts the content to produce a mask.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `mask` image or

  * raises an exception

  """
  @doc subject: "Mask"

  @spec convert_alpha_to_mask!(Vimage.t()) :: Vimage.t() | no_return()
  def convert_alpha_to_mask!(%Vimage{} = image) do
    case convert_alpha_to_mask(image) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Split the image into a list of its component
  bands.

  This can be considered the inverse of
  `Image.join_bands/1`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * a list of single band images extracted
    from `image`.

  """
  @doc subject: "Split and join", since: "0.13.0"

  @spec split_bands(Vimage.t()) :: [Vimage.t()]
  def split_bands(%Vimage{} = image) do
    for i <- 0..max_band_index(image), do: image[i]
  end

  @doc """
  Joins a list of bands into a single image.

  This can be considered the inverse operation of
  `Image.split_bands/1`.

  ### Arguments

  * `image_list` is any list of `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, image}` where `image` is created by joining
    `image_bands` together or

  * `{:error, reason}`.

  """
  @doc subject: "Split and join", since: "0.53.0"

  @spec join_bands(image_list :: [Vimage.t()]) ::
          {:ok, Vimage.t()} | {:error, error()}

  def join_bands(bands) when is_list(bands) do
    Operation.bandjoin(bands)
  end

  @doc """
  Joins a list of bands into a single image or
  raises an exception.

  This can be considered the inverse operation of
  `Image.split_bands/1`.

  ### Arguments

  * `image_list` is any list of `t:Vix.Vips.Image.t/0`.

  ### Returns

  * an image created by joining `image_bands`
    together or

  * raises an exception.

  """
  @doc subject: "Split and join", since: "0.53.0"

  @spec join_bands!(image_list :: [Vimage.t()]) ::
          Vimage.t() | no_return()

  def join_bands!(bands) when is_list(bands) do
    case join_bands(bands) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Boolean "and" the bands of an image together to
  produce a single band image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, and_image}` where `and_image` a single band image that is the
    result of boolean "and"ing the bands of `image` togther.

  """
  @doc subject: "Split and join", since: "0.60.0"

  @spec band_and(image :: Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def band_and(image) do
    Vix.Vips.Operation.bandbool(image, :VIPS_OPERATION_BOOLEAN_AND)
  end

  @doc """
  Boolean "and" the bands of an image together to
  produce a single band image or raises an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `and_image` where `and_image` a single band image that is the
    result of boolean "and"ing the bands of `image` togther or

  * raises an exception.

  """
  @doc subject: "Split and join", since: "0.60.0"

  @spec band_and!(image :: Vimage.t()) ::
          Vimage.t() | no_return()

  def band_and!(image) do
    case band_and(image) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Boolean "or" the bands of an image together to
  produce a single band image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, or_image}` where `or_image` a single band image that is the
    result of boolean "or"ing the bands of `image` togther.

  """
  @doc subject: "Split and join", since: "0.60.0"

  @spec band_or(image :: Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def band_or(image) do
    Vix.Vips.Operation.bandbool(image, :VIPS_OPERATION_BOOLEAN_OR)
  end

  @doc """
  Boolean "or" the bands of an image together to
  produce a single band image or raises an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `or_image` where `or_image` a single band image that is the
    result of boolean "or"ing the bands of `image` togther or

  * raises an exception.

  """
  @doc subject: "Split and join", since: "0.60.0"

  @spec band_and!(image :: Vimage.t()) ::
          Vimage.t() | no_return()

  def band_or!(image) do
    case band_or(image) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Boolean "exclusive or" the bands of an image together to
  produce a single band image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, xor_image}` where `xor_image` a single band image that is the
    result of boolean "exclusive or"ing the bands of `image` togther.

  """
  @doc subject: "Split and join", since: "0.60.0"

  @spec band_xor(image :: Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, error()}

  def band_xor(image) do
    Vix.Vips.Operation.bandbool(image, :VIPS_OPERATION_BOOLEAN_EOR)
  end

  @doc """
  Boolean "exclusive or" the bands of an image together to
  produce a single band image or raises an exception.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `xor_image` where `xor_image` a single band image that is the
    result of boolean "exclusive or"ing the bands of `image` togther or

  * raises an exception.

  """
  @doc subject: "Split and join", since: "0.60.0"

  @spec band_xor!(image :: Vimage.t()) ::
          Vimage.t() | no_return()

  def band_xor!(image) do
    case band_xor(image) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Returns a boolean based upon whether a given
  image has an alpha band.

  The determination is a heuristic so certainty
  cannot be guaranteed.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `true` or `false`

  ### Examples

      iex> image = Image.open!("./test/support/images/image_with_alpha2.png")
      iex> Image.has_alpha?(image)
      true

      iex> image = Image.open!("./test/support/images/Kamchatka-2019-8754.jpg")
      iex> Image.has_alpha?(image)
      false

  """
  @doc subject: "Image info"

  @spec has_alpha?(Vimage.t()) :: boolean()
  def has_alpha?(%Vimage{} = image) do
    Vimage.has_alpha?(image)
  end

  @doc """
  Returns the band number of the alpha
  channel of an image, or nil if it doesn't
  have one.

  The determination is a heuristic so certainty
  cannot be guaranteed.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * An integer in the range `1..4` depending
    on the image interpretation. Returns `nil`
    if there is no alpha band. The integer
    is a 0-based offset and can therefore be
    directly used to access the band. For example
    `image[alpha_band(image)]`.

  """
  @doc subject: "Split and join"

  @spec alpha_band(Vimage.t()) :: 1..4 | nil
  def alpha_band(%Vimage{} = image) do
    if has_alpha?(image) do
      Vimage.bands(image) - 1
    else
      nil
    end
  end

  @doc """
  Casts an image from one band format to another.

  The band format is the numeric type of each pixel.
  In the common case of `sRGB` images, the format is
  `{:u, 8}` meaning unsigned 8-bit values.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `band_format` is any known band format. See
    `Image.BandFormat.known_band_formats/0`.

  ### Returns

  * `{:ok, cast_image}` or

  * `{:error, reason}`.

  """
  @doc since: "0.30.0", subject: "Operation"

  @spec cast(Vimage.t(), BandFormat.t()) :: {:ok, Vimage.t()} | {:error, error()}
  def cast(%Vimage{} = image, band_format) do
    with {:ok, band_format} <- BandFormat.validate(band_format) do
      Operation.cast(image, band_format)
    end
  end

  @doc """
  Casts an image from one band format to another or
  raises an exception.

  The band format is the numeric type of each pixel.
  In the common case of `sRGB` images, the format is
  `{:u, 8}` meaning unsigned 8-bit values.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `band_format` is any known band format. See
    `Image.BandFormat.known_band_formats/0`.

  ### Returns

  * `cast_image` or

  * raises an exception.

  """
  @doc since: "0.42.0", subject: "Operation"

  @spec cast!(Vimage.t(), BandFormat.t()) :: Vimage.t() | no_return()
  def cast!(%Vimage{} = image, band_format) do
    case cast(image, band_format) do
      {:ok, casted} -> casted
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @doc """
  Execute a function over the image without
  its alpha band (if any) ensuring the alpha
  band is replaced when the function returns.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `fun` is any 1-arity function that is
    required to return `{:ok, image}` or
    `{:error, reason}`.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`.

  """
  @doc since: "0.29.0", subject: "Operation"

  @spec without_alpha_band(
          Vimage.t(),
          (Vimage.t() -> {:ok, Vimage.t()} | {:error, error()})
        ) ::
          {:ok, Vimage.t()} | {:error, error()}

  def without_alpha_band(%Vimage{} = image, fun) when is_function(fun, 1) do
    {without_alpha, alpha} = split_alpha(image)

    case fun.(without_alpha) do
      {:ok, image} -> {:ok, bandjoin!(image, alpha)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Execute a function over the image casting it
  first to a color space and ensuring the color
  space conversion is reverted when the function
  returns.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `colorspace` is any valid color space.
    See `Image.Interpretation.known_interpretations/0`.

  * `fun` is any 1-arity function that is
    required to return `{:ok, image}` or
    `{:error, reason}`.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`.

  """
  @doc since: "0.29.0", subject: "Operation"

  @spec with_colorspace(
          Vimage.t(),
          colorspace :: Interpretation.t(),
          (Vimage.t() -> {:ok, Vimage.t()} | {:error, error()})
        ) ::
          {:ok, Vimage.t()} | {:error, error()}

  def with_colorspace(image, colorspace, fun) do
    original_colorspace = colorspace(image)

    with {:ok, converted} <- to_colorspace(image, colorspace) do
      case fun.(converted) do
        {:ok, image} -> to_colorspace(image, original_colorspace)
        other -> other
      end
    end
  end

  @doc """
  Execute a function over the image casting it
  first to a different band format and ensuring the band
  format reverted when the function returns.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `band_format` is any valid band format.
    See `Image.BandFormat.known_band_formats/0`.

  * `fun` is any 1-arity function that is
    required to return `{:ok, image}` or
    `{:error, reason}`.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`.

  ### Example

      iex> image = Image.open!("./test/support/images/Singapore-2016-09-5887.jpg")
      iex> {:ok, updated_image} = Image.with_band_format(image, {:s, 16}, fn i -> {:ok, i} end)
      iex> Image.band_format(updated_image)
      {:u, 8}

  """
  @doc since: "0.35.0", subject: "Operation"

  @spec with_band_format(
          Vimage.t(),
          band_format :: BandFormat.t(),
          (Vimage.t() -> {:ok, Vimage.t()} | {:error, error()})
        ) ::
          {:ok, Vimage.t()} | {:error, error()}

  def with_band_format(image, band_format, fun) do
    original_band_format = band_format(image)

    with {:ok, converted} <- cast(image, band_format) do
      case fun.(converted) do
        {:ok, image} -> cast(image, original_band_format)
        other -> other
      end
    end
  end

  @doc """
  For each page of an image, execute `fun/1` then
  reassemble the pages.

  If the function is successful for each page,
  assemble the new pages (returned from `fun/1`)
  into a new image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` in `.gif`
     or `.png` multi-page format.

  * `fun` is any 1-arity function that takes a
    page as a `t:Vix.Vips.Image.t/0` as its argument
    and is required to return either `{:ok, new_page_image}`
    or `{:error, reason}` as its return value.

  ### Returns

  * `{:ok, mapped_joined_image}` where all the new pages returned
    from `fun/1` are assembled into `mapped_image` or

  * `{:error, reason}`.

  ### Examples

      # The option `pages: -1` means load all the pages of a multi-page image.
      iex> image = Image.open!("./test/support/images/animated.webp", pages: :all)
      iex> {:ok, _mapped_image} = Image.map_join_pages(image, &Image.equalize/1)

      # Also works for .gif images
      iex> image = Image.open!("./test/support/images/animated.gif", pages: :all)
      iex> {:ok, _mapped_image} = Image.map_join_pages(image, &Image.equalize/1)

      # If an image isn't opened with `pages: :all` then only
      # the first page of an image is loaded.
      iex> image_2 = Image.open!("./test/support/images/animated.webp")
      iex> {:error, %Image.Error{reason: :missing_page_height}} = Image.map_join_pages(image_2, &Image.equalize/1)
      iex> :ok
      :ok

  """
  @doc since: "0.39.0", subject: "Operation"

  @spec map_join_pages(Vimage.t(), (Vimage.t() -> {:ok, Vimage.t()} | {:error, error()})) ::
          {:ok, Vimage.t()} | {:error, error()}

  def map_join_pages(%Vimage{} = image, fun) when is_function(fun, 1) do
    map_join_pages(image, fun, pages(image))
  end

  # There is only one page - a normal image
  # So just invoke the given function.

  defp map_join_pages(image, fun, 1) do
    fun.(image)
  end

  # The image has multiple pages. We need to split the
  # image, process and reassemble. Then we need to set the
  # `page-height` of the new image.

  defp map_join_pages(image, fun, pages) do
    with {:ok, page_height} <- page_height(image),
         {:ok, new_pages} <- reduce_pages(image, pages, page_height, fun),
         {:ok, new_image} <- join(Enum.reverse(new_pages), across: 1) do
      new_page_height = Image.height(hd(new_pages))

      case mutate(new_image, &MutableImage.set(&1, "page-height", :gint, new_page_height)) do
        {:ok, updated_image} ->
          {:ok, updated_image}

        {:error, reason} ->
          {:error,
           %Image.Error{
             message: "Could not set the page-height header. Reason: #{inspect(reason)}",
             reason: "Could not set the page-height header. Reason: #{inspect(reason)}"
           }}
      end
    end
  end

  defp page_height(image) do
    case Vix.Vips.Image.header_value(image, "page-height") do
      {:ok, page_height} ->
        {:ok, page_height}

      {:error, _reason} ->
        message =
          "Image does not have a page-height header. " <>
            "Perhaps the image wasn't opened with the `pages: :all` option or " <>
            "libvips wasn't built with libwebp-dev/libgif-dev configured? " <>
            "Run `vips --vips-config` from the command line to check."

        {:error, %Image.Error{reason: :missing_page_height, message: message}}
    end
  end

  defp reduce_pages(image, pages, page_height, fun) do
    width = width(image)

    Enum.reduce_while(1..pages, {:ok, []}, fn n, {:ok, acc} ->
      {:ok, page_n} = Operation.extract_area(image, 0, page_height * (n - 1), width, page_height)

      case fun.(page_n) do
        {:ok, new_page_n} ->
          {:cont, {:ok, [new_page_n | acc]}}

        {:error, reason} ->
          {:halt,
           {:error,
            %Image.Error{
              message: "Page #{n} returned #{inspect(reason)}",
              reason: "Page #{n} returned #{inspect(reason)}"
            }}}
      end
    end)
  end

  @doc """
  Extract each page of a multi-page image into its
  own image.

  Not all image types support multi-page images.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` in `.gif`
     or `.png` multi-page format.

  ### Returns

  * `{:ok, list_of_images}` or

  * `{:error, reasom}`

  ### Notes

  The `pages: :all` option should be used when opening the
  multi-page image.

  ### Example

      iex> image = Image.open!("./test/support/images/animated.gif", pages: :all)
      iex> {:ok, list_of_images} = Image.extract_pages(image)
      iex> Enum.count(list_of_images)
      19

  """
  @doc since: "0.44.0", subject: "Operation"

  @spec extract_pages(Vimage.t()) :: {:ok, [Vimage.t()]} | {:error, error()}

  def extract_pages(%Vimage{} = image) do
    width = width(image)

    with {:ok, page_height} <- page_height(image) do
      result =
        Enum.reduce_while(1..pages(image), {:ok, []}, fn n, {:ok, acc} ->
          case Operation.extract_area(image, 0, page_height * (n - 1), width, page_height) do
            {:ok, new_page_n} ->
              {:cont, {:ok, [new_page_n | acc]}}

            {:error, reason} ->
              {:halt,
               {:error,
                %Image.Error{
                  message: "Page #{n} returned #{inspect(reason)}",
                  reason: "Page #{n} returned #{inspect(reason)}"
                }}}
          end
        end)

      case result do
        {:ok, pages} -> {:ok, Enum.reverse(pages)}
        error -> error
      end
    end
  end

  # The iTerm2 Image Preview protocol is:
  # ESC ] 1337 ; File = [arguments] : base-64 encoded file contents ^G

  # Decimal 27
  @esc <<0x1B>>
  # Decimal 7
  @ctrl_g <<0x07>>

  @default_max_width "1000"
  @max_width_env_key "IMAGE_PREVIEW_MAX_WIDTH"

  @doc """
  Outputs an inline preview of an image to
  an iTerm2 terminal.

  Only iTerm2 terminal windows are supported.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` or
    a tuple of the form `{:ok, image}`.

  ### Returns

  * The `image` parameter as provided with the
    side effect of emitting an image preview on
    an iTerm terminal.

  ### Notes

  * The function `Image.p/1` is delegated to
    this function.

  * The maximum width of the preview can be set
    by the environment variable `#{@max_width_env_key}`.
    The default is `1_000` pixels wide. If the width
    of the image is greater than the maximum it will be
    resized to the maximum width for the preview.

  * Intended to be used as shortcut in `iex`.
    It can be included in an `.iex.exs` file:

      # .iex.exs
      import_if_available(Image, only: [preview: 1])

  """
  @doc subject: "Display", since: "0.13.0"

  @spec preview(Vimage.t() | {:ok, Vimage.t()}) ::
          Vimage.t() | {:ok, Vimage.t()} | {:error, error()}

  def preview(%Vimage{} = image) do
    with {:ok, "iTerm2"} <- supported_terminal(System.get_env("LC_TERMINAL")) do
      {prelude, epilog} = get_prelude_epilog_for_term(System.get_env("TERM"))
      {:ok, image} = maybe_resize_to_fit(image, shape(image))

      with {:ok, binary} <- Vix.Vips.Image.write_to_buffer(image, ".png") do
        encoded_image = Base.encode64(binary, padding: true)
        bin_size = byte_size(binary)
        head = prelude <> "]1337;File=size=#{bin_size};inline=1:"
        IO.write(head <> encoded_image <> epilog)
        image
      end
    end
  end

  def preview({:ok, %Vimage{} = image}) do
    {:ok, preview(image)}
  end

  @doc """
  Outputs an inline preview of an image to
  an iTerm2 terminal.

  Only iTerm2 terminal windows are supported.

  Delegates to `Image.preview/1`

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Notes

  * The function `Image.p/1` is delegated to
    this function.

  * The maximum width of the preview can be set
    by the environment variable `#{@max_width_env_key}`.
    The default is `1_000` pixels wide. If the width
    of the image is greater than the maximum it will be
    resized to the maximum width for the preview.

  * Intended to be used as shortcut in `iex`.
    It can be included in `.iex.exs` file:

      # .iex.exs
      import_if_available(Image, only: [p: 1])

  """
  @doc subject: "Display", since: "0.13.0"

  @spec p(Vimage.t()) :: Vimage.t() | {:error, error()}
  def p(image) do
    preview(image)
  end

  defp supported_terminal("iTerm2" = terminal) do
    {:ok, terminal}
  end

  defp supported_terminal(terminal) do
    {:error,
     "Unsupported terminal #{inspect(terminal)}. iTerm2 is required for inline image display."}
  end

  defp get_prelude_epilog_for_term("screen" <> _rest) do
    {@esc <> "Ptmux;" <> @esc <> @esc, @ctrl_g <> @ctrl_g <> "\\\r\n"}
  end

  defp get_prelude_epilog_for_term(_term) do
    {@esc, @esc <> "\\" <> "\r\n"}
  end

  defp maybe_resize_to_fit(image, {width, _height, _bands}) do
    max_width =
      @max_width_env_key
      |> System.get_env(@default_max_width)
      |> String.to_integer()

    if width > max_width do
      thumbnail(image, max_width)
    else
      {:ok, image}
    end
  end

  @doc """
  Returns the number of operating system
  threads available for use by `libvips`.

  By default the number of threads will be
  the number of cores in the system.

  Since image processing is CPU intensive it
  may be appropriate to reduce the number of
  threads to be available to reduce the risk
  of CPU starvation for other workloads.

  See `Image.put_concurrency/1`.

  """
  @doc subject: "Configuration"

  @spec get_concurrency :: pos_integer()
  def get_concurrency do
    Vix.Vips.concurrency_get()
  end

  @doc """
  Sets the number of available threads for use
  by `libvips`.

  By default this is the same as the number of
  cores in the system. Reducing this number may
  prevent CPU starvation for other workloads.

  ### Arguments

  * `concurrency` is a positive integer denoting
    the maximum number of threads that `libvips` will
    use for concurrency.

  ### Returns

  * `{:ok, updated_concurrency}`

  """
  @doc subject: "Configuration"

  @spec put_concurrency(pos_integer()) :: pos_integer()
  def put_concurrency(concurrency) when is_integer(concurrency) and concurrency > 0 do
    :ok = Vix.Vips.concurrency_set(concurrency)
    get_concurrency()
  end

  @doc """
  Returns the aspect of an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`

  * `options` is a keyword list of options

  ### Options

  * `:square_ratio` indicates when an image
    is to be considered square. It is a floating
    point indicator of the ratio between the width
    and height below which the image is considered
    square. The default is `0.0` meaning that the
    dimensions must be exactly equal in order for
    the image to be considered square.

  ### Returns

  * Either `:landscape`, `:portrait` or `:square`.

  ### Example

      iex> puppy = Image.open!(Path.expand("test/support/images/puppy.webp"))
      iex> Image.aspect(puppy, square_ratio: 0.05)
      :landscape

  """
  @doc subject: "Image info"

  @spec aspect(Vimage.t()) :: aspect()
  def aspect(%Vimage{} = image, options \\ []) do
    square_ratio = Keyword.get(options, :square_ratio, @square_when_ratio_less_than)
    width = Image.width(image)
    height = Image.height(image)
    ratio = abs(1.0 - width / height)

    cond do
      ratio <= square_ratio -> :square
      width > height -> :landscape
      height > width -> :portrait
    end
  end

  @doc """
  Returns the version of `libvips` in
  operation.

  """
  @doc subject: "Configuration"

  @spec vips_version :: {:ok, Version.t()}
  def vips_version do
    Vix.Vips.version()
    |> Version.parse()
  end

  ### Helpers

  defp wrap(item, atom) do
    {atom, item}
  end

  # defp build_option_string(options, other_options) do
  #   "[" <> options <> "," <> join_options(other_options) <> "]"
  # end
  #
  # defp build_option_string(options) do
  #   "[" <> join_options(options) <> "]"
  # end
  #
  # defp join_options(options) do
  #   Enum.map_join(options, ",", fn {k, v} -> "#{k}=#{v}" end)
  # end

  defp file_exists?(path) do
    if File.exists?(path, [:raw]) do
      {:ok, path}
    else
      {:error, Image.Error.wrap(:enoent, path: path)}
    end
  end

  defp xy_offset(%Vimage{} = _image, _overlay, x, y)
       when is_number(x) and is_number(y) and x >= 0 and y >= 0 do
    {x, y}
  end

  # Offset from the right of the image
  defp xy_offset(%Vimage{} = base_image, overlay, x, y) when is_number(x) and x < 0 do
    x = Image.width(base_image) - Image.width(overlay) + x
    xy_offset(base_image, overlay, x, y)
  end

  # Offset from the bottom of the image
  defp xy_offset(%Vimage{} = base_image, overlay, x, y) when is_number(y) and y < 0 do
    y = Image.height(base_image) - Image.height(overlay) + y
    xy_offset(base_image, overlay, x, y)
  end

  defp xy_offset(%Vimage{} = base_image, %Vimage{} = overlay, x, y)
       when is_number(x) and is_atom(y) do
    y = offset_from(y, Image.height(base_image), Image.height(overlay))
    {x, y}
  end

  defp xy_offset(%Vimage{} = base_image, %Vimage{} = overlay, x, y)
       when is_atom(x) and is_number(y) do
    x = offset_from(x, Image.width(base_image), Image.width(overlay))
    {x, y}
  end

  defp xy_offset(%Vimage{} = base_image, %Vimage{} = overlay, x, y) do
    x = offset_from(x, Image.width(base_image), Image.width(overlay))
    y = offset_from(y, Image.height(base_image), Image.height(overlay))
    {x, y}
  end

  # Used for x offset
  defp offset_from(:left, _base_size, _overlay_size), do: 0
  defp offset_from(:right, base_size, overlay_size), do: base_size - overlay_size
  defp offset_from(:center, base_size, overlay_size), do: div(base_size, 2) - div(overlay_size, 2)

  # Used for y offset
  defp offset_from(:top, _base_size, _overlay_size), do: 0
  defp offset_from(:bottom, base_size, overlay_size), do: base_size - overlay_size
  defp offset_from(:middle, base_size, overlay_size), do: div(base_size, 2) - div(overlay_size, 2)

  defp offset_from(other, _base_size, _overlay_size) do
    raise ArgumentError, """
    Invalid offset position #{inspect(other)}.
    Valid positions are :left, :right, :middle, :top, :bottom, :center
    """
  end

  @doc false
  def validate_transferable_image(image) do
    case shape(image) do
      {width, height, bands} when bands == 3 ->
        {width, height, bands}

      other ->
        {:error,
         %Image.Error{
           reason: :wrong_band_count,
           value: other,
           message:
             "Only images with three bands can be transferred to eVision. " <>
               "Found an image of shape #{inspect(other)}"
         }}
    end
  end

  @doc false
  def evision_configured? do
    match?({:module, _module}, Code.ensure_compiled(Evision))
  end

  @doc false
  def xav_configured? do
    match?({:module, _module}, Code.ensure_compiled(Xav.Reader))
  end
end
