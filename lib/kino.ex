defmodule Image.Kino do
  @moduledoc false

  # A convenience module to use with livebooks
  # to render an image using Kino.
  #
  # Since Kino is not a dependency we
  # avoid compiler warnings by using `apply/3`

  alias Vix.Vips.{Operation, Image}

  @default_max_height 200

  def show(%Image{} = image, opts \\ []) do
    image = maybe_resize_image(image, opts)

    {:ok, image_bin} = Image.write_to_buffer(image, ".png")
    kino_image = apply(Kino.Image, :new, [image_bin, "image/png"])
    apply(Kino, :render, [kino_image])

    :ok
  end

  # scale down if image height is larger than max_height
  defp maybe_resize_image(image, opts) do
    height = Image.height(image)
    max_height = Keyword.get(opts, :max_height, @default_max_height)

    if height > max_height do
      Operation.resize!(image, max_height / height)
    else
      image
    end
  end
end
