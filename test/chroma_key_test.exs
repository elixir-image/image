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
    validate_path = validate_path("chroma_key/person.jpg")

    {:ok, image} = Vimage.new_from_file(image)
    {:ok, meme} = Image.chroma_key(image)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    assert :ok = Vimage.write_to_file(meme, out_path)

    # Image.write!(meme, validate_path)
    assert_images_equal out_path, validate_path
  end

  describe "color range bounds" do
    test ":greater_than is the lower bound and :less_than the upper bound" do
      dark = Image.new!(1, 1, color: [0, 0, 0])
      mid = Image.new!(1, 1, color: [100, 100, 100])
      light = Image.new!(1, 1, color: [200, 200, 200])

      {:ok, image} = Image.join([dark, mid, light], across: 3)

      {:ok, mask} =
        Image.chroma_mask(image, greater_than: [50, 50, 50], less_than: [150, 150, 150])

      # Only the pixel inside the range is masked out. The mask keeps (255)
      # everything outside it.
      assert Enum.map(0..2, &Image.get_pixel!(mask, &1, 0)) == [[255], [0], [255]]
    end
  end
end
