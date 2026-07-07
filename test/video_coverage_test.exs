defmodule Image.VideoCoverageTest do
  use ExUnit.Case, async: true

  @moduletag :video

  @video_path "./test/support/video/video_sample.mp4"

  defp open! do
    Image.Video.open!(@video_path)
  end

  describe "open/2, open!/1 and with_video/2" do
    test "open! raises when the source cannot be opened" do
      assert_raise Image.Error, fn ->
        Image.Video.open!("./test/support/video/no_such_video.mp4")
      end
    end

    test "with_video returns the open error when the source cannot be opened" do
      assert {:error, %Image.Error{}} =
               Image.Video.with_video("./test/support/video/no_such_video.mp4", fn _video ->
                 flunk("Should not be called")
               end)
    end
  end

  describe "close/1 and close!/1" do
    test "close! returns a struct with a nil reader" do
      video = open!()
      closed = Image.Video.close!(video)
      assert closed.reader == nil
    end

    test "operations on a closed video return errors" do
      closed = open!() |> Image.Video.close!()

      assert {:error, %Image.Error{reason: :video_closed}} = Image.Video.seek(closed, frame: 0)
      assert {:error, %Image.Error{reason: :video_closed}} = Image.Video.scrub(closed, 1)

      assert {:error, %Image.Error{reason: :video_closed}} =
               Image.Video.image_from_video(closed)
    end
  end

  describe "stream!/2" do
    test "streaming with default options produces images" do
      video = open!()
      images = video |> Image.Video.stream!() |> Enum.take(2)

      assert length(images) == 2
      assert Enum.all?(images, &match?(%Vix.Vips.Image{}, &1))
    end

    test "streaming a frame range with a step" do
      video = open!()
      images = video |> Image.Video.stream!(frame: 2, finish: 10, step: 4) |> Enum.to_list()

      assert length(images) == 3
    end

    test "streaming from a millisecond offset" do
      video = open!()
      images = video |> Image.Video.stream!(millisecond: 1_000, finish: 32) |> Enum.to_list()

      assert length(images) == 3
    end

    test "streaming past the end of the video halts at end of stream" do
      video = open!()

      # :finish is well past the end of the video so enumeration can only
      # terminate via the end-of-stream halt. FFmpeg seeks to the nearest
      # keyframe at or before the requested frame, so more frames than
      # frame_count - start may be produced — but always fewer than the
      # requested range implies.
      requested = 53

      images =
        video
        |> Image.Video.stream!(frame: video.frame_count - 2, finish: video.frame_count + 50)
        |> Enum.to_list()

      refute Enum.empty?(images)
      assert length(images) < requested
    end

    test "streaming a closed video raises" do
      closed = open!() |> Image.Video.close!()

      assert_raise Image.Error, ~r/closed/, fn ->
        Image.Video.stream!(closed)
      end
    end

    test "streaming with both :frame and :millisecond raises" do
      video = open!()

      assert_raise Image.Error, ~r/Only one of/, fn ->
        Image.Video.stream!(video, frame: 1, millisecond: 100)
      end
    end

    test "streaming with an invalid :finish raises" do
      video = open!()

      assert_raise Image.Error, ~r/Invalid :finish option/, fn ->
        Image.Video.stream!(video, finish: -2)
      end
    end

    test "streaming with an invalid :step raises" do
      video = open!()

      assert_raise Image.Error, ~r/Invalid :step option/, fn ->
        Image.Video.stream!(video, step: 0)
      end
    end
  end

  describe "seek/2 and seek!/2" do
    test "seek with invalid options returns an error" do
      video = open!()

      assert {:error, %Image.Error{reason: :invalid_seek_options}} =
               Image.Video.seek(video, frame: 1, millisecond: 100)

      assert {:error, %Image.Error{reason: :invalid_seek_options}} =
               Image.Video.seek(video, [])
    end

    test "seek! returns the video on success" do
      video = open!()
      assert %Image.Video{} = Image.Video.seek!(video, frame: 1)
    end

    test "seek! raises on error" do
      video = open!()

      assert_raise Image.Error, fn ->
        Image.Video.seek!(video, frame: -1)
      end
    end
  end

  describe "scrub/2" do
    test "scrub advances the video head" do
      video = open!()
      assert {:ok, %Image.Video{}} = Image.Video.scrub(video, 3)
      assert {:ok, %Vix.Vips.Image{}} = Image.Video.image_from_video(video)
    end

    test "scrubbing past the end leaves the video at end of stream" do
      video = open!()
      assert {:ok, video} = Image.Video.scrub(video, video.frame_count + 100)

      assert {:error, %Image.Error{reason: :end_of_stream}} =
               Image.Video.image_from_video(video)
    end
  end

  describe "image_from_video!/2" do
    test "returns an image on success" do
      video = open!()
      assert %Vix.Vips.Image{} = Image.Video.image_from_video!(video, frame: 1)
    end

    test "raises on error" do
      video = open!()

      assert_raise Image.Error, fn ->
        Image.Video.image_from_video!(video, frame: -1)
      end
    end
  end

  describe "frame_to_image/1" do
    test "converts a bgr24 frame by swapping the bands" do
      # A 2x1 frame with a blue pixel and a red pixel in BGR byte order.
      data = <<255, 0, 0, 0, 0, 255>>
      frame = %Xav.Frame{type: :video, data: data, width: 2, height: 1, format: :bgr24}

      assert {:ok, image} = Image.Video.frame_to_image(frame)
      assert Image.shape(image) == {2, 1, 3}
      assert Image.get_pixel!(image, 0, 0) == [0, 0, 255]
      assert Image.get_pixel!(image, 1, 0) == [255, 0, 0]
    end

    test "returns an error for an unsupported frame format" do
      frame = %Xav.Frame{type: :video, data: <<0>>, width: 1, height: 1, format: :yuv420p}

      assert {:error, %Image.Error{reason: :unsupported_frame_format}} =
               Image.Video.frame_to_image(frame)
    end
  end
end
