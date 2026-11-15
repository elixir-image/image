defmodule Image.XmpCoverageTest do
  use ExUnit.Case, async: true

  import Image.TestSupport

  alias Image.Xmp

  doctest Image.Xmp

  @namespaces """
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:Iptc4xmpExt="http://iptc.org/std/Iptc4xmpExt/2008-02-29/"
  xmlns:Iptc4xmpCore="http://iptc.org/std/Iptc4xmpCore/1.0/xmlns/"
  xmlns:mwg-rs="http://www.metadataworkinggroup.com/schemas/regions/"
  xmlns:MP="http://ns.microsoft.com/photo/1.2/"
  xmlns:MPRI="http://ns.microsoft.com/photo/1.2/t/RegionInfo#"
  xmlns:MPReg="http://ns.microsoft.com/photo/1.2/t/Region#"
  xmlns:exif="http://ns.adobe.com/exif/1.0/"
  """

  @full_xmp """
  <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
  <x:xmpmeta xmlns:x="adobe:ns:meta/">
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description rdf:about=""
        xmlns:dc="http://purl.org/dc/elements/1.1/"
        xmlns:xmp="http://ns.adobe.com/xap/1.0/"
        xmlns:photoshop="http://ns.adobe.com/photoshop/1.0/"
        xmlns:Iptc4xmpCore="http://iptc.org/std/Iptc4xmpCore/1.0/xmlns/"
        xmp:CreateDate="2020-01-02T03:04:05"
        xmp:Rating="4"
        photoshop:City="Singapore"
        photoshop:State="Central"
        photoshop:Country="Singapore"
        Iptc4xmpCore:CountryCode="SG">
        <dc:creator>
          <rdf:Seq>
            <rdf:li>Test Artist</rdf:li>
          </rdf:Seq>
        </dc:creator>
        <dc:subject>
          <rdf:Bag>
            <rdf:li>alpha</rdf:li>
            <rdf:li>beta</rdf:li>
          </rdf:Bag>
        </dc:subject>
        <dc:rights>
          <rdf:Alt>
            <rdf:li xml:lang="x-default">Copyright (c) Test 2020</rdf:li>
          </rdf:Alt>
        </dc:rights>
        <dc:title>
          <rdf:Alt>
            <rdf:li xml:lang="x-default">A title</rdf:li>
            <rdf:li xml:lang="de-DE">Ein Titel</rdf:li>
          </rdf:Alt>
        </dc:title>
        <dc:description>
          <rdf:Alt>
            <rdf:li xml:lang="x-default">A description</rdf:li>
          </rdf:Alt>
        </dc:description>
      </rdf:Description>
    </rdf:RDF>
  </x:xmpmeta>
  <?xpacket end="w"?>
  """

  @minimal_xmp """
  <x:xmpmeta xmlns:x="adobe:ns:meta/">
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description rdf:about=""/>
    </rdf:RDF>
  </x:xmpmeta>
  """

  describe "Image.Xmp.extract_xmp/1 with a full synthetic payload" do
    setup do
      {:ok, xmp: Xmp.extract_xmp(@full_xmp)}
    end

    test "extracts the artist", %{xmp: xmp} do
      assert xmp.artist == "Test Artist"
    end

    test "extracts keywords as a list", %{xmp: xmp} do
      assert xmp.keywords == ["alpha", "beta"]
    end

    test "extracts and parses the creation date", %{xmp: xmp} do
      assert xmp.created_at == ~N[2020-01-02 03:04:05]
    end

    test "extracts the rating as an integer", %{xmp: xmp} do
      assert xmp.rating == 4
    end

    test "zips copyright text with its language", %{xmp: xmp} do
      assert xmp.copyright == %{"x-default" => "Copyright (c) Test 2020"}
    end

    test "zips multiple title languages into a map", %{xmp: xmp} do
      assert xmp.title == %{"x-default" => "A title", "de-DE" => "Ein Titel"}
    end

    test "zips the description with its language", %{xmp: xmp} do
      assert xmp.description == %{"x-default" => "A description"}
    end

    test "extracts location fields", %{xmp: xmp} do
      assert xmp.location == %{
               city: "Singapore",
               state: "Central",
               territory: "Singapore",
               territory_code: "SG"
             }
    end
  end

  describe "Image.Xmp.extract_xmp/1 with a minimal payload" do
    setup do
      {:ok, xmp: Xmp.extract_xmp(@minimal_xmp)}
    end

    test "missing string fields are nil", %{xmp: xmp} do
      assert xmp.artist == nil
      assert xmp.created_at == nil
      assert xmp.rating == nil
    end

    test "missing keywords are an empty list", %{xmp: xmp} do
      assert xmp.keywords == []
    end

    test "missing language-alternative fields are nil", %{xmp: xmp} do
      assert xmp.title == nil
      assert xmp.description == nil
      assert xmp.copyright == nil
    end

    test "missing location fields are nil", %{xmp: xmp} do
      assert xmp.location == %{city: nil, state: nil, territory: nil, territory_code: nil}
    end
  end

  describe "Image.Xmp.extract_xmp/1 value edge cases" do
    test "a non-ISO8601 create date is returned as the raw string" do
      xmp =
        @minimal_xmp
        |> String.replace(~s(rdf:about=""), ~s(rdf:about="" xmp:CreateDate="2020:01:02"))
        |> String.replace(
          ~s(xmlns:x="adobe:ns:meta/"),
          ~s(xmlns:x="adobe:ns:meta/" xmlns:xmp="http://ns.adobe.com/xap/1.0/")
        )
        |> Xmp.extract_xmp()

      assert xmp.created_at == "2020:01:02"
    end

    test "a non-integer rating is nil" do
      xmp =
        @minimal_xmp
        |> String.replace(~s(rdf:about=""), ~s(rdf:about="" xmp:Rating="4.5"))
        |> String.replace(
          ~s(xmlns:x="adobe:ns:meta/"),
          ~s(xmlns:x="adobe:ns:meta/" xmlns:xmp="http://ns.adobe.com/xap/1.0/")
        )
        |> Xmp.extract_xmp()

      assert xmp.rating == nil
    end
  end

  describe "Image.xmp/1 on real images" do
    test "extracts XMP data from an image with an XMP segment" do
      {:ok, image} = Image.open(image_path("Kip_small.jpg"))

      assert {:ok, xmp} = Image.xmp(image)
      assert xmp.artist == "Kip Cole"
      assert xmp.created_at == ~N[2004-09-11 16:06:57]
      assert xmp.copyright == %{"x-default" => "Copyright (c) Kip Cole 2012"}
      assert xmp.location.territory == "Vietnam"
      assert xmp.location.territory_code == "VN"
      assert xmp.rating == nil
      assert xmp.keywords == []
    end

    test "extracts XMP keywords and title from a tagged image" do
      {:ok, image} = Image.open(image_path("Sydney-Opera-House-BW.jpg"))

      assert {:ok, xmp} = Image.xmp(image)
      assert xmp.title == %{"x-default" => "Opera House Shells"}
      assert xmp.description == %{"x-default" => "Opera House Shells in the late afternoon"}
      assert is_list(xmp.keywords) and xmp.keywords != []
    end

    test "returns an error for an image without XMP data" do
      {:ok, image} = Image.open(image_path("kodak-dc210.jpg"))

      assert {:error, _reason} = Image.xmp(image)
    end
  end

  describe "Image.Xmp.extract_xmp/1 invalid packets" do
    test "malformed XML is an error" do
      for xml <- ["<not xml", "", "plain text", <<0xFF, 0xFE>>, "<a><b></a>"] do
        assert Xmp.extract_xmp(xml) == {:error, :invalid_xmp}
      end
    end

    test "a packet that declares a DTD is refused" do
      xml = """
      <!DOCTYPE x [<!ENTITY a "aaaaaaaaaa"><!ENTITY b "&a;&a;&a;&a;&a;&a;&a;&a;">]>
      <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">&b;</rdf:RDF>
      """

      assert Xmp.extract_xmp(xml) == {:error, :invalid_xmp}
    end

    test "well-formed XML with no rdf:RDF element is an error" do
      assert Xmp.extract_xmp(~s(<x:xmpmeta xmlns:x="adobe:ns:meta/"></x:xmpmeta>)) ==
               {:error, :invalid_xmp}
    end

    test "a value that is not a binary is an error" do
      assert Xmp.extract_xmp(nil) == {:error, :invalid_xmp}
    end

    test "Image.xmp/1 returns an Image.Error for malformed XMP" do
      {:ok, image} =
        Vix.Vips.Image.mutate(Image.new!(4, 4), fn mutable ->
          Vix.Vips.MutableImage.set(mutable, "xmp-data", :VipsBlob, "<not xml")
        end)

      assert {:error, %Image.Error{reason: :invalid_xmp, operation: :xmp}} = Image.xmp(image)
    end
  end

  describe "Image.Xmp.extract_xmp/1 packet shapes" do
    test "rdf:RDF without an x:xmpmeta wrapper is read" do
      xml = """
      <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description xmlns:xmp="http://ns.adobe.com/xap/1.0/" xmp:Rating="3"/>
      </rdf:RDF>
      """

      assert %{rating: 3} = Xmp.extract_xmp(xml)
    end

    test "rdf:RDF with no rdf:Description has every property missing" do
      xml = ~s(<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"/>)

      assert %{artist: nil, keywords: [], title: nil, location: %{city: nil}} =
               Xmp.extract_xmp(xml)
    end

    test "simple properties written as elements are read" do
      xml = """
      <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description
          xmlns:xmp="http://ns.adobe.com/xap/1.0/"
          xmlns:photoshop="http://ns.adobe.com/photoshop/1.0/">
          <xmp:CreateDate>2020-01-02T03:04:05</xmp:CreateDate>
          <xmp:Rating> 5 </xmp:Rating>
          <photoshop:City>Hanoi</photoshop:City>
        </rdf:Description>
      </rdf:RDF>
      """

      assert %{created_at: ~N[2020-01-02 03:04:05], rating: 5, location: %{city: "Hanoi"}} =
               Xmp.extract_xmp(xml)
    end

    test "properties split across rdf:Description elements are all read" do
      xml = """
      <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description xmlns:photoshop="http://ns.adobe.com/photoshop/1.0/"
          photoshop:City="Hanoi"/>
        <rdf:Description xmlns:Iptc4xmpCore="http://iptc.org/std/Iptc4xmpCore/1.0/xmlns/"
          Iptc4xmpCore:CountryCode="VN"/>
      </rdf:RDF>
      """

      assert %{location: %{city: "Hanoi", territory_code: "VN"}} = Xmp.extract_xmp(xml)
    end

    test "properties are matched by namespace, not prefix" do
      xml = """
      <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description xmlns:d="http://purl.org/dc/elements/1.1/">
          <d:creator><rdf:Seq><rdf:li>Ann</rdf:li></rdf:Seq></d:creator>
        </rdf:Description>
      </rdf:RDF>
      """

      assert %{artist: "Ann"} = Xmp.extract_xmp(xml)
    end

    test "an alternative without xml:lang is given x-default" do
      xml = """
      <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:title><rdf:Alt><rdf:li>Untagged</rdf:li></rdf:Alt></dc:title>
        </rdf:Description>
      </rdf:RDF>
      """

      assert %{title: %{"x-default" => "Untagged"}} = Xmp.extract_xmp(xml)
    end

    test "non-ASCII text is kept" do
      xml = """
      <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description xmlns:photoshop="http://ns.adobe.com/photoshop/1.0/"
          photoshop:City="Zürich"/>
      </rdf:RDF>
      """

      assert %{location: %{city: "Zürich"}} = Xmp.extract_xmp(xml)
    end
  end

  describe "Image.Xmp.extract_xmp/1 people, contact and locations" do
    test "people in the image, from both IPTC forms, without repeats" do
      xmp =
        packet("""
        <Iptc4xmpExt:PersonInImage><rdf:Bag><rdf:li>Ann</rdf:li><rdf:li>Bob</rdf:li></rdf:Bag></Iptc4xmpExt:PersonInImage>
        <Iptc4xmpExt:PersonInImageWDetails><rdf:Bag><rdf:li rdf:parseType="Resource">
          <Iptc4xmpExt:PersonName><rdf:Alt><rdf:li xml:lang="x-default">Ann</rdf:li></rdf:Alt></Iptc4xmpExt:PersonName>
        </rdf:li></rdf:Bag></Iptc4xmpExt:PersonInImageWDetails>
        """)

      assert Xmp.extract_xmp(xmp).people_in_image == ["Ann", "Bob"]
    end

    test "face region names from MWG and Microsoft regions" do
      xmp =
        packet("""
        <mwg-rs:Regions rdf:parseType="Resource"><mwg-rs:RegionList><rdf:Bag>
          <rdf:li><rdf:Description mwg-rs:Name="Carol" mwg-rs:Type="Face"/></rdf:li>
          <rdf:li rdf:parseType="Resource"><mwg-rs:Name>Dan</mwg-rs:Name></rdf:li>
          <rdf:li rdf:parseType="Resource"><mwg-rs:Type>Focus</mwg-rs:Type></rdf:li>
        </rdf:Bag></mwg-rs:RegionList></mwg-rs:Regions>
        <MP:RegionInfo rdf:parseType="Resource"><MPRI:Regions><rdf:Bag>
          <rdf:li MPReg:PersonDisplayName="Erin"/>
        </rdf:Bag></MPRI:Regions></MP:RegionInfo>
        """)

      assert Xmp.extract_xmp(xmp).region_names == ["Carol", "Dan", "Erin"]
    end

    test "creator contact details as elements" do
      xmp =
        packet("""
        <Iptc4xmpCore:CreatorContactInfo rdf:parseType="Resource">
          <Iptc4xmpCore:CiTelWork>+84 123</Iptc4xmpCore:CiTelWork>
          <Iptc4xmpCore:CiAdrExtadr>1 Main St</Iptc4xmpCore:CiAdrExtadr>
          <Iptc4xmpCore:CiAdrPcode>10000</Iptc4xmpCore:CiAdrPcode>
        </Iptc4xmpCore:CreatorContactInfo>
        """)

      assert %{phone: "+84 123", address: "1 Main St", postal_code: "10000", email: nil} =
               Xmp.extract_xmp(xmp).creator_contact
    end

    test "creator contact details from a real file" do
      {:ok, image} = Image.open(image_path("Kip_small.jpg"))
      assert {:ok, xmp} = Image.xmp(image)

      assert %{email: "kip@noexpectations.com.au", url: "http://www.noexpectations.com.au"} =
               xmp.creator_contact
    end

    test "each location shown and the location created are kept apart from the image's own" do
      xmp =
        packet("""
        <Iptc4xmpExt:LocationShown><rdf:Bag>
          <rdf:li rdf:parseType="Resource">
            <Iptc4xmpExt:LocationName><rdf:Alt><rdf:li xml:lang="x-default">Old Quarter</rdf:li></rdf:Alt></Iptc4xmpExt:LocationName>
            <Iptc4xmpExt:City>Hanoi</Iptc4xmpExt:City>
            <exif:GPSLatitude>21,1.5N</exif:GPSLatitude>
          </rdf:li>
          <rdf:li Iptc4xmpExt:City="Hue" Iptc4xmpExt:CountryCode="VN"/>
        </rdf:Bag></Iptc4xmpExt:LocationShown>
        <Iptc4xmpExt:LocationCreated rdf:parseType="Resource">
          <Iptc4xmpExt:City>Da Nang</Iptc4xmpExt:City>
        </Iptc4xmpExt:LocationCreated>
        """)

      result = Xmp.extract_xmp(xmp)

      assert result.locations_shown == [
               %{city: "Hanoi", gps_latitude: "21,1.5N"},
               %{city: "Hue", country_code: "VN"}
             ]

      assert result.location_created == [%{city: "Da Nang"}]
      assert result.gps_latitude == nil
    end

    test "the document and instance IDs of the editing history, without repeats" do
      xmp =
        packet("""
        <xmpMM:DerivedFrom xmlns:xmpMM="http://ns.adobe.com/xap/1.0/mm/"
          xmlns:stRef="http://ns.adobe.com/xap/1.0/sType/ResourceRef#"
          stRef:instanceID="xmp.iid:one" stRef:documentID="xmp.did:two"/>
        <xmpMM:History xmlns:xmpMM="http://ns.adobe.com/xap/1.0/mm/"
          xmlns:stEvt="http://ns.adobe.com/xap/1.0/sType/ResourceEvent#"><rdf:Seq>
          <rdf:li rdf:parseType="Resource"><stEvt:instanceID>xmp.iid:three</stEvt:instanceID></rdf:li>
          <rdf:li stEvt:instanceID="xmp.iid:one"/>
        </rdf:Seq></xmpMM:History>
        """)

      assert Xmp.extract_xmp(xmp).document_history == [
               "xmp.iid:one",
               "xmp.did:two",
               "xmp.iid:three"
             ]
    end

    test "the editing history from a real file" do
      {:ok, image} = Image.open(image_path("Sydney-Opera-House-BW.jpg"))
      assert {:ok, xmp} = Image.xmp(image)
      assert length(xmp.document_history) == 7
    end

    test "a packet without them has empty lists and an empty contact" do
      result = Xmp.extract_xmp(packet(""))

      assert result.people_in_image == []
      assert result.region_names == []
      assert result.locations_shown == []
      assert result.location_created == []
      assert result.document_history == []
      assert Enum.all?(result.creator_contact, fn {_key, value} -> is_nil(value) end)
    end
  end

  defp packet(body) do
    "<rdf:RDF #{@namespaces}><rdf:Description>" <> body <> "</rdf:Description></rdf:RDF>"
  end
end

defmodule Image.XmpAtomTest do
  # Not async, so no other test creates atoms while the count is taken.
  use ExUnit.Case, async: false

  test "parsing XMP creates no atoms for element or attribute names" do
    Image.Xmp.extract_xmp(~s(<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"/>))

    names =
      for _n <- 1..1000, into: "" do
        "<e#{System.unique_integer([:positive])} a#{System.unique_integer([:positive])}=\"v\"/>"
      end

    xml =
      ~s(<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">) <> names <> "</rdf:RDF>"

    before = :erlang.system_info(:atom_count)
    assert %{artist: nil} = Image.Xmp.extract_xmp(xml)
    assert :erlang.system_info(:atom_count) - before < 50
  end
end
