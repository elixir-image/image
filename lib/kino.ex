defmodule Image.Kino do
  @moduledoc """
  Helper functions to simplify rendering images in Kino.

  """

  # Since Kino is not a required dependency we
  # avoid compiler warnings by using `apply/3`

  alias Vix.Vips.Operation
  alias Vix.Vips.Image, as: Vimage

  @default_max_height 200

  @doc """
  Renders an image in [Kino](https://hex.pm/packages/kino),

  ### Arguments

  * `image` is any `t:Vix.Vips.Image.t/0`.

  * `options` is a keyword list of options.

  ### Options

  * `:max_height` determines the maximum height for the
    rendered image. The aspect ratio of the rendered
    image is unchanged.  The default is `#{inspect(@default_max_height)}`.

  ### Returns

  * `maybe_resized_image` of type `t:Kino.Image.t/0`.

  """
  @doc since: "0.18.0"

  @spec show(image :: Vimage.t(), options :: Keyword.t()) :: Vimage.t()

  def show(%Vimage{} = image, opts \\ []) do
    image = maybe_resize_image(image, opts)

    {:ok, image_bin} = Vimage.write_to_buffer(image, ".png")
    apply(Kino.Image, :new, [image_bin, "image/png"])
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
