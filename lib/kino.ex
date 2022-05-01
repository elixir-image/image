defmodule Image.Kino do
  @moduledoc false

  # A convenience module to use with livebooks
  # to render an image using Kino.
  #
  # Since Kino is not a dependency and to therefore
  # avoid compiler warnings, we use `apply/3`

  alias Vix.Vips.{Operation, Image}

  @max_height 200

  def show(%Image{} = image) do
    height = Image.height(image)

    # scale down if image height is larger than 500px
    image =
      if height > @max_height do
        Operation.resize!(image, @max_height / height)
      else
        image
      end

    # write vips-image as png image to memory
    {:ok, image_bin} = Image.write_to_buffer(image, ".png")
    kino_image = apply(Kino.Image, :new, [image_bin, "image/png"])
    apply(Kino, :render, [kino_image])

    :ok
  end
end