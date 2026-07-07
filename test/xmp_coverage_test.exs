defmodule Image.XmpCoverageTest do
  use ExUnit.Case, async: true

  import Image.TestSupport

  alias Image.Xmp

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
end
