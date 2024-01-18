defmodule Image.VideoTest do
  use ExUnit.Case, async: true
  import Image.TestSupport

  @moduletag :video

  doctest Image.Video

  test "Extract a frame from a video" do
    validate_path = validate_path("video/video_sample_frame_0.png")

    {:ok, video} = Image.Video.open("./test/support/video/video_sample.mp4")
    {:ok, image} = Image.Video.image_from_video(video, millisecond: 0)

    # Image.write(image, validate_path)

    # Image.preview image
    # Image.preview Image.open!(validate_path)

    # The 6.5 comes from the variability of different
    # frameworks compressing differently
    assert_images_equal(image, validate_path, 6.5)
  end
end
