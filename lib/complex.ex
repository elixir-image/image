defmodule Image.Complex do
  # See http://libvips.blogspot.com/2015/11/fancy-transforms.html

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Operation

  defguard complex(format) when format in [:VIPS_FORMAT_COMPLEX, :VIPS_FORMAT_DPCOMPLEX]
  defguard float_format(format) when format in [:VIPS_FORMAT_FLOAT, :VIPS_FORMAT_DOUBLE]
  defguard even(bands) when rem(bands, 2) === 0

  def polar(%Vimage{} = image) do
    complex(image, &Operation.complex(&1, :VIPS_OPERATION_COMPLEX_POLAR))
  end

  def rectangular(%Vimage{} = image) do
    complex(image, &Operation.complex(&1, :VIPS_OPERATION_COMPLEX_RECT))
  end

  defp complex(%Vimage{} = image, fun) do
    bands = Vimage.bands(image)
    format = Vimage.format(image)

    with {:ok, image} <- to_complex(image, format, bands),
         {:ok, image} <- fun.(image) do
      uncomplex(image, format, Vimage.format(image), bands)
    end
  end

  defp to_complex(%Vimage{} = _image, format, bands)
      when not complex(format) and not even(bands) do
    {:error, "Not an even number of bands. Found: #{inspect bands}"}
  end

  defp to_complex(%Vimage{} = image, format, bands)
      when not complex(format) and not float_format(format) do
    {:ok, image} = Operation.cast(image, :VIPS_FORMAT_FLOAT)
    Operation.copy(image, format: :VIPS_FORMAT_COMPLEX, bands: div(bands, 2))
  end

  defp to_complex(%Vimage{} = image, format, bands) when format === :VIPS_FORMAT_DOUBLE do
    Operation.copy(image, format: :VIPS_FORMAT_DPCOMPLEX, bands: div(bands, 2))
  end

  defp to_complex(%Vimage{} = image, _format, bands) do
     Operation.copy(image, format: :VIPS_FORMAT_COMPLEX, bands: div(bands, 2))
  end

  defp uncomplex(image, original_format, format, bands)
      when not complex(original_format) and format === :VIPS_FORMAT_DPCOMPLEX do
    Operation.copy(image, format: :VIPS_FORMAT_DOUBLE, bands: bands)
  end

  defp uncomplex(image, original_format, _format, bands) when not complex(original_format) do
    Operation.copy(image, format: :VIPS_FORMAT_FLOAT, bands: bands)
  end

  defp uncomplex(image, original_format, format, bands) when not complex(original_format) do
    Operation.copy(image, format: format, bands: bands)
  end

  defp uncomplex(image, _original_format, _format, _bands) do
    {:ok, image}
  end
end