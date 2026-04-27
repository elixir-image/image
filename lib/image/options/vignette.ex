defmodule Image.Options.Vignette do
  @moduledoc """
  Options and option validation for `Image.vignette/2`.

  """

  @typedoc """
  Options applicable to `Image.vignette/2`.

  """
  @type vignette_option ::
          {:strength, number()}
          | {:k1, number()}
          | {:k2, number()}
          | {:k3, number()}

  @typedoc """
  Options list for `Image.vignette/2`.

  """
  @type vignette_options :: [vignette_option()] | map()

  @default_strength 0.5

  @doc false
  def default_strength, do: @default_strength

  @doc """
  Validate the options for `Image.vignette/2`.

  See `t:Image.Options.Vignette.vignette_options/0`.

  """
  def validate_options(options) when is_list(options) do
    options = Keyword.merge(default_options(), options)

    case Enum.reduce_while(options, options, &validate_option(&1, &2)) do
      {:error, value} -> {:error, value}
      options -> {:ok, normalize(Map.new(options))}
    end
  end

  def validate_options(%{} = options) do
    {:ok, normalize(options)}
  end

  defp validate_option({:strength, strength}, options) when is_number(strength) do
    {:cont, options}
  end

  defp validate_option({key, value}, options)
       when key in [:k1, :k2, :k3] and is_number(value) do
    {:cont, options}
  end

  defp validate_option(option, _options) do
    {:halt, {:error, invalid_option(option)}}
  end

  defp invalid_option(option) do
    "Invalid option or option value: #{inspect(option)}"
  end

  # If the caller supplies any explicit polynomial coefficient we use
  # those directly (defaulting omitted ones to 0). Otherwise we derive
  # `k1 = -strength` and leave higher-order terms at 0 — a smooth
  # quadratic darkening from centre to corner.
  defp normalize(options) do
    has_explicit? =
      Map.has_key?(options, :k1) or Map.has_key?(options, :k2) or Map.has_key?(options, :k3)

    cond do
      has_explicit? ->
        %{
          k1: Map.get(options, :k1, 0.0) * 1.0,
          k2: Map.get(options, :k2, 0.0) * 1.0,
          k3: Map.get(options, :k3, 0.0) * 1.0
        }

      true ->
        %{k1: -options.strength * 1.0, k2: 0.0, k3: 0.0}
    end
  end

  defp default_options do
    [strength: @default_strength]
  end
end
