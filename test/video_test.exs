defmodule Image.VideoTest do
  use ExUnit.Case, async: true
  import Image.TestSupport

  doctest Image.Video

  test "Extract a frame from a video" do
    validate_path =  validate_path("video/video_sample_frame_0.png")

    {:ok, video} = Image.Video.open("./test/support/video/video_sample.mp4")
    {:ok, image} = Image.Video.image_at_millisecond(video, 0)

    assert_images_equal(image, validate_path)
  end

end