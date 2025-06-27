defmodule Image.Math do
  @moduledoc """
  Implements math operators for images,
  delegating to the `Kernel` functions in the
  cases where the parameters do not include
  `t:Vix.Vips.Image.t/0`.

  To override the standard operations in a
  function or module, add `use Image.Math`.

  To maximise readability and clarity it
  is recommended that `use Image.Math` be added
  to only those functions that require it.

  ### Example

      defmodule MyModule do
        # Not recommended
        use Image.Math

        def my_function(%Vix.Vips.Image{} = image) do
          # Recommended
          use Image.Math

          # Increase the all bands by 20%
          brigher = image * 1.2

          # Or adjust only green by 20%
          bright_green = image * [1, 1.2, 1]
        end
      end

  """

  alias Vix.Vips.Operation
  alias Vix.Vips.Image, as: Vimage

  import Kernel,
    except: [+: 2, -: 1, -: 2, *: 2, /: 2, **: 2, <: 2, >: 2, ==: 2, >=: 2, <=: 2, abs: 1]

  @doc """
  Guards if a given value might be reasonably interpreted
  as a pixel.

  """
  defguard is_pixel(value) when is_number(value) or is_list(value)

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Kernel,
        except: [+: 2, -: 1, -: 2, *: 2, /: 2, **: 2, <: 2, >: 2, ==: 2, >=: 2, <=: 2, abs: 2]

      import Image.Math
    end
  end

  @doc """
  Matrix unary minues of an
  image or a number.

  """
  def -a when is_struct(a, Vimage) do
    multiply!(a, -1)
  end

  def -a when is_number(a) do
    Kernel.-(a)
  end

  @doc """
  Matrix addition of two images or
  one image and a constant or vector.

  Delegates to `Kernel.+/2` if none of
  the parameters is a `t:Vix.Vips.Image.t/0`.

  """
  def a + b do
    add!(a, b)
  end

  @doc """
  Matrix subtraction of two images or
  one image and a constant or vector.

  Delegates to `Kernel.-/2` if none of
  the parameters is a `t:Vix.Vips.Image.t/0`.

  """
  def a - b do
    subtract!(a, b)
  end

  @doc """
  Matrix multiplation of two images or
  one image and a constant or vector.

  Delegates to `Kernel.*/2` if none of
  the parameters is a `t:Vix.Vips.Image.t/0`.

  """
  def a * b do
    multiply!(a, b)
  end

  @doc """
  Matrix division of two images or
  one image and a constant or vector.

  Delegates to `Kernel.//2` if none of
  the parameters is a `t:Vix.Vips.Image.t/0`.

  """
  def a / b do
    divide!(a, b)
  end

  @doc """
  Matrix exponent of two images or
  one image and a constant or vector.

  Delegates to `Kernel.**/2` if none of
  the parameters is a `t:Vix.Vips.Image.t/0`.

  """
  def a ** b do
    pow!(a, b)
  end

  @doc """
  Matrix less than of two images or
  one image and a constant or vector.

  Delegates to `Kernel.</2` if none of
  the parameters is a `t:Vix.Vips.Image.t/0`.

  """
  def a < b do
    less_than!(a, b)
  end

  @doc """
  Matrix less than or equal of two images or
  one image and a constant or vector.

  Delegates to `Kernel.<=/2` if none of
  the parameters is a `t:Vix.Vips.Image.t/0`.

  """
  def a <= b do
    less_than_or_equal!(a, b)
  end

  @doc """
  Matrix greater than of two images or
  one image and a constant or vector.

  Delegates to `Kernel.>/2` if none of
  the parameters is a `t:Vix.Vips.Image.t/0`.

  """
  def a > b do
    greater_than!(a, b)
  end

  @doc """
  Matrix greater than or equal of two images or
  one image and a constant or vector.

  Delegates to `Kernel.>=/2` if none of
  the parameters is a `t:Vix.Vips.Image.t/0`.

  """
  def a >= b do
    greater_than_or_equal!(a, b)
  end

  @doc """
  Matrix equality of two images or
  one image and a constant or vector.

  Delegates to `Kernel.==/2` if none of
  the parameters is a `t:Vix.Vips.Image.t/0`.

  """
  def a == b do
    equal!(a, b)
  end

  @doc """
  Matrix inequality of two images or
  one image and a constant or vector.

  Delegates to `Kernel.!=/2` if none of
  the parameters is a `t:Vix.Vips.Image.t/0`.

  """
  def a != b do
    not_equal!(a, b)
  end

  @doc """
  Matrix bitwise 'and' of
  two images.

  """
  def a &&& b do
    boolean_and!(a, b)
  end

  @doc """
  Matrix bitwise 'or' of
  two images.

  """
  def a ||| b do
    boolean_or!(a, b)
  end

  # @doc """
  # Matrix bitwise 'xor' of
  # two images.
  #
  # """
  # def a ^^^ b do
  #   boolean_xor!(a, b)
  # end

  @doc """
  Matrix bitwise 'left shift' of
  two images.

  """
  def a <<< b do
    boolean_lshift!(a, b)
  end

  @doc """
  Matrix bitwise 'right shift' of
  two images.

  """
  def a >>> b do
    boolean_rshift!(a, b)
  end

  @spec exp(Vimage.t()) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def exp(image) do
    Operation.math(image, :VIPS_OPERATION_MATH_EXP)
  end

  @spec abs(Vimage.t()) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def abs(%Vimage{} = image) do
    Operation.abs(image)
  end

  @spec abs(number) :: {:ok, number}
  def abs(number) do
    {:ok, Kernel.abs(number)}
  end

  @spec max(Vimage.t()) :: {:ok, float()} | {:error, Image.error_message()}
  def max(%Vimage{} = image) do
    case Operation.max(image) do
      {:ok, {max, _}} -> {:ok, max}
      other -> other
    end
  end

  @spec min(Vimage.t()) :: {:ok, float()} | {:error, Image.error_message()}
  def min(%Vimage{} = image) do
    case Operation.min(image) do
      {:ok, {min, _}} -> {:ok, min}
      other -> other
    end
  end

  @spec pow(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def pow(%Vimage{} = image, %Vimage{} = image2) do
    Operation.math2(image, image2, :VIPS_OPERATION_MATH2_POW)
  end

  @spec pow(Vimage.t(), number()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def pow(%Vimage{} = image, value) when is_number(value) do
    Operation.math2_const(image, :VIPS_OPERATION_MATH2_POW, [value])
  end

  @spec pow(number(), number()) :: {:ok, number()}
  def pow(a, b) when is_number(a) and is_number(b) do
    {:ok, Kernel.**(a, b)}
  end

  @spec cos(Vimage.t()) :: {:ok, Vimage.t()}
  def cos(%Vimage{} = image) do
    Operation.math(image, :VIPS_OPERATION_MATH_COS)
  end

  @spec cos(number()) :: {:ok, number()}
  def cos(other) do
    {:ok, :math.cos(other)}
  end

  @spec sin(Vimage.t()) :: {:ok, Vimage.t()}
  def sin(%Vimage{} = image) do
    Operation.math(image, :VIPS_OPERATION_MATH_SIN)
  end

  @spec sin(number()) :: {:ok, number()}
  def sin(other) do
    {:ok, :math.sin(other)}
  end

  @spec add(Vimage.t(), Vimage.t()) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def add(%Vimage{} = image, %Vimage{} = image2) do
    Operation.add(image, image2)
  end

  @spec add(Vimage.t(), number()) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def add(%Vimage{} = image, value) when is_number(value) do
    add(image, [value])
  end

  @spec add(Vimage.t(), [number(), ...]) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def add(%Vimage{} = image, value) when is_list(value) do
    Operation.linear(image, [1.0], value)
  end

  def add(value, %Vimage{} = image) when is_number(value) do
    add(image, value)
  end

  @spec add(number(), number()) :: {:ok, number}
  def add(a, b) do
    {:ok, Kernel.+(a, b)}
  end

  @spec subtract(Vimage.t(), Vimage.t()) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def subtract(%Vimage{} = image, %Vimage{} = image2) do
    Operation.subtract(image, image2)
  end

  @spec subtract(Vimage.t(), number()) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def subtract(%Vimage{} = image, value) when is_number(value) do
    subtract(image, [value])
  end

  @spec subtract(Vimage.t(), [number()]) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def subtract(%Vimage{} = image, value) when is_list(value) do
    Operation.linear(image, [1.0], Enum.map(value, &(-&1)))
  end

  @spec subtract(number(), Vimage.t()) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def subtract(value, %Vimage{} = image) when is_number(value) do
    image
    |> multiply!(-1)
    |> add!(value)
    |> wrap(:ok)
  end

  @spec subtract(number(), number()) :: {:ok, number}
  def subtract(a, b) do
    {:ok, Kernel.-(a, b)}
  end

  @spec multiply(Vimage.t(), Vimage.t()) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def multiply(%Vimage{} = image, %Vimage{} = image2) do
    Operation.multiply(image, image2)
  end

  @spec multiply(Vimage.t(), number()) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def multiply(%Vimage{} = image, value) when is_number(value) do
    multiply(image, [value])
  end

  @spec multiply(number(), Vimage.t()) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def multiply(value, %Vimage{} = image) when is_number(value) do
    multiply(image, [value])
  end

  @spec multiply(Vimage.t(), list()) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def multiply(%Vimage{} = image, value) when is_list(value) do
    Operation.linear(image, value, [0.0])
  end

  @spec multiply(number(), number()) :: {:ok, number}
  def multiply(a, b) when is_number(a) and is_number(b) do
    {:ok, Kernel.*(a, b)}
  end

  @spec divide(Vimage.t(), Vimage.t()) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def divide(%Vimage{} = image, %Vimage{} = image2) do
    Operation.divide(image, image2)
  end

  @spec divide(Vimage.t(), number()) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def divide(%Vimage{} = image, value) when is_number(value) do
    divide(image, [value])
  end

  # See https://github.com/libvips/libvips/blob/master/cplusplus/VImage.cpp#L1062-L1066
  @spec divide(number(), Vimage.t()) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def divide(value, %Vimage{} = image) when is_number(value) do
    image
    |> pow!(-1.0)
    |> multiply(value)
  end

  @spec divide(Vimage.t(), [number()]) :: {:ok, Vimage.t()} | {:error, Image.error_message()}
  def divide(%Vimage{} = image, value) when is_list(value) do
    Operation.linear(image, Enum.map(value, &(1.0 / &1)), [0.0])
  end

  @spec divide(number(), number()) :: {:ok, number}
  def divide(a, b) do
    {:ok, Kernel.-(a, b)}
  end

  @spec less_than(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def less_than(%Vimage{} = image, %Vimage{} = other) do
    Vix.Vips.Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_LESS)
  end

  @spec less_than(Vimage.t(), Image.pixel()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def less_than(%Vimage{} = image, other) when is_pixel(other) do
    Vix.Vips.Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_LESS, List.wrap(other))
  end

  @spec less_than_or_equal(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def less_than_or_equal(%Vimage{} = image, %Vimage{} = other) do
    Vix.Vips.Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_LESSEQ)
  end

  @spec less_than_or_equal(Vimage.t(), Image.pixel()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def less_than_or_equal(%Vimage{} = image, other) when is_pixel(other) do
    Vix.Vips.Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_LESSEQ, List.wrap(other))
  end

  @spec greater_than(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def greater_than(%Vimage{} = image, %Vimage{} = other) do
    Vix.Vips.Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_MORE)
  end

  @spec greater_than(Vimage.t(), Image.pixel()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def greater_than(%Vimage{} = image, other) when is_pixel(other) do
    Vix.Vips.Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_MORE, List.wrap(other))
  end

  @spec greater_than_or_equal(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def greater_than_or_equal(%Vimage{} = image, %Vimage{} = other) do
    Vix.Vips.Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_MOREEQ)
  end

  @spec greater_than_or_equal(Vimage.t(), Image.pixel()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def greater_than_or_equal(%Vimage{} = image, other) when is_pixel(other) do
    Vix.Vips.Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_MOREEQ, List.wrap(other))
  end

  @spec equal(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def equal(%Vimage{} = image, %Vimage{} = other) do
    Vix.Vips.Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_EQUAL)
  end

  @spec equal(Vimage.t(), Image.pixel()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def equal(%Vimage{} = image, other) when is_pixel(other) do
    Vix.Vips.Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_EQUAL, List.wrap(other))
  end

  @spec not_equal(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def not_equal(%Vimage{} = image, %Vimage{} = other) do
    Vix.Vips.Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_NOTEQ)
  end

  @spec not_equal(Vimage.t(), Image.pixel()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}

  def not_equal(%Vimage{} = image, other) when is_pixel(other) do
    Vix.Vips.Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_NOTEQ, List.wrap(other))
  end

  @spec less_than!(Vimage.t(), Vimage.t() | Image.pixel()) :: Vimage.t() | no_return()
  def less_than!(%Vimage{} = image, value) do
    case less_than(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec less_than!(number(), number()) :: number() | no_return()
  def less_than!(a, b) do
    Kernel.<(a, b)
  end

  @spec less_than_or_equal!(Vimage.t(), Vimage.t() | Image.pixel()) :: Vimage.t() | no_return()
  def less_than_or_equal!(%Vimage{} = image, value) do
    case less_than_or_equal(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec less_than_or_equal!(number(), number()) :: number() | no_return()
  def less_than_or_equal!(a, b) do
    Kernel.<=(a, b)
  end

  @spec greater_than!(Vimage.t(), Vimage.t() | Image.pixel()) :: Vimage.t() | no_return()
  def greater_than!(%Vimage{} = image, value) do
    case greater_than(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec greater_than!(number(), number()) :: number() | no_return()
  def greater_than!(a, b) do
    Kernel.>(a, b)
  end

  @spec greater_than_or_equal!(Vimage.t(), Image.pixel()) :: Vimage.t() | no_return()
  def greater_than_or_equal!(%Vimage{} = image, value) do
    case greater_than_or_equal(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec greater_than_or_equal!(number(), number()) :: number() | no_return()
  def greater_than_or_equal!(a, b) do
    Kernel.>=(a, b)
  end

  @spec equal!(Vimage.t(), Image.pixel()) :: Vimage.t() | no_return()
  def equal!(%Vimage{} = image, value) do
    case equal(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec equal!(number(), number()) :: number() | no_return()
  def equal!(a, b) do
    Kernel.==(a, b)
  end

  @spec not_equal!(Vimage.t(), Image.pixel()) :: Vimage.t() | no_return()
  def not_equal!(%Vimage{} = image, value) do
    case not_equal(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec not_equal!(number(), number()) :: number() | no_return()
  def not_equal!(a, b) do
    Kernel.!=(a, b)
  end

  @spec add!(Vimage.t(), Image.pixel() | number()) :: Vimage.t() | no_return()
  def add!(%Vimage{} = image, value) do
    case add(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec add!(Image.pixel() | number(), Vimage.t()) :: Vimage.t() | no_return()
  def add!(value, %Vimage{} = image) do
    case add(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec add!(number(), number()) :: number() | no_return()
  def add!(a, b) do
    Kernel.+(a, b)
  end

  @spec subtract!(Vimage.t(), Image.pixel()) :: Vimage.t() | no_return()
  def subtract!(%Vimage{} = image, value) do
    case subtract(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec subtract!(Image.pixel(), Vimage.t()) :: Vimage.t() | no_return()
  def subtract!(value, %Vimage{} = image) when is_number(value) do
    case subtract(value, image) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec subtract!(number(), number()) :: number() | no_return()
  def subtract!(a, b) do
    Kernel.-(a, b)
  end

  @spec multiply!(Vimage.t(), Image.pixel() | number()) :: Vimage.t() | no_return()
  def multiply!(%Vimage{} = image, value) do
    case multiply(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec multiply!(Image.pixel() | number(), Vimage.t()) :: Vimage.t() | no_return()
  def multiply!(value, %Vimage{} = image) do
    case multiply(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec multiply!(number(), number()) :: number() | no_return()
  def multiply!(a, b) do
    Kernel.*(a, b)
  end

  @spec divide!(Vimage.t(), Image.pixel()) :: Vimage.t() | no_return()
  def divide!(%Vimage{} = image, value) do
    case divide(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec divide!(Image.pixel(), Vimage.t()) :: Vimage.t() | no_return()
  def divide!(value, %Vimage{} = image) do
    case divide(value, image) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec divide!(number(), number()) :: number() | no_return()
  def divide!(a, b) when is_number(a) and is_number(b) do
    Kernel./(a, b)
  end

  @spec exp!(Vimage.t()) :: Vimage.t() | no_return()
  def exp!(image) do
    case exp(image) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec abs!(Vimage.t()) :: Vimage.t() | no_return()
  def abs!(image) do
    case abs(image) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec max!(Vimage.t()) :: float() | no_return()
  def max!(image) do
    case max(image) do
      {:ok, float} -> float
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec min!(Vimage.t()) :: float() | no_return()
  def min!(image) do
    case min(image) do
      {:ok, float} -> float
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec pow!(Vimage.t(), number()) :: Vimage.t() | no_return()
  def pow!(%Vimage{} = image, value) do
    case pow(image, value) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec pow!(number(), number()) :: number() | no_return()
  def pow!(a, b) when is_number(a) and is_number(b) do
    Kernel.**(a, b)
  end

  @dialyzer {:nowarn_function, {:cos!, 1}}

  @spec cos!(Vimage.t()) :: Vimage.t() | no_return()
  def cos!(%Vimage{} = image) do
    case cos(image) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @dialyzer {:nowarn_function, {:sin!, 1}}

  @spec sin!(Vimage.t()) :: Vimage.t() | no_return()
  def sin!(%Vimage{} = image) do
    case sin(image) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  ### Logical operations

  @spec boolean_and(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}
  def boolean_and(%Vimage{} = image_1, %Vimage{} = image_2) do
    Operation.boolean(image_1, image_2, :VIPS_OPERATION_BOOLEAN_AND)
  end

  @spec boolean_and!(Vimage.t(), Vimage.t()) :: Vimage.t() | no_return()
  def boolean_and!(%Vimage{} = image_1, %Vimage{} = image_2) do
    case boolean_and(image_1, image_2) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec boolean_or(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}
  def boolean_or(%Vimage{} = image_1, %Vimage{} = image_2) do
    Operation.boolean(image_1, image_2, :VIPS_OPERATION_BOOLEAN_OR)
  end

  @spec boolean_or!(Vimage.t(), Vimage.t()) :: Vimage.t() | no_return()
  def boolean_or!(%Vimage{} = image_1, %Vimage{} = image_2) do
    case boolean_or(image_1, image_2) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec boolean_xor(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}
  def boolean_xor(%Vimage{} = image_1, %Vimage{} = image_2) do
    Operation.boolean(image_1, image_2, :VIPS_OPERATION_BOOLEAN_EOR)
  end

  @spec boolean_xor!(Vimage.t(), Vimage.t()) :: Vimage.t() | no_return()
  def boolean_xor!(%Vimage{} = image_1, %Vimage{} = image_2) do
    case boolean_xor(image_1, image_2) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec boolean_lshift(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}
  def boolean_lshift(%Vimage{} = image_1, %Vimage{} = image_2) do
    Operation.boolean(image_1, image_2, :VIPS_OPERATION_BOOLEAN_LSHIFT)
  end

  @spec boolean_lshift!(Vimage.t(), Vimage.t()) :: Vimage.t() | no_return()
  def boolean_lshift!(%Vimage{} = image_1, %Vimage{} = image_2) do
    case boolean_lshift(image_1, image_2) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @spec boolean_rshift(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error_message()}
  def boolean_rshift(%Vimage{} = image_1, %Vimage{} = image_2) do
    Operation.boolean(image_1, image_2, :VIPS_OPERATION_BOOLEAN_RSHIFT)
  end

  @spec boolean_rshift!(Vimage.t(), Vimage.t()) :: Vimage.t() | no_return()
  def boolean_rshift!(%Vimage{} = image_1, %Vimage{} = image_2) do
    case boolean_rshift(image_1, image_2) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Return the top `n` image maxima.

  The function returns the coordinates of`:n`
  largest values of the image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `n` is the number of maxima to find. The
    default is `10`. Maxima in this case means the
    largest `n` values; They may not be equal to the
    maximum.

  ### Returns

  * `{maximum, x_max, y_max, [{x_positions, y_positions}])`

  """
  @spec top_n(image :: Vimage.t(), n :: non_neg_integer()) ::
          {
            maximum :: float(),
            x_max :: non_neg_integer(),
            y_max :: non_neg_integer(),
            max_coordinates :: [{x_positions :: integer(), y_positions :: integer()}, ...]
          }

  def top_n(%Vimage{} = image, n \\ 10) when is_integer(n) do
    {:ok, {v, opts}} = Operation.max(image, size: n)
    {v, opts[:x], opts[:y], Enum.zip(opts[:"x-array"], opts[:"y-array"])}
  end

  @doc """
  Return the bottom `n` image minima.

  The function returns the coordinates of`:n`
  smallest values of the image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `n` is the number of minima to find. The
    default is `10`. Minima in this case means the
    smallest `n` values; They may not be equal to the
    minimum.

  ### Returns

  * `{minimum, x_min, y_min, [{x_positions, y_positions}])`

  """
  @spec bottom_n(image :: Vimage.t(), n :: non_neg_integer()) ::
          {
            minimim :: float(),
            x_max :: non_neg_integer(),
            y_max :: non_neg_integer(),
            max_coordinates :: [{x_positions :: integer(), y_positions :: integer()}, ...]
          }

  def bottom_n(%Vimage{} = image, n \\ 10) when is_integer(n) do
    {:ok, {v, opts}} = Operation.min(image, size: n)
    {v, opts[:x], opts[:y], Enum.zip(opts[:"x-array"], opts[:"y-array"])}
  end

  @doc """
  Return the image maxima.

  This function retrieves the coordinates of the `n`
  largest values then then filters them to return only
  those coordinates that have the maximum value.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `n` is the number of maxima to find. The
    default is `10`. Maxima in this case means
    those values that exactly match the maximum
    value.

  ### Returns

  * `{maximum, [{x_positions, y_positions}], maybe_overflow)`.  If
    `maybe_overflow` is set to `:maybe_overflow` its an indication
    that the number of coordinates is the same as the requested `:n`.
    Therefore it is possible - maybe even likely - that there are other
    coordinates that have the maximum value but have not been returned.

  ### Example

    This example draws a red image with a single green pixel. We then
    look for all the coordinates that have a green pixel.

      iex> {:ok, image} =
      iex>   Image.new!(5, 5, color: :red)
      iex>   |> Image.mutate(fn i -> Image.Draw.point!(i, 2, 2, color: [0,255,0]) end)
      iex> image
      iex> |> Image.Math.==([0, 255, 0])
      iex> |> Image.band_and!()
      iex> |> Image.Math.maxpos()
      {255, [{2, 2}], nil}

      # Since all pixels are :red and we want
      # the coordinates of all the red pixels
      # we have an overlow: We retrieve only 3
      # maxima and they are all red. Perhaps
      # the red of the image pixels are also red?
      # Yes - they are!
      iex> Image.new!(2, 2, color: :red)
      iex> |> Image.Math.==([255, 0, 0])
      iex> |> Image.band_and!()
      iex> |> Image.Math.maxpos(3)
      {255, [{0, 1}, {1, 0}, {0, 0}], :maybe_overflow}

  """
  @spec maxpos(image :: Vimage.t(), n :: non_neg_integer()) ::
          {
            maximum :: number(),
            max_coordinates :: [{x_positions :: integer(), y_positions :: integer()}, ...],
            maybe_overflow :: :maybe_overflow | nil
          }
  @dialyzer {:nowarn_function, maxpos: 2}
  def maxpos(%Vimage{} = image, n \\ 10) when is_integer(n) do
    band_format = Image.band_format(image)
    {:ok, {max, opts}} = Operation.max(image, size: n)

    coordinates =
      Enum.zip_reduce([opts[:"out-array"], opts[:"x-array"], opts[:"y-array"]], [], fn
        [^max, x, y], acc -> [{x, y} | acc]
        _other, acc -> acc
      end)

    max = if match?({:u, _}, band_format), do: trunc(max), else: max

    if length(coordinates) == n do
      {max, coordinates, :maybe_overflow}
    else
      {max, coordinates, nil}
    end
  end

  @doc """
  Return the image minima.

  This function retrieves the coordinates of the `n`
  smallest values then then filters them to return only
  those coordinates that have the minimum value.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `n` is the number of minima to find. The
    default is `10`. Minima in this case means
    those values that exactly match the minimum
    value.

  ### Returns

  * `{minimum, [{x_positions, y_positions}], maybe_overflow)`.  If
    `maybe_overflow` is set to `:maybe_overflow` its an indication
    that the number of coordinates is the same as the requested `:n`.
    Therefore it is possible - maybe even likely - that there are other
    coordinates that have the minimum value but have not been returned.

  """
  @dialyzer {:nowarn_function, minpos: 2}
  @spec minpos(image :: Vimage.t(), n :: non_neg_integer()) ::
          {
            maximum :: number(),
            max_coordinates :: [{x_positions :: integer(), y_positions :: integer()}, ...],
            maybe_overflow :: :maybe_overflow | nil
          }

  def minpos(%Vimage{} = image, n \\ 10) when is_integer(n) do
    band_format = Image.band_format(image)
    {:ok, {min, opts}} = Operation.min(image, size: n)

    coordinates =
      Enum.zip_reduce([opts[:"out-array"], opts[:"x-array"], opts[:"y-array"]], [], fn
        [^min, x, y], acc -> [{x, y} | acc]
        _other, acc -> acc
      end)

    min = if match?({:u, _}, band_format), do: trunc(min), else: min

    if length(coordinates) == n do
      {min, coordinates, :maybe_overflow}
    else
      {min, coordinates, nil}
    end
  end

  @doc false
  def list_height([first | _rest] = list) when is_list(first), do: length(list)
  def list_height(_other), do: 0

  @doc false
  def list_width([first | _rest]) when is_list(first), do: length(first)
  def list_width(list) when is_list(list), do: length(list)

  defp wrap(elem, atom) do
    {atom, elem}
  end
end
