defmodule Image do
  import SweetXml

  # @default_image "test/Hong-Kong-2015-07-1998.jpg"
  @default_image "test/Kamchatka-2019-8754.jpg"

  def exif(image \\ @default_image) do
    with {:ok, img} <- Vix.Vips.Image.new_from_file(image),
         {:ok, exif_blob} <- Vix.Vips.Image.header_value(img, "exif-data"),
         <<"Exif"::binary, 0::16, exif::binary>> <- exif_blob do
      exif
      |> Image.Exif.extract_exif()
      |> wrap(:ok)
    else
      other -> IO.inspect other, label: "error: "
    end
  end

  def xmp(image \\ @default_image) do
    with {:ok, img} <- Vix.Vips.Image.new_from_file(image),
         {:ok, xmp_blob} <- Vix.Vips.Image.header_value_as_string(img, "xmp-data"),
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

  @image "~/Desktop/Kip_small.jpg"
  @circle Path.expand("~/Desktop/circle_crop.png")
  @rounded Path.expand("~/Desktop/rounded_crop.png")
  @exif Path.expand("~/Desktop/with_simple_exif.jpg")
  @alpha_channel 3
  @copyright "exif-ifd0-Copyright"

  alias Vix.Vips.{Image, Operation, MutableImage}

  def circle(image \\ @image) do
    {:ok, img} = Image.new_from_file(image)
    width = Image.width(img)
    height = Image.height(img)
    size = min(width, height)

    {:ok, thumb} = Operation.thumbnail_image(img, size, crop: :VIPS_INTERESTING_ATTENTION)
    {:ok, mask} = mask(:circle, size, size)
    {:ok, cropped} = Operation.bandjoin([thumb, mask])

    Image.write_to_file(cropped, @circle)
  end

  def round(image \\ @image) do
    {:ok, img} = Image.new_from_file(image)
    width = Image.width(img)
    height = Image.height(img)

    {:ok, thumb} = Operation.thumbnail_image(img, width, crop: :VIPS_INTERESTING_ATTENTION)
    {:ok, mask} = mask(:rounded_corners, width, height)
    {:ok, cropped} = Operation.bandjoin([thumb, mask])

    Image.write_to_file(cropped, @rounded)
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

  def mask(:rounded_corners, width, height, radius \\ 50) do
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
    {:ok, img} = Image.new_from_file(image)
    {:ok, fields} = Image.header_field_names(img)

    {:ok, img} =
      Image.mutate(img, fn mut_img ->
        :ok = remove_metadata(mut_img, fields)
        :ok = MutableImage.set(mut_img, "exif-data", :VipsBlob, <<0>>)
        :ok = MutableImage.set(mut_img, @copyright, :gchararray, "Copyright (c) 2008 Kip Cole")
      end)
    Image.write_to_file(img, @exif)
  end

  def remove_metadata(img, fields) do
    Enum.each(fields, &MutableImage.remove(img, &1))
  end

  def lambo do
    {:ok, lambo} = Image.new_from_file("~/Desktop/lambo.jpg")
    {:ok, grad} = I.gradient(lambo)
    {:ok, composite} = Operation.composite2(lambo, grad, :VIPS_BLEND_MODE_OVER)
    Image.write_to_file composite, Path.expand("~/Desktop/composite.png")
  end

  @y_band 1
  def gradient(image, start \\ [0, 0, 0, 0], finish \\ [0, 0, 0, 255]) do
    width = Image.width(image)
    height = Image.height(image)

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
    Image.write_to_file(out, Path.expand("~/Desktop/x.png"))
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
    Image.write_to_file(out, Path.expand("~/Desktop/x2.png"))
  end

  def pow(image, value) when is_number(value) do
    Operation.math2_const(image, :VIPS_OPERATION_MATH2_POW, [value])
  end

  def pow(%Image{} = image, %Image{} = image2) do
    Operation.math2(image, image2, :VIPS_OPERATION_MATH2_POW)
  end

  def cos(%Image{} = image) do
    Operation.math(image, :VIPS_OPERATION_MATH_COS)
  end

  def add(%Image{} = image, %Image{} = image2) do
    Operation.add(image, image2)
  end

  def add(%Image{} = image, value) when is_number(value) do
    add(image, [value])
  end

  def add(%Image{} = image, value) when is_list(value) do
    Operation.linear(image, [1], value)
  end

  def subtract(%Image{} = image, %Image{} = image2) do
    Operation.subtract(image, image2)
  end

  def subtract(%Image{} = image, value) when is_number(value) do
    subtract(image, [value])
  end

  def subtract(%Image{} = image, value) when is_list(value) do
    Operation.linear(image, [1], Enum.map(value, &(-&1)))
  end

  def multiply(%Image{} = image, %Image{} = image2) do
    Operation.multiply(image, image2)
  end

  def multiply(%Image{} = image, value) when is_number(value) do
    multiply(image, [value])
  end

  def multiply(%Image{} = image, value) when is_list(value) do
    Operation.linear(image, value, [0])
  end

  def divide(%Image{} = image, %Image{} = image2) do
    Operation.divide(image, image2)
  end

  def divide(%Image{} = image, value) when is_number(value) do
    divide(image, [value])
  end

  def divide(%Image{} = image, value) when is_list(value) do
    Operation.linear(image, Enum.map(value, &(1.0 / &1)), [0])
  end

  @max_band_value 256

  def dominant_colour(%Image{} = image, options \\ []) do
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

  def maxpos(%Image{} = image, options \\ []) do
    size = Keyword.get(options, :size, 10)

    {:ok, {v, opts}} = Operation.max(image, size: size)
    {v, opts[:x], opts[:y]}
  end

  def minpos(%Image{} = image, options \\ []) do
    size = Keyword.get(options, :size, 10)

    {:ok, {v, opts}} = Operation.min(image, size: size)
    {v, opts[:x], opts[:y]}
  end

  def add!(%Image{} = image, value) do
    case add(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def subtract!(%Image{} = image, value) do
    case subtract(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def multiply!(%Image{} = image, value) do
    case multiply(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def divide!(%Image{} = image, value) do
    case divide(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def pow!(%Image{} = image, value) do
    case pow(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def cos!(%Image{} = image) do
    case cos(image) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def list_height([first | _rest] = list) when is_list(first), do: length(list)
  def list_height(_other), do: 0

  def list_width([first | _rest]) when is_list(first), do: length(first)
  def list_width(list) when is_list(list), do: length(list)

end


