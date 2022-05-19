defmodule Image.Options.Compose do
  @moduledoc false

  # Thie module propvides functions to calculate
  # x, y positions for compositions.

  # Since x,y can be relateive or absolution, can be symbolid
  # or numeric and can even by a function this becomse more
  # complex that it might initially seem

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

  # Left align to iamge
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
    {:error, "Invalid value for :x, found #{inspect x}"}
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

  # Top align to iamge
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
    {:error, "Invalid value for :y, found #{inspect y}"}
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