defmodule Image.Skew.Test do
  use ExUnit.Case, async: true
  import Image.TestSupport

  alias Vix.Vips.Image, as: Vimage

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  test "Autorotate an image based upon the skew angle", %{dir: dir} do
    image = image_path("skewed.jpg")
    {:ok, image} = Vimage.new_from_file(image)

    skew_angle = Image.skew_angle(image)
    {:ok, straight} = Image.rotate(image, skew_angle)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    validate_path = validate_path("skew_correction.jpg")

    assert :ok = Vimage.write_to_file(straight, out_path)

    assert_files_equal(out_path, validate_path)
    assert_in_delta skew_angle, 1.1628, 0.0001
  end
end