defmodule Image.Math do
  alias Vix.Vips.Operation
  alias Vix.Vips.Image, as: Vimage

  defmacro __using__(_opts) do
    quote do
      import Kernel, except: [+: 2, -: 2, *: 2, /: 2, **: 2]
      import Image.Math

      def a + b do
        Image.Math.add!(a, b)
      end

      def a - b do
        Image.Math.subtract!(a, b)
      end

      def a * b do
        Image.Math.multiply!(a, b)
      end

      def a / b do
        Image.Math.divide!(a, b)
      end

      def a ** b do
        Image.Math.pow!(a, b)
      end
    end
  end

  def pow(image, value) when is_number(value) do
    Operation.math2_const(image, :VIPS_OPERATION_MATH2_POW, [value])
  end

  def pow(%Vimage{} = image, %Vimage{} = image2) do
    Operation.math2(image, image2, :VIPS_OPERATION_MATH2_POW)
  end

  def pow(a, b) do
    Kernel.**(a, b)
  end

  def cos(%Vimage{} = image) do
    Operation.math(image, :VIPS_OPERATION_MATH_COS)
  end

  def cos(other) do
    :math.cos(other)
  end

  def add(%Vimage{} = image, %Vimage{} = image2) do
    Operation.add(image, image2)
  end

  def add(%Vimage{} = image, value) when is_number(value) do
    add(image, [value])
  end

  def add(%Vimage{} = image, value) when is_list(value) do
    Operation.linear(image, [1], value)
  end

  def add(value, %Vimage{} = image) when is_number(value) do
    add(image, value)
  end

  def add(a, b) do
    Kernel.+(a, b)
  end

  def subtract(%Vimage{} = image, %Vimage{} = image2) do
    Operation.subtract(image, image2)
  end

  def subtract(%Vimage{} = image, value) when is_number(value) do
    subtract(image, [value])
  end

  def subtract(%Vimage{} = image, value) when is_list(value) do
    Operation.linear(image, [1], Enum.map(value, &(-&1)))
  end

  def subtract(value, %Vimage{} = image) when is_number(value) do
    image
    |> multiply!(-1)
    |> add!(value)
    |> wrap(:ok)
  end

  def multiply(%Vimage{} = image, %Vimage{} = image2) do
    Operation.multiply(image, image2)
  end

  def multiply(%Vimage{} = image, value) when is_number(value) do
    multiply(image, [value])
  end

  def multiply(%Vimage{} = image, value) when is_list(value) do
    Operation.linear(image, value, [0])
  end

  def divide(%Vimage{} = image, %Vimage{} = image2) do
    Operation.divide(image, image2)
  end

  def divide(%Vimage{} = image, value) when is_number(value) do
    divide(image, [value])
  end

  def divide(%Vimage{} = image, value) when is_list(value) do
    Operation.linear(image, Enum.map(value, &(1.0 / &1)), [0])
  end

  def maxpos(%Vimage{} = image, options \\ []) do
    size = Keyword.get(options, :size, 10)

    {:ok, {v, opts}} = Operation.max(image, size: size)
    {v, opts[:x], opts[:y]}
  end

  def minpos(%Vimage{} = image, options \\ []) do
    size = Keyword.get(options, :size, 10)

    {:ok, {v, opts}} = Operation.min(image, size: size)
    {v, opts[:x], opts[:y]}
  end

  def add!(%Vimage{} = image, value) do
    case add(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def subtract!(%Vimage{} = image, value) do
    case subtract(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def subtract!(value, %Vimage{} = image) when is_number(value) do
    case subtract(value, image) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def multiply!(%Vimage{} = image, value) do
    case multiply(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def divide!(%Vimage{} = image, value) do
    case divide(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def pow!(%Vimage{} = image, value) do
    case pow(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def cos!(%Vimage{} = image) do
    case cos(image) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def list_height([first | _rest] = list) when is_list(first), do: length(list)
  def list_height(_other), do: 0

  def list_width([first | _rest]) when is_list(first), do: length(first)
  def list_width(list) when is_list(list), do: length(list)

  defp wrap(elem, atom) do
    {atom, elem}
  end
end
