defmodule Image.BandFormat do
  @moduledoc """
  Functions to define and validate the band
  formats of an image.

  """

  alias Vix.Vips.Image, as: Vimage

  @type t ::
          {:u, 8}
          | {:s, 8}
          | {:u, 16}
          | {:s, 16}
          | {:u, 32}
          | {:s, 32}
          | {:u, 64}
          | {:s, 64}
          | {:f, 32}
          | {:f, 64}

  @long_format_map %{
    {:u, 8} => :VIPS_FORMAT_UCHAR,
    {:s, 8} => :VIPS_FORMAT_CHAR,
    {:u, 16} => :VIPS_FORMAT_USHORT,
    {:s, 16} => :VIPS_FORMAT_SHORT,
    {:u, 32} => :VIPS_FORMAT_UINT,
    {:s, 32} => :VIPS_FORMAT_INT,
    {:u, 64} => :VIPS_FORMAT_UINT,
    {:s, 64} => :VIPS_FORMAT_UINT,
    {:f, 32} => :VIPS_FORMAT_FLOAT,
    {:f, 64} => :VIPS_FORMAT_DOUBLE
  }

  @short_format_map @long_format_map
                    |> Enum.map(fn {{sign, size}, enum} ->
                      {String.to_atom(to_string(sign) <> to_string(size)), enum}
                    end)
                    |> Map.new()

  @band_format_map Map.merge(@long_format_map, @short_format_map)

  @inverse_band_format_map @long_format_map
                           |> Enum.map(fn {code, enum} -> {enum, code} end)
                           |> Map.new()

  defp band_format_map do
    @band_format_map
  end

  defp inverse_band_format_map do
    @inverse_band_format_map
  end

  @known_band_formats Map.keys(@long_format_map)
  @vips_band_formats Map.values(@long_format_map)

  @doc """
  Returns a list of the known band formats.

  """
  def known_band_formats do
    @known_band_formats
  end

  @doc """
  Validates a band format returning the band
  format value required in the underlying
  `Vix` code.

  ### Arguments

  * `format` is any format returned by
    `Image.BandFormat.known_band_formats/0`.

  ### Returns

  * `{:ok, validated_foramt}` or

  * `{:error, reason}`

  ### Examples

        iex> Image.BandFormat.validate({:u, 8})
        {:ok, :VIPS_FORMAT_UCHAR}

        iex> Image.BandFormat.validate(:u8)
        {:ok, :VIPS_FORMAT_UCHAR}

        iex> Image.BandFormat.validate(:VIPS_FORMAT_UCHAR)
        {:ok, :VIPS_FORMAT_UCHAR}

  """
  def validate(format) when format in @vips_band_formats do
    {:ok, format}
  end

  def validate(format) do
    case Map.get(band_format_map(), format) do
      nil ->
        {:error, "Invalid band format. Found #{inspect(format)}"}

      format ->
        {:ok, format}
    end
  end

  if Code.ensure_loaded?(Nx) do
    def image_format_from_nx(%Nx.Tensor{} = tensor) do
      tensor
      |> Nx.type()
      |> image_format_from_nx()
    end
  end

  @dialyzer {:nowarn_function, {:nx_format, 1}}

  @doc """
  Returns the `Image` format type for an
  `Nx` format type.

  `Image` uses the same type formats as `Nx` so
  this function is more a validation than a
  conversion.

  ### Arguments

  * Any `Nx` type like `{:u, 8}`.

  ### Returns

  * `{:ok, band_format}` or

  * `{:error, reason}`

  """
  def image_format_from_nx(nx_type) do
    validate(nx_type)
  end

  @doc """
  Returns the `Nx` format type for an
  `Image` or image format type.

  `Image` uses the same type formats as `Nx` so
  this function is more a validation than a
  conversion.

  ### Arguments

  * Any `t:Vimage.t/0` of format in the list
    returned by `Image.BandFormat.known_band_formats/0`.

  ### Returns

  * `{:ok, band_format}` or

  * `{:error, reason}`

  """
  def nx_format(%Vimage{} = image) do
    nx_format(Vix.Vips.Image.format(image))
  end

  def nx_format(format) when is_atom(format) do
    case Map.get(inverse_band_format_map(), format) do
      nil ->
        {:error, "Invalid band format. Found #{inspect(format)}"}

      format ->
        {:ok, format}
    end
  end

  @doc """
  Returns the `Nx` format type for an
  `Image` or image format type or raises
  an exception.

  `Image` uses the same type formats as `Nx` so
  this function is more a validation than a
  conversion.

  ### Arguments

  * Any `t:Vimage.t/0` of format in the list
    returned by `Image.BandFormat.known_band_formats/0`.

  ### Returns

  * `band_format` or

  * raises an exception.

  """
  def nx_format!(image_or_format) do
    case nx_format(image_or_format) do
      {:ok, format} -> format
      {:error, reason} -> raise Image.Error, reason
    end
  end
end
