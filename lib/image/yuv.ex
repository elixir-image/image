defmodule Image.YUV do
  @moduledoc """
  Functions to convert from/to YUV (YCbCr) encoding and BT.601/BT.709
  colorspaces and sRGB images.

  The following YUV ([YCbCr](https://en.wikipedia.org/wiki/YCbCr)) binary
  formats are supported:

  * Planar frame types only (not packed frames).

  * `4:4:4`, `4:2:2` and `4:2:0` encodings.

  * [BT.601](https://en.wikipedia.org/wiki/Rec._601) and
    [BT.709](https://en.wikipedia.org/wiki/Rec._709) colorspaces.

  * `:limited` (studio-swing, the default) and `:full` (PC/JPEG)
    signal ranges. See `t:Image.YUV.yuv_range/0`.

  Performance profiling indicates this implementation is not suitable
  for real time frame processing of YUV images.

  """

  @typedoc "YUV encoding"
  @type yuv_encoding :: :C444 | :C422 | :C420

  @typedoc "YUV colorspace"
  @type yuv_colorspace :: :bt601 | :bt709

  @typedoc """
  YUV signal range.

  * `:limited` (also called studio-swing or TV range) encodes luma in
    `16..235` and chroma in `16..240`. This is the convention used by
    most video formats (including YUV4MPEG) and is the default.

  * `:full` (also called PC range or JPEG range) encodes luma and chroma
    across the whole `0..255` range.

  The range must match on encode and decode; mixing them shifts colors
  (a full-range signal decoded as limited-range washes toward grey, and
  vice versa).
  """
  @type yuv_range :: :limited | :full

  @typedoc "YUV data as a three-element list of binaries"
  @type yuv_list :: [binary()]

  # See:
  #  https://support.medialooks.com/hc/en-us/articles/360030737152-Color-correction-with-matrix-transformation
  #  https://mymusing.co/bt-709-yuv-to-rgb-conversion-color/
  #  https://mymusing.co/bt601-yuv-to-rgb-conversion-color/
  #  https://github.com/libvips/libvips/discussions/2561
  #  https://en.wikipedia.org/wiki/YCbCr#ITU-R_BT.2020_conversion
  #  https://wiki.multimedia.cx/index.php/YUV4MPEG2#Frame_data

  alias Vix.Vips.Image, as: Vimage
  alias Image.Vips.Operation

  # ---- YUV -> RGB inverse coefficients ------------------------------------
  #
  # Limited-range (studio-swing, 16..235) inverse coefficients matching the
  # limited-range forward matrices below: 1.164384 is 255/219 (luma
  # expansion) and the chroma coefficients are scaled by 255/224.

  @bt601_to_rgb_limited [
    [1.164384, 0.0, 1.596027],
    [1.164384, -0.391762, -0.812968],
    [1.164384, 2.017232, 0.0]
  ]

  @bt709_to_rgb_limited [
    [1.164384, 0.0, 1.792741],
    [1.164384, -0.213249, -0.532909],
    [1.164384, 2.112402, 0.0]
  ]

  # Full-range (0..255) inverse coefficients: unity luma with the standard
  # chroma coefficients.

  @bt601_to_rgb_full [
    [1.0, 0.0, 1.402],
    [1.0, -0.344136, -0.714136],
    [1.0, 1.772, 0.0]
  ]

  @bt709_to_rgb_full [
    [1.0, 0.0, 1.5748],
    [1.0, -0.187324, -0.468124],
    [1.0, 1.8556, 0.0]
  ]

  # ---- RGB -> YUV forward coefficients (scaled by 256) --------------------
  #
  # Limited-range "Computer RGB to YCbCr" coefficients.

  @rgb_to_bt601_limited [
    [65.738, 129.057, 25.064],
    [-37.945, -74.494, 112.439],
    [112.439, -94.154, -18.285]
  ]

  @rgb_to_bt709_limited [
    [46.7428, 157.243, 15.873],
    [-25.765, -86.674, 112.439],
    [112.439, -102.129, -10.31]
  ]

  # Full-range forward coefficients (unity luma, 0.5 chroma), scaled by 256
  # to match the limited-range convention.

  @rgb_to_bt601_full [
    [76.544, 150.272, 29.184],
    [-43.196416, -84.803584, 128.0],
    [128.0, -107.184128, -20.815872]
  ]

  @rgb_to_bt709_full [
    [54.4256, 183.0912, 18.4832],
    [-29.330432, -98.669568, 128.0],
    [128.0, -116.263168, -11.736832]
  ]

  # Lookup maps keyed by {colorspace, range}

  @to_yuv %{
    {:bt601, :limited} => @rgb_to_bt601_limited,
    {:bt709, :limited} => @rgb_to_bt709_limited,
    {:bt601, :full} => @rgb_to_bt601_full,
    {:bt709, :full} => @rgb_to_bt709_full
  }

  @to_rgb %{
    {:bt601, :limited} => @bt601_to_rgb_limited,
    {:bt709, :limited} => @bt709_to_rgb_limited,
    {:bt601, :full} => @bt601_to_rgb_full,
    {:bt709, :full} => @bt709_to_rgb_full
  }

  # The luma offset is 16 for limited range and 0 for full range; the
  # chroma offset is always 128 (unsigned representation of a signed value).
  @offsets %{
    limited: [16.0, 128.0, 128.0],
    full: [0.0, 128.0, 128.0]
  }

  @valid_encodings [:C444, :C422, :C420]
  @valid_colorspace [:bt601, :bt709]
  @valid_ranges [:limited, :full]

  @doc """
  Returns the list of YUV chroma-subsampling encodings supported by
  this module.

  ### Examples

      iex> Image.YUV.valid_encodings()
      [:C444, :C422, :C420]

  """
  @spec valid_encodings() :: [:C444 | :C422 | :C420]
  def valid_encodings, do: @valid_encodings

  @doc """
  Returns the list of YUV → RGB conversion colorspaces supported by
  this module.

  ### Examples

      iex> Image.YUV.valid_colorspaces()
      [:bt601, :bt709]

  """
  @spec valid_colorspaces() :: [:bt601 | :bt709]
  def valid_colorspaces, do: @valid_colorspace

  @doc """
  Returns the list of YUV signal ranges supported by this module.

  See `t:Image.YUV.yuv_range/0` for the meaning of each range.

  ### Examples

      iex> Image.YUV.valid_ranges()
      [:limited, :full]

  """
  @spec valid_ranges() :: [:limited | :full]
  def valid_ranges, do: @valid_ranges

  @doc """
  Converts the raw YUV data in a `.yuv` file
  into an RGB image.

  The data is assumed, and required to be in:

  * Planar format
  * 8-bit color depth

  ### Arguments

  * `path` is any accessible file system path.

  * `width` is the width of the image encoded in
    the YUV data.

  * `height` is the height of the image encoded in
    the YUV data.

  * `encoding` is one of `:C444`, `:C422` or
    `:C420`.

  * `colorspace` is one of `:bt601` (the default) or
    `:bt709`.

  * `range` is one of `:limited` (the default) or `:full`.
    See `t:Image.YUV.yuv_range/0`. It must match the range used
    when the data was encoded.

  ### Returns

  * `{:ok, rgb_image}` or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(8, 8, color: :green)
      iex> path = Path.join(System.tmp_dir!(), "yuv_new_from_file_doctest.yuv")
      iex> :ok = Image.YUV.write_to_file(image, path, :C420)
      iex> {:ok, rgb_image} = Image.YUV.new_from_file(path, 8, 8, :C420)
      iex> File.rm(path)
      :ok
      iex> Image.shape(rgb_image)
      {8, 8, 3}

  """
  @doc since: "0.41.0"

  @spec new_from_file(
          path :: Path.t(),
          width :: pos_integer(),
          height :: pos_integer(),
          encoding :: yuv_encoding(),
          colorspace :: yuv_colorspace(),
          range :: yuv_range()
        ) ::
          {:ok, Vimage.t()} | {:error, Image.error()}

  def new_from_file(path, width, height, encoding, colorspace \\ :bt601, range \\ :limited)
      when encoding in @valid_encodings and colorspace in @valid_colorspace and
             range in @valid_ranges do
    with {:ok, binary} <- File.read(path) do
      new_from_binary(binary, width, height, encoding, colorspace, range)
    end
  end

  @doc """
  Converts raw YUV data into an RGB image.

  The data is assumed, and required to be in:

  * Planar format
  * 8-bit color depth

  ### Arguments

  * `binary` is raw YUV data as a binary.

  * `width` is the width of the image encoded in
    the YUV data.

  * `height` is the height of the image encoded in
    the YUV data.

  * `encoding` is one of `:C444`, `:C422` or
    `:C420`.

  * `colorspace` is one of `:bt601` (the default) or
    `:bt709`.

  * `range` is one of `:limited` (the default) or `:full`.
    See `t:Image.YUV.yuv_range/0`. It must match the range used
    when the data was encoded.

  ### Returns

  * `{:ok, rgb_image}` or

  * `{:error, reason}`.

  ### Examples

      iex> binary = :binary.copy(<<128>>, 3 * 8 * 8)
      iex> {:ok, image} = Image.YUV.new_from_binary(binary, 8, 8, :C444)
      iex> {Image.shape(image), Image.colorspace(image)}
      {{8, 8, 3}, :srgb}

  """
  @doc since: "0.41.0"

  @spec new_from_binary(
          binary :: binary(),
          width :: pos_integer(),
          height :: pos_integer(),
          encoding :: yuv_encoding(),
          colorspace :: yuv_colorspace(),
          range :: yuv_range()
        ) ::
          {:ok, Vimage.t()} | {:error, Image.error()}

  def new_from_binary(binary, width, height, encoding, colorspace \\ :bt601, range \\ :limited)
      when encoding in @valid_encodings and colorspace in @valid_colorspace and
             range in @valid_ranges do
    with {:ok, decoded} <- decode(binary, width, height, encoding) do
      to_rgb(decoded, width, height, encoding, colorspace, range)
    end
  end

  @doc """
  Writes an image to a YUV file as raw YUV data.

  It is recommeneded, but not required, that the path
  name use a `.yuv` suffix.

  ### Arguments

  * `path` is any accessible file system path.

  * `encoding` is one of `:C444`, `:C422` or
    `:C420`.

  * `colorspace` is one of `:bt601` (the default) or
    `:bt709`.

  * `range` is one of `:limited` (the default) or `:full`.
    See `t:Image.YUV.yuv_range/0`.

  ### Returns

  * `:ok` or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(8, 8, color: :green)
      iex> path = Path.join(System.tmp_dir!(), "yuv_write_to_file_doctest.yuv")
      iex> Image.YUV.write_to_file(image, path, :C420)
      :ok
      iex> File.rm(path)
      :ok

  """
  @doc since: "0.41.0"

  @spec write_to_file(
          image :: Vimage.t(),
          path :: Path.t(),
          encoding :: yuv_encoding(),
          colorspace :: yuv_colorspace(),
          range :: yuv_range()
        ) ::
          :ok | {:error, Image.error()}

  def write_to_file(%Vimage{} = image, path, encoding, colorspace \\ :bt601, range \\ :limited) do
    with {:ok, binary} <- write_to_binary(image, encoding, colorspace, range) do
      File.write(path, binary)
    end
  end

  @doc """
  Writes an image to a YUV raw binary.

  ### Arguments

  * `image` is any `t:Vimage.t/0`.

  * `encoding` is one of `:C444`, `:C422` or
    `:C420`.

  * `colorspace` is one of `:bt601` (the default) or
    `:bt709`.

  * `range` is one of `:limited` (the default) or `:full`.
    See `t:Image.YUV.yuv_range/0`.

  ### Returns

  * `{:ok, yuv_binary}` or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(8, 8, color: :green)
      iex> {:ok, binary} = Image.YUV.write_to_binary(image, :C420)
      iex> byte_size(binary)
      96

  """
  @doc since: "0.41.0"

  @spec write_to_binary(
          image :: Vimage.t(),
          encoding :: yuv_encoding(),
          colorspace :: yuv_colorspace(),
          range :: yuv_range()
        ) ::
          {:ok, binary()} | {:error, Image.error()}

  def write_to_binary(%Vimage{} = image, encoding, colorspace \\ :bt601, range \\ :limited) do
    with {:ok, [y, u, v]} <- to_yuv(image, encoding, colorspace, range) do
      {:ok, :erlang.iolist_to_binary([y, u, v])}
    end
  end

  @doc """
  Convert an image in an YUV colorspace and convert it to RGB
  colorspace.

  ### Arguments

  * `image` is any `t:Vimage.t/0` that is in a YUV
    colorspace such as that returned from `Image.YUV.new_from_file/5`
    or `Image.YUV.new_from_binary/5`.

  * `colorspace` is one of `:bt601` (the default) or
    `:bt709` that represents the colorspace of `image` before
    conversion.

  * `range` is one of `:limited` (the default) or `:full`.
    See `t:Image.YUV.yuv_range/0`.

  ### Examples

      iex> yuv_image = Image.new!(8, 8, color: [128, 128, 128])
      iex> {:ok, rgb_image} = Image.YUV.to_rgb(yuv_image, :bt601)
      iex> {Image.shape(rgb_image), Image.colorspace(rgb_image)}
      {{8, 8, 3}, :srgb}

  """
  # See https://github.com/libvips/libvips/discussions/2561
  @doc since: "0.41.0"

  @spec to_rgb(image :: Vimage.t(), colorspace :: yuv_colorspace(), range :: yuv_range()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}

  def to_rgb(%Vimage{} = image, colorspace, range \\ :limited)
      when colorspace in @valid_colorspace and range in @valid_ranges do
    with {:ok, transform} <- Vimage.new_from_list(@to_rgb[{colorspace, range}]),
         {:ok, recombed} <- Operation.recomb(image, transform),
         {:ok, rgb} <- Image.cast(recombed, {:u, 8}) do
      Operation.copy(rgb, interpretation: :VIPS_INTERPRETATION_sRGB)
    end
  end

  @doc """
  Takes the `[y, u, v]` planes and converts them to
  an RGB image.

  ### Arguments

  * `yuv` is a list of three binaries representing the `Y`,
    `U` and `V` planes. Such a list is returned from
    `Image.YUV.to_yuv/3` and from `Image.YUV.encode/2`.

  * `width` is the width of the image encoded in `yuv`.

  * `height` is the height of the image encoded in `yuv`.

  * `encoding` is one of `:C444`, `:C422` or
    `:C420` representing how `yuv` is encoded.

  * `colorspace` is one of `:bt601` (the default) or
    `:bt709` that represents the colorspace of `image` before
    conversion.

  * `range` is one of `:limited` (the default) or `:full`.
    See `t:Image.YUV.yuv_range/0`.

  ### Returns

  * `{:ok, image}` or

  * `{:error, reason}`.

  ### Examples

      iex> y = :binary.copy(<<235>>, 64)
      iex> u = :binary.copy(<<128>>, 64)
      iex> v = :binary.copy(<<128>>, 64)
      iex> {:ok, image} = Image.YUV.to_rgb([y, u, v], 8, 8, :C444, :bt601)
      iex> Image.shape(image)
      {8, 8, 3}

  """
  @doc since: "0.41.0"

  @spec to_rgb(
          yuv :: yuv_list(),
          width :: pos_integer(),
          height :: pos_integer(),
          encoding :: yuv_encoding,
          colorspace :: yuv_colorspace(),
          range :: yuv_range()
        ) ::
          {:ok, Vimage.t()} | {:error, Image.error()}

  def to_rgb(yuv, width, height, encoding, colorspace \\ :bt601, range \\ :limited)

  def to_rgb([y, u, v], width, height, :C444, colorspace, range) do
    use Image.Math

    with {:ok, y} <- new_scaled_image(y, width, height, 1.0, 1.0),
         {:ok, u} <- new_scaled_image(u, width, height, 1.0, 1.0),
         {:ok, v} <- new_scaled_image(v, width, height, 1.0, 1.0),
         {:ok, image_444} <- Operation.bandjoin([y, u, v]) do
      to_rgb(image_444 - @offsets[range], colorspace, range)
    end
  end

  def to_rgb([y, u, v], width, height, :C422, colorspace, range) do
    use Image.Math

    with {:ok, y} <- new_scaled_image(y, width, height, 1.0, 1.0),
         {:ok, u} <- new_scaled_image(u, width, height, 2.0, 1.0),
         {:ok, v} <- new_scaled_image(v, width, height, 2.0, 1.0),
         {:ok, image_444} <- Operation.bandjoin([y, u, v]) do
      to_rgb(image_444 - @offsets[range], colorspace, range)
    end
  end

  def to_rgb([y, u, v], width, height, :C420, colorspace, range) do
    use Image.Math

    with {:ok, y} <- new_scaled_image(y, width, height, 1.0, 1.0),
         {:ok, u} <- new_scaled_image(u, width, height, 2.0, 2.0),
         {:ok, v} <- new_scaled_image(v, width, height, 2.0, 2.0),
         {:ok, image_444} <- Operation.bandjoin([y, u, v]) do
      to_rgb(image_444 - @offsets[range], colorspace, range)
    end
  end

  @doc """
  Converts an image to raw YUV data as
  a binary.

  ### Arguments

  * `image` is any `t:Vimage.t/0`.

  * `encoding` is one of `:C444`, `:C422` or
    `:C420`.

  * `colorspace` is one of `:bt601` (the default) or
    `:bt709`.

  * `range` is one of `:limited` (the default) or `:full`.
    See `t:Image.YUV.yuv_range/0`.

  ### Returns

  * `{:ok, [y, u, v]}` or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(8, 8, color: :red)
      iex> {:ok, [y, u, v]} = Image.YUV.to_yuv(image, :C420)
      iex> {byte_size(y), byte_size(u), byte_size(v)}
      {64, 16, 16}

  """
  @doc since: "0.41.0"

  @spec to_yuv(
          image :: Vimage.t(),
          encoding :: yuv_encoding(),
          colorspace :: yuv_colorspace(),
          range :: yuv_range()
        ) ::
          {:ok, yuv_list()} | {:error, Image.error()}

  def to_yuv(image, encoding, colorspace \\ :bt601, range \\ :limited)

  def to_yuv(%Vimage{} = image, encoding, colorspace, range)
      when encoding in @valid_encodings and colorspace in @valid_colorspace and
             range in @valid_ranges do
    with {:ok, image} <- Image.flatten(image),
         {:ok, transform} <- Vimage.new_from_list(@to_yuv[{colorspace, range}]),
         {:ok, divided} <- Image.Math.divide(transform, 256.0),
         {:ok, recombed} <- Operation.recomb(image, divided),
         {:ok, offset} <- Image.Math.add(recombed, @offsets[range]),
         {:ok, yuv} <- Image.cast(offset, {:u, 8}) do
      encode(yuv, encoding)
    end
  end

  @doc """
  Encodes an image that is in a YUV colorspace to
  raw YUV data that is a list of the three planes, each a
  binary.

  The data is always written in a planar format.

  ### Arguments

  * `image` is any `t:Vimage.t/0` that is in a YUV
    colorspace such as that returned from `Image.YUV.new_from_file/5`
    or `Image.YUV.new_from_binary/5`.

  * `encoding` is one of `:C444`, `:C422` or
    `:C420` representing how `yuv` is to be encoded.

  ### Returns

  * `{:ok, [y, u, v]}` or

  * `{:error, Image.error()}`.

  ### Examples

      iex> yuv_image = Image.new!(8, 8, color: [128, 128, 128])
      iex> {:ok, [y, u, v]} = Image.YUV.encode(yuv_image, :C422)
      iex> {byte_size(y), byte_size(u), byte_size(v)}
      {64, 32, 32}

  """
  @doc since: "0.41.0"

  @spec encode(image :: Vimage.t(), encoding :: yuv_encoding()) ::
          {:ok, yuv_list()} | {:error, Image.error()}

  def encode(%Vimage{} = image, :C444) do
    with {:ok, y} <- Vimage.write_to_binary(image[0]),
         {:ok, u} <- Vimage.write_to_binary(image[1]),
         {:ok, v} <- Vimage.write_to_binary(image[2]) do
      {:ok, [y, u, v]}
    end
  end

  def encode(%Vimage{} = image, :C422) do
    with {:ok, subsampled} <- Operation.subsample(image, 2, 1),
         {:ok, y} <- Vimage.write_to_binary(image[0]),
         {:ok, u} <- Vimage.write_to_binary(subsampled[1]),
         {:ok, v} <- Vimage.write_to_binary(subsampled[2]) do
      {:ok, [y, u, v]}
    end
  end

  def encode(%Vimage{} = image, :C420) do
    with {:ok, subsampled} <- Operation.subsample(image, 2, 2),
         {:ok, y} <- Vimage.write_to_binary(image[0]),
         {:ok, u} <- Vimage.write_to_binary(subsampled[1]),
         {:ok, v} <- Vimage.write_to_binary(subsampled[2]) do
      {:ok, [y, u, v]}
    end
  end

  @doc """
  Deocdes a raw YUV binary into `[y, u, v]` planes
  where each plane is a binary.

  ### Arguments

  * `binary` is a binary representation of a YUV image.

  * `width` is the width of the image encoded in `yuv`.

  * `height` is the height of the image encoded in `yuv`.

  * `encoding` is one of `:C444`, `:C422` or
    `:C420` representing how `yuv` is encoded.

  ### Returns

  * `{:ok, [y, u, v]}` or

  * `{:error, reason}`.

  ### Examples

      iex> binary = :binary.copy(<<128>>, 8 * 8 + 2 * (4 * 4))
      iex> {:ok, [y, u, v]} = Image.YUV.decode(binary, 8, 8, :C420)
      iex> {byte_size(y), byte_size(u), byte_size(v)}
      {64, 16, 16}

      iex> {:error, %Image.Error{}} = Image.YUV.decode(<<1, 2, 3>>, 8, 8, :C444)

  """
  @doc since: "0.41.0"

  def decode(binary, width, height, :C444) do
    y_bytes = width * height

    case binary do
      <<y::bytes-size(^y_bytes), u::bytes-size(^y_bytes), v::bytes-size(^y_bytes)>> ->
        {:ok, [y, u, v]}

      _other ->
        {:error,
         %Image.Error{
           message: "Could not decode raw YUV data as 4:4:4",
           reason: "Could not decode raw YUV data as 4:4:4"
         }}
    end
  end

  def decode(binary, width, height, :C422) do
    y_bytes = width * height
    uv_bytes = div(width, 2) * height

    case binary do
      <<y::bytes-size(^y_bytes), u::bytes-size(^uv_bytes), v::bytes-size(^uv_bytes)>> ->
        {:ok, [y, u, v]}

      _other ->
        {:error,
         %Image.Error{
           message: "Could not decode raw YUV data as 4:2:2",
           reason: "Could not decode raw YUV data as 4:2:2"
         }}
    end
  end

  def decode(binary, width, height, :C420) do
    y_bytes = width * height
    uv_bytes = div(width, 2) * div(height, 2)

    case binary do
      <<y::bytes-size(^y_bytes), u::bytes-size(^uv_bytes), v::bytes-size(^uv_bytes)>> ->
        {:ok, [y, u, v]}

      _other ->
        {:error,
         %Image.Error{
           message: "Could not decode raw YUV data as 4:2:0",
           reason: "Could not decode raw YUV data as 4:2:0"
         }}
    end
  end

  # Scales the U and V planes to be the same size as the Y
  # plane.

  defp new_scaled_image(data, width, height, x_scale, y_scale)
       when x_scale == 1.0 and y_scale == 1.0 do
    Vimage.new_from_binary(data, width, height, 1, :VIPS_FORMAT_UCHAR)
  end

  defp new_scaled_image(data, width, height, x_scale, y_scale) do
    # Subsampled planes have floor-divided dimensions (matching
    # Vix.Vips.Operation.subsample/3), so for odd dimensions the scale
    # back to the full size is not exactly x_scale/y_scale.
    plane_width = max(div(width, round(x_scale)), 1)
    plane_height = max(div(height, round(y_scale)), 1)

    with {:ok, image} <-
           Vimage.new_from_binary(data, plane_width, plane_height, 1, :VIPS_FORMAT_UCHAR) do
      Operation.resize(image, width / plane_width,
        vscale: height / plane_height,
        kernel: :VIPS_KERNEL_LINEAR
      )
    end
  end
end
