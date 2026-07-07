defmodule Image.Vips.Operation do
  @moduledoc false

  # A thin proxy over `Vix.Vips.Operation` that normalizes errors at the
  # libvips boundary so that every fallible `Image` function returns
  # `{:error, %Image.Error{}}` as `t:Image.error/0` promises, rather than
  # leaking raw libvips message strings.
  #
  # Every public function of `Vix.Vips.Operation` is mirrored here:
  #
  # * Non-bang functions have `{:error, reason}` results wrapped with
  #   `Image.Error.wrap/2`, tagged with the operation name.
  #
  # * Bang functions re-raise the Vix exceptions as `Image.Error` so the
  #   raising contract of `Image.*!` functions is a single exception type.
  #
  # This module is the designated `try/rescue` boundary for the Vix NIF
  # wrapper library.

  for {name, arity} <- Vix.Vips.Operation.__info__(:functions) do
    args = Macro.generate_arguments(arity, __MODULE__)

    if name |> Atom.to_string() |> String.ends_with?("!") do
      base_name = name |> Atom.to_string() |> String.trim_trailing("!") |> String.to_atom()

      def unquote(name)(unquote_splicing(args)) do
        Vix.Vips.Operation.unquote(name)(unquote_splicing(args))
      rescue
        error in [Vix.Vips.Operation.Error, Vix.Vips.Image.Error] ->
          reraise Image.Error.wrap(error.message, operation: unquote(base_name)),
                  __STACKTRACE__
      end
    else
      def unquote(name)(unquote_splicing(args)) do
        case Vix.Vips.Operation.unquote(name)(unquote_splicing(args)) do
          {:error, reason} -> {:error, Image.Error.wrap(reason, operation: unquote(name))}
          other -> other
        end
      end
    end
  end
end
