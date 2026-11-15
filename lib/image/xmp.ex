defmodule Image.Xmp do
  @moduledoc """
  Functions to extract and interpret image XMP data.

  [XMP](https://www.adobe.com/products/xmp.html) is RDF serialised as
  XML. This module reads a selected set of its properties: the
  artist, keywords, creation date, rating, copyright, title,
  description, location and GPS coordinates, the IPTC digital source
  type that labels AI-generated images, the document identifiers
  editing software writes, including those in its editing history, the
  people shown and the names given to
  face regions, the creator's contact details, and the IPTC locations
  shown and created. Properties are matched by their
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

  alias Image.Xmp.Edit

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
  @mwg_regions "http://www.metadataworkinggroup.com/schemas/regions/"
  @microsoft_region "http://ns.microsoft.com/photo/1.2/t/Region#"
  @microsoft_photo "http://ns.microsoft.com/photo/1.2/"
  @resource_ref "http://ns.adobe.com/xap/1.0/sType/ResourceRef#"
  @resource_event "http://ns.adobe.com/xap/1.0/sType/ResourceEvent#"

  # The properties read, keyed by {namespace URI, local name}. The kind
  # says how the value is decoded: `:first` takes the first item of an
  # array, `:list` all of them, `:alternatives` a map of language to
  # text, and `:text`, `:date_time` and `:integer` a single value.
  # `:collect` gathers the values of every occurrence, for properties
  # that repeat inside structures, such as the name of each face region.
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
    {@exif, "GPSLongitude"} => {:gps_longitude, :text},
    {@iptc_extension, "PersonInImage"} => {:people_in_image, :collect},
    {@iptc_extension, "PersonName"} => {:people_in_image, :collect},
    {@mwg_regions, "Name"} => {:region_names, :collect},
    {@microsoft_region, "PersonDisplayName"} => {:region_names, :collect},
    {@iptc_core, "CiEmailWork"} => {:creator_email, :text},
    {@iptc_core, "CiTelWork"} => {:creator_phone, :text},
    {@iptc_core, "CiUrlWork"} => {:creator_url, :text},
    {@iptc_core, "CiAdrExtadr"} => {:creator_address, :text},
    {@iptc_core, "CiAdrCity"} => {:creator_city, :text},
    {@iptc_core, "CiAdrRegion"} => {:creator_region, :text},
    {@iptc_core, "CiAdrPcode"} => {:creator_postal_code, :text},
    {@iptc_core, "CiAdrCtry"} => {:creator_country, :text},
    {@resource_ref, "documentID"} => {:document_history, :collect},
    {@resource_ref, "instanceID"} => {:document_history, :collect},
    {@resource_ref, "originalDocumentID"} => {:document_history, :collect},
    {@resource_event, "instanceID"} => {:document_history, :collect}
  }

  @location_keys [:city, :state, :territory, :territory_code]

  # IPTC location structures. Inside one, a location field describes that
  # location rather than the image, so it is kept with the structure.
  @location_scopes %{
    {@iptc_extension, "LocationShown"} => :locations_shown,
    {@iptc_extension, "LocationCreated"} => :location_created
  }

  @location_fields %{
    {@iptc_extension, "Sublocation"} => :sublocation,
    {@iptc_extension, "City"} => :city,
    {@iptc_extension, "ProvinceState"} => :province_state,
    {@iptc_extension, "CountryName"} => :country_name,
    {@iptc_extension, "CountryCode"} => :country_code,
    {@iptc_extension, "WorldRegion"} => :world_region,
    {@exif, "GPSLatitude"} => :gps_latitude,
    {@exif, "GPSLongitude"} => :gps_longitude
  }

  @containers [{@rdf, "Bag"}, {@rdf, "Seq"}, {@rdf, "Alt"}]

  # The keys of the `:creator_contact` map, and the values they come from.
  @contact_keys [
    email: :creator_email,
    phone: :creator_phone,
    url: :creator_url,
    address: :creator_address,
    city: :creator_city,
    region: :creator_region,
    postal_code: :creator_postal_code,
    country: :creator_country
  ]

  # The properties removed for each field `extract_xmp/1` returns. Every
  # occurrence is removed, except that GPS inside an IPTC location
  # structure describes that location and is kept.
  @removal_properties %{
    artist: [{@dc, "creator"}],
    gps_latitude: [{@exif, "GPSLatitude"}],
    gps_longitude: [{@exif, "GPSLongitude"}],
    city: [{@photoshop, "City"}],
    state: [{@photoshop, "State"}],
    territory: [{@photoshop, "Country"}],
    territory_code: [{@iptc_core, "CountryCode"}],
    digital_source_type: [{@iptc_extension, "DigitalSourceType"}],
    document_id: [{@xmp_media_management, "DocumentID"}],
    instance_id: [{@xmp_media_management, "InstanceID"}],
    original_document_id: [{@xmp_media_management, "OriginalDocumentID"}],
    document_ancestors: [{@photoshop, "DocumentAncestors"}],
    people_in_image: [
      {@iptc_extension, "PersonInImage"},
      {@iptc_extension, "PersonInImageWDetails"}
    ],
    region_names: [{@mwg_regions, "Regions"}, {@microsoft_photo, "RegionInfo"}],
    creator_contact: [{@iptc_core, "CreatorContactInfo"}],
    location_created: [{@iptc_extension, "LocationCreated"}],
    locations_shown: [{@iptc_extension, "LocationShown"}],
    document_history: [
      {@xmp_media_management, "DerivedFrom"},
      {@xmp_media_management, "History"},
      {@xmp_media_management, "Ingredients"},
      {@xmp_media_management, "ManagedFrom"},
      {@xmp_media_management, "Manifest"},
      {@resource_ref, "documentID"},
      {@resource_ref, "instanceID"},
      {@resource_ref, "originalDocumentID"},
      {@resource_event, "instanceID"}
    ]
  }

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
    `:document_id`, `:instance_id`, `:original_document_id`,
    `:document_ancestors`, `:people_in_image`, `:region_names`,
    `:creator_contact`, `:location_created`, `:locations_shown` and
    `:document_history`.
    `:people_in_image` lists the people the IPTC says are shown, and
    `:region_names` the names photo managers give to face regions.
    `:location_created` and `:locations_shown` are lists of maps, one
    per IPTC location structure. `:document_history` lists the document
    and instance IDs of the files the image was made from and of its
    editing history. A property the packet does not have
    is `nil`, except the lists, which are empty, and the fields of
    `:location` and `:creator_contact`, which are each `nil`, or

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

  @doc false
  # Removes the properties behind the given fields of `extract_xmp/1` from
  # the packet in place, keeping every other byte. The result is parsed
  # again before it is returned.
  @spec remove_properties(binary(), [atom()]) :: {:ok, binary()} | {:error, :invalid_xmp}
  def remove_properties(xmp, fields) when is_binary(xmp) do
    case extract_xmp(xmp) do
      {:error, :invalid_xmp} = error -> error
      _xmp -> cut_properties(xmp, Enum.flat_map(fields, &Map.get(@removal_properties, &1, [])))
    end
  end

  defp cut_properties(xmp, targets) do
    case Edit.properties(xmp) do
      {:ok, properties} ->
        spans = for property <- properties, removed?(property, targets), do: property.span
        checked(Edit.cut(xmp, spans))

      :error ->
        {:error, :invalid_xmp}
    end
  end

  defp checked(xmp) do
    case extract_xmp(xmp) do
      {:error, :invalid_xmp} = error -> error
      _xmp -> {:ok, xmp}
    end
  end

  defp removed?(%{name: {@exif, _local} = name, ancestors: ancestors}, targets) do
    name in targets and not Enum.any?(ancestors, &Map.has_key?(@location_scopes, &1))
  end

  defp removed?(%{name: name}, targets) do
    name in targets
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
    |> push(element, attributes)
    |> put_attributes(attributes)
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
  # that describes the resource. Inside a location structure, a
  # location field belongs to that location.
  defp put_attributes(state, attributes) do
    Enum.reduce(attributes, state, fn {uri, _prefix, name, value}, state ->
      element = {List.to_string(uri), List.to_string(name)}
      put_attribute(state, element, List.to_string(value))
    end)
  end

  defp put_attribute(state, element, value) do
    location_field = Map.get(@location_fields, element)

    if location_field && in_scope?(state.stack) do
      %{state | stack: put_in_scope(state.stack, location_field, value)}
    else
      put_property_attribute(state, Map.get(@properties, element), value)
    end
  end

  defp put_property_attribute(state, nil, _value) do
    state
  end

  defp put_property_attribute(state, property, value) do
    %{state | values: put_value(state.values, property, [{nil, value}])}
  end

  defp push(state, {@rdf, "li"}, attributes) do
    if scope_item?(state.stack) do
      push_frame(state, :scope_item)
    else
      %{state | stack: [{:item, language(attributes)} | state.stack], text: []}
    end
  end

  defp push(state, element, attributes) do
    cond do
      Map.has_key?(@location_scopes, element) ->
        push_frame(state, {:scope, Map.fetch!(@location_scopes, element), %{}, []})

      Map.has_key?(@location_fields, element) and in_scope?(state.stack) ->
        %{
          state
          | stack: [{:scope_field, Map.fetch!(@location_fields, element)} | state.stack],
            text: []
        }

      true ->
        push_property_or_other(state, element, attributes)
    end
  end

  defp push_property_or_other(state, element, attributes) do
    case Map.fetch(@properties, element) do
      {:ok, property} -> push_property(state, property, resource(attributes))
      :error -> push_frame(state, {:other, element})
    end
  end

  defp push_frame(state, frame) do
    %{state | stack: [frame | state.stack]}
  end

  # A property whose value is a URI can be written as an empty element
  # with an rdf:resource attribute.
  defp push_property(state, property, nil) do
    %{state | stack: [{:property, property, []} | state.stack], text: []}
  end

  defp push_property(state, property, resource) do
    state = %{state | values: put_value(state.values, property, [{nil, resource}])}
    push_frame(state, {:other, :resource})
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

  defp pop(%{stack: [:scope_item | stack]} = state) do
    %{state | stack: finish_location(stack)}
  end

  defp pop(%{stack: [{:scope_field, field} | stack]} = state) do
    %{state | stack: put_in_scope(stack, field, text(state))}
  end

  defp pop(%{stack: [{:scope, key, current, done} | stack]} = state) do
    locations = Enum.reverse(add_location(done, current))
    %{state | stack: stack, values: Map.update(state.values, key, locations, &(&1 ++ locations))}
  end

  defp pop(%{stack: [_frame | stack]} = state) do
    %{state | stack: stack}
  end

  defp pop(state) do
    state
  end

  # An rdf:li directly inside a location scope, past any array
  # container, is one location.
  defp scope_item?([{:other, element} | stack]) when element in @containers do
    scope_item?(stack)
  end

  defp scope_item?([{:scope, _key, _current, _done} | _stack]) do
    true
  end

  defp scope_item?(_stack) do
    false
  end

  defp in_scope?(stack) do
    Enum.any?(stack, &match?({:scope, _key, _current, _done}, &1))
  end

  defp put_in_scope(stack, _field, "") do
    stack
  end

  defp put_in_scope(stack, field, value) do
    update_scope(stack, fn {:scope, key, current, done} ->
      {:scope, key, Map.put_new(current, field, value), done}
    end)
  end

  defp finish_location(stack) do
    update_scope(stack, fn {:scope, key, current, done} ->
      {:scope, key, %{}, add_location(done, current)}
    end)
  end

  defp add_location(done, current) when map_size(current) == 0 do
    done
  end

  defp add_location(done, current) do
    [current | done]
  end

  # Applies `fun` to the innermost location scope on the stack.
  defp update_scope([{:scope, _key, _current, _done} = scope | stack], fun) do
    [fun.(scope) | stack]
  end

  defp update_scope([frame | stack], fun) do
    [frame | update_scope(stack, fun)]
  end

  defp update_scope([], _fun) do
    []
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
      [_ | _] = items -> store(values, key, kind, decode(kind, items))
    end
  end

  defp store(values, key, :collect, texts) do
    Map.update(values, key, texts, &(&1 ++ texts))
  end

  defp store(values, key, _kind, value) do
    Map.put_new(values, key, value)
  end

  defp decode(:collect, items) do
    Enum.map(items, fn {_language, text} -> text end)
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
      document_ancestors: Map.get(values, :document_ancestors, []),
      people_in_image: Enum.uniq(Map.get(values, :people_in_image, [])),
      region_names: Enum.uniq(Map.get(values, :region_names, [])),
      creator_contact: Map.new(@contact_keys, fn {key, value} -> {key, Map.get(values, value)} end),
      location_created: Map.get(values, :location_created, []),
      locations_shown: Map.get(values, :locations_shown, []),
      document_history: Enum.uniq(Map.get(values, :document_history, []))
    }
  end
end
