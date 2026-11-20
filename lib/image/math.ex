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

  ### Operands

  When at least one operand is an image, the operation is done by
  libvips. A number or a list of numbers (one per band) may be on
  either side, so `100 - image` and `5 < image` work as expected.
  An operand that cannot be combined with an image returns
  `{:error, %Image.Error{reason: :invalid_argument}}` from the
  functions, and raises `Image.Error` from the `!` functions and the
  operators.

  When neither operand is an image, the operators behave exactly as
  the `Kernel` operators, and `&&&`, `|||`, `<<<` and `>>>` as the
  `Bitwise` ones.

  Trigonometric functions take angles in degrees, for numbers as
  for images, since that is what libvips uses.

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

  alias Image.Vips.Operation
  alias Vix.Vips.Image, as: Vimage

  import Kernel,
    except: [+: 2, -: 1, -: 2, *: 2, /: 2, **: 2, <: 2, >: 2, ==: 2, !=: 2, >=: 2, <=: 2, abs: 1]

  @typedoc """
  A value the arithmetic and comparison operators accept: an
  image, a number, or a list of numbers with one number per band.

  """
  @type operand :: Vimage.t() | number() | [number()]

  @doc """
  Guards if a given value might be reasonably interpreted
  as a pixel.

  """
  defguard is_pixel(value) when is_number(value) or is_list(value)

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Kernel,
        except: [
          +: 2,
          -: 1,
          -: 2,
          *: 2,
          /: 2,
          **: 2,
          <: 2,
          >: 2,
          ==: 2,
          !=: 2,
          >=: 2,
          <=: 2,
          abs: 1
        ]

      import Image.Math
    end
  end

  @doc """
  Negates each pixel of an image, or a number.

  Applies `Kernel.-/1` when the argument is not an image.

  ### Arguments

  * `a` is any `t:Vix.Vips.Image.t/0` or a number.

  ### Returns

  * an image when `a` is an image, or

  * a number when `a` is a number.

  ### Examples

      iex> use Image.Math
      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(-image, 0, 0)
      [-10.0, -20.0, -30.0]

  """
  @spec -Vimage.t() :: Vimage.t()
  @spec -number() :: number()
  def -a when is_struct(a, Vimage) do
    multiply!(a, -1)
  end

  def -a do
    Kernel.-(a)
  end

  @doc """
  Adds two images, or an image and a number or a list of numbers, pixel by pixel.

  Delegates to `Kernel.+/2` when neither argument is an image.
  Raises `Image.Error` if the operation fails.

  ### Arguments

  * `a` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `b` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * an image when either argument is an image, or

  * a number when both are numbers.

  ### Examples

      iex> use Image.Math
      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(image + 5, 0, 0)
      [15.0, 25.0, 35.0]

  """
  @spec operand() + operand() :: Vimage.t() | number()
  def a + b do
    add!(a, b)
  end

  @doc """
  Subtracts one image from another, or a number or a list of numbers from an image, or an image from a number, pixel by pixel.

  Delegates to `Kernel.-/2` when neither argument is an image.
  Raises `Image.Error` if the operation fails.

  ### Arguments

  * `a` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `b` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * an image when either argument is an image, or

  * a number when both are numbers.

  ### Examples

      iex> use Image.Math
      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(image - 5, 0, 0)
      [5.0, 15.0, 25.0]

  """
  @spec operand() - operand() :: Vimage.t() | number()
  def a - b do
    subtract!(a, b)
  end

  @doc """
  Multiplies two images, or an image and a number or a list of numbers, pixel by pixel.

  Delegates to `Kernel.*/2` when neither argument is an image.
  Raises `Image.Error` if the operation fails.

  ### Arguments

  * `a` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `b` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * an image when either argument is an image, or

  * a number when both are numbers.

  ### Examples

      iex> use Image.Math
      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(image * 2, 0, 0)
      [20.0, 40.0, 60.0]

  """
  @spec operand() * operand() :: Vimage.t() | number()
  def a * b do
    multiply!(a, b)
  end

  @doc """
  Divides one image by another, an image by a number or a list of numbers, or a number by an image, pixel by pixel.

  Delegates to `Kernel.//2` when neither argument is an image.
  Raises `Image.Error` if the operation fails.

  ### Arguments

  * `a` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `b` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * an image when either argument is an image, or

  * a number when both are numbers.

  ### Examples

      iex> use Image.Math
      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(image / 2, 0, 0)
      [5.0, 10.0, 15.0]

  """
  @spec operand() / operand() :: Vimage.t() | number()
  def a / b do
    divide!(a, b)
  end

  @doc """
  Raises each pixel of an image to a power, given as a number or as the
  matching pixel of a second image, or a number to the power of each pixel.

  Delegates to `Kernel.**/2` when neither argument is an image.
  Raises `Image.Error` if the operation fails.

  ### Arguments

  * `a` is any `t:Vix.Vips.Image.t/0` or a number.

  * `b` is any `t:Vix.Vips.Image.t/0` or a number.

  ### Returns

  * an image when either argument is an image, or

  * a number when both are numbers.

  ### Examples

      iex> use Image.Math
      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(image ** 2, 0, 0)
      [100.0, 400.0, 900.0]

  """
  @spec (Vimage.t() | number()) ** (Vimage.t() | number()) :: Vimage.t() | number()
  def a ** b do
    pow!(a, b)
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, returning an image that is `255` in each band of each
  pixel where `a` is less than `b`, and `0` elsewhere.

  Delegates to `Kernel.</2` when neither argument is an image, and
  either argument may be the image. Raises `Image.Error` if the operation fails.

  ### Arguments

  * `a` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `b` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * the comparison image when either argument is an image, or

  * a boolean when neither is.

  ### Examples

      iex> use Image.Math
      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(image < 20, 0, 0)
      [255, 0, 0]

  """
  @spec term() < term() :: Vimage.t() | boolean()
  def a < b do
    less_than!(a, b)
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, returning an image that is `255` in each band of each
  pixel where `a` is less than or equal to `b`, and `0` elsewhere.

  Delegates to `Kernel.<=/2` when neither argument is an image, and
  either argument may be the image. Raises `Image.Error` if the operation fails.

  ### Arguments

  * `a` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `b` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * the comparison image when either argument is an image, or

  * a boolean when neither is.

  ### Examples

      iex> use Image.Math
      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(image <= 20, 0, 0)
      [255, 255, 0]

  """
  @spec term() <= term() :: Vimage.t() | boolean()
  def a <= b do
    less_than_or_equal!(a, b)
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, returning an image that is `255` in each band of each
  pixel where `a` is greater than `b`, and `0` elsewhere.

  Delegates to `Kernel.>/2` when neither argument is an image, and
  either argument may be the image. Raises `Image.Error` if the operation fails.

  ### Arguments

  * `a` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `b` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * the comparison image when either argument is an image, or

  * a boolean when neither is.

  ### Examples

      iex> use Image.Math
      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(image > 20, 0, 0)
      [0, 0, 255]

  """
  @spec term() > term() :: Vimage.t() | boolean()
  def a > b do
    greater_than!(a, b)
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, returning an image that is `255` in each band of each
  pixel where `a` is greater than or equal to `b`, and `0` elsewhere.

  Delegates to `Kernel.>=/2` when neither argument is an image, and
  either argument may be the image. Raises `Image.Error` if the operation fails.

  ### Arguments

  * `a` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `b` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * the comparison image when either argument is an image, or

  * a boolean when neither is.

  ### Examples

      iex> use Image.Math
      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(image >= 20, 0, 0)
      [0, 255, 255]

  """
  @spec term() >= term() :: Vimage.t() | boolean()
  def a >= b do
    greater_than_or_equal!(a, b)
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, returning an image that is `255` in each band of each
  pixel where `a` is equal to `b`, and `0` elsewhere.

  Delegates to `Kernel.==/2` when neither argument is an image, and
  either argument may be the image. Raises `Image.Error` if the operation fails.

  ### Arguments

  * `a` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `b` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * the comparison image when either argument is an image, or

  * a boolean when neither is.

  ### Examples

      iex> use Image.Math
      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(image == [10, 20, 30], 0, 0)
      [255, 255, 255]

  """
  @spec term() == term() :: Vimage.t() | boolean()
  def a == b do
    equal!(a, b)
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, returning an image that is `255` in each band of each
  pixel where `a` is not equal to `b`, and `0` elsewhere.

  Delegates to `Kernel.!=/2` when neither argument is an image, and
  either argument may be the image. Raises `Image.Error` if the operation fails.

  ### Arguments

  * `a` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `b` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * the comparison image when either argument is an image, or

  * a boolean when neither is.

  ### Examples

      iex> use Image.Math
      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(image != [10, 20, 30], 0, 0)
      [0, 0, 0]

  """
  @spec term() != term() :: Vimage.t() | boolean()
  def a != b do
    not_equal!(a, b)
  end

  @doc """
  Returns the bitwise *and*, band by band, of two images.

  Raises `Image.Error` if the operation fails. Delegates to
  `Bitwise.&&&/2` when neither argument is an image.

  ### Arguments

  * `a` is any `t:Vix.Vips.Image.t/0` or an integer.

  * `b` is any `t:Vix.Vips.Image.t/0` or an integer.

  ### Returns

  * the resulting image when either argument is an image, or

  * an integer when neither is.

  ### Examples

      iex> use Image.Math
      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(image &&& image, 0, 0)
      [10, 20, 30]

  """
  @spec (Vimage.t() | integer()) &&& (Vimage.t() | integer()) :: Vimage.t() | integer()
  def a &&& b do
    boolean_and!(a, b)
  end

  @doc """
  Returns the bitwise *or*, band by band, of two images.

  Raises `Image.Error` if the operation fails. Delegates to
  `Bitwise.|||/2` when neither argument is an image.

  ### Arguments

  * `a` is any `t:Vix.Vips.Image.t/0` or an integer.

  * `b` is any `t:Vix.Vips.Image.t/0` or an integer.

  ### Returns

  * the resulting image when either argument is an image, or

  * an integer when neither is.

  ### Examples

      iex> use Image.Math
      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(image ||| image, 0, 0)
      [10, 20, 30]

  """
  @spec (Vimage.t() | integer()) ||| (Vimage.t() | integer()) :: Vimage.t() | integer()
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
  Returns the left shift of the first image's pixels by the number of bits in the second's, band by band, of two images.

  Raises `Image.Error` if the operation fails. Delegates to
  `Bitwise.<<</2` when neither argument is an image.

  ### Arguments

  * `a` is any `t:Vix.Vips.Image.t/0` or an integer.

  * `b` is any `t:Vix.Vips.Image.t/0` or an integer.

  ### Returns

  * the resulting image when either argument is an image, or

  * an integer when neither is.

  ### Examples

      iex> use Image.Math
      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> one = Image.new!(2, 2, color: [1, 1, 1])
      iex> Image.get_pixel!(image <<< one, 0, 0)
      [20, 40, 60]

  """
  @spec (Vimage.t() | integer()) <<< (Vimage.t() | integer()) :: Vimage.t() | integer()
  def a <<< b do
    boolean_lshift!(a, b)
  end

  @doc """
  Returns the right shift of the first image's pixels by the number of bits in the second's, band by band, of two images.

  Raises `Image.Error` if the operation fails. Delegates to
  `Bitwise.>>>/2` when neither argument is an image.

  ### Arguments

  * `a` is any `t:Vix.Vips.Image.t/0` or an integer.

  * `b` is any `t:Vix.Vips.Image.t/0` or an integer.

  ### Returns

  * the resulting image when either argument is an image, or

  * an integer when neither is.

  ### Examples

      iex> use Image.Math
      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> one = Image.new!(2, 2, color: [1, 1, 1])
      iex> Image.get_pixel!(image >>> one, 0, 0)
      [5, 10, 15]

  """
  @spec (Vimage.t() | integer()) >>> (Vimage.t() | integer()) :: Vimage.t() | integer()
  def a >>> b do
    boolean_rshift!(a, b)
  end

  @doc """
  Raises *e* to the power of each pixel value of an image,
  band by band, or of a number.

  ### Arguments

  * `value` is any `t:Vix.Vips.Image.t/0` or a number.

  ### Returns

  * `{:ok, image}` for an image, or

  * `{:ok, float}` for a number, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(1, 1, color: [0, 1, 2])
      iex> {:ok, result} = Image.Math.exp(image)
      iex> Enum.map(Image.get_pixel!(result, 0, 0), &Float.round(&1, 3))
      [1.0, 2.718, 7.389]

      iex> Image.Math.exp(0)
      {:ok, 1.0}

  """
  @spec exp(Vimage.t() | number()) :: {:ok, Vimage.t() | float()} | {:error, Image.error()}
  def exp(%Vimage{} = image) do
    Operation.math(image, :VIPS_OPERATION_MATH_EXP)
  end

  def exp(number) when is_number(number) do
    {:ok, :math.exp(number)}
  end

  def exp(other) do
    invalid_operands(:exp, [other])
  end

  @doc """
  Returns the absolute value of each pixel of an image,
  or of a number.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0` or a number.

  ### Returns

  * `{:ok, image}` for an image, or

  * `{:ok, number}` for a number, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(1, 1, color: [1, 2, 3])
      iex> {:ok, result} = Image.Math.abs(Image.Math.subtract!(image, 5))
      iex> Image.get_pixel!(result, 0, 0)
      [4.0, 3.0, 2.0]

      iex> Image.Math.abs(-3)
      {:ok, 3}

  """
  @spec abs(Vimage.t() | number()) :: {:ok, Vimage.t() | number()} | {:error, Image.error()}
  def abs(%Vimage{} = image) do
    Operation.abs(image)
  end

  def abs(number) when is_number(number) do
    {:ok, Kernel.abs(number)}
  end

  def abs(other) do
    invalid_operands(:abs, [other])
  end

  @doc """
  Returns the maximum pixel value of an image, across all bands.

  `Image.Math.maxpos/2` also returns where the maximum values are.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, maximum}` where `maximum` is a float, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.Math.max(image)
      {:ok, 30.0}

  """
  @spec max(Vimage.t()) :: {:ok, float()} | {:error, Image.error()}
  def max(%Vimage{} = image) do
    case Operation.max(image) do
      {:ok, {max, _}} -> {:ok, max}
      other -> other
    end
  end

  def max(other) do
    invalid_operands(:max, [other])
  end

  @doc """
  Returns the minimum pixel value of an image, across all bands.

  `Image.Math.minpos/2` also returns where the minimum values are.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, minimum}` where `minimum` is a float, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.Math.min(image)
      {:ok, 10.0}

  """
  @spec min(Vimage.t()) :: {:ok, float()} | {:error, Image.error()}
  def min(%Vimage{} = image) do
    case Operation.min(image) do
      {:ok, {min, _}} -> {:ok, min}
      other -> other
    end
  end

  def min(other) do
    invalid_operands(:min, [other])
  end

  @doc """
  Raises each pixel of an image to a power, given as a number or
  as the matching pixel of a second image, or raises a number to
  the power of each pixel of an image.

  When both arguments are numbers the result is that of `Kernel.**/2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, or a number.

  * `other` is any `t:Vix.Vips.Image.t/0` or a number.

  ### Returns

  * `{:ok, image}` when either argument is an image, or

  * `{:ok, number}` when both are numbers, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(2, 2, color: [1, 2, 3])
      iex> {:ok, result} = Image.Math.pow(image, 2)
      iex> Image.get_pixel!(result, 0, 0)
      [1.0, 4.0, 9.0]
      iex> {:ok, result} = Image.Math.pow(2, image)
      iex> Image.get_pixel!(result, 0, 0)
      [2.0, 4.0, 8.0]

      iex> Image.Math.pow(2, 3)
      {:ok, 8}

  """
  @spec pow(Vimage.t() | number(), Vimage.t() | number()) ::
          {:ok, Vimage.t() | number()} | {:error, Image.error()}

  def pow(%Vimage{} = image, %Vimage{} = image2) do
    Operation.math2(image, image2, :VIPS_OPERATION_MATH2_POW)
  end

  def pow(%Vimage{} = image, value) when is_number(value) do
    Operation.math2_const(image, :VIPS_OPERATION_MATH2_POW, [value])
  end

  # VIPS_OPERATION_MATH2_WOP is pow with its arguments swapped: the
  # constant raised to the power of each pixel.
  def pow(value, %Vimage{} = image) when is_number(value) do
    Operation.math2_const(image, :VIPS_OPERATION_MATH2_WOP, [value])
  end

  def pow(a, b) when is_number(a) and is_number(b) do
    {:ok, Kernel.**(a, b)}
  end

  def pow(a, b) do
    invalid_operands(:pow, [a, b])
  end

  @doc """
  Returns the cosine of each pixel of an image, or of a number.

  Angles are in degrees, for numbers as for the pixel values of
  an image, since that is what libvips uses.

  ### Arguments

  * `value` is any `t:Vix.Vips.Image.t/0` or a number.

  ### Returns

  * `{:ok, image}` for an image, or

  * `{:ok, float}` for a number, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(1, 1, color: [0, 180, 0])
      iex> {:ok, result} = Image.Math.cos(image)
      iex> Image.get_pixel!(result, 0, 0)
      [1.0, -1.0, 1.0]

      iex> Image.Math.cos(180)
      {:ok, -1.0}

  """
  @spec cos(Vimage.t() | number()) :: {:ok, Vimage.t() | float()} | {:error, Image.error()}
  def cos(%Vimage{} = image) do
    Operation.math(image, :VIPS_OPERATION_MATH_COS)
  end

  def cos(degrees) when is_number(degrees) do
    {:ok, :math.cos(degrees * :math.pi() / 180)}
  end

  def cos(other) do
    invalid_operands(:cos, [other])
  end

  @doc """
  Returns the sine of each pixel of an image, or of a number.

  Angles are in degrees, for numbers as for the pixel values of
  an image, since that is what libvips uses.

  ### Arguments

  * `value` is any `t:Vix.Vips.Image.t/0` or a number.

  ### Returns

  * `{:ok, image}` for an image, or

  * `{:ok, float}` for a number, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(1, 1, color: [0, 90, 0])
      iex> {:ok, result} = Image.Math.sin(image)
      iex> Image.get_pixel!(result, 0, 0)
      [0.0, 1.0, 0.0]

      iex> Image.Math.sin(90)
      {:ok, 1.0}

  """
  @spec sin(Vimage.t() | number()) :: {:ok, Vimage.t() | float()} | {:error, Image.error()}
  def sin(%Vimage{} = image) do
    Operation.math(image, :VIPS_OPERATION_MATH_SIN)
  end

  def sin(degrees) when is_number(degrees) do
    {:ok, :math.sin(degrees * :math.pi() / 180)}
  end

  def sin(other) do
    invalid_operands(:sin, [other])
  end

  @doc """
  Adds two images, or an image and a number or a list of numbers, pixel by pixel.

  When both arguments are numbers the result is that of `Kernel.+/2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, or a number.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * `{:ok, image}` when either argument is an image, or

  * `{:ok, number}` when both are numbers, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> {:ok, result} = Image.Math.add(image, [1, 2, 3])
      iex> Image.get_pixel!(result, 0, 0)
      [11.0, 22.0, 33.0]

      iex> Image.Math.add(1, 2)
      {:ok, 3}

  """
  @spec add(operand(), operand()) :: {:ok, Vimage.t() | number()} | {:error, Image.error()}
  def add(%Vimage{} = image, %Vimage{} = image2) do
    Operation.add(image, image2)
  end

  def add(%Vimage{} = image, value) when is_number(value) do
    add(image, [value])
  end

  def add(%Vimage{} = image, value) when is_list(value) do
    Operation.linear(image, [1.0], value)
  end

  def add(value, %Vimage{} = image) when is_pixel(value) do
    add(image, value)
  end

  def add(a, b) when is_number(a) and is_number(b) do
    {:ok, Kernel.+(a, b)}
  end

  def add(a, b) do
    invalid_operands(:add, [a, b])
  end

  @doc """
  Subtracts one image from another, or a number or a list of numbers from an image, or an image from a number, pixel by pixel.

  When both arguments are numbers the result is that of `Kernel.-/2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, or a number.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * `{:ok, image}` when either argument is an image, or

  * `{:ok, number}` when both are numbers, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> {:ok, result} = Image.Math.subtract(image, [1, 2, 3])
      iex> Image.get_pixel!(result, 0, 0)
      [9.0, 18.0, 27.0]

      iex> Image.Math.subtract(3, 1)
      {:ok, 2}

  """
  @spec subtract(operand(), operand()) :: {:ok, Vimage.t() | number()} | {:error, Image.error()}
  def subtract(%Vimage{} = image, %Vimage{} = image2) do
    Operation.subtract(image, image2)
  end

  def subtract(%Vimage{} = image, value) when is_number(value) do
    subtract(image, [value])
  end

  def subtract(%Vimage{} = image, value) when is_list(value) do
    Operation.linear(image, [1.0], Enum.map(value, &(-&1)))
  end

  def subtract(value, %Vimage{} = image) when is_pixel(value) do
    with {:ok, negated} <- multiply(image, -1) do
      add(negated, value)
    end
  end

  def subtract(a, b) when is_number(a) and is_number(b) do
    {:ok, Kernel.-(a, b)}
  end

  def subtract(a, b) do
    invalid_operands(:subtract, [a, b])
  end

  @doc """
  Multiplies two images, or an image and a number or a list of numbers, pixel by pixel.

  When both arguments are numbers the result is that of `Kernel.*/2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, or a number.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * `{:ok, image}` when either argument is an image, or

  * `{:ok, number}` when both are numbers, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> {:ok, result} = Image.Math.multiply(image, [1, 2, 3])
      iex> Image.get_pixel!(result, 0, 0)
      [10.0, 40.0, 90.0]

      iex> Image.Math.multiply(2, 3)
      {:ok, 6}

  """
  @spec multiply(operand(), operand()) :: {:ok, Vimage.t() | number()} | {:error, Image.error()}
  def multiply(%Vimage{} = image, %Vimage{} = image2) do
    Operation.multiply(image, image2)
  end

  def multiply(%Vimage{} = image, value) when is_number(value) do
    multiply(image, [value])
  end

  def multiply(%Vimage{} = image, value) when is_list(value) do
    Operation.linear(image, value, [0.0])
  end

  def multiply(value, %Vimage{} = image) when is_pixel(value) do
    multiply(image, value)
  end

  def multiply(a, b) when is_number(a) and is_number(b) do
    {:ok, Kernel.*(a, b)}
  end

  def multiply(a, b) do
    invalid_operands(:multiply, [a, b])
  end

  @doc """
  Divides one image by another, an image by a number or a list of numbers, or a number by an image, pixel by pixel.

  When both arguments are numbers the result is that of `Kernel.//2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, or a number.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * `{:ok, image}` when either argument is an image, or

  * `{:ok, number}` when both are numbers, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> {:ok, result} = Image.Math.divide(image, [1, 2, 3])
      iex> Image.get_pixel!(result, 0, 0)
      [10.0, 10.0, 10.0]

      iex> Image.Math.divide(6, 3)
      {:ok, 2.0}

  """
  @spec divide(operand(), operand()) :: {:ok, Vimage.t() | number()} | {:error, Image.error()}
  def divide(%Vimage{} = image, %Vimage{} = image2) do
    Operation.divide(image, image2)
  end

  def divide(%Vimage{} = image, value) when is_number(value) do
    divide(image, [value])
  end

  def divide(%Vimage{} = image, value) when is_list(value) do
    Operation.linear(image, Enum.map(value, &(1.0 / &1)), [0.0])
  end

  # See https://github.com/libvips/libvips/blob/master/cplusplus/VImage.cpp#L1062-L1066
  def divide(value, %Vimage{} = image) when is_pixel(value) do
    with {:ok, reciprocal} <- pow(image, -1.0) do
      multiply(reciprocal, value)
    end
  end

  def divide(a, b) when is_number(a) and is_number(b) do
    {:ok, Kernel./(a, b)}
  end

  def divide(a, b) do
    invalid_operands(:divide, [a, b])
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, and returns an image that is `255` in each band of each
  pixel where `image` is less than `other`, and `0` elsewhere.

  The image may be either argument: `less_than(5, image)` compares
  `5` with each pixel.

  One of the two arguments must be an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * `{:ok, comparison_image}`, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> {:ok, result} = Image.Math.less_than(image, 20)
      iex> Image.get_pixel!(result, 0, 0)
      [255, 0, 0]

  """
  @spec less_than(Vimage.t() | Image.pixel(), Vimage.t() | Image.pixel()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}

  def less_than(%Vimage{} = image, %Vimage{} = other) do
    Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_LESS)
  end

  def less_than(%Vimage{} = image, other) when is_pixel(other) do
    Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_LESS, List.wrap(other))
  end

  def less_than(other, %Vimage{} = image) when is_pixel(other) do
    greater_than(image, other)
  end

  def less_than(a, b) do
    invalid_operands(:less_than, [a, b])
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, and returns an image that is `255` in each band of each
  pixel where `image` is less than or equal to `other`, and `0` elsewhere.

  The image may be either argument: `less_than_or_equal(5, image)` compares
  `5` with each pixel.

  One of the two arguments must be an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * `{:ok, comparison_image}`, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> {:ok, result} = Image.Math.less_than_or_equal(image, 20)
      iex> Image.get_pixel!(result, 0, 0)
      [255, 255, 0]

  """
  @spec less_than_or_equal(Vimage.t() | Image.pixel(), Vimage.t() | Image.pixel()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}

  def less_than_or_equal(%Vimage{} = image, %Vimage{} = other) do
    Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_LESSEQ)
  end

  def less_than_or_equal(%Vimage{} = image, other) when is_pixel(other) do
    Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_LESSEQ, List.wrap(other))
  end

  def less_than_or_equal(other, %Vimage{} = image) when is_pixel(other) do
    greater_than_or_equal(image, other)
  end

  def less_than_or_equal(a, b) do
    invalid_operands(:less_than_or_equal, [a, b])
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, and returns an image that is `255` in each band of each
  pixel where `image` is greater than `other`, and `0` elsewhere.

  The image may be either argument: `greater_than(5, image)` compares
  `5` with each pixel.

  One of the two arguments must be an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * `{:ok, comparison_image}`, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> {:ok, result} = Image.Math.greater_than(image, 20)
      iex> Image.get_pixel!(result, 0, 0)
      [0, 0, 255]

  """
  @spec greater_than(Vimage.t() | Image.pixel(), Vimage.t() | Image.pixel()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}

  def greater_than(%Vimage{} = image, %Vimage{} = other) do
    Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_MORE)
  end

  def greater_than(%Vimage{} = image, other) when is_pixel(other) do
    Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_MORE, List.wrap(other))
  end

  def greater_than(other, %Vimage{} = image) when is_pixel(other) do
    less_than(image, other)
  end

  def greater_than(a, b) do
    invalid_operands(:greater_than, [a, b])
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, and returns an image that is `255` in each band of each
  pixel where `image` is greater than or equal to `other`, and `0` elsewhere.

  The image may be either argument: `greater_than_or_equal(5, image)` compares
  `5` with each pixel.

  One of the two arguments must be an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * `{:ok, comparison_image}`, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> {:ok, result} = Image.Math.greater_than_or_equal(image, 20)
      iex> Image.get_pixel!(result, 0, 0)
      [0, 255, 255]

  """
  @spec greater_than_or_equal(Vimage.t() | Image.pixel(), Vimage.t() | Image.pixel()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}

  def greater_than_or_equal(%Vimage{} = image, %Vimage{} = other) do
    Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_MOREEQ)
  end

  def greater_than_or_equal(%Vimage{} = image, other) when is_pixel(other) do
    Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_MOREEQ, List.wrap(other))
  end

  def greater_than_or_equal(other, %Vimage{} = image) when is_pixel(other) do
    less_than_or_equal(image, other)
  end

  def greater_than_or_equal(a, b) do
    invalid_operands(:greater_than_or_equal, [a, b])
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, and returns an image that is `255` in each band of each
  pixel where `image` is equal to `other`, and `0` elsewhere.

  The image may be either argument: `equal(5, image)` compares
  `5` with each pixel.

  One of the two arguments must be an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * `{:ok, comparison_image}`, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> {:ok, result} = Image.Math.equal(image, [10, 0, 30])
      iex> Image.get_pixel!(result, 0, 0)
      [255, 0, 255]

  """
  @spec equal(Vimage.t() | Image.pixel(), Vimage.t() | Image.pixel()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}

  def equal(%Vimage{} = image, %Vimage{} = other) do
    Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_EQUAL)
  end

  def equal(%Vimage{} = image, other) when is_pixel(other) do
    Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_EQUAL, List.wrap(other))
  end

  def equal(other, %Vimage{} = image) when is_pixel(other) do
    equal(image, other)
  end

  def equal(a, b) do
    invalid_operands(:equal, [a, b])
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, and returns an image that is `255` in each band of each
  pixel where `image` is not equal to `other`, and `0` elsewhere.

  The image may be either argument: `not_equal(5, image)` compares
  `5` with each pixel.

  One of the two arguments must be an image.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * `{:ok, comparison_image}`, or

  * `{:error, reason}`.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> {:ok, result} = Image.Math.not_equal(image, [10, 0, 30])
      iex> Image.get_pixel!(result, 0, 0)
      [0, 255, 0]

  """
  @spec not_equal(Vimage.t() | Image.pixel(), Vimage.t() | Image.pixel()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}

  def not_equal(%Vimage{} = image, %Vimage{} = other) do
    Operation.relational(image, other, :VIPS_OPERATION_RELATIONAL_NOTEQ)
  end

  def not_equal(%Vimage{} = image, other) when is_pixel(other) do
    Operation.relational_const(image, :VIPS_OPERATION_RELATIONAL_NOTEQ, List.wrap(other))
  end

  def not_equal(other, %Vimage{} = image) when is_pixel(other) do
    not_equal(image, other)
  end

  def not_equal(a, b) do
    invalid_operands(:not_equal, [a, b])
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, and returns an image that is `255` in each band of each
  pixel where `image` is less than `other`, and `0` elsewhere.

  The image may be either argument: `less_than(5, image)` compares
  `5` with each pixel.

  Raises `Image.Error` on error. When neither argument is an image
  the result is that of `Kernel.</2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * the comparison image when either argument is an image, or

  * a boolean when neither is.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(Image.Math.less_than!(image, 20), 0, 0)
      [255, 0, 0]

      iex> Image.Math.less_than!(1, 2)
      true

  """
  @spec less_than!(term(), term()) :: Vimage.t() | boolean() | no_return()
  def less_than!(a, b) when is_struct(a, Vimage) or is_struct(b, Vimage) do
    unwrap!(less_than(a, b))
  end

  def less_than!(a, b) do
    Kernel.<(a, b)
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, and returns an image that is `255` in each band of each
  pixel where `image` is less than or equal to `other`, and `0` elsewhere.

  The image may be either argument: `less_than_or_equal(5, image)` compares
  `5` with each pixel.

  Raises `Image.Error` on error. When neither argument is an image
  the result is that of `Kernel.<=/2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * the comparison image when either argument is an image, or

  * a boolean when neither is.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(Image.Math.less_than_or_equal!(image, 20), 0, 0)
      [255, 255, 0]

      iex> Image.Math.less_than_or_equal!(2, 2)
      true

  """
  @spec less_than_or_equal!(term(), term()) :: Vimage.t() | boolean() | no_return()
  def less_than_or_equal!(a, b) when is_struct(a, Vimage) or is_struct(b, Vimage) do
    unwrap!(less_than_or_equal(a, b))
  end

  def less_than_or_equal!(a, b) do
    Kernel.<=(a, b)
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, and returns an image that is `255` in each band of each
  pixel where `image` is greater than `other`, and `0` elsewhere.

  The image may be either argument: `greater_than(5, image)` compares
  `5` with each pixel.

  Raises `Image.Error` on error. When neither argument is an image
  the result is that of `Kernel.>/2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * the comparison image when either argument is an image, or

  * a boolean when neither is.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(Image.Math.greater_than!(image, 20), 0, 0)
      [0, 0, 255]

      iex> Image.Math.greater_than!(1, 2)
      false

  """
  @spec greater_than!(term(), term()) :: Vimage.t() | boolean() | no_return()
  def greater_than!(a, b) when is_struct(a, Vimage) or is_struct(b, Vimage) do
    unwrap!(greater_than(a, b))
  end

  def greater_than!(a, b) do
    Kernel.>(a, b)
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, and returns an image that is `255` in each band of each
  pixel where `image` is greater than or equal to `other`, and `0` elsewhere.

  The image may be either argument: `greater_than_or_equal(5, image)` compares
  `5` with each pixel.

  Raises `Image.Error` on error. When neither argument is an image
  the result is that of `Kernel.>=/2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * the comparison image when either argument is an image, or

  * a boolean when neither is.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(Image.Math.greater_than_or_equal!(image, 20), 0, 0)
      [0, 255, 255]

      iex> Image.Math.greater_than_or_equal!(2, 2)
      true

  """
  @spec greater_than_or_equal!(term(), term()) :: Vimage.t() | boolean() | no_return()
  def greater_than_or_equal!(a, b) when is_struct(a, Vimage) or is_struct(b, Vimage) do
    unwrap!(greater_than_or_equal(a, b))
  end

  def greater_than_or_equal!(a, b) do
    Kernel.>=(a, b)
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, and returns an image that is `255` in each band of each
  pixel where `image` is equal to `other`, and `0` elsewhere.

  The image may be either argument: `equal(5, image)` compares
  `5` with each pixel.

  Raises `Image.Error` on error. When neither argument is an image
  the result is that of `Kernel.==/2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * the comparison image when either argument is an image, or

  * a boolean when neither is.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(Image.Math.equal!(image, [10, 0, 30]), 0, 0)
      [255, 0, 255]

      iex> Image.Math.equal!(2, 2)
      true

  """
  @spec equal!(term(), term()) :: Vimage.t() | boolean() | no_return()
  def equal!(a, b) when is_struct(a, Vimage) or is_struct(b, Vimage) do
    unwrap!(equal(a, b))
  end

  def equal!(a, b) do
    Kernel.==(a, b)
  end

  @doc """
  Compares an image with another image, a number or a list of
  numbers, and returns an image that is `255` in each band of each
  pixel where `image` is not equal to `other`, and `0` elsewhere.

  The image may be either argument: `not_equal(5, image)` compares
  `5` with each pixel.

  Raises `Image.Error` on error. When neither argument is an image
  the result is that of `Kernel.!=/2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * the comparison image when either argument is an image, or

  * a boolean when neither is.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(Image.Math.not_equal!(image, [10, 0, 30]), 0, 0)
      [0, 255, 0]

      iex> Image.Math.not_equal!(2, 2)
      false

  """
  @spec not_equal!(term(), term()) :: Vimage.t() | boolean() | no_return()
  def not_equal!(a, b) when is_struct(a, Vimage) or is_struct(b, Vimage) do
    unwrap!(not_equal(a, b))
  end

  def not_equal!(a, b) do
    Kernel.!=(a, b)
  end

  @doc """
  Adds two images, or an image and a number or a list of numbers, pixel by pixel.

  Raises on error. When both arguments are numbers the result is
  that of `Kernel.+/2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, or a number.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * an image when either argument is an image, or

  * a number when both are numbers.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(Image.Math.add!(image, [1, 2, 3]), 0, 0)
      [11.0, 22.0, 33.0]

      iex> Image.Math.add!(1, 2)
      3

  """
  @spec add!(operand(), operand()) :: Vimage.t() | number() | no_return()
  def add!(a, b) when is_struct(a, Vimage) or is_struct(b, Vimage) do
    unwrap!(add(a, b))
  end

  def add!(a, b) do
    Kernel.+(a, b)
  end

  @doc """
  Subtracts one image from another, or a number or a list of numbers from an image, or an image from a number, pixel by pixel.

  Raises on error. When both arguments are numbers the result is
  that of `Kernel.-/2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, or a number.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * an image when either argument is an image, or

  * a number when both are numbers.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(Image.Math.subtract!(image, [1, 2, 3]), 0, 0)
      [9.0, 18.0, 27.0]

      iex> Image.Math.subtract!(3, 1)
      2

  """
  @spec subtract!(operand(), operand()) :: Vimage.t() | number() | no_return()
  def subtract!(a, b) when is_struct(a, Vimage) or is_struct(b, Vimage) do
    unwrap!(subtract(a, b))
  end

  def subtract!(a, b) do
    Kernel.-(a, b)
  end

  @doc """
  Multiplies two images, or an image and a number or a list of numbers, pixel by pixel.

  Raises on error. When both arguments are numbers the result is
  that of `Kernel.*/2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, or a number.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * an image when either argument is an image, or

  * a number when both are numbers.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(Image.Math.multiply!(image, [1, 2, 3]), 0, 0)
      [10.0, 40.0, 90.0]

      iex> Image.Math.multiply!(2, 3)
      6

  """
  @spec multiply!(operand(), operand()) :: Vimage.t() | number() | no_return()
  def multiply!(a, b) when is_struct(a, Vimage) or is_struct(b, Vimage) do
    unwrap!(multiply(a, b))
  end

  def multiply!(a, b) do
    Kernel.*(a, b)
  end

  @doc """
  Divides one image by another, an image by a number or a list of numbers, or a number by an image, pixel by pixel.

  Raises on error. When both arguments are numbers the result is
  that of `Kernel.//2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, or a number.

  * `other` is any `t:Vix.Vips.Image.t/0`, a number, or a list of
    numbers with one number per band.

  ### Returns

  * an image when either argument is an image, or

  * a number when both are numbers.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(Image.Math.divide!(image, [1, 2, 3]), 0, 0)
      [10.0, 10.0, 10.0]

      iex> Image.Math.divide!(6, 3)
      2.0

  """
  @spec divide!(operand(), operand()) :: Vimage.t() | number() | no_return()
  def divide!(a, b) when is_struct(a, Vimage) or is_struct(b, Vimage) do
    unwrap!(divide(a, b))
  end

  def divide!(a, b) do
    Kernel./(a, b)
  end

  @doc """
  Raises *e* to the power of each pixel value of an image,
  band by band, or of a number, raising on error.

  ### Arguments

  * `value` is any `t:Vix.Vips.Image.t/0` or a number.

  ### Returns

  * an image for an image, or

  * a float for a number.

  ### Examples

      iex> image = Image.new!(1, 1, color: [0, 1, 2])
      iex> Enum.map(Image.get_pixel!(Image.Math.exp!(image), 0, 0), &Float.round(&1, 3))
      [1.0, 2.718, 7.389]

  """
  @spec exp!(Vimage.t() | number()) :: Vimage.t() | float() | no_return()
  def exp!(value) do
    unwrap!(exp(value))
  end

  @doc """
  Returns the absolute value of each pixel of an image, or of a
  number, raising on error.

  ### Arguments

  * `value` is any `t:Vix.Vips.Image.t/0` or a number.

  ### Returns

  * an image for an image, or

  * a number for a number.

  ### Examples

      iex> image = Image.new!(1, 1, color: [1, 2, 3])
      iex> Image.get_pixel!(Image.Math.abs!(Image.Math.subtract!(image, 5)), 0, 0)
      [4.0, 3.0, 2.0]

      iex> Image.Math.abs!(-3)
      3

  """
  @spec abs!(Vimage.t() | number()) :: Vimage.t() | number() | no_return()
  def abs!(value) do
    unwrap!(abs(value))
  end

  @doc """
  Returns the maximum pixel value of an image, across all bands,
  raising on error.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * the maximum as a float.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.Math.max!(image)
      30.0

  """
  @spec max!(Vimage.t()) :: float() | no_return()
  def max!(value) do
    unwrap!(max(value))
  end

  @doc """
  Returns the minimum pixel value of an image, across all bands,
  raising on error.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * the minimum as a float.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.Math.min!(image)
      10.0

  """
  @spec min!(Vimage.t()) :: float() | no_return()
  def min!(value) do
    unwrap!(min(value))
  end

  @doc """
  Raises each pixel of an image to a power, given as a number or as the matching pixel of a second image.

  Raises on error. When both arguments are numbers the result is
  that of `Kernel.**/2`.

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`, or a number.

  * `other` is any `t:Vix.Vips.Image.t/0` or a number.

  ### Returns

  * an image when either argument is an image, or

  * a number when both are numbers.

  ### Examples

      iex> image = Image.new!(2, 2, color: [10, 20, 30])
      iex> Image.get_pixel!(Image.Math.pow!(image, 2), 0, 0)
      [100.0, 400.0, 900.0]

      iex> Image.Math.pow!(2, 3)
      8

  """
  @spec pow!(operand(), operand()) :: Vimage.t() | number() | no_return()
  def pow!(a, b) when is_struct(a, Vimage) or is_struct(b, Vimage) do
    unwrap!(pow(a, b))
  end

  def pow!(a, b) do
    Kernel.**(a, b)
  end

  @doc """
  Returns the cosine of each pixel of an image, or of a number,
  raising on error.

  Angles are in degrees.

  ### Arguments

  * `value` is any `t:Vix.Vips.Image.t/0` or a number.

  ### Returns

  * an image for an image, or

  * a float for a number.

  ### Examples

      iex> image = Image.new!(1, 1, color: [0, 180, 0])
      iex> Image.get_pixel!(Image.Math.cos!(image), 0, 0)
      [1.0, -1.0, 1.0]

      iex> Image.Math.cos!(180)
      -1.0

  """
  @spec cos!(Vimage.t() | number()) :: Vimage.t() | float() | no_return()
  def cos!(value) do
    unwrap!(cos(value))
  end

  @doc """
  Returns the sine of each pixel of an image, or of a number,
  raising on error.

  Angles are in degrees.

  ### Arguments

  * `value` is any `t:Vix.Vips.Image.t/0` or a number.

  ### Returns

  * an image for an image, or

  * a float for a number.

  ### Examples

      iex> image = Image.new!(1, 1, color: [0, 90, 0])
      iex> Image.get_pixel!(Image.Math.sin!(image), 0, 0)
      [0.0, 1.0, 0.0]

      iex> Image.Math.sin!(90)
      1.0

  """
  @spec sin!(Vimage.t() | number()) :: Vimage.t() | float() | no_return()
  def sin!(value) do
    unwrap!(sin(value))
  end

  ### Logical operations

  @doc """
  Returns the bitwise *and*, band by band, of two images.

  ### Arguments

  * `image_1` is any `t:Vix.Vips.Image.t/0`.

  * `image_2` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, image}`, or

  * `{:error, reason}`.

  ### Examples

      iex> image_1 = Image.new!(2, 2, color: [10, 20, 30])
      iex> image_2 = Image.new!(2, 2, color: [1, 2, 3])
      iex> {:ok, result} = Image.Math.boolean_and(image_1, image_2)
      iex> Image.get_pixel!(result, 0, 0)
      [0, 0, 2]

  """
  @spec boolean_and(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}
  def boolean_and(%Vimage{} = image_1, %Vimage{} = image_2) do
    Operation.boolean(image_1, image_2, :VIPS_OPERATION_BOOLEAN_AND)
  end

  def boolean_and(image_1, image_2) do
    invalid_operands(:boolean_and, [image_1, image_2])
  end

  @doc """
  Returns the bitwise *and*, band by band, of two images.

  Raises `Image.Error` on error. When neither argument is an image
  the result is that of `Bitwise.band/2`.

  ### Arguments

  * `image_1` is any `t:Vix.Vips.Image.t/0` or an integer.

  * `image_2` is any `t:Vix.Vips.Image.t/0` or an integer.

  ### Returns

  * the resulting image when either argument is an image, or

  * an integer when neither is.

  ### Examples

      iex> image_1 = Image.new!(2, 2, color: [10, 20, 30])
      iex> image_2 = Image.new!(2, 2, color: [1, 2, 3])
      iex> Image.get_pixel!(Image.Math.boolean_and!(image_1, image_2), 0, 0)
      [0, 0, 2]

      iex> Image.Math.boolean_and!(6, 3)
      2

  """
  @spec boolean_and!(Vimage.t() | integer(), Vimage.t() | integer()) ::
          Vimage.t() | integer() | no_return()
  def boolean_and!(a, b) when is_struct(a, Vimage) or is_struct(b, Vimage) do
    unwrap!(boolean_and(a, b))
  end

  def boolean_and!(a, b) do
    Bitwise.band(a, b)
  end

  @doc """
  Returns the bitwise *or*, band by band, of two images.

  ### Arguments

  * `image_1` is any `t:Vix.Vips.Image.t/0`.

  * `image_2` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, image}`, or

  * `{:error, reason}`.

  ### Examples

      iex> image_1 = Image.new!(2, 2, color: [10, 20, 30])
      iex> image_2 = Image.new!(2, 2, color: [1, 2, 3])
      iex> {:ok, result} = Image.Math.boolean_or(image_1, image_2)
      iex> Image.get_pixel!(result, 0, 0)
      [11, 22, 31]

  """
  @spec boolean_or(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}
  def boolean_or(%Vimage{} = image_1, %Vimage{} = image_2) do
    Operation.boolean(image_1, image_2, :VIPS_OPERATION_BOOLEAN_OR)
  end

  def boolean_or(image_1, image_2) do
    invalid_operands(:boolean_or, [image_1, image_2])
  end

  @doc """
  Returns the bitwise *or*, band by band, of two images.

  Raises `Image.Error` on error. When neither argument is an image
  the result is that of `Bitwise.bor/2`.

  ### Arguments

  * `image_1` is any `t:Vix.Vips.Image.t/0` or an integer.

  * `image_2` is any `t:Vix.Vips.Image.t/0` or an integer.

  ### Returns

  * the resulting image when either argument is an image, or

  * an integer when neither is.

  ### Examples

      iex> image_1 = Image.new!(2, 2, color: [10, 20, 30])
      iex> image_2 = Image.new!(2, 2, color: [1, 2, 3])
      iex> Image.get_pixel!(Image.Math.boolean_or!(image_1, image_2), 0, 0)
      [11, 22, 31]

      iex> Image.Math.boolean_or!(6, 3)
      7

  """
  @spec boolean_or!(Vimage.t() | integer(), Vimage.t() | integer()) ::
          Vimage.t() | integer() | no_return()
  def boolean_or!(a, b) when is_struct(a, Vimage) or is_struct(b, Vimage) do
    unwrap!(boolean_or(a, b))
  end

  def boolean_or!(a, b) do
    Bitwise.bor(a, b)
  end

  @doc """
  Returns the bitwise *exclusive or*, band by band, of two images.

  ### Arguments

  * `image_1` is any `t:Vix.Vips.Image.t/0`.

  * `image_2` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, image}`, or

  * `{:error, reason}`.

  ### Examples

      iex> image_1 = Image.new!(2, 2, color: [10, 20, 30])
      iex> image_2 = Image.new!(2, 2, color: [1, 2, 3])
      iex> {:ok, result} = Image.Math.boolean_xor(image_1, image_2)
      iex> Image.get_pixel!(result, 0, 0)
      [11, 22, 29]

  """
  @spec boolean_xor(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}
  def boolean_xor(%Vimage{} = image_1, %Vimage{} = image_2) do
    Operation.boolean(image_1, image_2, :VIPS_OPERATION_BOOLEAN_EOR)
  end

  def boolean_xor(image_1, image_2) do
    invalid_operands(:boolean_xor, [image_1, image_2])
  end

  @doc """
  Returns the bitwise *exclusive or*, band by band, of two images.

  Raises `Image.Error` on error. When neither argument is an image
  the result is that of `Bitwise.bxor/2`.

  ### Arguments

  * `image_1` is any `t:Vix.Vips.Image.t/0` or an integer.

  * `image_2` is any `t:Vix.Vips.Image.t/0` or an integer.

  ### Returns

  * the resulting image when either argument is an image, or

  * an integer when neither is.

  ### Examples

      iex> image_1 = Image.new!(2, 2, color: [10, 20, 30])
      iex> image_2 = Image.new!(2, 2, color: [1, 2, 3])
      iex> Image.get_pixel!(Image.Math.boolean_xor!(image_1, image_2), 0, 0)
      [11, 22, 29]

      iex> Image.Math.boolean_xor!(6, 3)
      5

  """
  @spec boolean_xor!(Vimage.t() | integer(), Vimage.t() | integer()) ::
          Vimage.t() | integer() | no_return()
  def boolean_xor!(a, b) when is_struct(a, Vimage) or is_struct(b, Vimage) do
    unwrap!(boolean_xor(a, b))
  end

  def boolean_xor!(a, b) do
    Bitwise.bxor(a, b)
  end

  @doc """
  Returns the left shift of the first image's pixels by the number of bits in the second's, band by band, of two images.

  ### Arguments

  * `image_1` is any `t:Vix.Vips.Image.t/0`.

  * `image_2` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, image}`, or

  * `{:error, reason}`.

  ### Examples

      iex> image_1 = Image.new!(2, 2, color: [10, 20, 30])
      iex> image_2 = Image.new!(2, 2, color: [1, 2, 3])
      iex> {:ok, result} = Image.Math.boolean_lshift(image_1, image_2)
      iex> Image.get_pixel!(result, 0, 0)
      [20, 80, 240]

  """
  @spec boolean_lshift(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}
  def boolean_lshift(%Vimage{} = image_1, %Vimage{} = image_2) do
    Operation.boolean(image_1, image_2, :VIPS_OPERATION_BOOLEAN_LSHIFT)
  end

  def boolean_lshift(image_1, image_2) do
    invalid_operands(:boolean_lshift, [image_1, image_2])
  end

  @doc """
  Returns the left shift of the first image's pixels by the number of bits in the second's, band by band, of two images.

  Raises `Image.Error` on error. When neither argument is an image
  the result is that of `Bitwise.bsl/2`.

  ### Arguments

  * `image_1` is any `t:Vix.Vips.Image.t/0` or an integer.

  * `image_2` is any `t:Vix.Vips.Image.t/0` or an integer.

  ### Returns

  * the resulting image when either argument is an image, or

  * an integer when neither is.

  ### Examples

      iex> image_1 = Image.new!(2, 2, color: [10, 20, 30])
      iex> image_2 = Image.new!(2, 2, color: [1, 2, 3])
      iex> Image.get_pixel!(Image.Math.boolean_lshift!(image_1, image_2), 0, 0)
      [20, 80, 240]

      iex> Image.Math.boolean_lshift!(1, 4)
      16

  """
  @spec boolean_lshift!(Vimage.t() | integer(), Vimage.t() | integer()) ::
          Vimage.t() | integer() | no_return()
  def boolean_lshift!(a, b) when is_struct(a, Vimage) or is_struct(b, Vimage) do
    unwrap!(boolean_lshift(a, b))
  end

  def boolean_lshift!(a, b) do
    Bitwise.bsl(a, b)
  end

  @doc """
  Returns the right shift of the first image's pixels by the number of bits in the second's, band by band, of two images.

  ### Arguments

  * `image_1` is any `t:Vix.Vips.Image.t/0`.

  * `image_2` is any `t:Vix.Vips.Image.t/0`.

  ### Returns

  * `{:ok, image}`, or

  * `{:error, reason}`.

  ### Examples

      iex> image_1 = Image.new!(2, 2, color: [10, 20, 30])
      iex> image_2 = Image.new!(2, 2, color: [1, 2, 3])
      iex> {:ok, result} = Image.Math.boolean_rshift(image_1, image_2)
      iex> Image.get_pixel!(result, 0, 0)
      [5, 5, 3]

  """
  @spec boolean_rshift(Vimage.t(), Vimage.t()) ::
          {:ok, Vimage.t()} | {:error, Image.error()}
  def boolean_rshift(%Vimage{} = image_1, %Vimage{} = image_2) do
    Operation.boolean(image_1, image_2, :VIPS_OPERATION_BOOLEAN_RSHIFT)
  end

  def boolean_rshift(image_1, image_2) do
    invalid_operands(:boolean_rshift, [image_1, image_2])
  end

  @doc """
  Returns the right shift of the first image's pixels by the number of bits in the second's, band by band, of two images.

  Raises `Image.Error` on error. When neither argument is an image
  the result is that of `Bitwise.bsr/2`.

  ### Arguments

  * `image_1` is any `t:Vix.Vips.Image.t/0` or an integer.

  * `image_2` is any `t:Vix.Vips.Image.t/0` or an integer.

  ### Returns

  * the resulting image when either argument is an image, or

  * an integer when neither is.

  ### Examples

      iex> image_1 = Image.new!(2, 2, color: [10, 20, 30])
      iex> image_2 = Image.new!(2, 2, color: [1, 2, 3])
      iex> Image.get_pixel!(Image.Math.boolean_rshift!(image_1, image_2), 0, 0)
      [5, 5, 3]

      iex> Image.Math.boolean_rshift!(16, 2)
      4

  """
  @spec boolean_rshift!(Vimage.t() | integer(), Vimage.t() | integer()) ::
          Vimage.t() | integer() | no_return()
  def boolean_rshift!(a, b) when is_struct(a, Vimage) or is_struct(b, Vimage) do
    unwrap!(boolean_rshift(a, b))
  end

  def boolean_rshift!(a, b) do
    Bitwise.bsr(a, b)
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

  * `{maximum, x_max, y_max, [{x, y}, ...])`

  ### Example

      iex> {:ok, image} = Vix.Vips.Image.new_from_list([[1, 2], [3, 4]])
      iex> {maximum, x_max, y_max, _coordinates} = Image.Math.top_n(image, 2)
      iex> {maximum, x_max, y_max}
      {4.0, 1, 1}

  """
  @spec top_n(image :: Vimage.t(), n :: non_neg_integer()) ::
          {
            maximum :: float(),
            x_max :: non_neg_integer(),
            y_max :: non_neg_integer(),
            max_coordinates :: [Image.point(), ...]
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

  * `{minimum, x_min, y_min, [{x, y}, ...])`

  ### Example

      iex> {:ok, image} = Vix.Vips.Image.new_from_list([[1, 2], [3, 4]])
      iex> {minimum, x_min, y_min, _coordinates} = Image.Math.bottom_n(image, 2)
      iex> {minimum, x_min, y_min}
      {1.0, 0, 0}

  """
  @spec bottom_n(image :: Vimage.t(), n :: non_neg_integer()) ::
          {
            minimum :: float(),
            x_min :: non_neg_integer(),
            y_min :: non_neg_integer(),
            min_coordinates :: [Image.point(), ...]
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

  * `{maximum, [{x, y}, ...], maybe_overflow)`.  If
    `maybe_overflow` is set to `:maybe_overflow` its an indication
    that the number of coordinates is the same as the requested `n`.
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

      # Since all pixels are red and we want
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
            max_coordinates :: [Image.point(), ...],
            maybe_overflow :: :maybe_overflow | nil
          }
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

  * `{minimum, [{x, y}, ...], maybe_overflow)`.  If
    `maybe_overflow` is set to `:maybe_overflow` its an indication
    that the number of coordinates is the same as the requested `n`.
    Therefore it is possible - maybe even likely - that there are other
    coordinates that have the minimum value but have not been returned.

  ### Example

      iex> {:ok, image} = Vix.Vips.Image.new_from_list([[1, 2], [3, 4]])
      iex> Image.Math.minpos(image, 2)
      {1.0, [{0, 0}], nil}

  """
  @spec minpos(image :: Vimage.t(), n :: non_neg_integer()) ::
          {
            maximum :: number(),
            max_coordinates :: [Image.point(), ...],
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

  defp unwrap!({:ok, value}) do
    value
  end

  defp unwrap!({:error, reason}) do
    raise Image.Error, reason
  end

  defp invalid_operands(function, arguments) do
    message =
      "Invalid arguments to Image.Math.#{function}: " <>
        Enum.map_join(arguments, ", ", &describe_operand/1)

    {:error, %Image.Error{reason: :invalid_argument, value: arguments, message: message}}
  end

  defp describe_operand(%Vimage{}) do
    "an image"
  end

  defp describe_operand(other) do
    inspect(other)
  end
end
