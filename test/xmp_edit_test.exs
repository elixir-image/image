defmodule Image.Xmp.EditTest do
  use ExUnit.Case, async: true

  alias Image.Xmp.Edit

  @rdf ~s(xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#")
  @dc_uri "http://purl.org/dc/elements/1.1/"

  describe "properties/1" do
    test "gives the exact span of elements and attributes" do
      xmp = ~s(<a xmlns:dc="#{@dc_uri}" dc:format="image/jpeg"><dc:title>T</dc:title><dc:x/></a>)
      {:ok, properties} = Edit.properties(xmp)

      assert text(xmp, properties, {@dc_uri, "format"}) == ~s( dc:format="image/jpeg")
      assert text(xmp, properties, {@dc_uri, "title"}) == "<dc:title>T</dc:title>"
      assert text(xmp, properties, {@dc_uri, "x"}) == "<dc:x/>"
    end

    test "resolves prefixes in scope, including a redeclared one and the default namespace" do
      xmp =
        ~s(<a xmlns="urn:default" xmlns:p="urn:one"><p:x><b xmlns:p="urn:two"><p:y/></b></p:x></a>)

      {:ok, properties} = Edit.properties(xmp)
      names = Enum.map(properties, & &1.name)

      assert {"urn:one", "x"} in names
      assert {"urn:two", "y"} in names
      assert {"urn:default", "b"} in names
    end

    test "records the elements a property is inside, innermost first" do
      {:ok, properties} = Edit.properties(~s(<a xmlns="urn:n"><b><c/></b></a>))

      assert %{ancestors: [{"urn:n", "b"}, {"urn:n", "a"}]} =
               Enum.find(properties, &(&1.name == {"urn:n", "c"}))
    end

    test "skips comments, CDATA and processing instructions" do
      xmp =
        ~s(<?xpacket begin=""?><a xmlns="urn:n"><!-- <b/> --><![CDATA[<c/>]]><d/></a><?xpacket end="w"?>)

      {:ok, properties} = Edit.properties(xmp)

      assert Enum.map(properties, & &1.name) == [{"urn:n", "d"}, {"urn:n", "a"}]
    end

    test "reads attribute values in either quote that contain a >" do
      xmp = ~s(<a xmlns:p="urn:p" p:x='1>2' p:y="3"/>)
      {:ok, properties} = Edit.properties(xmp)

      assert text(xmp, properties, {"urn:p", "x"}) == " p:x='1>2'"
      assert text(xmp, properties, {"urn:p", "y"}) == ~s( p:y="3")
    end

    test "malformed input and a DTD are errors" do
      assert :error = Edit.properties("<a b=1/>")
      assert :error = Edit.properties("<a></b></a></c>")
      assert :error = Edit.properties(~s(<!DOCTYPE a><a/>))
    end
  end

  describe "cut/2" do
    test "removes spans and keeps every other byte" do
      assert Edit.cut("0123456789", [{2, 2}, {6, 1}]) == "0145789"
    end

    test "a span inside another is covered by it" do
      assert Edit.cut("0123456789", [{1, 6}, {2, 2}, {8, 1}]) == "079"
    end
  end

  describe "Image.Xmp.remove_properties/2" do
    test "removes exactly the property and keeps the rest of the packet" do
      xmp =
        ~s(<rdf:RDF #{@rdf}><rdf:Description xmlns:dc="#{@dc_uri}"><dc:creator><rdf:Seq><rdf:li>Ann</rdf:li></rdf:Seq></dc:creator><dc:rights><rdf:Alt><rdf:li xml:lang="x-default">C</rdf:li></rdf:Alt></dc:rights></rdf:Description></rdf:RDF>)

      assert {:ok, edited} = Image.Xmp.remove_properties(xmp, [:artist])

      assert edited ==
               String.replace(
                 xmp,
                 "<dc:creator><rdf:Seq><rdf:li>Ann</rdf:li></rdf:Seq></dc:creator>",
                 ""
               )
    end

    test "a field it does not know leaves the packet unchanged" do
      xmp = ~s(<rdf:RDF #{@rdf}/>)

      assert {:ok, ^xmp} = Image.Xmp.remove_properties(xmp, [:not_a_field])
    end

    test "an invalid packet is an error" do
      assert {:error, :invalid_xmp} = Image.Xmp.remove_properties("<not xml", [:artist])
    end
  end

  defp text(xmp, properties, name) do
    %{span: {start, length}} = Enum.find(properties, &(&1.name == name))
    binary_part(xmp, start, length)
  end
end
