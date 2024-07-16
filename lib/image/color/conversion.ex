defmodule Image.Color.Conversion do
  def colorspaces do
    Image.Interpretation.known_interpretations()
    |> Enum.map(&to_string/1)
  end

  def vips_conversion_functions do
    Vix.Vips.Operation.module_info(:functions)
    |> Keyword.keys()
    |> Enum.map(&to_string/1)
  end

  def conversion_graph() do
    graph =
      :digraph.new()

    for fun <- vips_conversion_functions(), reduce: [] do
      acc ->
        case String.split(fun, "2") do
          [from, to] ->
            if from in colorspaces() and to in colorspaces() do
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

    graph
  end

  def conversion_paths() do
    graph = conversion_graph()
    vertices = :digraph.vertices(graph)

    for v1 <- vertices, v2 <- vertices, v1 != v2 do
      case :digraph.get_path(graph, v1, v2) do
        path when is_list(path) ->
          {v1, v2, path}

        false ->
          raise "No path found from #{v1} to #{v2}"
      end
    end
  end

  def fun_name(a, b) do
    String.to_atom("Vix.Vips.Operation.#{a}2#{b}!")
  end

  def pipeline_from_path([a, b]) do
    fun_name = fun_name(a, b)

    quote do
      unquote(fun_name)()
    end
  end

  def pipeline_from_path([a, b | rest]) do
    fun_name = fun_name(a, b)

    quoted =
      quote do
        unquote(fun_name)()
      end

    rest =
      pipeline_from_path([b | rest])

    quote do
      unquote(quoted) |> unquote(rest)
    end
  end

  def define_conversion(from, to, path) do
    pipeline =
      pipeline_from_path(path)

    conversion =
      quote do
        image |> unquote(pipeline)
      end

    quote do
      def conversion(image, unquote(from), unquote(to)) do
        unquote(conversion)
      end
    end
    |> Macro.to_string()
    |> Code.format_string!()
    |> IO.puts
  end

end