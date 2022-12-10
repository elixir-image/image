defmodule Image.Kernel do
  @moduledoc """
  Defines the known resampling kernels to which
  an image can be converted to and from.

  """

  @kernel_map %{
    nearest: :VIPS_KERNEL_NEAREST,
    linear: :VIPS_KERNEL_LINEAR,
    cubic: :VIPS_KERNEL_CUBIC,
    mitchell: :VIPS_KERNEL_MITCHELL,
    lanczos2: :VIPS_KERNEL_LANCZOS2,
    lanczos3: :VIPS_KERNEL_LANCZOS3
  }

  @kernel Map.keys(@kernel_map)
  @vips_kernel Map.values(@kernel_map)

  @reverse_kernel Enum.map(@kernel_map, fn {k, v} -> {v, k} end)
                  |> Map.new()

  @typedoc """
  Defines the known kernel resampling methods.

  """
  @type t :: unquote(Enum.reduce(@kernel, &{:|, [], [&1, &2]}))

  @doc """
  Returns the known colorspace interpretations

  """
  def known_kernel do
    @kernel
  end

  @doc """
  Normalizes and validates a resampling kernel.

  ### Arguments

  * `kernel` is any atom or string value
    in `Image.Kernel.known_kernel/0`.

  ### Returns

  * `{:error, normalized_kernel}` or

  * `{:error, reason}`

  ### Examples

      iex> Image.Kernel.validate_kernel(:linear)
      {:ok, :VIPS_KERNEL_LINEAR}

      iex> Image.Kernel.validate_kernel(:VIPS_KERNEL_CUBIC)
      {:ok, :VIPS_KERNEL_CUBIC}

      iex> Image.Kernel.validate_kernel(:unknown)
      {:error, "Unknown kernel. Found :unknown"}

  """
  def validate_kernel(kernel) when kernel in @vips_kernel do
    {:ok, kernel}
  end

  def validate_kernel(kernel) when is_atom(kernel) do
    case Map.fetch(@kernel_map, kernel) do
      {:ok, kernel} -> {:ok, kernel}
      :error -> {:error, unknown_kernel_error(kernel)}
    end
  end

  def validate_kernel(kernel) when is_binary(kernel) do
    kernel
    |> String.downcase()
    |> String.to_existing_atom()
    |> validate_kernel()
  rescue
    ArgumentError ->
      {:error, unknown_kernel_error(kernel)}
  end

  @doc false
  def validate_kernel(kernel, options) when kernel in @kernel do
    kernel = Map.fetch!(@kernel_map, kernel)

    options =
      options
      |> Keyword.delete(:interpolate)
      |> Keyword.put(:kernel, kernel)

    {:cont, options}
  end

  def validate_kernel(kernel, options) when kernel in @vips_kernel do
    {:cont, Keyword.put(options, :kernel, kernel)}
  end

  def validate_kernel(kernel, _options) do
    {:halt, {:error, unknown_kernel_error(kernel)}}
  end

  @doc false
  def decode_kernel(kernel) do
    Map.fetch!(@reverse_kernel, kernel)
  end

  defp unknown_kernel_error(kernel) do
    "Unknown kernel. Found #{inspect(kernel)}"
  end
end
