defmodule Image.YUV do
  @moduledoc """
  Functions to convert from/to YUV encoding and colorspaces
  to RGB images.

  """

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Operation

  # See https://mymusing.co/bt601-yuv-to-rgb-conversion-color/
  # And https://github.com/libvips/libvips/discussions/2561

  @bt601_to_rgb [
    [1.0,  0.0,       1.402   ],
    [1.0, -0.344136, -0.714136],
    [1.0,  1.772,     0.0     ],
  ]

  # This are the "Computer RGB to YCbCr"
  # coefficients

  @rgb_to_bt601 [
    [65.738, 129.057, 25.064  ],
    [-37.945, -74.494, 112.439],
    [112.439, -94.154, -18.285],
  ]

  # See https://mymusing.co/bt-709-yuv-to-rgb-conversion-color/

  @bt709_to_rgb [
    [1.0,  0.0,       1.5748  ],
    [1.0, -0.187324, -0.468124],
    [1.0,  1.8556,    0.0     ],
  ]

  # This are the "Computer RGB to YCbCr"
  # coefficients

  @rgb_to_bt709 [
    [46.7428, 157.243, 15.873 ],
    [-25.765, -86.674, 112.439],
    [112.439, -102.129, -10.31],
  ]

  @yuv_to_rgb_offsets [16, 128, 128]
  @valid_encodings [:C444, :C422, :C420]
  @valid_colorspace [:bt601, :bt709]

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

  * `colorspace is one of `:bt601` (the default) or
    `:bt709`.

  ### Returns

  * `{:ok, rgb_image}` or

  * `{:error, reason}`.

  """
  @spec new_from_file(path :: Path.t, width :: pos_integer(), height :: pos_integer(), encoding :: atom(), colorspace :: atom()) ::
    {:ok, Vimage.t()} | {:error, Image.error_message()}

  def new_from_file(path, width, height, encoding, colorspace \\ :bt601)
      when encoding in @valid_encodings and colorspace in @valid_colorspace do
    with {:ok, binary} <- File.read(path) do
      new_from_binary(binary, width, height, encoding, colorspace)
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

  * `colorspace is one of `:bt601` (the default) or
    `:bt709`.

  ### Returns

  * `{:ok, rgb_image}` or

  * `{:error, reason}`.

  """
  @spec new_from_binary(binary :: binary(), width :: pos_integer(), height :: pos_integer(), encoding :: atom(), colorspace :: atom()) ::
    {:ok, Vimage.t()} | {:error, Image.error_message()}

  def new_from_binary(binary, width, height, encoding, colorspace \\ :bt601)
      when encoding in @valid_encodings and colorspace in @valid_colorspace do
    with {:ok, decoded} = decode(binary, width, height, encoding) do
      to_rgb(decoded, width, height, encoding, colorspace)
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

  * `colorspace is one of `:bt601` (the default) or
    `:bt709`.

  ### Returns

  * `:ok` or

  * `{:error, reason}`.

  """
  def write_to_file(%Vimage{} = image, path, encoding, colorspace \\ :bt601) do
    with {:ok, binary} <- write_to_binary(image, encoding, colorspace) do
      File.write(path, binary)
    end
  end

  @doc """
  Writes an image to a YUV raw binary.

  ### Arguments

  * `image` is any `t:Vimage.t/0`.

  * `encoding` is one of `:C444`, `:C422` or
    `:C420`.

  * `colorspace is one of `:bt601` (the default) or
    `:bt709`.

  ### Returns

  * `{:ok, yuv_binary}` or

  * `{:error, reason}`.

  """
  def write_to_binary(%Vimage{} = image, encoding, colorspace \\ :bt601) do
    with {:ok, [y, u, v]} <- to_yuv(image, encoding, colorspace) do
      {:ok, y <> u <> v}
    end
  end

  @doc """
  Take an image in a YUV colorspace (which libvips does not
  understand) and convert it to RGB.

  """
  # See https://github.com/libvips/libvips/discussions/2561

  def to_rgb(%Vimage{} = image, :bt601) do
    with {:ok, transform} <- Vimage.new_from_list(@bt601_to_rgb),
         {:ok, recombed} <- Operation.recomb(image, transform),
         {:ok, rgb} <- Image.cast(recombed, {:u, 8}) do
      Operation.copy(rgb, interpretation: :VIPS_INTERPRETATION_sRGB)
    end
  end

  def to_rgb(%Vimage{} = image, :bt709) do
    with {:ok, transform} <- Vimage.new_from_list(@bt709_to_rgb),
         {:ok, float} <- Operation.recomb(image, transform),
         {:ok, rgb} <- Image.cast(float, {:u, 8}) do
      Operation.copy(rgb, interpretation: :VIPS_INTERPRETATION_sRGB)
    end
  end

  @doc """
  Takes the `[y, u, v]` planes and converts them to
  an RGB image.

  """
  def to_rgb([y, u, v], width, height, :C444, colorspace) do
    use Image.Math

    with {:ok, y} <- new_scaled_image(y, width, height, 1.0, 1.0),
         {:ok, u} <- new_scaled_image(u, width, height, 1.0, 1.0),
         {:ok, v} <- new_scaled_image(v, width, height, 1.0, 1.0),
         {:ok, image_444} <- Operation.bandjoin([y, u, v]) do
      to_rgb(image_444 - @yuv_to_rgb_offsets, colorspace)
    end
  end

  def to_rgb([y, u, v], width, height, :C422, colorspace) do
    use Image.Math

    with {:ok, y} <- new_scaled_image(y, width, height, 1.0, 1.0),
         {:ok, u} <- new_scaled_image(u, width, height, 2.0, 1.0),
         {:ok, v} <- new_scaled_image(v, width, height, 2.0, 1.0),
         {:ok, image_444} <- Operation.bandjoin([y, u, v]) do
      to_rgb(image_444 - @yuv_to_rgb_offsets, colorspace)
    end
  end

  def to_rgb([y, u, v], width, height, :C420, colorspace) do
    use Image.Math

    with {:ok, y} <- new_scaled_image(y, width, height, 1.0, 1.0),
         {:ok, u} <- new_scaled_image(u, width, height, 2.0, 2.0),
         {:ok, v} <- new_scaled_image(v, width, height, 2.0, 2.0),
         {:ok, image_444} <- Operation.bandjoin([y, u, v]) do
      to_rgb(image_444 - @yuv_to_rgb_offsets, colorspace)
    end
  end

  @doc """
  Converts an image to raw YUV data as
  a binary.

  ### Arguments

  * `image` is any `t:Vimage.t/0`.

  * `encoding` is one of `:C444`, `:C422` or
    `:C420`.

  * `colorspace is one of `:bt601` (the default) or
    `:bt709`.

  ### Returns

  * `{:ok, [y, u, v]}` or

  * `{:error, reason}`.

  """
  def to_yuv(image, encoding, colorspace \\ :bt601)

  def to_yuv(%Vimage{} = image, encoding, :bt601) when encoding in @valid_encodings do
    use Image.Math

    with {:ok, transform} <- Vimage.new_from_list(@rgb_to_bt601),
         {:ok, divided} <- Image.Math.divide(transform, 256),
         {:ok, float} <- Operation.recomb(image, divided),
         {:ok, yuv} <- Image.cast(float + @yuv_to_rgb_offsets, {:u, 8}) do
      encode(yuv, encoding)
    end
  end

  def to_yuv(%Vimage{} = image, encoding, :bt709) when encoding in @valid_encodings do
    use Image.Math

    with {:ok, transform} <- Vimage.new_from_list(@rgb_to_bt709),
         {:ok, divided} <- Image.Math.divide(transform, 256),
         {:ok, float} <- Operation.recomb(image, divided),
         {:ok, yuv} <- Image.cast(float + @yuv_to_rgb_offsets, {:u, 8}) do
      encode(yuv, encoding)
    end
  end

  @doc """
  Take an image in a YUV colorspace and converts it to
  raw YUV data a list of the three planes, each in
  binary format.

  The data is always writeen in a planar format.

  """
  def encode(%Vimage{} = image, :C444) do
    with {:ok, y} <- new_scaled_plane(image[0], 1.0, 1.0),
         {:ok, u} <- new_scaled_plane(image[1], 1.0, 1.0),
         {:ok, v} <- new_scaled_plane(image[2], 1.0, 1.0) do
      {:ok, [y, u, v]}
    end
  end

  def encode(%Vimage{} = image, :C422) do
    with {:ok, y} <- new_scaled_plane(image[0], 1.0, 1.0),
         {:ok, u} <- new_scaled_plane(image[1], 0.5, 1.0),
         {:ok, v} <- new_scaled_plane(image[2], 0.5, 1.0) do
      {:ok, [y, u, v]}
    end
  end

  def encode(%Vimage{} = image, :C420) do
    with {:ok, y} <- new_scaled_plane(image[0], 1.0, 1.0),
         {:ok, u} <- new_scaled_plane(image[1], 0.5, 0.5),
         {:ok, v} <- new_scaled_plane(image[2], 0.5, 0.5) do
      {:ok, [y, u, v]}
    end
  end

  @doc """
  Takes a raw YUV binary and decodes to the `[y, u, v]` planes.

  """
  def decode(binary, width, height, :C444) do
    y_bytes = width * height

    case binary do
      <<y::bytes-size(y_bytes), u::bytes-size(y_bytes), v::bytes-size(y_bytes)>> ->
        {:ok, [y, u, v]}

      _other ->
        {:error, "Could not decode raw YUV data as 4:4:4"}
    end
  end

  def decode(binary, width, height, :C420) do
    y_bytes = width * height
    uv_bytes = div(y_bytes, 4)

    case binary do
      <<y::bytes-size(y_bytes), u::bytes-size(uv_bytes), v::bytes-size(uv_bytes)>> ->
        {:ok, [y, u, v]}

      _other ->
        {:error, "Could not decode raw YUV data as 4:2:0"}
    end
  end

  def decode(binary, width, height, :C422) do
    y_bytes = width * height
    uv_bytes = div(y_bytes, 2)

    case binary do
      <<y::bytes-size(y_bytes), u::bytes-size(uv_bytes), v::bytes-size(uv_bytes)>> ->
        {:ok, [y, u, v]}

      _other ->
        {:error, "Could not decode raw YUV data as 4:2:2"}
    end
  end

  # Scales the U and V planes to be the same size as the Y
  # plane.

  defp new_scaled_image(data, width, height, x_scale, y_scale)
      when x_scale == 1.0 and y_scale == 1.0 do
    Vimage.new_from_binary(data, width, height, 1, :VIPS_FORMAT_UCHAR)
  end

  defp new_scaled_image(data, width, height, x_scale, y_scale) do
    width = round(width / x_scale)
    height = round(height / y_scale)

    with {:ok, image} <- Vimage.new_from_binary(data, width, height, 1, :VIPS_FORMAT_UCHAR) do
      Operation.resize(image, x_scale, vscale: y_scale, kernel: :VIPS_KERNEL_LINEAR)
    end
  end

  # Subsample one YUV plane and write it to a binary

  def new_scaled_plane(image, 1.0, 1.0) do
    Vimage.write_to_binary(image)
  end

  def new_scaled_plane(image, x_scale, y_scale) do
    with {:ok, resized} <- Image.resize(image, x_scale, vertical_scale: y_scale) do
      Vimage.write_to_binary(resized)
    end
  end
end