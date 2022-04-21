defmodule Image do
  alias Vix.Vips.{Operation, MutableImage}
  alias Vix.Vips.Image, as: Vimage

  alias Image.{Exif, Xmp, Complex, Options, Color}

  @default_round_corner_radius 50
  @default_avatar_size 180
  @alpha_channel 3
  @default_streaming_bytes 65_536

  @copyright_header "exif-ifd0-Copyright"

  defguard is_box(left, top, width, height)
           when is_integer(left) and is_integer(top) and is_integer(width) and is_integer(height) and
                  left > 0 and top > 0 and width > 0 and height > 0

  @typedoc """
  The valid rendering intent values. For all
  functions that take an optioanl intent
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
  Error messages returned by `libvips`

  Typically a string.

  """
  @type error_message :: term()

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

  @doc """
  Opens an image file for image processing.

  ## Arguments

  * `image_path` is the file system path to an image
    file.

  * `options` is a keyword list of options. The default is
    `[access: :sequential]`.

  ## Options

  The available options depends on the type of image
  file being opened.

  ### All image types

  * `:access` is the file access mode, either `:random`
    or `:sequential`. THe default is `:sequentual`.
    When `:sequential`, `Image` (via `Vix`) is able
    to support streaming transformations and optimise
    memory usage more effectively. Howwevef `:sequenial`
    also means that some operationas cannot be completed
    because they would require non-sequential access to
    the image. In these cases, `:random` access is required.

  * `:fail_on` sets the error level at which image
    loading and decoding will stop. The default is `:none`.
    Each error state implies all the states before it such
    that `:error` implies also `:truncated`.

  ### JPEG image options

  * `:shrink` is an integer factor in the range `1..16` by
    which the image is reduced upon loading. This is an
    optimization that can result in improved performance and
    reduced memory usage if the image is being loaded
    with the intend to resize it to smaller dimensions. The
    default value is `1` meaning no shrnk-on-load.

  * `:autorotate` is a boolean value indicating if
    the image should be rotated according to the orientation
    data stored in the image metadata. The default is
    `false`.

  ### Webp options

  * `:scale` will scale the image on load. The value is
    `1..1024` with a default of `1`.

  * `:page` indicates the image page to be loaded. The
    value is in the range `0..100_000` with a default
    value of `0`.

  * `:pages` indicates how many pages to load. THe value is
    in the range `1..100_000` with a default value of `1`.

  ### TIFF options

  * `:autorotate` is a boolean value indicating if
    the image should be rotated according to the orientation
    data stored in the image metadata. The default is
    `false`.

  * `:page` indicates the image page to be loaded. The
    value is in the range `0..100_000` with a default
    value of `0`.

  * `:pages` indicates how many pages to load. THe value is
    in the range `1..100_000` with a default value of `1`.

  ### PNG options

  * There are no PNG-specific image loading
    options.

  ## Returns

  * `{:ok, image}` or

  * `{:error, message}`

  """
  @spec open(image_path :: Path.t(), options :: Options.Open.image_open_options()) ::
          {:ok, Vimage.t()} | {:error, error_message()}

  def open(image_path, options \\ []) do
    with {:ok, options} <- Options.Open.validate_options(options) do
      image_path
      |> String.split("[", parts: 2)
      |> do_open(options)
    end
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

  @doc """
  Stream an image file for image operations.

  This function returns a `t:Vix.Vips.Image.t()` that
  will be streamed when processing the image pipeline.
  It is *not* an enumerable itself, but it does rely on
  `File.stream!/3` for the underlying file streaming
  functionality.

  Most image operations will work on streamed
  images. However operations which would require
  "rewinding" the image will not work and will
  return an error.

  This function is most useful when the image source
  is an HTTP source (like Amazon S3) or some other
  API-based service. It allows image process to commence
  even as the image itself is being downloaded from
  the remote service.

  Images can also be [streamed on write])() allowing
  a fully asynchronous image pipeline.

  ## Arguments

  * `path` is the file system path to an image
    file.

  * `bytes` is the number of bytes in
    each stream element. The default is #{@default_streaming_bytes}.

  ## Returns

  * `{:ok, enumerable_image}` or

  * `{:error, reason}`

  """

  @spec stream(image_path :: Path.t(), streaming_bytes :: pos_integer()) ::
    {:ok, Vimage.t()} | {:error, error_message()}

  def stream(image_path, bytes \\ @default_streaming_bytes) do
    if File.exists?(image_path) do
      image_path
      |> File.stream!([], bytes)
      |> Vimage.new_from_enum()
    else
      {:error, :enoent}
    end
  end

  @doc """
  Write an image to a file.

  ## Arguments

  * `image_path` is the file system path to an image
    file.

  * `options` is a keyword list of options. The default is
    `[]`.

  ## Options

  The available options depends on the type of image
  file being opened.

  ### All image types

  * `:profile` is the name of any [ICC color profile]()

  * `:strip` is a boolean indicating if all metadata
    is to be stripped from the image. The default is `false`.

  * `:background` is the background value to be used
    for any transparent areas of the image. Jpeg does
    not support alpha bands so a color value must be
    assigned.

  * `:quality` which influences image compression and
    is a integer in the range `1..100`. The default for
    most image formats is `75`. For PNG files it is the
    quantization quality with a default of `100`. For
    HEIF files the default is `50`.

  ### JPEG images

  * `:progressive` is a boolean indicating if the image
    should be interleaved rather than baseline. Progressive
    has the advantage of perceived time for the inital
    image load and the cost of multiple decoding passes on
    the client. For many applications `:progressive` is
    to be preferred but validation of this assumption for
    specific use cases is required.

  ### PNG images

   * `:color_depth` is an integer describing the number
     of bits for each color. The value can be `1`, `2`,
     `4`, `8` or `16`.  The default is to use the current
     color depth of the image.  For web applications, `8`
     bits would be reasonable for photographic images with
     lower bit depts for monochromatic images or diagrams.

   * `:progressive` which has the same meaning and values
      as for JPEG images.

   * `:compression` is the image compression factor as an
      image between `0..9`. The default is `6`.

  ### TIFF images

  * `:color_depth` which has the same meaning as for
    PNG images.

  ### Heif images

  * `:compression` is the compression strategy to
    be applied. The allowable values are `:hevc`,
    `:avc`, `:jpeg` and `:av1`. The default is `:hevc`.

  """
  @spec write(image :: Vimage.t(), image_path :: Path.t(), options :: Options.Write.image_write_options()) ::
    {:ok, Vimage.t()} | {:error, error_message()}

  def write(%Vimage{} = image, image_path, options \\ []) do
    with {:ok, options} <- Options.Write.validate_options(options) do
      image_path
      |> String.split("[", parts: 2)
      |> do_write(image, options)
    end
  end

  defp do_write([image_path], image, options) do
    options = build_option_string(options)
    Vimage.write_to_file(image, image_path <> options)
  end

  defp do_write([image_path, open_options], image, options) do
    write_options = String.trim_trailing(open_options, "]")
    options = build_option_string(write_options, options)
    Vimage.write_to_file(image, image_path <> options)
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

  * `direction` is either `:horizontal` or
    `:vertical`.

  ## Returns

  * `{:ok, flipped_image}` or

  * `{:error, reason}`

  """
  @spec flip(image :: Vimage.t(), direction :: :vertical | :horizontal) ::
          {:ok, Vimage.t()} | {:error, error_message()}

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
  Resize an image to fit or fill a bounding box.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`.

  * `width` is the width of the resulting
    image after resizing.

  * `options` is a keyword list of options.

  ## Options

  * `:crop` determines if the strategy is "resize to fit"
    (crop is `:none`) or `resize to fill" (when the crop
    option is not `:none`. The value may be [one of]()
    `:none`, `:center`, `:entropy`, `:attention`, `:low`
    or `:high`. The default is `:none`.

  * `:autorotate` is a boolean indicating if the image should
    be autorated based upon the image metadata. The default
    is `true`.

  * `:intent` indicates the [rendering intent](). The default
    is `:relative`.

  * `:export_icc_profile` -Indicates the icc profile to be attached
    to the resized image. The value may be an inbuilt profile (`:srgb`,
    `:p3` or `:cmyk`), the name of an icc profile in the systems
    profile directory or a full path to an icc profile file. The
    default is to export the icc profile of the resized image if
    there is one.

  * `:import_icc_profile` -Indicates the icc profile to be attached
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
    downsized, or both. The value may be one of `:up`, `:down`
    or `:both`. The default is `:both`.

  * `:height` - Size to this height. Default is to maintain
    the image aspect ratio.

  ## Returns

  * `{:ok, resized_image}` or

  * `{:error, reason}`

  """
  @spec resize(
          Vimage.t() | Path.t(),
          width :: pos_integer(),
          options :: Options.Resize.resize_options()
        ) ::
          {:ok, Vimage.t()} | {:error, error_message()}

  def resize(image_or_path, wide, options \\ [])

  def resize(%Vimage{} = image, width, options)
      when is_integer(width) and width > 0 do
    with {:ok, options} <- Options.Resize.validate_options(options) do
      Operation.thumbnail_image(image, width, options)
    end
  end

  def resize(image_path, width, options)
      when is_binary(image_path) and is_integer(width) and width > 0 do
    with {:ok, options} <- Options.Resize.validate_options(options),
         :ok = file_exists?(image_path) do
      Operation.thumbnail(image_path, width, options)
    end
  end

  @doc """
  Make a circular avatar image.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`.

  * `size` is the diameter of the resulting
    image after resizing.

  * `options` is a keyword list of options.

  ## Options

  ## Returns

  * `{:ok, avatar_image}` or

  * `{:error, reason}`

  """

  @spec avatar(Vimage.t(), size :: float(), options :: Options.Avatar.avatar_options()) ::
          {:ok, Vimage.t()} | {:error, error_message()}

  def avatar(image, size \\ @default_avatar_size, options \\ [])

  def avatar(%Vimage{} = image, size, options) do
    with {:ok, options} <- Options.Avatar.validate_options(options) do
      Operation.thumbnail_image(image, size, options)
    end
  end

  def avatar(image_path, size, options) when is_binary(image_path) do
    with {:ok, options} <- Options.Avatar.validate_options(options),
         :ok = file_exists?(image_path) do
      Operation.thumbnail(image_path, size, options)
    end
  end

  @doc """
  Crop an image.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`.

  * `left` is the left edge of extract area as a
    positive integer.

  * `top` is the top edge of extract area as a
    positive integer.

  * `width` is the width of extract area as a
    positive integer.

  * `height` is the height of extract area as a
    positive integer.

  * `options` is a keyword list of options.

  ## Options



  ## Returns

  * `{:ok, cropped_image}` or

  * `{:error, reason}`

  """
  @spec crop(Vimage.t(), integer, integer, integer, integer, Options.Crop.crop_options()) ::
          {:ok, Vimage.t()} | {:error, error_message()}

  def crop(%Vimage{} = image, left, top, width, height, options \\ [])
      when is_box(left, top, width, height) do
    with {:ok, _options} <- Options.Crop.validate_options(options) do
      Operation.extract_area(image, left, top, width, height, options)
    end
  end

  @doc """
  Returns a boolean based upon whether a given
  image has an alpha band.

  The determination is a heuristic so certainty
  cannot be guaranteed.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`.

  ## Returns

  * `true` or `false`

  """
  def has_alpha?(%Vimage{} = image) do
    Vimage.has_alpha?(image)
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
  @spec rotate(
          image :: Vimage.t(),
          angle :: float(),
          options :: Options.Rotation.rotation_options()
        ) ::
          {:ok, Vimage.t()} | {:error, error_message()}

  def rotate(%Vimage{} = image, angle, options \\ []) when is_number(angle) do
    options = Keyword.merge(default_rotation_options(), options)
    Operation.rotate(image, angle, options)
  end

  defp default_rotation_options do
    []
  end

  @doc """
  Rotate an image based upon the orientation
  information in an image's EXIF data.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`.

  ## Returns

  * `{:ok, {auto_rotated_image, flags}}` or

  * `{:error, reason}`

  ## Flags

  Two flags are returned indicating what action
  was taken:

  * `:flip` which is a boolean indicating if the image
  was flipped or not and

  * `:angle` through which the image was rotated.
    This value will be one of `0`, `90`, `180` or
    `270` representing the degrees of rotation.

  """
  @spec autorotate(image :: Vimage.t()) :: {:ok, Vimage.t()} | {:error, error_message()}
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
    angle = Keyword.fetch!(flags, :angle)
    angle = Map.fetch!(@rotation_encoding, angle)

    Keyword.put(flags, :angle, angle)
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
    use Image.Math

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

  * `{:ok, image_in_rectuangular_coordinates}` or

  * `{:error, reason}`

  """
  def to_rectangular_coordinates(%Vimage{} = image) do
    use Image.Math

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
  Adds concentric ripple effect to an image

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`.

  ## Returns

  * `{:ok, image_with_ripple}` or

  * `{:error, reason}`

  """
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
  Apply a circular mask to an image.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`.

  ## Returns

  * `{:ok, circular_image}` or

  * `{:error, reason}

  """
  def circle(%Vimage{} = image, _options \\ []) do
    width = width(image)
    height = height(image)
    size = min(width, height)

    {:ok, mask} = mask(:circle, size, size)
    Operation.bandjoin([image, mask])
  end

  @doc """
  Apply rounded corners to an image.

  """
  def rounded(%Vimage{} = image, options \\ []) do
    options = Keyword.put_new(options, :radius, @default_round_corner_radius)
    width = width(image)
    height = height(image)

    {:ok, mask} = mask(:rounded_corners, width, height, options)
    Operation.bandjoin([image, mask])
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
        :ok = MutableImage.set(mut_img, @copyright_header, :gchararray, "Copyright (c) 2008 Kip Cole")
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
    use Image.Math

    width = width(image)
    height = height(image)

    {:ok, xyz} = Operation.xyz(width, height)
    {:ok, y} = Operation.extract_band(xyz, @y_band)

    # the distance image: 0 - 1 for the start to the end of the gradient
    d = y / height

    # and use it to fade the quads ... we need to tag the result as an RGB
    # image
    (d * finish + (1 - d) * start)
    |> Operation.copy(interpretation: :VIPS_INTERPRETATION_sRGB)
  end

  @doc """
  Returns the dominant color of an image
  as an RBG triplet value in an integer
  list.

  ## Arguments

  * `image` is any `t:Vix.Vips.Image.t()`.

  * `options` is a keyword list of options.
    The default is `[]`.

  ## Options

  * `:bins` is an integer number of color
   freuqency bins the image is divided into.
   The default is `10`.

  ## Returns

  * `[r, g, b]`

  """
  @max_band_value 256

  @spec dominant_color(Vimage.t(), Keyword.t()) :: Color.rgb_color()
  def dominant_color(%Vimage{} = image, options \\ []) do
    bins = Keyword.get(options, :bins, 10)
    bin_size = @max_band_value / bins

    {:ok, histogram} = Operation.hist_find_ndim(image, bins: bins)
    {v, x, y} = Image.Math.maxpos(histogram)
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

  defp build_option_string(options, other_options) do
    "[" <> options <> "," <> join_options(other_options) <> "]"
  end

  defp build_option_string(options) do
    "[" <> join_options(options) <> "]"
  end

  defp join_options(options) do
    Enum.map_join(options, ",", fn {k, v} -> "#{k}=#{v}" end)
  end

  defp file_exists?(path) do
    if File.exists?(path, :raw), do: {:ok, path}, else: {:error, :enoent}
  end
end
