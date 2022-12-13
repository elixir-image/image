defmodule Image.Meme.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport
  alias Vix.Vips.Image, as: Vimage

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  @tag :full

  test "Meme image generation", %{dir: dir} do
    image = image_path("meme.jpg")

    {:ok, image} = Vimage.new_from_file(image)

    {:ok, meme} =
      Image.meme(image, "One simply cannot", text: "Enjoy image processing without libvips")

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(meme, out_path)

    assert_images_equal out_path, validate_path("meme/meme.jpg")
  end
end
