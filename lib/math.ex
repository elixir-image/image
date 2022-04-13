defmodule Image.Math do
  alias Vix.Vips.Operation
  alias Vix.Vips.Image, as: Vimage

  def pow(image, value) when is_number(value) do
    Operation.math2_const(image, :VIPS_OPERATION_MATH2_POW, [value])
  end

  def pow(%Vimage{} = image, %Vimage{} = image2) do
    Operation.math2(image, image2, :VIPS_OPERATION_MATH2_POW)
  end

  def cos(%Vimage{} = image) do
    Operation.math(image, :VIPS_OPERATION_MATH_COS)
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

  def subtract(%Vimage{} = image, %Vimage{} = image2) do
    Operation.subtract(image, image2)
  end

  def subtract(%Vimage{} = image, value) when is_number(value) do
    subtract(image, [value])
  end

  def subtract(%Vimage{} = image, value) when is_list(value) do
    Operation.linear(image, [1], Enum.map(value, &(-&1)))
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
end