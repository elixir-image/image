if Code.ensure_loaded?(Kino.SmartCell) do
  defmodule Image.SmartCell.Transform do
    @moduledoc false

    # A Livebook smart cell that composes an `Image` pipeline from a form
    # and writes the equivalent source into the notebook.
    #
    # The client is handed the operation catalogue from
    # `Image.SmartCell.Operations` and renders whatever it is given, so
    # adding an operation needs no change to the JavaScript.
    #
    # Attributes are persisted into the notebook's markdown, so everything
    # in `to_attrs/1` has to survive a round trip through JSON. That is why
    # operation names and select values are held as strings here and cast
    # to atoms only when a call is generated.

    use Kino.JS, assets_path: "lib/assets"
    use Kino.JS.Live
    use Kino.SmartCell, name: "Image: transform"

    alias Image.SmartCell.Operations

    @default_fields %{
      "source_type" => "path",
      "source_path" => "",
      "source_variable" => "",
      "to_variable" => "transformed",
      "operations" => []
    }

    @impl true
    def init(attrs, ctx) do
      fields = Map.merge(@default_fields, Map.take(attrs, Map.keys(@default_fields)))

      ctx =
        assign(ctx,
          fields: fields,
          variables: [],
          catalogue: client_catalogue()
        )

      {:ok, ctx}
    end

    @impl true
    def handle_connect(ctx) do
      payload = %{
        "fields" => ctx.assigns.fields,
        "variables" => ctx.assigns.variables,
        "catalogue" => ctx.assigns.catalogue
      }

      {:ok, payload, ctx}
    end

    # Offers any variable already bound to an image as a source.
    @impl true
    def scan_binding(pid, binding, _env) do
      variables =
        for {key, value} <- binding,
            is_atom(key),
            is_struct(value, Vix.Vips.Image),
            do: Atom.to_string(key)

      send(pid, {:variables, Enum.sort(variables)})
    end

    @impl true
    def handle_info({:variables, variables}, ctx) do
      ctx = assign(ctx, variables: variables)
      broadcast_event(ctx, "variables", %{"variables" => variables})
      {:noreply, ctx}
    end

    @impl true
    def handle_event("update_field", %{"field" => field, "value" => value}, ctx) do
      ctx = update(ctx, :fields, &Map.put(&1, field, value))
      broadcast_event(ctx, "update", %{"fields" => %{field => value}})
      {:noreply, ctx}
    end

    def handle_event("update_param", params, ctx) do
      %{"index" => index, "key" => key, "value" => value} = params

      ctx =
        update(ctx, :fields, fn fields ->
          update_in(fields, ["operations", Access.at(index), "params", key], fn _ -> value end)
        end)

      broadcast_event(ctx, "operations", %{"operations" => ctx.assigns.fields["operations"]})
      {:noreply, ctx}
    end

    def handle_event("add_operation", %{"name" => name}, ctx) do
      operation = %{"name" => name, "params" => default_params(name)}

      ctx = update(ctx, :fields, &Map.update!(&1, "operations", fn ops -> ops ++ [operation] end))
      broadcast_event(ctx, "operations", %{"operations" => ctx.assigns.fields["operations"]})
      {:noreply, ctx}
    end

    def handle_event("remove_operation", %{"index" => index}, ctx) do
      ctx =
        update(
          ctx,
          :fields,
          &Map.update!(&1, "operations", fn ops -> List.delete_at(ops, index) end)
        )

      broadcast_event(ctx, "operations", %{"operations" => ctx.assigns.fields["operations"]})
      {:noreply, ctx}
    end

    def handle_event("move_operation", %{"index" => index, "to" => to}, ctx) do
      ctx =
        update(ctx, :fields, fn fields ->
          Map.update!(fields, "operations", fn ops ->
            if to >= 0 and to < length(ops) do
              operation = Enum.at(ops, index)
              ops |> List.delete_at(index) |> List.insert_at(to, operation)
            else
              ops
            end
          end)
        end)

      broadcast_event(ctx, "operations", %{"operations" => ctx.assigns.fields["operations"]})
      {:noreply, ctx}
    end

    @impl true
    def to_attrs(%{assigns: %{fields: fields}}), do: fields

    @impl true
    def to_source(attrs) do
      attrs
      |> quoted_source()
      |> Kino.SmartCell.quoted_to_string()
    end

    @doc false
    def quoted_source(attrs) do
      variable = variable_name(attrs["to_variable"], :transformed)

      pipeline =
        attrs
        |> operation_calls()
        |> Enum.reduce(source_expression(attrs), fn call, accumulator ->
          {:|>, [], [accumulator, call]}
        end)

      quote do
        unquote(Macro.var(variable, nil)) = unquote(pipeline)
        Image.Kino.show(unquote(Macro.var(variable, nil)))
      end
    end

    defp source_expression(%{"source_type" => "variable"} = attrs) do
      Macro.var(variable_name(attrs["source_variable"], :image), nil)
    end

    defp source_expression(attrs) do
      quote do: Image.open!(unquote(attrs["source_path"] || ""))
    end

    defp operation_calls(attrs) do
      for operation <- attrs["operations"] || [],
          name = existing_operation(operation["name"]),
          {:ok, call} = Operations.quoted_call(name, operation["params"] || %{}),
          do: call
    end

    # An operation name read back from a notebook may be anything, so it is
    # resolved against the catalogue rather than converted blindly.
    defp existing_operation(name) when is_binary(name) do
      Enum.find(Operations.names(), &(Atom.to_string(&1) == name))
    end

    defp existing_operation(_name), do: nil

    # A variable name comes from a text field, so it is validated rather
    # than converted straight to an atom.
    defp variable_name(name, fallback) when is_binary(name) do
      if Regex.match?(~r/^[a-z_][a-zA-Z0-9_]*$/, name) do
        String.to_atom(name)
      else
        fallback
      end
    end

    defp variable_name(_name, fallback), do: fallback

    defp default_params(name) do
      case existing_operation(name) do
        nil ->
          %{}

        operation ->
          Map.new(Operations.defaults(operation), fn {k, v} -> {to_string(k), to_string(v)} end)
      end
    end

    # The catalogue as the client needs it: strings throughout, so it
    # survives the JSON boundary.
    defp client_catalogue do
      for operation <- Operations.all() do
        %{
          "name" => to_string(operation.name),
          "label" => operation.label,
          "doc" => operation.doc,
          "params" =>
            for param <- operation.params do
              param
              |> Map.take([:key, :label, :type, :default, :min, :max, :step])
              |> Map.new(fn
                {:key, value} -> {"key", to_string(value)}
                {:type, value} -> {"type", to_string(value)}
                {:default, value} -> {"default", to_string(value)}
                {key, value} -> {to_string(key), value}
              end)
              |> put_options(param)
            end
        }
      end
    end

    defp put_options(rendered, %{type: :select, options: options}) do
      Map.put(rendered, "options", Enum.map(options, &to_string/1))
    end

    defp put_options(rendered, _param), do: rendered
  end
else
  defmodule Image.SmartCell.Transform do
    @moduledoc false
  end
end
