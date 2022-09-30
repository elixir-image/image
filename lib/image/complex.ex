defmodule Image.Complex do
  @moduledoc false
  # See http://libvips.blogspot.com/2015/11/fancy-transforms.html

  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Operation

  defguard complex(format) when format in [:VIPS_FORMAT_COMPLEX, :VIPS_FORMAT_DPCOMPLEX]
  defguard float_format(format) when format in [:VIPS_FORMAT_FLOAT, :VIPS_FORMAT_DOUBLE]
  defguard even(bands) when rem(bands, 2) === 0

  @dialyzer {:nowarn_function, {:polar, 1}}

  def polar(%Vimage{} = image) do
    complex(image, &Operation.complex(&1, :VIPS_OPERATION_COMPLEX_POLAR))
  end

  @dialyzer {:nowarn_function, {:rectangular, 1}}

  def rectangular(%Vimage{} = image) do
    complex(image, &Operation.complex(&1, :VIPS_OPERATION_COMPLEX_RECT))
  end

  @dialyzer {:nowarn_function, {:rectangular!, 1}}

  def rectangular!(%Vimage{} = image) do
    case rectangular(image) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  @dialyzer {:nowarn_function, {:complex, 2}}

  defp complex(%Vimage{} = image, fun) do
    bands = Vimage.bands(image)
    original_format = Vimage.format(image)

    with {:ok, image} <- to_complex(image, original_format, bands),
         {:ok, image} <- fun.(image) do
      new_format = Vimage.format(image)
      from_complex(image, original_format, new_format, bands)
    end
  end

  # Convert to complex

  @dialyzer {:nowarn_function, {:to_complex, 3}}

  defp to_complex(%Vimage{} = _image, format, bands)
       when not complex(format) and not even(bands) do
    {:error, "Not an even number of bands. Found: #{inspect(bands)}"}
  end

  # If its already complex, return it
  defp to_complex(%Vimage{} = image, format, _bands) when complex(format) do
    {:ok, image}
  end

  defp to_complex(%Vimage{} = image, :VIPS_FORMAT_FLOAT, bands) do
    Operation.copy(image, format: :VIPS_FORMAT_COMPLEX, bands: div(bands, 2))
  end

  defp to_complex(%Vimage{} = image, :VIPS_FORMAT_DOUBLE, bands) do
    Operation.copy(image, format: :VIPS_FORMAT_DPCOMPLEX, bands: div(bands, 2))
  end

  defp to_complex(%Vimage{} = image, _format, bands) do
    {:ok, image} = Operation.cast(image, :VIPS_FORMAT_FLOAT)
    to_complex(image, Vimage.format(image), bands)
  end

  # Convert from complex

  @dialyzer {:nowarn_function, {:from_complex, 4}}

  defp from_complex(image, original_format, :VIPS_FORMAT_DPCOMPLEX, bands)
       when not complex(original_format) do
    Operation.copy(image, format: :VIPS_FORMAT_DOUBLE, bands: bands)
  end

  defp from_complex(image, original_format, _new_format, bands)
       when not complex(original_format) do
    Operation.copy(image, format: :VIPS_FORMAT_FLOAT, bands: bands)
  end

  defp from_complex(image, _original_format, _format, _bands) do
    {:ok, image}
  end
end
