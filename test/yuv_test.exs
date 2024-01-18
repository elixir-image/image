defmodule Image.YUVTest do
  use ExUnit.Case, async: true
  import Image.TestSupport

  test "Opening an .YUV image, convert to RGB then back to YUV" do
    raw_yuv_file = image_path("image.yuv")
    {:ok, binary} = File.read(raw_yuv_file)

    assert {:ok, rgb_image} = Image.YUV.new_from_binary(binary, 1920, 1080, :C420, :bt601)
    assert {:ok, _yuv} = Image.YUV.to_yuv(rgb_image, :C420, :bt601)
    assert {:ok, _yuv} = Image.YUV.to_yuv(rgb_image, :C420, :bt709)
    assert {:ok, _yuv} = Image.YUV.to_yuv(rgb_image, :C422, :bt601)
    assert {:ok, _yuv} = Image.YUV.to_yuv(rgb_image, :C444, :bt709)
  end
end