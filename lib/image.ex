defmodule Image do
  import SweetXml
  alias Vix.Vips.{Operation, MutableImage}
  alias Vix.Vips.Image, as: Vimage
  alias Image.Exif
  import Image.Math

  # @default_image "test/Hong-Kong-2015-07-1998.jpg"
  @default_image "test/support/images/Kamchatka-2019-8754.jpg"
  @default_round_corner_radius 50

  def exif(image \\ @default_image) do
    with {:ok, img} <- Vimage.new_from_file(image),
         {:ok, exif_blob} <- Vimage.header_value(img, "exif-data"),
         <<"Exif"::binary, 0::16, exif::binary>> <- exif_blob do
      exif
      |> Exif.extract_exif()
      |> wrap(:ok)
    else
      other -> IO.inspect other, label: "error: "
    end
  end

  def xmp(image \\ @default_image) do
    with {:ok, img} <- Vimage.new_from_file(image),
         {:ok, xmp_blob} <- Vimage.header_value_as_string(img, "xmp-data"),
         {:ok, xmp_binary} <- Base.decode64(xmp_blob) do
      xmp_binary
      |> SweetXml.parse(dtd: :none)
      |> extract_xmp()
      |> wrap(:ok)
    end
  end

  def extract_xmp(xmp) do
    SweetXml.xpath(xmp, ~x"//x:xmpmeta",
      title: [
        ~x".//dc:title/rdf:Alt",
        text: ~x"./rdf:li/text()"s,
        language: ~x"./rdf:li/@xml:lang"s
        ],

      description: [
        ~x".//dc:description/rdf:Alt",
        text: ~x"./rdf:li/text()"s,
        language: ~x"./rdf:li/@xml:lang"s
        ],

      keywords: ~x".//dc:subject/rdf:Bag/rdf:li/text()"ls,
      created_at: ~x".//rdf:Description/xmp:CreateDate"s |> transform_by(&to_date_time/1),
      rating: ~x".//rdf:Description/@xmp:Rating"s |> transform_by(&to_integer/1),
      location: [
        ~x".//rdf:Description",
        city: ~x"./@photoshop:City"s,
        state: ~x"./@photoshop:State"s,
        territory: ~x"./@photoshop:Country"s,
        territory_code: ~x"./Iptc4xmpCore:CountryCode"s
      ]
    )
  end

  defp to_date_time(string) do
    string = if String.contains?(string, "+"), do: string, else: string <> "+00:00"

    case NaiveDateTime.from_iso8601(string) do
      {:ok, date_time} -> date_time
      _other -> string
    end
  end

  defp to_integer(string) do
    case Integer.parse(string) do
      {integer, ""} -> integer
      _other -> string
    end
  end

  defp wrap(item, atom) do
    {atom, item}
  end

  def width(%Vimage{} = image) do
    Vimage.width(image)
  end

  def height(%Vimage{} = image) do
    Vimage.height(image)
  end

  @image "test/support/images/Kip_small.jpg"
  @circle Path.expand("test/support/output/circle_crop.png")
  @rounded Path.expand("test/support/output/rounded_crop.png")
  @exif Path.expand("test/support/output/with_simple_exif.jpg")
  @alpha_channel 3
  @copyright "exif-ifd0-Copyright"

  def circle(%Vimage{} = image) do
    width = width(image)
    height = height(image)
    size = min(width, height)

    {:ok, thumb} = Operation.thumbnail_image(image, size, crop: :VIPS_INTERESTING_ATTENTION)
    {:ok, mask} = mask(:circle, size, size)
    Operation.bandjoin([thumb, mask])
  end

  def round(%Vimage{} = image) do
    width = width(image)
    height = height(image)

    {:ok, thumb} = Operation.thumbnail_image(img, width, crop: :VIPS_INTERESTING_ATTENTION)
    {:ok, mask} = mask(:rounded_corners, width, height)
    Operation.bandjoin([thumb, mask])
  end

  def mask(:circle, diameter, _) do
    centre = div(diameter, 2)

    svg =
      """
      <svg viewBox="0 0 #{diameter} #{diameter}">
        <circle style="fill: black; stroke: none" cx="#{centre}" cy="#{centre}" r="#{centre}"/>
      </svg>
      """

    {:ok, {circle, _flags}} = Operation.svgload_buffer(svg)
    Operation.extract_band(circle, @alpha_channel)
  end

  def mask(:rounded_corners, width, height, radius \\ @default_round_corner_radius) do
    svg =
      """
      <svg viewBox="0 0 #{width} #{height}">
        <rect rx="#{radius}" ry="#{radius}"
         x="0" y="0"
         width="#{width}" height="#{height}"
         fill=black/>
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

  def add_exif(image \\ @image) do
    {:ok, img} = Vimage.new_from_file(image)
    {:ok, fields} = Vimage.header_field_names(img)

    {:ok, img} =
      Vimage.mutate(img, fn mut_img ->
        :ok = remove_metadata(mut_img, fields)
        :ok = MutableImage.set(mut_img, "exif-data", :VipsBlob, <<0>>)
        :ok = MutableImage.set(mut_img, @copyright, :gchararray, "Copyright (c) 2008 Kip Cole")
      end)
    Vimage.write_to_file(img, @exif)
  end

  def remove_metadata(img, fields) do
    Enum.each(fields, &MutableImage.remove(img, &1))
  end

  def lambo do
    {:ok, lambo} = Vimage.new_from_file("~/Desktop/lambo.jpg")
    {:ok, grad} = gradient(lambo)
    {:ok, composite} = Operation.composite2(lambo, grad, :VIPS_BLEND_MODE_OVER)
    Vimage.write_to_file composite, Path.expand("~/Desktop/composite.png")
  end

  @y_band 1
  def gradient(image, start \\ [0, 0, 0, 0], finish \\ [0, 0, 0, 255]) do
    width = width(image)
    height = height(image)

    {:ok, xyz} = Operation.xyz(width, height)
    {:ok, y} = Operation.extract_band(xyz, @y_band)

    # the distance image: 0 - 1 for the start to the end of the gradient
    {:ok, d} = divide(y, height)

    # and use it to fade the quads ... we need to tag the result as an RGB
    # image
    d
    |> multiply!(finish)
    |> add!(fun(d, start))
    |> Operation.copy(interpretation: :VIPS_INTERPRETATION_sRGB)
  end

  defp fun(d, start) do
    d
    |> multiply!(-1)
    |> add!(1)
    |> multiply!(start)
  end

  def grad do
    start = [100, 50, 0]
    finish = [50, 0, 50]
    size = 512

    {:ok, x} = Operation.xyz(size, size)
    {:ok, x} = subtract(x, [Image.width(x) / 2, Image.height(x) / 2])

    {:ok, x0} = Operation.extract_band(x, 0)
    {:ok, x1} = Operation.extract_band(x, 1)

    d =
      pow!(x0, 2)
      |> add!(pow!(x1, 2))
      |> pow!(0.5)
      |> divide!(2 ** 0.5 * size / 2)

    out =
      d
      |> multiply!(finish)
      |> add!(multiply!(d, -1) |> add!(1) |> multiply!(start))


    {:ok, out} = Operation.copy(out, interpretation: :VIPS_INTERPRETATION_LAB)
    Vimage.write_to_file(out, Path.expand("~/Desktop/x.png"))
  end

  def grad2 do
    start = [255, 0, 0]
    finish = [0, 0, 255]

    {:ok, x} = Operation.xyz(100, 200)
    {:ok, x} = subtract(x, [Image.width(x) / 2, Image.height(x) / 2])

    {:ok, x0} = Operation.extract_band(x, 0)
    {:ok, x1} = Operation.extract_band(x, 1)

    d =
      x0
      |> pow!(2)
      |> add!(pow!(x1, 2))
      |> pow!(0.5)

    d =
      d
      |> multiply!(10)
      |> cos!()
      |> divide!(2)
      |> add!(0.5)

    out =
      d
      |> multiply!(finish)
      |> add!(multiply!(d, -1) |> add!(1) |> multiply!(start))

    {:ok, out} = Operation.copy(out, interpretation: :VIPS_INTERPRETATION_sRGB)
    Vimage.write_to_file(out, Path.expand("~/Desktop/x2.png"))
  end

  @max_band_value 256

  def dominant_colour(%Vimage{} = image, options \\ []) do
    bins = Keyword.get(options, :bins, 10)
    bin_size = @max_band_value / bins

    {:ok, histogram} = Operation.hist_find_ndim(image, bins: bins)
    {v, x, y} = maxpos(histogram)
    {:ok, pixel} = Operation.getpoint(histogram, x, y)
    band = Enum.find_index(pixel, &(&1 == v))

    r = (x * bin_size) + (bin_size / 2)
    g = (y * bin_size) + (bin_size / 2)
    b = (band * bin_size) + (bin_size / 2)

    [trunc(r), trunc(g), trunc(b)]
  end



end


