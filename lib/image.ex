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
        territory: ~x"./@photoshop:Country"s
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
end

# field_names
# |> Enum.map(fn field_name ->
#   {:ok, value} = Vix.Vips.Image.header_value(img, field_name)
#   if is_binary(value) do
#     IO.puts(field_name <> " = " <> value)
#   end
# end)