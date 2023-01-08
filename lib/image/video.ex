if match?({:module, _module}, Code.ensure_compiled(Evision)) do
  defmodule Image.Video do
    @moduledoc """
    Implements functions to extract frames froma video file
    as images using [eVision](https://hex.pm/packages/evision).

    Images can be extracted by frame number of number of milliseconds with
    `Image.Video.image_from_video/2`.

    In order to extract images the video file must first be
    opened with `Image.Video.open/1`. At the end of processing the video
    file should be closed with `Image.Video.close/1`.

    This process can be wrrapped by `Image.Video.with_video/2` which will
    open a video file, execute a function (passing it the video reference) and
    closing the video file at the end of the function.

    """

    alias Vix.Vips.Image, as: Vimage

    @typedoc "The valid options for Image.Video.seek/2, Image.Video.image_from_video/2"
    @type seek_options :: [frame: non_neg_integer()] | [millisecond: non_neg_integer()]

    @typedoc "The representation of a video stream"
    @type stream_id :: non_neg_integer() | :default_camera

    @doc "Guards that a frame offset is valid for a video"
    defguard is_frame(frame, frame_count)
             when (is_integer(frame) and frame in 0..(trunc(frame_count) - 1)) or
            (is_integer(frame) and frame_count == 0.0)

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
        ...>  Image.Video.image_from_video(video, 1)
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
    Opens a video file or video stream for
    frame extraction.

    ### Arguments

    * `filename_or_stream` is the filename of a video file
      or the OpenCV representation of a video stream as
      an integer.  It may also be `:default_camera` to open
      the default camera if there is one.

    ### Returns

    * `{:ok, video}` or

    * `{:error, reason}`

    ### Example

        iex> Image.Video.open "./test/support/video/video_sample.mp4"
        iex> {:ok, camera_video} = Image.Video.open(:default_camera)
        iex> Image.Video.close(camera_video)

    """
    @spec open(filename_or_stream :: Path.t() | stream_id()) :: {:ok, Evision.VideoCapture.t()} | {:error, Image.error_message()}
    def open(filename) when is_binary(filename) do
      case Evision.VideoCapture.videoCapture(filename) do
        %Evision.VideoCapture{} = video ->
          {:ok, video}

        error ->
          {:error, "Could not open video #{inspect(filename)}. Error #{inspect(error)}"}
      end
    end

    @default_camera_id 0

    def open(:default_camera) do
      open(@default_camera_id)
    end

    def open(camera) when is_integer(camera) and camera >= 0 do
      case Evision.VideoCapture.videoCapture(camera) do
        %Evision.VideoCapture{} = video ->
          {:ok, video}

        error ->
          {:error, "Could not open the camera. Error #{inspect(error)}"}
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
    @spec open!(filename_or_stream :: Path.t() | stream_id()) :: Evision.VideoCapture.t() | no_return()
    def open!(filename_or_stream) do
      case open(filename_or_stream) do
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
    def close!(video) do
      case close(video) do
        {:ok, video} -> video
        {:error, reason} -> raise Image.Error, reason
      end
    end

    @doc """
    Seeks the video head to a specified frame offset
    or millisecond offset.

    Note that seeking a video format is supported,
    seeking a live video stream (such as from a
    webcam) is not supported and will return an
    error.

    ### Arguments

    * `video` is any `t:Evision.VideoCapture.t/0`

    * `options` is a keyword list of options

    ### Options

    * `unit` is either `:frame` or `:millisecond` with a
      non-negative integer offset. For example `frame: 3`.

    ### Returns

    * `{:ok, video}` or

    * `{:error, reason}`

    ### Notes

    Seeking cannot be performed on image streams such as
    webcams.  Therefore no options may be provided when
    extracting images from an image stream.

    ### Examples

        iex> {:ok, video} = Image.Video.open "./test/support/video/video_sample.mp4"
        iex> {:ok, _image} = Image.Video.seek(video, frame: 0)
        iex> {:ok, _image} = Image.Video.seek(video, millisecond: 1_000)
        iex> {:error, "Offset for :frame must be a positive integer. Found -1"} =
        ...>   Image.Video.seek(video, frame: -1)

    """
    @spec seek(Evision.VideoCapture.t(), seek_options()) ::
      {:ok, Evision.VideoCapture.t()} | {:error, Image.error_message()}

    def seek(%Evision.VideoCapture{isOpened: true, frame_count: frame_count} = video, [{:frame, frame}])
        when is_frame(frame, frame_count) do
      case Evision.VideoCapture.set(video, Evision.cv_CAP_PROP_POS_FRAMES(), frame) do
        true -> {:ok, video}
        false -> {:error, "Could not seek to the frame offset #{inspect(frame)}."}
      end
    end

    def seek(%Evision.VideoCapture{isOpened: true, fps: fps, frame_count: frame_count} = video, [{:millisecond, millis}])
        when is_valid_millis(millis, frame_count, fps) do
      case Evision.VideoCapture.set(video, Evision.cv_CAP_PROP_POS_MSEC(), millis) do
        true -> {:ok, video}
        false -> {:error, "Could not seek to the millisecond offset #{inspect(millis)}."}
      end
    end

    def seek(%Evision.VideoCapture{isOpened: true}, [{unit, offset}]) when unit in [:frame, :millisecond] and offset < 0 do
      {:error, "Offset for #{inspect unit} must be a positive integer. Found #{inspect offset}"}
    end

    def seek(%Evision.VideoCapture{isOpened: true}, [{unit, offset}]) when unit in [:frame, :millisecond] and is_integer(offset) do
      {:error, "Offset for #{inspect unit} is too large"}
    end

    def seek(%Evision.VideoCapture{isOpened: true}, options) do
      {:error, "Options must be either `frame: frame_offet` or `milliseconds: millisecond_offset`. Found #{inspect options}"}
    end

    def seek(%Evision.VideoCapture{isOpened: false}, _options) do
      {:error, "Video is not open"}
    end

    @doc """
    Seeks the video head to a specified frame offset
    or millisecond offset.

    Note that seeking a video format is supported,
    seeking a live video stream (such as from a
    webcam) is not supported and will return an
    error.

    ### Arguments

    * `video` is any `t:Evision.VideoCapture.t/0`

    * `options` is a keyword list of options

    ### Options

    * `unit` is either `:frame` or `:millisecond` with a
      non-negative integer offset. For example `frame: 3`.

    ### Returns

    * `{:ok, video}` or

    * `{:error, reason}`

    ### Notes

    Seeking cannot be performed on image streams such as
    webcams.  Therefore no options may be provided when
    extracting images from an image stream.

    """
    @spec seek!(Evision.VideoCapture.t(), seek_options()) ::
      Evision.VideoCapture.t() | no_return()

    def seek!(video, options \\ []) do
      case seek(video, options) do
        {:ok, video} -> video
        {:error, reason} -> raise Image.Error, reason
      end
    end

    @doc """
    Extracts a frame from a video and returns
    an image.

    After the image is extracted the play head
    in the video file is advanced one frame. That is,
    successive calls to `Image.Video.image_from_video/2`
    will return successive frames - not the same frame.

    ### Arguments

    * `video` is any `t:Evision.VideoCapture.t/0`

    * `options` is a keyword list of options. The defalt

    ### Options

    * `unit` is either `:frame` or `:millisecond` with a
      non-negative integer offset. For example `frame: 3`.
      The default is `[]` which means that no seek is performed
      and the extracted image is taken from the current
      position in the file or video stream.

    ### Returns

    * `{:ok, image}` or

    * `{:error, reason}`

    ### Notes

    Seeking cannot be performed on image streams such as
    webcams.  Therefore no options may be provided when
    extracting images from an image stream.

    ### Warning

    This frame extraction is NOT atomic. First the read head is
    set to the frame of interest, then the frame is extracted and
    decoded.  It is possible for another process to interleave
    its own seek operation resulting in undefined results.

    ### Examples

        iex> {:ok, video} = Image.Video.open "./test/support/video/video_sample.mp4"
        iex> {:ok, _image} = Image.Video.image_from_video(video)
        iex> {:ok, _image} = Image.Video.image_from_video(video, frame: 0)
        iex> {:ok, _image} = Image.Video.image_from_video(video, millisecond: 1_000)
        iex> {:error, "Offset for :frame must be a positive integer. Found -1"} = Image.Video.image_from_video(video, frame: -1)
        iex> {:error, "Offset for :frame is too large"} = Image.Video.image_from_video(video, frame: 500)

    """
    @spec image_from_video(Evision.VideoCapture.t(), seek_options()) ::
            {:ok, Vimage.t()} | {:error, Image.error_message()}

    def image_from_video(video, options \\ [])

    def image_from_video(%Evision.VideoCapture{isOpened: true} = video, []) do
      with %Evision.Mat{} = cv_image <- Evision.VideoCapture.read(video) do
        Image.from_evision(cv_image)
      else
        error -> {:error, "Could not extract the frame. Error #{inspect error}."}
      end
    end

    def image_from_video(%Evision.VideoCapture{isOpened: true} = video, options) do
      with {:ok, video} <- seek(video, options) do
        image_from_video(video)
      end
    end

    def image_from_video(%Evision.VideoCapture{isOpened: false}, _options) do
      {:error, "The video is not open."}
    end

    @doc """
    Extracts a frame from a video and returns
    an image or raises an exception.

    After the image is extracted the play head
    in the video file is advanced one frame. That is,
    successive calls to `Image.Video.image_from_video/2`
    will return successive frames - not the same frame.

    ### Arguments

    * `video` is any `t:Evision.VideoCapture.t/0`

    * `options` is a keyword list of options

    ### Options

    * `unit` is either `:frame` or `:millisecond` with a
      non-negative integer offset. For example `frame: 3`.
      The default is `[]` which means that no seek is performed
      and the extracted image is taken from the current
      position in the file or video stream.

    ### Returns

    * `image` or

    * raises an exception

    ### Notes

    Seeking cannot be performed on image streams such as
    webcams.  Therefore no options may be provided when
    extracting images from an image stream.

    ### Warning

    This frame extraction is NOT atomic. First the read head is
    set to the frame of interest, then the frame is extracted and
    decoded.  It is possible for another process to interleave
    its own seek operation resulting in undefined results.

    """
    @spec image_from_video!(Evision.VideoCapture.t(), seek_options()) :: Vimage.t() | no_return()
    def image_from_video!(%Evision.VideoCapture{} = video, options \\ []) do
      case image_from_video(video, options) do
        {:ok, image} -> image
        {:error, reason} -> raise Image.Error, reason
      end
    end
  end
end
