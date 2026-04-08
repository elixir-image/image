defmodule Image.Error do
  @moduledoc """
  The structured exception raised by `Image.*!/_arity` functions and
  returned in the error half of every `{:ok, _} | {:error, _}` tuple
  in the library.

  Every fallible function in `Image` returns either `{:ok, value}` or
  `{:error, %Image.Error{}}`. Bang variants raise the same struct.

  ## Fields

  * `:message` — a human-readable description. Always present.

  * `:reason` — a structured discriminator: an atom (`:enoent`,
    `:invalid_option`, `:unsupported_format`, …), a `{:atom, value}`
    tuple for parameterised errors, or a binary for free-form
    libvips errors that don't yet have a structured form.

  * `:operation` — the high-level `Image` function that failed
    (e.g. `:open`, `:write`, `:resize`, `:draw_rect`), or `nil` if
    not known.

  * `:path` — the file system path involved, when applicable.

  * `:value` — the offending input value, when applicable.

  ## Example

      iex> {:error, %Image.Error{reason: :enoent}} = Image.open("/no/such/file.jpg")
      iex> :ok
      :ok

  ## Pattern matching

  Callers should match on `:reason` rather than scraping `:message`:

      case Image.open(path) do
        {:ok, image} -> ...
        {:error, %Image.Error{reason: :enoent}} -> not_found_handler()
        {:error, %Image.Error{reason: {:invalid_option, opt}}} -> ...
        {:error, %Image.Error{} = err} -> raise err
      end

  ## Constructing

  Use the standard `defexception` callback (`exception/1`) via
  `raise` or by passing structured input:

      raise Image.Error, reason: :enoent, path: "/tmp/foo.jpg"

      raise Image.Error, "free form message"

      raise Image.Error, {:enoent, "/tmp/foo.jpg"}

  Or convert a raw `{:error, raw}` tuple coming from libvips with
  `Image.Error.wrap/2`:

      with {:error, raw} <- Vix.Vips.Operation.thumbnail(path, 256) do
        {:error, Image.Error.wrap(raw, operation: :thumbnail)}
      end

  """

  @typedoc """
  A structured `Image.Error`. The `:reason` field is the canonical
  discriminator; `:message` is always derivable from `:reason` plus
  `:operation`/`:path`/`:value`.
  """
  @type t :: %__MODULE__{
          message: String.t(),
          reason: atom() | {atom(), any()} | String.t() | nil,
          operation: atom() | nil,
          path: Path.t() | nil,
          value: any() | nil
        }

  defexception message: "Unknown image error",
               reason: nil,
               operation: nil,
               path: nil,
               value: nil

  @impl true

  # ---- raise Image.Error, reason: ..., path: ..., ... ---------------------

  def exception(opts) when is_list(opts) do
    fields = Keyword.take(opts, [:message, :reason, :operation, :path, :value])
    struct = struct!(__MODULE__, fields)
    %{struct | message: struct.message || format_message(struct)}
  end

  # ---- raise Image.Error, {:enoent, path} ---------------------------------

  def exception({:enoent, path}) do
    %__MODULE__{
      reason: :enoent,
      path: to_path(path),
      message: "The image file #{inspect(path)} was not found or could not be opened"
    }
  end

  def exception({message, path}) when is_binary(message) and is_binary(path) do
    %__MODULE__{
      reason: message,
      path: path,
      message: "#{message}: #{path}"
    }
  end

  # ---- raise Image.Error, "free form" -------------------------------------

  def exception(message) when is_binary(message) do
    %__MODULE__{message: message, reason: message}
  end

  # ---- raise Image.Error, %Image.Error{} ----------------------------------

  def exception(%__MODULE__{} = error) do
    error
  end

  # ---- raise Image.Error, atom --------------------------------------------

  def exception(reason) when is_atom(reason) and not is_nil(reason) do
    %__MODULE__{reason: reason, message: Atom.to_string(reason)}
  end

  # ---- safe fallback for unknown shapes -----------------------------------
  #
  # The previous implementation returned `other` unchanged from
  # exception/1, which made `raise Image.Error, %{}` evaluate to
  # `raise %{}` and crash with BadStructError. Wrap unknown shapes in a
  # real struct so the raise always succeeds.

  def exception(other) do
    %__MODULE__{
      reason: other,
      message: "Image error: #{inspect(other)}"
    }
  end

  @doc """
  Wraps a raw `{:error, _}` payload from libvips, the colour library,
  or another underlying source as an `%Image.Error{}`.

  Used at the boundary between Vix and `Image` to attach
  high-level context (`:operation`, `:path`, `:value`) before the
  error propagates to the caller.

  ### Arguments

  * `raw` is the inner value of the error tuple — typically a
    string from libvips, an atom from `File.*`, or another struct
    that already implements `Exception.message/1`.

  * `context` is a keyword list of context fields to attach. The
    accepted keys are `:operation`, `:path`, `:value`, and
    `:reason` (to override the auto-derived reason).

  ### Examples

      iex> Image.Error.wrap("operation build: bad seek", operation: :open, path: "/tmp/x.jpg")
      %Image.Error{
        reason: "operation build: bad seek",
        operation: :open,
        path: "/tmp/x.jpg",
        message: "open /tmp/x.jpg: operation build: bad seek",
        value: nil
      }

      iex> Image.Error.wrap(:enoent, path: "/tmp/x.jpg")
      %Image.Error{
        reason: :enoent,
        path: "/tmp/x.jpg",
        operation: nil,
        message: "The image file \\"/tmp/x.jpg\\" was not found or could not be opened",
        value: nil
      }

  """
  @spec wrap(term(), keyword()) :: t()
  def wrap(raw, context \\ [])

  def wrap(%__MODULE__{} = error, context) do
    Enum.reduce(context, error, fn
      {_key, nil}, acc -> acc
      {key, value}, acc when key in [:operation, :path, :value] -> Map.put(acc, key, value)
      _, acc -> acc
    end)
  end

  def wrap(:enoent, context) do
    path = Keyword.get(context, :path)

    %__MODULE__{
      reason: :enoent,
      path: path,
      operation: Keyword.get(context, :operation),
      value: Keyword.get(context, :value),
      message: "The image file #{inspect(path)} was not found or could not be opened"
    }
  end

  def wrap(raw, context) when is_binary(raw) do
    operation = Keyword.get(context, :operation)
    path = Keyword.get(context, :path)
    value = Keyword.get(context, :value)

    %__MODULE__{
      reason: raw,
      operation: operation,
      path: path,
      value: value,
      message: format_libvips(operation, path, raw)
    }
  end

  def wrap(raw, context) when is_atom(raw) do
    operation = Keyword.get(context, :operation)
    path = Keyword.get(context, :path)
    value = Keyword.get(context, :value)

    %__MODULE__{
      reason: raw,
      operation: operation,
      path: path,
      value: value,
      message: Atom.to_string(raw)
    }
  end

  def wrap({reason_atom, _} = raw, context) when is_atom(reason_atom) do
    %__MODULE__{
      reason: raw,
      operation: Keyword.get(context, :operation),
      path: Keyword.get(context, :path),
      value: Keyword.get(context, :value),
      message: inspect(raw)
    }
  end

  def wrap(other, context) do
    %__MODULE__{
      reason: other,
      operation: Keyword.get(context, :operation),
      path: Keyword.get(context, :path),
      value: Keyword.get(context, :value),
      message: "Image error: #{inspect(other)}"
    }
  end

  ## Internals --------------------------------------------------------------

  defp to_path(path) when is_binary(path), do: path
  defp to_path(_), do: nil

  defp format_message(%__MODULE__{} = error) do
    cond do
      is_binary(error.reason) -> format_libvips(error.operation, error.path, error.reason)
      error.reason == :enoent and error.path -> "File not found: #{error.path}"
      is_atom(error.reason) and not is_nil(error.reason) -> Atom.to_string(error.reason)
      true -> "Image error: #{inspect(error.reason)}"
    end
  end

  defp format_libvips(nil, nil, reason), do: reason
  defp format_libvips(nil, path, reason), do: "#{path}: #{reason}"
  defp format_libvips(op, nil, reason), do: "#{op}: #{reason}"
  defp format_libvips(op, path, reason), do: "#{op} #{path}: #{reason}"
end
