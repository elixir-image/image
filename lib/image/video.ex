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
    alias Image.Options

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

    @doc "Guards that a stream id is valid for a video stream"
    defguard is_stream(stream_id)
             when (is_integer(stream_id) and stream_id >= 0) or stream_id == :default_camera

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
    @spec open(filename_or_stream :: Path.t() | stream_id()) ::
            {:ok, Evision.VideoCapture.t()} | {:error, Image.error_message()}
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
    @spec open!(filename_or_stream :: Path.t() | stream_id()) ::
            Evision.VideoCapture.t() | no_return()
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
    Returns video file or live video as a `t:Stream.t/0`
    stream.

    This allows a video file or live video to be streamed
    for processing like any other enumerable.

    ### Arguments

    * `filename_or_stream` is either a pathname on the
      current system, a non-negative integer representing a
      video stream or `:default_camera` representing the
      stream for the default system camera. It can also
      be a `t:Evision.VideoCapture.t/0` representing a
      video file or stream that is already opened (this is the
      preferred approach).

    * `options` is a keyword list of options.`

    ### Options

    Only one of the following options can be provided. No
    options means the entire video will be streamed frame
    by frame..

    * `:frame` is a `t:Range.t/0` representing the range
      of frames to be extracted. `:frames` can only be specified
      for video files, not for video streams. For example,
      `frames: 10..100/2` will produce a stream of images that
      are every second image between the frame offsets `10` and `100`.

    * `:millisecond` is a `t:Range.t/0` representing the range
      of milliseconds to be extracted. `:milliseconds` can only
      be specified for video files, not for video streams. For example,
      `milliseconds: 1000..100000/2` will produce a stream of images
      that are every second image between the millisecond offsets of `1_000`
      and `100_000`.

    ### Returns

    * A `t:Enumerable.t/0` that can be used with functions in
      the `Stream` and `Enum` modules to lazily enumerate images
      extracted from a video stream.

    ### Example

        # Extract every second frame starting at the
        # first frame and ending at the last frame.
        iex> "./test/support/video/video_sample.mp4"
        ...> |> Image.Video.stream!(frame: 0..-1//2)
        ...> |> Enum.to_list()
        ...> |> Enum.count()
        86

    """
    @spec stream!(
            filename_or_stream :: Path.t() | stream_id() | Evision.VideoCapture.t(),
            options :: Keyword.t()
          ) :: Enumerable.t()
    def stream!(video, options \\ [])

    def stream!(filename_or_stream, options)
        when is_binary(filename_or_stream) or is_stream(filename_or_stream) do
      filename_or_stream
      |> open!()
      |> stream!(options)
    end

    def stream!(%Evision.VideoCapture{} = video, options) do
      options = Options.Video.validate_stream_options!(video, options)

      Stream.resource(
        fn ->
          seek_to_video_first(video, options)
        end,
        fn
          {video, _unit, first, last, _step} = stream when first <= last ->
            case Image.Video.image_from_video(video) do
              {:ok, image} ->
                {[image], advance_stream(stream)}

              _other ->
                {:halt, video}
            end

          {video, _unit, _first, _last, _step} ->
            {:halt, video}
        end,
        fn video -> Image.Video.close(video) end
      )
    end

    defp seek_to_video_first(video, {nil = unit, first, last, step}) do
      {video, unit, first, last, step}
    end

    defp seek_to_video_first(video, {unit, 0 = first, last, step}) do
      {video, unit, first, last, step}
    end

    defp seek_to_video_first(video, {unit, first, last, step}) do
      {:ok, video} = seek(video, [{unit, first}])
      {video, unit, first, last, step}
    end

    defp advance_stream({video, nil = unit, first, last, step}) do
      {video, unit, first, last, step}
    end

    defp advance_stream({video, unit, first, last, 1 = step}) do
      next = first + step
      {video, unit, next, last, step}
    end

    defp advance_stream({video, unit, first, last, step}) do
      next = first + step
      Enum.each(1..step - 1, fn _x -> Evision.VideoCapture.grab(video) end)
      {video, unit, next, last, step}
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

    def seek(%Evision.VideoCapture{isOpened: true, frame_count: frame_count} = video, [
          {:frame, frame}
        ])
        when is_frame(frame, frame_count) do
      case Evision.VideoCapture.set(video, Evision.cv_CAP_PROP_POS_FRAMES(), frame) do
        true -> {:ok, video}
        false -> {:error, "Could not seek to the frame offset #{inspect(frame)}."}
      end
    end

    def seek(%Evision.VideoCapture{isOpened: true, fps: fps, frame_count: frame_count} = video, [
          {:millisecond, millis}
        ])
        when is_valid_millis(millis, frame_count, fps) do
      case Evision.VideoCapture.set(video, Evision.cv_CAP_PROP_POS_MSEC(), millis) do
        true -> {:ok, video}
        false -> {:error, "Could not seek to the millisecond offset #{inspect(millis)}."}
      end
    end

    def seek(%Evision.VideoCapture{isOpened: true}, [{unit, offset}])
        when unit in [:frame, :millisecond] and offset < 0 do
      {:error, "Offset for #{inspect(unit)} must be a positive integer. Found #{inspect(offset)}"}
    end

    def seek(%Evision.VideoCapture{isOpened: true}, [{unit, offset}])
        when unit in [:frame, :millisecond] and is_integer(offset) do
      {:error, "Offset for #{inspect(unit)} is too large"}
    end

    def seek(%Evision.VideoCapture{isOpened: true}, options) do
      {:error,
       "Options must be either `frame: frame_offet` or `milliseconds: millisecond_offset`. Found #{inspect(options)}"}
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
        error -> {:error, "Could not extract the frame. Error #{inspect(error)}."}
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
