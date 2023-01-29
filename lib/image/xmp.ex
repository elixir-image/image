defmodule Image.Xmp do
  @moduledoc """
  Functions to extract and interpret image XMP
  data.

  """

  import SweetXml

  def extract_xmp(xmp) do
    SweetXml.xpath(xmp, ~x"//x:xmpmeta",
      artist: ~x".//dc:creator/rdf:Seq/rdf:li/text()"s |> transform_by(&maybe_nil/1),
      keywords: ~x".//dc:subject/rdf:Bag/rdf:li/text()"ls,
      created_at: ~x".//@xmp:CreateDate"s |> transform_by(&to_date_time/1),
      rating: ~x".//@xmp:Rating"s |> transform_by(&to_integer/1),
      copyright: [
        ~x".//dc:rights/rdf:Alt"l,
        text: ~x"./rdf:li/text()"ls,
        language: ~x"./rdf:li/@xml:lang"ls
      ],
      title: [
        ~x".//dc:title/rdf:Alt"l,
        text: ~x"./rdf:li/text()"ls,
        language: ~x"./rdf:li/@xml:lang"ls
      ],
      description: [
        ~x".//dc:description/rdf:Alt"l,
        text: ~x"./rdf:li/text()"ls,
        language: ~x"./rdf:li/@xml:lang"ls
      ],
      location: [
        ~x".//rdf:Description",
        city: ~x"./@photoshop:City"s |> transform_by(&maybe_nil/1),
        state: ~x"./@photoshop:State"s |> transform_by(&maybe_nil/1),
        territory: ~x"./@photoshop:Country"s |> transform_by(&maybe_nil/1),
        territory_code: ~x"./@Iptc4xmpCore:CountryCode"s |> transform_by(&maybe_nil/1)
      ]
    )
    |> zip(:description)
    |> zip(:title)
    |> zip(:copyright)
  end

  defp zip(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} ->
        zipped = zip(value)
        Map.put(map, key, zipped)

      :error ->
        map
    end
  end

  defp zip([%{language: languages, text: texts}]) do
    languages
    |> Enum.zip(texts)
    |> Map.new()
  end

  defp zip([]) do
    nil
  end

  defp to_date_time("") do
    nil
  end

  defp to_date_time(string) do
    case NaiveDateTime.from_iso8601(string) do
      {:ok, date_time} -> date_time
      _other -> string
    end
  end

  defp to_integer(string) do
    case Integer.parse(string) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp maybe_nil(""), do: nil
  defp maybe_nil(other), do: other
end
