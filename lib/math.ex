defmodule Image.Math do
  alias Vix.Vips.Operation
  alias Vix.Vips.Image, as: Vimage

  defguard is_pixel(value) when is_number(value) or is_list(value)

  defmacro __using__(_opts) do
    quote do
      import Kernel, except: [+: 2, -: 2, *: 2, /: 2, **: 2, <: 2, >: 2, ==: 2, >=: 2, <=: 2]
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

      def a < b do
        Image.Math.less_than!(a, b)
      end

      def a <= b do
        Image.Math.less_than_or_equal!(a, b)
      end

      def a > b do
        Image.Math.greater_than!(a, b)
      end

      def a >= b do
        Image.Math.greater_than_or_equal!(a, b)
      end

      def a == b do
        Image.Math.equal!(a, b)
      end

      def a != b do
        Image.Math.not_equal!(a, b)
      end
    end
  end

  def less_than(%Vimage{} = image, %Vimage{} = other) do
    Vix.Vips.Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_LESS)
  end

  def less_than(%Vimage{} = image, other) when is_pixel(other) do
    Vix.Vips.Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_LESS, List.wrap(other))
  end

  def less_than_or_equal(%Vimage{} = image, %Vimage{} = other) do
    Vix.Vips.Operation.relational(image, :VIPS_OPERATION_RELATIONAL_LESSEQ, List.wrap(other))
  end

  def less_than_or_equal(%Vimage{} = image, other) when is_pixel(other) do
    Vix.Vips.Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_LESSEQ, List.wrap(other))
  end

  def greater_than(%Vimage{} = image, %Vimage{} = other) do
    Vix.Vips.Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_MORE)
  end

  def greater_than(%Vimage{} = image, other) when is_pixel(other) do
    Vix.Vips.Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_MORE, List.wrap(other))
  end

  def greater_than_or_equal(%Vimage{} = image, %Vimage{} = other) do
    Vix.Vips.Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_MOREEQ)
  end

  def greater_than_or_equal(%Vimage{} = image, other) when is_pixel(other) do
    Vix.Vips.Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_MOREEQ, List.wrap(other))
  end

  def equal(%Vimage{} = image, %Vimage{} = other) do
    Vix.Vips.Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_EQUAL)
  end

  def equal(%Vimage{} = image, other) when is_pixel(other) do
    Vix.Vips.Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_EQUAL, List.wrap(other))
  end

  def not_equal(%Vimage{} = image, %Vimage{} = other) do
    Vix.Vips.Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_NOTEQU)
  end

  def not_equal(%Vimage{} = image, other) when is_pixel(other) do
    Vix.Vips.Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_NOTEQU, List.wrap(other))
  end

  def pow(%Vimage{} = image, value) when is_number(value) do
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

  def less_than!(%Vimage{} = image, value) do
    case less_than(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def less_than!(a, b) do
    Kernel.<(a, b)
  end

  def less_than_or_equal!(%Vimage{} = image, value) do
    case less_than_or_equal(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def less_than_or_equal!(a, b) do
    Kernel.<=(a, b)
  end

  def greater_than!(%Vimage{} = image, value) do
    case greater_than(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def greater_than!(a, b) do
    Kernel.>(a, b)
  end

  def greater_than_or_equal!(%Vimage{} = image, value) do
    case greater_than_or_equal(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def greater_than_or_equal!(a, b) do
    Kernel.>=(a, b)
  end

  def equal!(%Vimage{} = image, value) do
    case equal(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def equal!(a, b) do
    Kernel.==(a, b)
  end

  def not_equal!(%Vimage{} = image, value) do
    case not_equal(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def not_equal!(a, b) do
    Kernel.!=(a, b)
  end

  def add!(%Vimage{} = image, value) do
    case add(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def add!(a, b) do
    Kernel.+(a, b)
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

  def subtract!(a, b) do
    Kernel.-(a, b)
  end

  def multiply!(%Vimage{} = image, value) do
    case multiply(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def multiply!(a, b) do
    Kernel.*(a, b)
  end

  def divide!(%Vimage{} = image, value) do
    case divide(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def divide!(a, b) do
    Kernel./(a, b)
  end

  def pow!(%Vimage{} = image, value) do
    case pow(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def pow!(a, b) do
    Kernel.**(a, b)
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
