defmodule Image.Avatar.Test do
  use ExUnit.Case, async: true

  import Image.TestSupport
  alias Vix.Vips.Image, as: Vimage

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  test "Create avatar", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)

    {:ok, avatar} = Image.avatar(kip)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    validate_path = validate_path("Kip_small_avatar.png")

    assert {:ok, _image} = Image.write(avatar, out_path, quality: 50)

    # Image.write!(avatar, validate_path)

    # IO.inspect Image.shape(avatar), label: "Avatar shape"
    # Image.preview avatar
    # Image.preview Image.open!(validate_path)

    assert_images_equal(out_path, validate_path)
  end

  test "Squircle avatar", %{dir: dir} do
    image = image_path("Kip_small.jpg")
    {:ok, kip} = Vimage.new_from_file(image)

    {:ok, avatar} = Image.avatar(kip, shape: :squircle)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    validate_path = validate_path("Kip_small_avatar_squircle.png")

    assert {:ok, _image} = Image.write(avatar, out_path)

    # Image.write!(avatar, validate_path)

    # IO.inspect Image.shape(avatar), label: "Avatar shape"
    # Image.preview avatar
    # Image.preview Image.open!(validate_path)

    assert_images_equal(out_path, validate_path)
  end

  @tag :text_avatar
  test "Text-based avatar - circle" do
    validate_path = validate_path("text_avatar.png")

    {:ok, avatar} =
      Image.Text.text!("KC", background_fill_color: :cyan, font_size: 200, padding: 80)
      |> Image.avatar(shape: :circle)

    # Image.write!(avatar, validate_path)

    # IO.inspect Image.shape(avatar), label: "Avatar shape"
    # Image.preview avatar
    # Image.preview Image.open!(validate_path)

    assert_images_equal(avatar, validate_path)
  end

  @tag :text_avatar
  test "Text-based avatar - square" do
    validate_path = validate_path("text_avatar_square.png")

    {:ok, avatar} =
      Image.Text.text!("KC", background_fill_color: :cyan, font_size: 200, padding: 80)
      |> Image.avatar(shape: :square)

    # Image.write!(avatar, validate_path)

    # IO.inspect Image.shape(avatar), label: "Avatar shape"
    # Image.preview avatar
    # Image.preview Image.open!(validate_path)

    assert_images_equal(avatar, validate_path)
  end
end
