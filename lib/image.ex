defmodule Image do
  alias Vix.Vips.{Operation, MutableImage}
  alias Vix.Vips.Image, as: Vimage
  alias Image.{Exif, Xmp, Complex}

  use Image.Math

  @default_round_corner_radius 50
  @default_open_options [access: :sequential]
  @alpha_channel 3
  @copyright "exif-ifd0-Copyright"

  @typedoc """
  The options applicable to rotating an
  image.

  """
  @type rotation_options :: [
    {:idy, float()},
    {:idx, float()},
    {:ody, float()},
    {:odx, float()},
    {:background, pixel()}
  ]

  @typedoc """
  Error messages returned by `libvips`
  """
  @type error_message :: binary()

  @typedoc """
  A pixel is represented as a list of float values.
  The number of list elements is determined by
  the colorspace interpreations. For example:

  * `RGB` colorspace would be represented by
    a list of three floats like `[0.0, 0,0, 0.0]` for black.

  * `CMYK` colorspace would be represented by a
    list of four floats.

  * A `PNG` image can be in any appropriate
    colorspace but may also have an `alpha` band
    and therefore have three, four or five floats
    in a list to represent the pixel.

  """
  @type pixel :: [float()]

  def open(image_path, options \\ []) do
    options = Keyword.merge(@default_open_options, options)

    image_path
    |> String.split("[", parts: 2)
    |> do_open(options)
  end

  defp do_open([path], options) do
    if File.exists?(path) do
      options = build_option_string(options)
      Vimage.new_from_file(path <> options)
    else
      {:error, :enoent}
    end
  end

  defp do_open([path, open_options], options) do
    if File.exists?(path) do
      open_options = String.trim_trailing(open_options, "]")
      options = build_option_string(open_options, options)
      Vimage.new_from_file(path <> options)
    else
      {:error, :enoent}
    end
  end

  defp build_option_string(options, other_options) do
    "[" <> options <> "," <> join_options(other_options) <> "]"
  end

  defp build_option_string(options) do
    "[" <> join_options(options) <> "]"
  end

  defp join_options(options) do
    Enum.map_join(options, ",", fn {k, v} -> "#{k}=#{v}" end)
  end

  @doc """
  Returns the EXIF data for an image as a
  keyword list.

  Only a selected set of EXIF data is returned.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`

  ## Returns

  * `{:ok, exif_map}` where `exif_map` is a map
    of selected EXIF data

  """
  @spec exif(Vimage.t()) :: {:ok, map()}
  def exif(%Vimage{} = image) do
    with {:ok, exif_blob} <- Vimage.header_value(image, "exif-data"),
         <<"Exif"::binary, 0::16, exif::binary>> <- exif_blob do
      exif
      |> Exif.extract_exif()
      |> wrap(:ok)
    end
  end

  @doc """
  Retruns the XMP data for an image as a
  keyword list.

  Only a selected set of XMP data is returned.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`

  ## Returns

  * `{:ok, xmp_map}` where `xmp_map` is a map
    of selected XMP data

  """
  @spec xmp(Vimage.t()) :: {:ok, map()}
  def xmp(%Vimage{} = image) do
    with {:ok, xmp_blob} <- Vimage.header_value_as_string(image, "xmp-data"),
         {:ok, xmp_binary} <- Base.decode64(xmp_blob) do
      xmp_binary
      |> SweetXml.parse(dtd: :none)
      |> Xmp.extract_xmp()
      |> wrap(:ok)
    end
  end

  @doc """
  Returns the width of an image.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`

  ## Returns

  * The image width as an integer

  """
  @spec width(Vimage.t()) :: integer()
  def width(%Vimage{} = image) do
    Vimage.width(image)
  end

  @doc """
  Returns the height of an image.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`

  ## Returns

  * The image height as an integer

  """
  @spec height(Vimage.t()) :: integer()
  def height(%Vimage{} = image) do
    Vimage.height(image)
  end

  @doc """
  Return the number of bands in an image.

  A band is sometimes referred to as a
  channel.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`.

  ## Returns

  * An integer number of bands in the image.

  """
  @spec bands(Vimage.t()) :: integer
  def bands(%Vimage{} = image) do
    Vimage.bands(image)
  end

  @doc """
  Flip an image horizontally or
  vertically.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`.

  * `direction` is either `:horitzontal` or
    `:vertical`.

  """
  @spec flip(image :: Vimage.t(), direction :: :vertical | :horizontal) :: {:ok, Vimage.t()}
  def flip(%Vimage{} = image, :vertical) do
    Operation.flip(image, :VIPS_DIRECTION_VERTICAL)
  end

  def flip(%Vimage{} = image, :horizontal) do
    Operation.flip(image, :VIPS_DIRECTION_HORIZONTAL)
  end

  @doc """
  Rotate an image clockwise (to the
  right) by a number of degrees.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`.

  * Angle is a `float` number of degrees
    to rotate in a clockwise direction.

  * `options` is a keyword list of options.

  ## Options

  * `:idy` is the vertical input displacement. Default: `0.0`

  * `:idx` is the horizontal input displacement. Default: `0.0`

  * `:ody` is the vertical output displacement. Default: `0.0`

  * `:odx` is the horizontal output displacement. Default: `0.0`

  * `:background` is the background color to be used for filling
    the blank areas of the image. The background is specified as
    a list of 3 or 4 float values.

  ## Notes

  The displacement parameters cause the image canvas to be
  expanded and the image displaced (relative to the top left
  corner of the image) but the amount specified.

  The rules defining how the image canvas is expanded
  is not known to the author of `Image`. Experimentation will
  be required if you explore these options.

  ## Returns

  * `{:ok, rotated_image}` or

  * `{:error, reason}`

  """
  @spec rotate(image :: Vimage.t(), angle :: float(), options :: rotation_options()) ::
    {:ok, Vimage.t()} | {:error, error_message()}

  def rotate(%Vimage{} = image, angle, options \\ []) when is_number(angle) do
    options = Keyword.merge(default_rotation_options(), options)
    Operation.rotate(image, angle, options)
  end

  defp default_rotation_options do
    []
  end

  @doc """
  Convert image to polar coordinates.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`.

  ## Returns

  * `{:ok, image_in_polar_coordiantes}` or

  * `{:error, reason}`

  """
  def to_polar_coordinates(%Vimage{} = image) do
    width = width(image)
    height = height(image)

    {:ok, xy} = Operation.xyz(width, height)
    xy = xy - [width / 2.0, height / 2.0]

    scale = min(width, height) / width
    xy = xy * 2.0 / scale

    {:ok, index} = Complex.polar(xy)
    index = index * [1, height / 360.0]

    Operation.mapim(image, index)
  end

  @doc """
  Convert image to rectangular coordinates.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`.

  ## Notes

  Roundtrip to polar and back to rectangular
  coordinates displays some image distortion,
  likely due to rounding errors in float
  arithmetic. Further study is required.

  ## Returns

  * `{:ok, image_in_polar_coordiantes}` or

  * `{:error, reason}`

  """
  def to_rectangular_coordinates(%Vimage{} = image) do
    width = width(image)
    height = height(image)

    {:ok, xy} = Operation.xyz(width, height)
    xy = xy * [1, 360.0 / height]

    {:ok, index} = Complex.rectangular(xy)
    scale = min(width, height) / width

    index = index * scale / 2.0
    index = index + [width / 2.0, height / 2.0]

    Operation.mapim(image, index)
  end

  @doc """
  Apply a circular mask to an image.

  """
  def circle(%Vimage{} = image, _options \\ []) do
    width = width(image)
    height = height(image)
    size = min(width, height)

    {:ok, thumb} =
      Operation.thumbnail_image(image, size, crop: :VIPS_INTERESTING_ATTENTION)

    {:ok, mask} =
      mask(:circle, size, size)

    Operation.bandjoin([thumb, mask])
  end

  @doc """
  Apply rounded corners to an image.

  """
  def rounded(%Vimage{} = image, options \\ []) do
    options = Keyword.put_new(options, :radius, @default_round_corner_radius)
    width = width(image)
    height = height(image)

    {:ok, thumb} =
      Operation.thumbnail_image(image, width, crop: :VIPS_INTERESTING_ATTENTION)

    {:ok, mask} =
      mask(:rounded_corners, width, height, options)

    Operation.bandjoin([thumb, mask])
  end

  @doc """
  Create an image mask.

  """
  def mask(type, width, height, options \\ [])

  def mask(:circle, diameter, diameter, _options) do
    centre = div(diameter, 2)

    svg = """
    <svg viewBox="0 0 #{diameter} #{diameter}">
      <circle style="fill: black; stroke: none" cx="#{centre}" cy="#{centre}" r="#{centre}"/>
    </svg>
    """

    {:ok, {circle, _flags}} = Operation.svgload_buffer(svg)
    Operation.extract_band(circle, @alpha_channel)
  end

  def mask(:rounded_corners, width, height, options) do
    radius = Keyword.get(options, :radius, @default_round_corner_radius)

    svg = """
    <svg viewBox="0 0 #{width} #{height}">
      <rect rx="#{radius}" ry="#{radius}" x="0" y="0" width="#{width}" height="#{height}" fill="black" />
    </svg>
    """

    {:ok, {mask, _flags}} = Operation.svgload_buffer(svg)
    Operation.extract_band(mask, @alpha_channel)
  end

  # In general, keep:
  # Title
  # Caption
  # Copyright
  # Creator
  # ? GPS

  # Remove
  # xmp data
  # iptc data

  def add_minimal_exif(%Vimage{} = image) do
    with {:ok, _exif} <- exif(image),
         # {:ok, xmp} <- xmp(image),
         {:ok, image} <- remove_metadata(image) do
      Vimage.mutate(image, fn mut_img ->
        :ok = MutableImage.set(mut_img, "exif-data", :VipsBlob, <<0>>)
        :ok = MutableImage.set(mut_img, @copyright, :gchararray, "Copyright (c) 2008 Kip Cole")
      end)
    end
  end

  @doc """
  Remove all metadata from an image.

  This can significant;y reduce the size of
  an image file.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`

  * `fields` is a list of metadata binary
    field names. The default is all known
    field names.

  ## Returns

  * An image without the specified metadata
    fields.

  """
  def remove_metadata(image, fields \\ [])

  def remove_metadata(image, []) do
    {:ok, fields} = Vimage.header_field_names(image)
    remove_metadata(image, fields)
  end

  def remove_metadata(%Vimage{} = image, fields) when is_list(fields) do
    Vimage.mutate(image, fn mut_img ->
      Enum.each(fields, &MutableImage.remove(mut_img, &1))
    end)
  end

  @doc """
  Create an image gradient of the same size as
  the given image.

  The gradient will interpolate from the `start`
  value to the `end` value. The default `start`
  value is black with 100% transparency. The
  default `finish` value is black with 100% opacity.

  `start` and `finish` are given as an `rgb` triplet
  or quadruplet list of integers between `0` and `255`.

  """
  @y_band 1

  def linear_gradient(image, start \\ [0, 0, 0, 0], finish \\ [0, 0, 0, 255]) do
    width = width(image)
    height = height(image)

    {:ok, xyz} = Operation.xyz(width, height)
    {:ok, y} = Operation.extract_band(xyz, @y_band)

    # the distance image: 0 - 1 for the start to the end of the gradient
    d = y / height

    # and use it to fade the quads ... we need to tag the result as an RGB
    # image
    (d * finish) + (1 - d) * start
    |> Operation.copy(interpretation: :VIPS_INTERPRETATION_sRGB)
  end

  @doc """
  Returns the dominant color of an image
  as an RBG triplet value in an integer
  list.

  """
  @max_band_value 256

  def dominant_colour(%Vimage{} = image, options \\ []) do
    bins = Keyword.get(options, :bins, 10)
    bin_size = @max_band_value / bins

    {:ok, histogram} = Operation.hist_find_ndim(image, bins: bins)
    {v, x, y} = maxpos(histogram)
    {:ok, pixel} = Operation.getpoint(histogram, x, y)
    band = Enum.find_index(pixel, &(&1 == v))

    r = x * bin_size + bin_size / 2
    g = y * bin_size + bin_size / 2
    b = band * bin_size + bin_size / 2

    [trunc(r), trunc(g), trunc(b)]
  end

  defp wrap(item, atom) do
    {atom, item}
  end
end
