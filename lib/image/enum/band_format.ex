defmodule Image.BandFormat do
  @moduledoc """
  Functions to define and validate the band
  formats of an image.

  """

  def image_format_from_nx(tensor) do
    case Nx.type(tensor) do
      {:u, 8} ->
        {:ok, :VIPS_FORMAT_UCHAR}

      {:s, 8} ->
        {:ok, :VIPS_FORMAT_CHAR}

      {:u, 16} ->
        {:ok, :VIPS_FORMAT_USHORT}

      {:s, 16} ->
        {:ok, :VIPS_FORMAT_SHORT}

      {:u, 32} ->
        {:ok, :VIPS_FORMAT_UINT}

      {:s, 32} ->
        {:ok, :VIPS_FORMAT_INT}

      {:f, 32} ->
        {:ok, :VIPS_FORMAT_FLOAT}

      {:f, 64} ->
        {:ok, :VIPS_FORMAT_DOUBLE}

      other ->
        {:error, "Cannot convert this tensor type to an image. Found #{inspect(other)}"}
    end
  end

  def nx_format(image) do
    case Vix.Vips.Image.format(image) do
      :VIPS_FORMAT_UCHAR ->
        {:ok, {:u, 8}}

      :VIPS_FORMAT_CHAR ->
        {:ok, {:s, 8}}

      :VIPS_FORMAT_USHORT ->
        {:ok, {:u, 16}}

      :VIPS_FORMAT_SHORT ->
        {:ok, {:s, 16}}

      :VIPS_FORMAT_UINT ->
        {:ok, {:u, 32}}

      :VIPS_FORMAT_INT ->
        {:ok, {:s, 32}}

      :VIPS_FORMAT_FLOAT ->
        {:ok, {:f, 32}}

      :VIPS_FORMAT_DOUBLE ->
        {:ok, {:f, 64}}

      other ->
        {:error, "Cannot convert this image type to binary. Found #{inspect(other)}"}
    end
  end

end