defmodule Image.Xmp.Edit do
  @moduledoc false

  # Finds the byte span of every element and attribute in an XMP packet,
  # so properties can be removed in place and everything else is kept
  # byte for byte. The packet must already have been checked to be
  # well-formed by `Image.Xmp.extract_xmp/1`, so this only needs to find
  # tags, attribute values, comments, CDATA sections and processing
  # instructions. It creates no atoms.

  @xmlns "xmlns"

  @typedoc """
  A property: its `{namespace URI, local name}`, whether it is an
  element or an attribute, its byte span, and the names of the elements
  it is inside, innermost first.
  """
  @type property :: %{
          name: {String.t(), String.t()},
          kind: :element | :attribute,
          span: {non_neg_integer(), non_neg_integer()},
          ancestors: [{String.t(), String.t()}]
        }

  @doc false
  @spec properties(binary()) :: {:ok, [property()]} | :error
  def properties(xmp) do
    scan(xmp, 0, [], [])
  end

  @doc false
  # Removes the given byte spans. A span inside another is covered by it.
  @spec cut(binary(), [{non_neg_integer(), non_neg_integer()}]) :: binary()
  def cut(xmp, spans) do
    {kept, position} =
      spans
      |> Enum.sort()
      |> Enum.reduce({[], 0}, fn {start, length}, {kept, position} ->
        keep_until(xmp, kept, position, start, length)
      end)

    IO.iodata_to_binary([Enum.reverse(kept), binary_part(xmp, position, byte_size(xmp) - position)])
  end

  defp keep_until(_xmp, kept, position, start, length) when start < position do
    {kept, max(position, start + length)}
  end

  defp keep_until(xmp, kept, position, start, length) do
    {[binary_part(xmp, position, start - position) | kept], start + length}
  end

  # The stack holds a frame for each open element: its qualified name,
  # start offset, resolved name and namespace scope.
  defp scan(xmp, position, stack, acc) do
    case :binary.match(xmp, "<", scope: {position, byte_size(xmp) - position}) do
      {start, 1} -> markup(xmp, start, stack, acc)
      :nomatch -> {:ok, Enum.reverse(acc)}
    end
  end

  defp markup(xmp, start, stack, acc) do
    case binary_part(xmp, start, min(9, byte_size(xmp) - start)) do
      <<"<?", _rest::binary>> -> skip_to(xmp, start, "?>", stack, acc)
      <<"<!--", _rest::binary>> -> skip_to(xmp, start, "-->", stack, acc)
      <<"<![CDATA[", _rest::binary>> -> skip_to(xmp, start, "]]>", stack, acc)
      <<"</", _rest::binary>> -> end_tag(xmp, start, stack, acc)
      <<"<!", _rest::binary>> -> :error
      _start_tag -> start_tag(xmp, start, stack, acc)
    end
  end

  defp skip_to(xmp, start, terminator, stack, acc) do
    case :binary.match(xmp, terminator, scope: {start, byte_size(xmp) - start}) do
      {found, length} -> scan(xmp, found + length, stack, acc)
      :nomatch -> :error
    end
  end

  defp end_tag(xmp, start, [{_qname, element_start, name, _namespaces} | stack], acc) do
    case :binary.match(xmp, ">", scope: {start, byte_size(xmp) - start}) do
      {close, 1} ->
        property = element(name, element_start, close + 1, stack)
        scan(xmp, close + 1, stack, [property | acc])

      :nomatch ->
        :error
    end
  end

  defp end_tag(_xmp, _start, [], _acc) do
    :error
  end

  defp start_tag(xmp, start, stack, acc) do
    {qname, position} = read_name(xmp, start + 1)

    with {:ok, attributes, close, self_closing?} <- read_attributes(xmp, position, []) do
      namespaces = declare(attributes, parent_namespaces(stack))
      name = resolve(qname, namespaces, true)
      ancestors = [name | Enum.map(stack, &elem(&1, 2))]
      acc = attribute_properties(attributes, namespaces, ancestors) ++ acc
      open(xmp, {qname, start, name, namespaces}, close, self_closing?, stack, acc)
    end
  end

  defp open(xmp, {_qname, start, name, _namespaces}, close, true, stack, acc) do
    scan(xmp, close, stack, [element(name, start, close, stack) | acc])
  end

  defp open(xmp, frame, close, false, stack, acc) do
    scan(xmp, close, [frame | stack], acc)
  end

  defp element(name, start, finish, stack) do
    %{
      name: name,
      kind: :element,
      span: {start, finish - start},
      ancestors: Enum.map(stack, &elem(&1, 2))
    }
  end

  defp attribute_properties(attributes, namespaces, ancestors) do
    for {qname, span, _value} <- attributes, not namespace_declaration?(qname) do
      %{name: resolve(qname, namespaces, false), kind: :attribute, span: span, ancestors: ancestors}
    end
  end

  # Reads attributes up to the end of the start tag. Each is returned with
  # the span from the white space before its name to its closing quote.
  defp read_attributes(xmp, position, acc) do
    after_space = skip_space(xmp, position)

    case binary_part(xmp, after_space, min(2, byte_size(xmp) - after_space)) do
      "/>" -> {:ok, Enum.reverse(acc), after_space + 2, true}
      <<">", _rest::binary>> -> {:ok, Enum.reverse(acc), after_space + 1, false}
      <<>> -> :error
      _attribute -> read_attribute(xmp, position, after_space, acc)
    end
  end

  defp read_attribute(xmp, space_start, name_start, acc) do
    {qname, position} = read_name(xmp, name_start)
    position = skip_space(xmp, position)

    if binary_part(xmp, position, min(1, byte_size(xmp) - position)) == "=" do
      attribute_value(xmp, qname, space_start, skip_space(xmp, position + 1), acc)
    else
      :error
    end
  end

  defp attribute_value(xmp, qname, space_start, value_start, acc) do
    case read_value(xmp, value_start) do
      {:ok, value, value_end} ->
        attribute = {qname, {space_start, value_end - space_start}, value}
        read_attributes(xmp, value_end, [attribute | acc])

      :error ->
        :error
    end
  end

  defp read_value(xmp, start) when start < byte_size(xmp) do
    quote = binary_part(xmp, start, 1)

    case :binary.match(xmp, quote, scope: {start + 1, byte_size(xmp) - start - 1}) do
      {close, 1} when quote in ["\"", "'"] ->
        {:ok, binary_part(xmp, start + 1, close - start - 1), close + 1}

      _other ->
        :error
    end
  end

  defp read_value(_xmp, _start) do
    :error
  end

  defp read_name(xmp, start) do
    finish = name_end(xmp, start)
    {binary_part(xmp, start, finish - start), finish}
  end

  defp name_end(xmp, position) when position < byte_size(xmp) do
    if :binary.at(xmp, position) in ~c" \t\r\n=/>" do
      position
    else
      name_end(xmp, position + 1)
    end
  end

  defp name_end(_xmp, position) do
    position
  end

  defp skip_space(xmp, position) when position < byte_size(xmp) do
    if :binary.at(xmp, position) in ~c" \t\r\n" do
      skip_space(xmp, position + 1)
    else
      position
    end
  end

  defp skip_space(_xmp, position) do
    position
  end

  defp parent_namespaces([{_qname, _start, _name, namespaces} | _stack]) do
    namespaces
  end

  defp parent_namespaces([]) do
    %{}
  end

  defp declare(attributes, namespaces) do
    Enum.reduce(attributes, namespaces, fn
      {@xmlns, _span, uri}, namespaces -> Map.put(namespaces, "", uri)
      {@xmlns <> ":" <> prefix, _span, uri}, namespaces -> Map.put(namespaces, prefix, uri)
      _attribute, namespaces -> namespaces
    end)
  end

  defp namespace_declaration?(qname) do
    qname == @xmlns or String.starts_with?(qname, @xmlns <> ":")
  end

  # An unprefixed element takes the default namespace; an unprefixed
  # attribute has none.
  defp resolve(qname, namespaces, element?) do
    case String.split(qname, ":", parts: 2) do
      [prefix, local] -> {Map.get(namespaces, prefix, ""), local}
      [local] when element? -> {Map.get(namespaces, "", ""), local}
      [local] -> {"", local}
    end
  end
end
