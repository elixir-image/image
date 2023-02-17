defmodule Image.VideoTest do
  use ExUnit.Case, async: true
  import Image.TestSupport

  doctest Image.Video

  test "Extract a frame from a video" do
    validate_path = validate_path("video/video_sample_frame_0.png")

    # :avfoundation is only on Mac OS so this test isn't appropriate
    # across operating systems
    {:ok, video} = Image.Video.open("./test/support/video/video_sample.mp4", backend: :avfoundation)
    {:ok, image} = Image.Video.image_from_video(video, millisecond: 0)

    assert_images_equal(image, validate_path, 2.2)
  end
end
