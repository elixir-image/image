defmodule Image.Options.Compose do
  @moduledoc """
  This module processes the options for
  `Image.compose/3`.

  Since x,y can be relative or absolution, can be symbolic
  or numeric and can even by a function this becomes more
  complex that it might initially seem

  """

  @typedoc """
  Image compoositions options

  """
  @type t :: list(composition_option())

  @typedoc """
  When composing an image on a base image, these
  options drive how the composition proceeds.

  * `:x` describes the absolute `x` offset on the
    base image where this image will be placed. If
    this option is set to `:left`, `:center` or
    `:right` then the `x` position will be calculated
    relative to the base image. If `:x` is nil
    (the default) then the image will be placed according
    to the relative offset of the previously composed
    image using `:dx`.

  * `:y` describes the absolute `y` offset on the
    base image where this image will be placed. If
    this option is set to `:top`, `:middle` or
    `:bottom` then the `y` position will be calculated
    relative to the base image. If `:y` is nil
    (the default) then the image will be placed according
    to the relative offset of the previously composed
    image using `:dy`.

  * `:dx` describes the relative offset used to calculate
    the `x` value. `:dx` is an integer offset from the
    edge of the previously composed image. Which edge is
    determined by the `:x_baseline` option. If `:x` is also
    specified then `:x` is first calculated, then `:dx` is
    added to it. In this case, `:x_baseline` is ignored.

  * `:dy` describes the relative offset used to calculate
    the `y` value. `:dy` is an integer offset from the
    edge of the previously composed image. Which edge is
    determined by the `:y_baseline` option. If `:y` is also
    specified then `:y` is first calculated, then `:dy` is
    added to it. In this case, `:x_baseline` is ignored.

  * `:blend_mode` is the `t:Image.BlendMode.t/0` used when
    composing this image over its base image. The default
    is `:over` which is appropriate for most use cases.

  * `:x_baseline` establishes the baseline on the
    previously composed image from which `:dx` is
    calculated. The default is `:right`.

  * `:y_baseline` establishes the baseline on the
    previously composed image from which `:dy` is
    calculated. The default is `:bottom`.

  """
  @type composition_option ::
          {:x, non_neg_integer() | nil | :left | :center | :right}
          | {:y, non_neg_integer() | nil | :top | :middle | :bottom}
          | {:dx, integer()}
          | {:dy, integer()}
          | {:blend_mode, Image.BlendMode.t()}
          | {:x_baseline, nil | :left | :center | :right}
          | {:y_baseline, nil | :top | :middle | :bottom}

  @doc false
  def get_x(image, prev_x, prev_width, x, dx, baseline) when is_function(x, 6) do
    x = x.(image, prev_x, prev_width, x, dx, baseline)
    get_x(image, prev_x, prev_width, x, dx, baseline)
  end

  def get_x(image, prev_x, prev_width, x, dx, baseline) when is_function(dx, 6) do
    dx = dx.(image, prev_x, prev_width, x, dx, baseline)
    get_y(image, prev_x, prev_width, x, dx, baseline)
  end

  def get_x(_image, _prev_x, _prev_width, x, dx, _) when is_integer(x) and is_integer(dx) do
    {:ok, x + dx}
  end

  # Centre align to image
  def get_x(image, prev_x, prev_width, :center, dx, _) do
    {:ok, prev_x + div(prev_width, 2) - div(Image.width(image), 2) + dx}
  end

  # Left align to image
  def get_x(_image, prev_x, _prev_width, :left, dx, _) do
    {:ok, prev_x + dx}
  end

  # Right align to image
  def get_x(image, prev_x, prev_width, :right, dx, _) do
    {:ok, prev_x + prev_width - Image.width(image) + dx}
  end

  # Offset from right edge of image
  def get_x(_image, prev_x, prev_width, nil, dx, :right) do
    {:ok, prev_x + prev_width + dx}
  end

  # Offset from left edge of image
  def get_x(_image, prev_x, _prev_width, nil, dx, :left) do
    {:ok, prev_x + dx}
  end

  # Default to right edge of image if no baseline
  def get_x(image, prev_x, prev_width, nil, dx, nil) do
    get_x(image, prev_x, prev_width, nil, dx, :left)
  end

  def get_x(_image, _prev_x, _prev_width, x, _dx, _baseline) do
    {:error, "Invalid value for :x, found #{inspect(x)}"}
  end

  @doc false
  def get_y(image, prev_y, prev_height, y, dy, baseline) when is_function(y, 6) do
    y = y.(image, prev_y, prev_height, y, dy, baseline)
    get_y(image, prev_y, prev_height, y, dy, baseline)
  end

  def get_y(image, prev_y, prev_height, y, dy, baseline) when is_function(dy, 6) do
    dy = dy.(image, prev_y, prev_height, y, dy, baseline)
    get_y(image, prev_y, prev_height, y, dy, baseline)
  end

  def get_y(_image, _prev_y, _prev_width, y, dy, _) when is_integer(y) and is_integer(dy) do
    {:ok, y + dy}
  end

  # Middle align to image
  def get_y(image, prev_y, prev_height, :middle, dy, _) do
    {:ok, prev_y + div(prev_height, 2) - div(Image.height(image), 2) + dy}
  end

  # Top align to image
  def get_y(_image, prev_y, _prev_height, :top, dy, _) do
    {:ok, prev_y + dy}
  end

  # Bottom align to image
  def get_y(image, prev_y, prev_height, :bottom, dy, _) do
    {:ok, prev_y + prev_height - Image.height(image) + dy}
  end

  # Offset from bottom edge of image
  def get_y(_image, prev_y, prev_height, nil, dy, :bottom) do
    {:ok, prev_y + prev_height + dy}
  end

  # Offset from top edge of image
  def get_y(_image, prev_y, _prev_height, nil, dy, :top) do
    {:ok, prev_y + dy}
  end

  # Default to bottom aligned
  def get_y(image, prev_y, prev_height, nil, dy, nil) do
    get_y(image, prev_y, prev_height, nil, dy, :bottom)
  end

  def get_y(_image, _prev_y, _prev_height, y, _dy, _baseline) do
    {:error, "Invalid value for :y, found #{inspect(y)}"}
  end

  def default_composit_options do
    %{
      x: nil,
      y: nil,
      dx: 0,
      dy: 0,
      x_baseline: nil,
      y_baseline: nil,
      blend_mode: Image.BlendMode.default_blend_mode()
    }
  end
end
