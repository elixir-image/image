defmodule Image.Vips.MutableOperation do
  @moduledoc false

  # A thin proxy over `Vix.Vips.MutableOperation` that normalizes errors
  # at the libvips boundary, mirroring `Image.Vips.Operation`. See that
  # module for the rationale.

  for {name, arity} <- Vix.Vips.MutableOperation.__info__(:functions) do
    args = Macro.generate_arguments(arity, __MODULE__)

    if name |> Atom.to_string() |> String.ends_with?("!") do
      base_name = name |> Atom.to_string() |> String.trim_trailing("!") |> String.to_atom()

      def unquote(name)(unquote_splicing(args)) do
        Vix.Vips.MutableOperation.unquote(name)(unquote_splicing(args))
      rescue
        error in [Vix.Vips.Operation.Error, Vix.Vips.Image.Error] ->
          reraise Image.Error.wrap(error.message, operation: unquote(base_name)),
                  __STACKTRACE__
      end
    else
      def unquote(name)(unquote_splicing(args)) do
        case Vix.Vips.MutableOperation.unquote(name)(unquote_splicing(args)) do
          {:error, reason} -> {:error, Image.Error.wrap(reason, operation: unquote(name))}
          other -> other
        end
      end
    end
  end
end
