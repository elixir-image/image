if match?({:module, _module}, Code.ensure_compiled(Evision)) do
  defmodule Image.Video do
    @moduledoc """
    Implements functions to extract frames froma video file
    as images using [eVision](https://hex.pm/packages/evision).

    Images can be extracted by frame number of number of milliseconds with:
    * `Image.Video.image_from_frame/2` or
    * `Image.Video.image_at_millisecond/2`.

    In order to extract images the video file must first be
    opened with `Image.Video.open/1`. At the end of processing the video
    file should be closed with `Image.Video.close/1`.

    This process can be wrrapped by `Image.Video.with_video/2` which will
    open a video file, execute a function (passing it the video reference) and
    closing the video file at the end of the function.

    """

    alias Vix.Vips.Image, as: Vimage

    @doc "Guards that a frame offset is valid for a video"
    defguard is_frame(frame, frame_count)
             when is_integer(frame) and frame in 0..(trunc(frame_count) - 1)

    @doc "Guards that a millisecond count is valid for a video"
    defguard is_valid_millis(millis, frames, fps)
             when is_integer(millis) and millis in 0..(trunc(fps * frames * 1000) - 1)

    @doc """
    Opens a video file, calls the given function with the video
    reference and closes the video after the function returns.

    ### Arguments

    * `filename` is the filename of a video file

    ### Returns

    * `{:ok, video}` or

    * `{:error, reason}`

    ### Example

        iex> Image.Video.with_video "./test/support/video/video_sample.mp4", fn video ->
        ...>  Image.Video.image_from_frame(video, 1)
        ...> end

    """
    @spec with_video(filename :: Path.t(), (Evision.VideoCapture.t() -> any())) ::
            {:ok, Evision.VideoCapture.t()} | {:error, Image.error_message()}

    def with_video(filename, fun) when is_binary(filename) and is_function(fun, 1) do
      filename
      |> open()
      |> do_with_video(fun)
    end

    defp do_with_video({:ok, video}, fun) do
      fun.(video)
    after
      close(video)
    end

    defp do_with_video({:error, reason}, _fun) do
      {:error, reason}
    end

    @doc """
    Opens a video file for frame extraction.

    ### Arguments

    * `filename` is the filename of a video file

    ### Returns

    * `{:ok, video}` or

    * `{:error, reason}`

    ### Example

        iex> Image.Video.open "./test/support/video/video_sample.mp4"

    """
    @spec open(Path.t()) :: {:ok, Evision.VideoCapture.t()} | {:error, Image.error_message()}
    def open(filename) when is_binary(filename) do
      case Evision.VideoCapture.videoCapture(filename) do
        %Evision.VideoCapture{} = video ->
          {:ok, video}

        error ->
          {:error, "Could not open video #{inspect(filename)}. Error #{inspect(error)}"}
      end
    end

    @doc """
    Opens a video file for frame extraction or
    raises an exception.

    ### Arguments

    * `filename` is the filename of a video file

    ### Returns

    * `video` or

    * raises an exception

    ### Example

        iex> Image.Video.open! "./test/support/video/video_sample.mp4"

    """
    @spec open!(Path.t()) :: Evision.VideoCapture.t() | no_return()
    def open!(filename) when is_binary(filename) do
      case open(filename) do
        {:ok, video} -> video
        {:error, reason} -> raise Image.Error, reason
      end
    end

    @doc """
    Closes a video.

    ### Arguments

    * `video` is any `t:Evision.VideoCapture.t/0`

    ### Returns

    * `{:ok, closed_video}` or

    * `{:error, reason}`

    ### Example

        iex> {:ok, video} = Image.Video.open "./test/support/video/video_sample.mp4"
        iex> Image.Video.close(video)

    """
    @spec close(Evision.VideoCapture.t()) ::
            {:ok, Evision.VideoCapture.t()} | {:error, Image.error_message()}
    def close(%Evision.VideoCapture{} = video) do
      case Evision.VideoCapture.release(video) do
        %Evision.VideoCapture{} = video ->
          {:ok, video}

        error ->
          {:error, "Could not close video. Error #{inspect(error)}"}
      end
    end

    @doc """
    Closes a video or raises an exception.

    ### Arguments

    * `video` is any `t:Evision.VideoCapture.t/0`

    ### Returns

    * `closed_video` or

    * raises an exception.

    ### Example

        iex> {:ok, video} = Image.Video.open "./test/support/video/video_sample.mp4"
        iex> Image.Video.close!(video)

    """
    @spec close!(Evision.VideoCapture.t()) :: Evision.VideoCapture.t() | no_return()
    def close!(filename) do
      case close(filename) do
        {:ok, video} -> video
        {:error, reason} -> raise Image.Error, reason
      end
    end

    @doc """
    Extracts a frame from a video and returns
    an image.

    ### Arguments

    * `video` is any `t:Evision.VideoCapture.t/0`

    * `frame` is an integer frame offset into the video.
      The first frame of a video is frame `0`.

    ### Returns

    * `{:ok, image}` or

    * `{:error, reason}`

    ### Example

        iex> {:ok, video} = Image.Video.open "./test/support/video/video_sample.mp4"
        iex> {:ok, _image} = Image.Video.image_from_frame(video, 0)
        iex> {:error, "Frame number must be in the range 0..172. Found -1"} = Image.Video.image_from_frame(video, -1)
        iex> {:error, "Frame number must be in the range 0..172. Found 500"} = Image.Video.image_from_frame(video, 500)

    """
    @spec image_from_frame(Evision.VideoCapture.t(), non_neg_integer()) ::
            {:ok, Vimage.t()} | {:error, Image.error_message()}
    def image_from_frame(
          %Evision.VideoCapture{isOpened: true, frame_count: frame_count} = video,
          frame
        )
        when is_frame(frame, frame_count) do
      with true <- Evision.VideoCapture.set(video, Evision.cv_CAP_PROP_POS_FRAMES(), frame),
           %Evision.Mat{} = cv_image <- Evision.VideoCapture.read(video) do
        Image.from_evision(cv_image)
      else
        _error -> {:error, "Could not extract the frame number #{inspect(frame)}."}
      end
    end

    def image_from_frame(%Evision.VideoCapture{isOpened: true, frame_count: max_frame}, frame) do
      {:error,
       "Frame number must be in the range 0..#{trunc(max_frame) - 1}. Found #{inspect(frame)}"}
    end

    def image_from_frame(%Evision.VideoCapture{isOpened: false}, _frame) do
      {:error, "The video is not open."}
    end

    @doc """
    Extracts a frame from a video and returns
    an image or raises an exception.

    ### Arguments

    * `video` is any `t:Evision.VideoCapture.t/0`

    * `frame` is an integer frame offset into the video.
      The first frame of a video is frame `0`.

    ### Returns

    * `image` or

    * raises an exception

    """
    @spec image_from_frame!(Evision.VideoCapture.t(), non_neg_integer()) :: Vimage.t() | no_return()
    def image_from_frame!(%Evision.VideoCapture{} = video, frame) do
      case image_from_frame(video, frame) do
        {:ok, image} -> image
        {:error, reason} -> raise Image.Error, reason
      end
    end

    @doc """
    Extracts a frame at a given millisecond offset of the a video
    and returns an image.

    ### Arguments

    * `video` is any `t:Evision.VideoCapture.t/0`

    * `millis` is an integer millisecond offset into the video.
      The first millisecond of a video is frame `0`.

    ### Returns

    * `{:ok, image}` or

    * `{:error, reason}`

    ### Example

        iex> {:ok, video} = Image.Video.open "./test/support/video/video_sample.mp4"
        iex> {:ok, _image} = Image.Video.image_at_millisecond(video, 0)
        iex> {:error, "Milliseconds number must be in the range 0..5189999. Found -1"} =
        ...>   Image.Video.image_at_millisecond(video, -1)
        iex> {:error, "Milliseconds number must be in the range 0..5189999. Found 10000000"} =
        ...>   Image.Video.image_at_millisecond(video, 10_000_000)

    """
    @spec image_at_millisecond(Evision.VideoCapture.t(), non_neg_integer()) ::
            {:ok, Vimage.t()} | {:error, Image.error_message()}
    def image_at_millisecond(
          %Evision.VideoCapture{isOpened: true, frame_count: frame_count, fps: fps} = video,
          millis
        )
        when is_valid_millis(millis, frame_count, fps) do
      with true <- Evision.VideoCapture.set(video, Evision.cv_CAP_PROP_POS_MSEC(), millis),
           %Evision.Mat{} = cv_image <- Evision.VideoCapture.read(video) do
        Image.from_evision(cv_image)
      else
        _error -> {:error, "Could not extract the frame at #{inspect(millis)}."}
      end
    end

    def image_at_millisecond(
          %Evision.VideoCapture{isOpened: true, frame_count: frame_count, fps: fps},
          millis
        ) do
      max_millis = trunc(fps * frame_count * 1000) - 1

      {:error,
       "Milliseconds number must be in the range 0..#{max_millis}. Found #{inspect(millis)}"}
    end

    def image_at_millisecond(%Evision.VideoCapture{isOpened: false}, _millis) do
      {:error, "The video is not open."}
    end

    @doc """
    Extracts a frame at a given millisecond offset of the a video
    and returns an image or raises an exception.

    ### Arguments

    * `video` is any `t:Evision.VideoCapture.t/0`

    * `millis` is an integer millisecond offset into the video.
      The first millisecond of a video is frame `0`.

    ### Returns

    * `image` or

    * raises an exception.

    """
    @spec image_at_millisecond!(Evision.VideoCapture.t(), non_neg_integer()) ::
            Vimage.t() | no_return()
    def image_at_millisecond!(%Evision.VideoCapture{} = video, millis) do
      case image_at_millisecond(video, millis) do
        {:ok, image} -> image
        {:error, reason} -> raise Image.Error, reason
      end
    end
  end
end
