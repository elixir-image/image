defmodule Image.Avatar.Test do
  use ExUnit.Case, async: true

  import Image.TestSupport
  alias Vix.Vips.Image, as: Vimage

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  @tag :full
  test "Create avatar", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)

    {:ok, avatar} = Image.avatar(kip)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    validate_path = validate_path("Kip_small_avatar.png")

    assert {:ok, _image} = Image.write(avatar, out_path, quality: 50)

    assert_images_equal(out_path, validate_path)
  end
end
