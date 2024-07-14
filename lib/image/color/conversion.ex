defmodule Image.Color.Conversion do
  @colorspaces Image.Interpretation.known_interpretations() |> Enum.map(&to_string/1)

  functions =
    Vix.Vips.Operation.module_info(:functions)
    |> Keyword.keys()
    |> Enum.map(&to_string/1)

  graph =
    :digraph.new()

  edges =
    for fun <- functions, reduce: [] do
      acc ->
        case String.split(fun, "2") do
          [from, to] ->
            if from in @colorspaces and to in @colorspaces do
              IO.inspect {from, to}, label: "Adding edge"
              :digraph.add_vertex(graph, from)
              :digraph.add_vertex(graph, to)
              :digraph.add_edge(graph, from, to)
              [{from, to} | acc]
            else
              acc
            end

          _other ->
            acc
        end
    end
    |> Enum.uniq()

  vertices =
    :digraph.vertices(graph)

  for v1 <- vertices, v2 <- vertices do
    case :digraph.get_path(graph, v1, v2) do
      path when is_list(path) ->
        from = String.to_atom(v1)
        to = String.to_atom(v2)
        conversions = Image.Color.Conversion

        def convert(_image, unquote(from), unquote(to), _options) do

        end

      false ->
        []
    end
    end
end