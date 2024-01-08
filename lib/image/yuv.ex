defmodule Image.YUV do
  alias Vix.Vips.Image, as: Vimage
  alias Vix.Vips.Operation

  @bt601_to_rgb [
    [1.0,  0.0,       1.402   ],
    [1.0, -0.344136, -0.714136],
    [1.0,  1.772,     0.0     ],
  ]

  @bt709_to_rgb [
    [1.0,  0.0,       1.5748  ],
    [1.0, -0.187324, -0.468124],
    [1.0,  1.8556,    0.0     ],
  ]

  def decode(binary, width, height, encoding \\ :C420)

  def decode(binary, width, height, :C420) do
    y_bytes = width * height
    uv_bytes = div(y_bytes, 4)
    <<y::bytes-size(y_bytes), u::bytes-size(uv_bytes), v::bytes-size(uv_bytes)>> = binary
    [y, u, v]
  end

  def to_rgb(%Vimage{} = image, :bt601) do
    with {:ok, transform} <- Vimage.new_from_list(@bt601_to_rgb),
         {:ok, float} <- Operation.recomb(image, transform),
         {:ok, rgb} <- Image.cast(float, {:u, 8}) do
      Operation.copy(rgb, interpretation: :VIPS_INTERPRETATION_sRGB)
    end
  end

  def to_rgb(%Vimage{} = image, :bt709) do
    with {:ok, transform} <- Vimage.new_from_list(@bt709_to_rgb),
         {:ok, float} <- Operation.recomb(image, transform),
         {:ok, rgb} <- Image.cast(float, {:u, 8}) do
      Operation.copy(rgb, interpretation: :VIPS_INTERPRETATION_sRGB)
    end
  end

  def to_rgb([y, u, v], width, height, :C444, colorspace) do
    with {:ok, y} <- new_scaled_image(y, width, height, 1.0, 1.0),
         {:ok, u} <- new_scaled_image(u, width, height, 1.0, 1.0),
         {:ok, v} <- new_scaled_image(v, width, height, 1.0, 1.0),
         {:ok, image_444} <- Operation.bandjoin([y, u, v]) do
      to_rgb(image_444, colorspace)
    end
  end

  def to_rgb([y, u, v], width, height, :C422, colorspace) do
    with {:ok, y} <- new_scaled_image(y, width, height, 1.0, 1.0),
         {:ok, u} <- new_scaled_image(u, width, height, 2.0, 1.0),
         {:ok, v} <- new_scaled_image(v, width, height, 2.0, 1.0),
         {:ok, image_444} <- Operation.bandjoin([y, u, v]) do
      to_rgb(image_444, colorspace)
    end
  end

  def to_rgb([y, u, v], width, height, :C420, colorspace) do
    with {:ok, y} <- new_scaled_image(y, width, height, 1.0, 1.0),
         {:ok, u} <- new_scaled_image(u, width, height, 2.0, 2.0),
         {:ok, v} <- new_scaled_image(v, width, height, 2.0, 2.0),
         {:ok, image_444} <- Operation.bandjoin([y, u, v]) do
      to_rgb(image_444, colorspace)
    end
  end

  defp new_scaled_image(data, width, height, x_scale, y_scale)
      when x_scale == 1.0 and y_scale == 1.0 do
    Vimage.new_from_binary(data, width, height, 1, :VIPS_FORMAT_UCHAR)
  end

  defp new_scaled_image(data, width, height, x_scale, y_scale) do
    width = round(width / x_scale)
    height = round(height / y_scale)

    with {:ok, image} <- Vimage.new_from_binary(data, width, height, 1, :VIPS_FORMAT_UCHAR) do
      Operation.resize(image, x_scale, vscale: y_scale, kernel: :VIPS_KERNEL_LINEAR)
    end
  end
end