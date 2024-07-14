defmodule Image.Color.Conversion do
  @colorspaces Image.Interpretation.known_interpretations() |> Enum.map(&to_string/1)

  functions =
    Vix.Vips.Operation.module_info(:functions)
    |> Keyword.keys()
    |> Enum.map(&to_string/1)

  graph =
    :digraph.new([:acyclic])

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

    vertices = :digraph.vertices(graph) |> IO.inspect(label: "Vertices")

    for v1 <- vertices, v2 <- vertices do
      case :digraph.get_path(graph, v1, v2) do
        path when is_list(path) -> "From #{inspect v1} to #{inspect v2} -> #{inspect path}}"; {v1, v2, path}
        false -> IO.puts "No path from #{inspect v1} to #{inspect v2}"
      end
    end

end