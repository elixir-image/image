defmodule Image.ChromaKey.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport
  alias Vix.Vips.Image, as: Vimage

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  test "Chroma Key an image", %{dir: dir} do
    image = image_path("chroma_key/greenscreen.jpg")

    {:ok, image} = Vimage.new_from_file(image)
    {:ok, meme} = Image.chroma_key(image)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(meme, out_path)

    assert_images_equal out_path, validate_path("chroma_key/person.jpg")
  end
end