defmodule Image.Xmp do
  @moduledoc """
  Functions to extract and interpret image XMP data.

  [XMP](https://www.adobe.com/products/xmp.html) is RDF serialised as
  XML. This module reads a selected set of its properties: the
  artist, keywords, creation date, rating, copyright, title,
  description, location and GPS coordinates, the IPTC digital source
  type that labels AI-generated images, and the document identifiers
  editing software writes. Properties are matched by their
  namespace URI rather than their prefix, and are read whether they
  are written as attributes of `rdf:Description` or as child
  elements.

  XMP comes from untrusted image files, so it is parsed with OTP's
  `:xmerl_sax_parser`, which creates no atoms for element or
  attribute names, and a packet that declares a DTD is refused, so
  entity expansion cannot be used against the parser. Invalid XMP
  returns an error rather than raising.

  The primary API is `Image.xmp/1`, which reads the XMP of an image,
  and `extract_xmp/1`, which parses an XMP packet.

  """

  @rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  # xml:lang arrives as a charlist attribute in the XML namespace.
  @xml_namespace ~c"http://www.w3.org/XML/1998/namespace"
  @rdf_namespace ~c"http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  @dc "http://purl.org/dc/elements/1.1/"
  @xmp "http://ns.adobe.com/xap/1.0/"
  @photoshop "http://ns.adobe.com/photoshop/1.0/"
  @iptc_core "http://iptc.org/std/Iptc4xmpCore/1.0/xmlns/"
  @iptc_extension "http://iptc.org/std/Iptc4xmpExt/2008-02-29/"
  @xmp_media_management "http://ns.adobe.com/xap/1.0/mm/"
  @exif "http://ns.adobe.com/exif/1.0/"

  # The properties read, keyed by {namespace URI, local name}. The kind
  # says how the value is decoded: `:first` takes the first item of an
  # array, `:list` all of them, `:alternatives` a map of language to
  # text, and `:text`, `:date_time` and `:integer` a single value.
  @properties %{
    {@dc, "creator"} => {:artist, :first},
    {@dc, "subject"} => {:keywords, :list},
    {@dc, "rights"} => {:copyright, :alternatives},
    {@dc, "title"} => {:title, :alternatives},
    {@dc, "description"} => {:description, :alternatives},
    {@xmp, "CreateDate"} => {:created_at, :date_time},
    {@xmp, "Rating"} => {:rating, :integer},
    {@photoshop, "City"} => {:city, :text},
    {@photoshop, "State"} => {:state, :text},
    {@photoshop, "Country"} => {:territory, :text},
    {@iptc_core, "CountryCode"} => {:territory_code, :text},
    {@iptc_extension, "DigitalSourceType"} => {:digital_source_type, :text},
    {@xmp_media_management, "DocumentID"} => {:document_id, :text},
    {@xmp_media_management, "InstanceID"} => {:instance_id, :text},
    {@xmp_media_management, "OriginalDocumentID"} => {:original_document_id, :text},
    {@photoshop, "DocumentAncestors"} => {:document_ancestors, :list},
    {@exif, "GPSLatitude"} => {:gps_latitude, :text},
    {@exif, "GPSLongitude"} => {:gps_longitude, :text}
  }

  @location_keys [:city, :state, :territory, :territory_code]

  # The language given to an array item that has no xml:lang.
  @default_language "x-default"

  @doc """
  Extracts an XMP metadata packet into an Elixir map.

  ### Arguments

  * `xmp` is the XMP packet as a binary. This is the form libvips
    returns from `Vix.Vips.Image.header_value(image, "xmp-data")`.

  ### Returns

  * A map with the keys `:artist`, `:keywords`, `:created_at`,
    `:rating`, `:copyright`, `:title`, `:description`, `:location`,
    `:gps_latitude`, `:gps_longitude`, `:digital_source_type`,
    `:document_id`, `:instance_id`, `:original_document_id` and
    `:document_ancestors`. A property the packet does not have is
    `nil`, except `:keywords` and `:document_ancestors`, which are
    empty lists, and the fields of `:location`, which are each `nil`,
    or

  * `{:error, :invalid_xmp}` if the packet is not well-formed XML,
    declares a DTD, or has no `rdf:RDF` element.

  ### Examples

      iex> image = Image.open!("./test/support/images/Kip_small.jpg")
      iex> {:ok, xmp} = Vix.Vips.Image.header_value(image, "xmp-data")
      iex> xmp_map = Image.Xmp.extract_xmp(xmp)
      iex> xmp_map.artist
      "Kip Cole"
      iex> xmp_map.created_at
      ~N[2004-09-11 16:06:57]

      iex> Image.Xmp.extract_xmp("<not xml")
      {:error, :invalid_xmp}

  """
  @spec extract_xmp(binary()) :: map() | {:error, :invalid_xmp}
  def extract_xmp(xmp) when is_binary(xmp) do
    if String.contains?(xmp, "<!DOCTYPE") do
      {:error, :invalid_xmp}
    else
      parse(xmp)
    end
  end

  def extract_xmp(_other) do
    {:error, :invalid_xmp}
  end

  defp parse(xmp) do
    state = %{stack: [], text: [], values: %{}, rdf?: false}
    options = [event_fun: &event/3, event_state: state, external_entities: :none]

    case :xmerl_sax_parser.stream(xmp, options) do
      {:ok, %{rdf?: true, values: values}, _rest} -> to_map(values)
      _other -> {:error, :invalid_xmp}
    end
  end

  # The stack holds a frame for each open element: `{:property, property,
  # items}` for a property this module reads, `{:item, language}` for an
  # `rdf:li`, and `:other` for anything else. Text is collected from the
  # start of the innermost property or item.
  defp event({:startElement, uri, name, _qualified_name, attributes}, _location, state) do
    element = {List.to_string(uri), List.to_string(name)}

    state
    |> note_rdf(element)
    |> put_attributes(attributes)
    |> push(element, attributes)
  end

  defp event({:characters, characters}, _location, state) do
    %{state | text: [state.text, characters]}
  end

  defp event({:endElement, _uri, _name, _qualified_name}, _location, state) do
    pop(state)
  end

  defp event(_event, _location, state) do
    state
  end

  defp note_rdf(state, {@rdf, "RDF"}) do
    %{state | rdf?: true}
  end

  defp note_rdf(state, _element) do
    state
  end

  # A simple property can be written as an attribute of the element
  # that describes the resource.
  defp put_attributes(state, attributes) do
    Enum.reduce(attributes, state, fn {uri, _prefix, name, value}, state ->
      element = {List.to_string(uri), List.to_string(name)}
      put_attribute(state, Map.get(@properties, element), List.to_string(value))
    end)
  end

  defp put_attribute(state, nil, _value) do
    state
  end

  defp put_attribute(state, property, value) do
    %{state | values: put_value(state.values, property, [{nil, value}])}
  end

  defp push(state, {@rdf, "li"}, attributes) do
    %{state | stack: [{:item, language(attributes)} | state.stack], text: []}
  end

  defp push(state, element, attributes) do
    case Map.fetch(@properties, element) do
      {:ok, property} -> push_property(state, property, resource(attributes))
      :error -> %{state | stack: [:other | state.stack]}
    end
  end

  # A property whose value is a URI can be written as an empty element
  # with an rdf:resource attribute.
  defp push_property(state, property, nil) do
    %{state | stack: [{:property, property, []} | state.stack], text: []}
  end

  defp push_property(state, property, resource) do
    state = %{state | values: put_value(state.values, property, [{nil, resource}])}
    %{state | stack: [:other | state.stack]}
  end

  defp resource(attributes) do
    Enum.find_value(attributes, fn
      {@rdf_namespace, _prefix, ~c"resource", resource} -> List.to_string(resource)
      _attribute -> nil
    end)
  end

  defp language(attributes) do
    Enum.find_value(attributes, fn
      {@xml_namespace, _prefix, ~c"lang", language} -> List.to_string(language)
      _attribute -> nil
    end)
  end

  defp pop(%{stack: [{:item, language} | stack]} = state) do
    %{state | stack: add_item(stack, {language, text(state)})}
  end

  # A property with no items holds its value as text, the element form
  # of a simple property.
  defp pop(%{stack: [{:property, property, []} | stack]} = state) do
    %{state | stack: stack, values: put_value(state.values, property, [{nil, text(state)}])}
  end

  defp pop(%{stack: [{:property, property, items} | stack]} = state) do
    %{state | stack: stack, values: put_value(state.values, property, Enum.reverse(items))}
  end

  defp pop(%{stack: [_frame | stack]} = state) do
    %{state | stack: stack}
  end

  defp pop(state) do
    state
  end

  # Adds an array item to the innermost open property.
  defp add_item([{:property, property, items} | stack], item) do
    [{:property, property, [item | items]} | stack]
  end

  defp add_item([frame | stack], item) do
    [frame | add_item(stack, item)]
  end

  defp add_item([], _item) do
    []
  end

  defp text(state) do
    state.text
    |> List.to_string()
    |> String.trim()
  end

  # The first value of a property wins. Empty values are not recorded, so
  # the property stays absent.
  defp put_value(values, {key, kind}, items) do
    case Enum.reject(items, &match?({_language, ""}, &1)) do
      [] -> values
      [_ | _] = items -> Map.put_new(values, key, decode(kind, items))
    end
  end

  defp decode(:first, [{_language, text} | _items]) do
    text
  end

  defp decode(:list, items) do
    Enum.map(items, fn {_language, text} -> text end)
  end

  defp decode(:alternatives, items) do
    Map.new(items, fn {language, text} -> {language || @default_language, text} end)
  end

  defp decode(:text, [{_language, text} | _items]) do
    text
  end

  defp decode(:date_time, [{_language, text} | _items]) do
    case NaiveDateTime.from_iso8601(text) do
      {:ok, date_time} -> date_time
      {:error, _reason} -> text
    end
  end

  defp decode(:integer, [{_language, text} | _items]) do
    case Integer.parse(text) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp to_map(values) do
    %{
      artist: Map.get(values, :artist),
      keywords: Map.get(values, :keywords, []),
      created_at: Map.get(values, :created_at),
      rating: Map.get(values, :rating),
      copyright: Map.get(values, :copyright),
      title: Map.get(values, :title),
      description: Map.get(values, :description),
      location: Map.new(@location_keys, &{&1, Map.get(values, &1)}),
      gps_latitude: Map.get(values, :gps_latitude),
      gps_longitude: Map.get(values, :gps_longitude),
      digital_source_type: Map.get(values, :digital_source_type),
      document_id: Map.get(values, :document_id),
      instance_id: Map.get(values, :instance_id),
      original_document_id: Map.get(values, :original_document_id),
      document_ancestors: Map.get(values, :document_ancestors, [])
    }
  end
end
