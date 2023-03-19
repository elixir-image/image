defmodule Image.ExtendMode do
  @moduledoc """
  Defines the known modes by which an image
  can be extended.

  """

  @extend_map %{
    black: :VIPS_EXTEND_BLACK,
    copy: :VIPS_EXTEND_COPY,
    repeat: :VIPS_EXTEND_REPEAT,
    mirror: :VIPS_EXTEND_MIRROR,
    white: :VIPS_EXTEND_WHITE,
    background: :VIPS_EXTEND_BACKGROUND
  }

  @extend Map.keys(@extend_map)
  @vips_extend Map.values(@extend_map)

  @reverse_extend Enum.map(@extend_map, fn {k, v} -> {v, k} end)
                  |> Map.new()

  @typedoc """
  Defines the known extend strategies.

  """
  @type t :: unquote(Enum.reduce(@extend, &{:|, [], [&1, &2]}))

  @doc """
  Returns the known extend modes.

  """
  def known_extend_modes do
    @extend
  end

  @doc """
  Normalizes and validates an extend mode.

  ### Arguments

  * `extend` is any atom or string value
    in `Image.ExtendMode.known_extend_modes/0`.

  ### Returns

  * `{:error, normalized_extend_mode}` or

  * `{:error, reason}`.

  ### Examples

      iex> Image.Kernel.validate_extend(:black)
      {:ok, :VIPS_EXTEND_BLACK}

      iex> Image.Kernel.validate_extend(:VIPS_EXTEND_REPEAT)
      {:ok, :VIPS_EXTEND_REPEAT}

      iex> Image.Kernel.validate_extend(:unknown)
      {:error, "Unknown extend mode. Found :unknown"}

  """
  def validate_extend(extend) when extend in @vips_extend do
    {:ok, extend}
  end

  def validate_extend(extend) when is_atom(extend) do
    case Map.fetch(@extend_map, extend) do
      {:ok, extend} -> {:ok, extend}
      :error -> {:error, unknown_extend_error(extend)}
    end
  end

  def validate_extend(extend) when is_binary(extend) do
    extend
    |> String.downcase()
    |> String.to_existing_atom()
    |> validate_extend()
  rescue
    ArgumentError ->
      {:error, unknown_extend_error(extend)}
  end

  @doc false
  def validate_extend(extend, options) when extend in @extend do
    extend = Map.fetch!(@extend_map, extend)

    options =
      options
      |> Keyword.delete(:interpolate)
      |> Keyword.put(:extend, extend)

    {:cont, options}
  end

  def validate_extend(extend, options) when extend in @vips_extend do
    {:cont, Keyword.put(options, :extend, extend)}
  end

  def validate_extend(extend, _options) do
    {:halt, {:error, unknown_extend_error(extend)}}
  end

  @doc false
  def decode_extend(extend) do
    Map.fetch!(@reverse_extend, extend)
  end

  defp unknown_extend_error(extend) do
    "Unknown extend mode. Found #{inspect(extend)}"
  end
end
