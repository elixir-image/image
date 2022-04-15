defmodule Image do
  alias Vix.Vips.{Operation, MutableImage}
  alias Vix.Vips.Image, as: Vimage
  alias Image.{Exif, Xmp}
  use Image.Math

  @default_round_corner_radius 50
  @default_open_options [access: :sequential]
  @alpha_channel 3
  @copyright "exif-ifd0-Copyright"

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
  Retruns the EXIF data for an image as a
  keyword list.

  Only a limited set of EXIF data is returned.

  """
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

  Only a limited set of XMP data is returned.

  """
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
  Returns the eidth of an image.

  """
  def width(%Vimage{} = image) do
    Vimage.width(image)
  end

  @doc """
  Returns the height of an image.

  """
  def height(%Vimage{} = image) do
    Vimage.height(image)
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
