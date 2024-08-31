if Image.evision_configured?() do
  defmodule Image.Video do
    @moduledoc """
    Implements functions to extract frames froma video file
    as images using [eVision](https://hex.pm/packages/evision). The
    implementation is based upon
    [OpenCV Video Capture](https://docs.opencv.org/3.4/d0/da7/videoio_overview.html).

    Images can be extracted by frame number of number of milliseconds with
    `Image.Video.image_from_video/2`.

    In order to extract images the video file must first be
    opened with `Image.Video.open/1`. At the end of processing the video
    file should be closed with `Image.Video.close/1`.

    This process can be wrapped by `Image.Video.with_video/2` which will
    open a video file, execute a function (passing it the video reference) and
    closing the video file at the end of the function.

    ### Note

    This module is only available if the optional dependency
    [eVision](https://hex.pm/packages/evision) is configured in
    `mix.exs`.

    """

    alias Vix.Vips.Image, as: Vimage
    alias Evision.VideoCapture
    alias Evision.Constant
    alias Image.Options

    @typedoc "The valid options for Image.Video.seek/2, Image.Video.image_from_video/2"
    @type seek_options :: [frame: non_neg_integer()] | [millisecond: non_neg_integer()]

    @typedoc "The representation of a video stream"
    @type stream_id :: non_neg_integer() | :default_camera

    @doc subject: "Guard"
    @doc "Guards that a frame offset is valid for a video"
    defguard is_frame(frame, frame_count)
             when (is_integer(frame) and frame >= 0 and frame <= trunc(frame_count) - 1) or
                    (is_integer(frame) and frame_count == 0.0)

    @doc subject: "Guard"
    @doc "Guards that a millisecond count is valid for a video"
    defguard is_valid_millis(millis, frames, fps)
             when is_integer(millis) and millis >= 0 and millis <= trunc(fps * frames * 1000) - 1

    @doc "Guards that a stream id is valid for a video stream"
    @doc subject: "Guard"
    defguard is_stream(stream_id)
             when (is_integer(stream_id) and stream_id >= 0) or stream_id == :default_camera

    @doc """
    Opens a video file, calls the given function with the video
    reference and closes the video after the function returns.

    ### Arguments

    * `filename` is the filename of a video file.

    ### Returns

    * The result of the user function or

    * `{:error, reason}` if the video file could not be opened.

    ### Example

        iex> Image.Video.with_video "./test/support/video/video_sample.mp4", fn video ->
        ...>  Image.Video.image_from_video(video, 1)
        ...> end

    """
    @spec with_video(filename :: Path.t(), (VideoCapture.t() -> any())) :: any()

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
    Opens a video file, camera, RTSP URL or video stream for
    frame extraction.

    ### Arguments

    * `filename_or_stream` is the filename of a video file,
      the URL of an [RTSP stream](https://en.wikipedia.org/wiki/Real-Time_Streaming_Protocol)
      or the OpenCV representation of a video stream as
      an integer.  It may also be `:default_camera` to open
      the default camera if there is one.

    * `options` is a keyword list of options. The default
      is `[]`.

    ### Options

    * `:backend` specifies the backend video processing
      system to be used. The default is `:any` which means
      that the first available backend in the current OpenCV
      configuration will be used.  The available backends
      can be returned by `Image.Video.available_backends/0`.

    ### Returns

    * `{:ok, video}` or

    * `{:error, reason}`.

    ### Notes

    * The video `t:VideoCapture.t/0` struct that is returned
      includes metadata fields for frame rate (:fps), frame width
      (:frame_width), frame height (:frame_height) and frame count
      (:frame_count). *Note that frame count is an approximation due to
      issues in the underlying OpenCV*.

    * Opening an RTSP stream requires that `evision` be built with
      `ffpmeg` support. Since the prebuilt `evision` packages are not
      built with `ffmpeg` support, `evision` must be installed and
      compiled with the environment variable `EVISION_PREFER_PRECOMPILED=false`
      after ensuring that `ffmpeg` is installed. On a MacOS system,
      `brew install ffmpeg && brew link ffpeg` or similar will perform
      that installation. See also the [detailed evision installation instructions](https://github.com/cocoa-xu/evision/wiki/Compile-evision-from-source).

    ### Example

        iex> Image.Video.open "./test/support/video/video_sample.mp4"
        iex> {:ok, camera_video} = Image.Video.open(:default_camera)
        iex> Image.Video.close(camera_video)

    """
    @spec open(filename_or_stream :: Path.t() | stream_id(), Options.Video.open_options()) ::
            {:ok, VideoCapture.t()} | {:error, Image.error_message()}

    def open(filename, options \\ [])

    def open(filename, options) when is_binary(filename) and is_list(options) do
      with {:ok, backend} <- Options.Video.validate_open_options(options) do
        case VideoCapture.videoCapture(filename, apiPreference: backend) do
          %VideoCapture{isOpened: true} = video ->
            {:ok, video}

          %VideoCapture{isOpened: false} ->
            {:error, "Could not open video #{inspect(filename)}"}

          error ->
            {:error, "Could not open video #{inspect(filename)}. Error #{inspect(error)}"}
        end
      end
    end

    def open(camera, options) when is_integer(camera) and camera >= 0 do
      with {:ok, backend} <- Options.Video.validate_open_options(options) do
        case VideoCapture.videoCapture(camera, apiPreference: backend) do
          %VideoCapture{isOpened: true} = video ->
            {:ok, video}

          %VideoCapture{isOpened: false} ->
            {:error, "Could not open camera #{inspect(camera)}"}

          error ->
            {:error, "Could not open the camera. Error #{inspect(error)}"}
        end
      end
    end

    @default_camera_id 0

    def open(:default_camera, options) do
      open(@default_camera_id, options)
    end

    @doc """
    Opens a video file, camera, RTSP URL or video stream for
    frame extraction or raises an exception.

    ### Arguments

    * `filename_or_stream` is the filename of a video file,
      the URL of an [RTSP stream](https://en.wikipedia.org/wiki/Real-Time_Streaming_Protocol)
      or the OpenCV representation of a video stream as
      an integer.  It may also be `:default_camera` to open
      the default camera if there is one.

    * `options` is a keyword list of options. The default
      is `[]`.

    ### Options

    * `:backend` specifies the backend video processing
      system to be used. The default is `:any` which means
      that the first available backend in the current OpenCV
      configuration will be used.  The available backends
      can be returned by `Image.Video.available_backends/0`.

    ### Returns

    * `video` or

    * raises an exception.

    ### Notes

    * The video `t:VideoCapture.t/0` struct that is returned
      includes metadata fields for frame rate (:fps), frame width
      (:frame_width), frame height (:frame_height) and frame count
      (:frame_count). *Note that frame count is an approximation due to
      issues in the underlying OpenCV*.

    * Opening an RTSP stream requires that `evision` be built with
      `ffpmeg` support. Since the prebuilt `evision` packages are not
      built with `ffmpeg` support, `evision` must be installed and
      compiled with the environment variable `EVISION_PREFER_PRECOMPILED=false`
      after ensuring that `ffmpeg` is installed. On a MacOS system,
      `brew install ffmpeg && brew link ffpeg` or similar will perform
      that installation. See also the [detailed evision installation instructions](https://github.com/cocoa-xu/evision/wiki/Compile-evision-from-source).

    ### Example

        iex> Image.Video.open! "./test/support/video/video_sample.mp4"

    """
    @spec open!(filename_or_stream :: Path.t() | stream_id()) ::
            VideoCapture.t() | no_return()
    def open!(filename_or_stream) do
      case open(filename_or_stream) do
        {:ok, video} -> video
        {:error, reason} -> raise Image.Error, reason
      end
    end

    @doc """
    Closes a video.

    ### Arguments

    * `video` is any `t:VideoCapture.t/0`.

    ### Returns

    * `{:ok, closed_video}` or

    * `{:error, reason}`.

    ### Example

        iex> {:ok, video} = Image.Video.open "./test/support/video/video_sample.mp4"
        iex> Image.Video.close(video)

    """
    @spec close(VideoCapture.t()) ::
            {:ok, VideoCapture.t()} | {:error, Image.error_message()}
    def close(%VideoCapture{} = video) do
      case VideoCapture.release(video) do
        %VideoCapture{} = video ->
          {:ok, video}

        error ->
          {:error, "Could not close video. Error #{inspect(error)}"}
      end
    end

    @doc """
    Closes a video or raises an exception.

    ### Arguments

    * `video` is any `t:VideoCapture.t/0`.

    ### Returns

    * `closed_video` or

    * raises an exception.

    ### Example

        iex> {:ok, video} = Image.Video.open "./test/support/video/video_sample.mp4"
        iex> Image.Video.close!(video)

    """
    @spec close!(VideoCapture.t()) :: VideoCapture.t() | no_return()
    def close!(video) do
      case close(video) do
        {:ok, video} -> video
        {:error, reason} -> raise Image.Error, reason
      end
    end

    @doc """
    Returns video file or live video as a `t:Enumerable.t/0`
    stream.

    This allows a video file or live video to be streamed
    for processing like any other enumerable.

    ### Arguments

    * `filename_or_stream` is either a pathname on the
      current system, a non-negative integer representing a
      video stream or `:default_camera` representing the
      stream for the default system camera. It can also
      be a `t:VideoCapture.t/0` representing a
      video file or stream that is already opened (this is the
      preferred approach).

    * `options` is a keyword list of options.

    ### Options

    Only one of the following options can be provided. No
    options means the entire video will be streamed frame
    by frame.

    * `:frame` is a `t:Range.t/0` representing the range
      of frames to be extracted. `:frames` can only be specified
      for video files, not for video streams. For example,
      `frames: 10..100/2` will produce a stream of images that
      are every second image between the frame offsets `10` and `100`.

    * `:millisecond` is a `t:Range.t/0` representing the range
      of milliseconds to be extracted. `:millisecond` can only
      be specified for video files, not for video streams. For example,
      `millisecond: 1000..100000/2` will produce a stream of images
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
            filename_or_stream :: Path.t() | stream_id() | VideoCapture.t(),
            options :: Keyword.t()
          ) :: Enumerable.t()
    def stream!(video, options \\ [])

    def stream!(filename_or_stream, options)
        when is_binary(filename_or_stream) or is_stream(filename_or_stream) do
      filename_or_stream
      |> open!()
      |> stream!(options)
    end

    def stream!(%VideoCapture{} = video, options) do
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
      Enum.each(1..(step - 1), fn _x -> VideoCapture.grab(video) end)
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

    * `video` is any `t:VideoCapture.t/0`.

    * `options` is a keyword list of options.

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

    ### Warning

    Seeking is not [frame accurate](https://github.com/opencv/opencv/issues/9053)!

    ### Examples

        iex> {:ok, video} = Image.Video.open("./test/support/video/video_sample.mp4")
        iex> {:ok, _image} = Image.Video.seek(video, frame: 0)
        iex> {:ok, _image} = Image.Video.seek(video, millisecond: 1_000)
        iex> Image.Video.seek(video, frame: -1)
        {:error, "Offset for :frame must be a non-negative integer. Found -1"}

    """
    @spec seek(VideoCapture.t(), seek_options()) ::
            {:ok, VideoCapture.t()} | {:error, Image.error_message()}

    def seek(%VideoCapture{isOpened: true, frame_count: frame_count} = video, [{:frame, frame}])
        when is_frame(frame, frame_count) do
      case VideoCapture.set(video, Constant.cv_CAP_PROP_POS_FRAMES(), frame) do
        true -> {:ok, video}
        false -> {:error, "Could not seek to the frame offset #{inspect(frame)}."}
      end
    end

    def seek(%VideoCapture{isOpened: true, fps: fps, frame_count: frame_count} = video, [
          {:millisecond, millis}
        ])
        when is_valid_millis(millis, frame_count, fps) do
      case VideoCapture.set(video, Constant.cv_CAP_PROP_POS_MSEC(), millis) do
        true -> {:ok, video}
        false -> {:error, "Could not seek to the millisecond offset #{inspect(millis)}."}
      end
    end

    def seek(%VideoCapture{isOpened: true}, [{unit, offset}])
        when unit in [:frame, :millisecond] and offset < 0 do
      {:error,
       "Offset for #{inspect(unit)} must be a non-negative integer. Found #{inspect(offset)}"}
    end

    def seek(%VideoCapture{isOpened: true}, [{unit, offset}])
        when unit in [:frame, :millisecond] and is_integer(offset) do
      {:error, "Offset for #{inspect(unit)} is too large"}
    end

    def seek(%VideoCapture{isOpened: true}, options) do
      {:error,
       "Options must be either `frame: frame_offet` or `millisecond: millisecond_offset`. Found #{inspect(options)}"}
    end

    def seek(%VideoCapture{isOpened: false}, _options) do
      {:error, video_closed_error()}
    end

    @doc """
    Seeks the video head to a specified frame offset
    or millisecond offset.

    Note that seeking a video format is supported,
    seeking a live video stream (such as from a
    webcam) is not supported and will return an
    error.

    ### Arguments

    * `video` is any `t:VideoCapture.t/0`.

    * `options` is a keyword list of options.

    ### Options

    * `unit` is either `:frame` or `:millisecond` with a
      non-negative integer offset. For example `frame: 3`.

    ### Returns

    * `{:ok, video}` or

    * `{:error, reason}`.

    ### Notes

    Seeking cannot be performed on image streams such as
    webcams.  Therefore no options may be provided when
    extracting images from an image stream.

    """
    @spec seek!(VideoCapture.t(), seek_options()) ::
            VideoCapture.t() | no_return()

    def seek!(video, options \\ []) do
      case seek(video, options) do
        {:ok, video} -> video
        {:error, reason} -> raise Image.Error, reason
      end
    end

    @doc """
    Scrubs a video forward by a number of frames.

    In OpenCV (the underlying video library used by
    `Image.Video`), seeking to a specified frame is not
    frame accurate.  This function moves the video
    play head forward frame by frame and is therefore
    a frame accurate way of moving the the video head
    forward.

    ### Arguements

    * `video` is any `t:VideoCapture.t/0`.

    * `frames` is a positive integer number of frames
      to scrub forward.

    ### Returns

    * `{:ok, frames_scrubbed}`. `frames_scrubbed` may
      be less than the number of requested frames. This may
      happen of the end of the video stream is reached, or

    * `{:error, reason}`.

    ### Examples

        iex> {:ok, video} = Image.Video.open "./test/support/video/video_sample.mp4"
        iex> {:ok, 10} = Image.Video.scrub(video, 10)
        iex>  Image.Video.scrub(video, 100_000_000)
        {:ok, 161}

    """
    @spec scrub(VideoCapture.t(), frames :: pos_integer) ::
            {:ok, pos_integer()} | {:error, Image.error_message()}

    def scrub(%VideoCapture{isOpened: true} = video, frames)
        when is_integer(frames) and frames > 0 do
      Enum.reduce_while(1..frames, {:ok, 0}, fn _frame, {:ok, count} ->
        case VideoCapture.grab(video) do
          true -> {:cont, {:ok, count + 1}}
          false -> {:halt, {:ok, count}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end

    def scrub(%VideoCapture{isOpened: false}, _frames) do
      {:error, video_closed_error()}
    end

    @doc """
    Extracts a frame from a video and returns
    an image.

    After the image is extracted the play head
    in the video file is advanced one frame. That is,
    successive calls to `Image.Video.image_from_video/2`
    will return successive frames - not the same frame.

    ### Arguments

    * `video` is any `t:VideoCapture.t/0`

    * `options` is a keyword list of options. The defalt

    ### Options

    * `unit` is either `:frame` or `:millisecond` with a
      non-negative integer offset. For example `frame: 3`.
      The default is `[]` which means that no seek is performed
      and the extracted image is taken from the current
      position in the file or video stream. Note that seeking
      is not guaranteed to be accurate. If frame accuracy is
      required the recommended process is:

      * Open the video file with `Image.Video.open/1`
      * Scrub forward to the required freame with `Image.Video.scrub/2`
      * Then capture the frame with `Image.Video.image_from_video/1`

    ### Returns

    * `{:ok, image}` or

    * `{:error, reason}`.

    ### Notes

    Seeking cannot be performed on image streams such as
    webcams.  Therefore no options may be provided when
    extracting images from an image stream.

    ### Examples

        iex> {:ok, video} = Image.Video.open("./test/support/video/video_sample.mp4")
        iex> {:ok, _image} = Image.Video.image_from_video(video)
        iex> {:ok, _image} = Image.Video.image_from_video(video, frame: 0)
        iex> {:ok, _image} = Image.Video.image_from_video(video, millisecond: 1_000)
        iex> Image.Video.image_from_video(video, frame: -1)
        {:error, "Offset for :frame must be a non-negative integer. Found -1"}
        iex> Image.Video.image_from_video(video, frame: 500)
        {:error, "Offset for :frame is too large"}

    """
    @spec image_from_video(VideoCapture.t(), seek_options()) ::
            {:ok, Vimage.t()} | {:error, Image.error_message()}

    def image_from_video(video, options \\ [])

    def image_from_video(%VideoCapture{isOpened: true} = video, []) do
      with %Evision.Mat{} = cv_image <- VideoCapture.read(video) do
        Image.from_evision(cv_image)
      else
        error -> {:error, "Could not extract the frame. Error #{inspect(error)}."}
      end
    end

    def image_from_video(%VideoCapture{isOpened: true} = video, options) do
      with {:ok, video} <- seek(video, options) do
        image_from_video(video)
      end
    end

    def image_from_video(%VideoCapture{isOpened: false}, _options) do
      {:error, video_closed_error()}
    end

    @doc """
    Extracts a frame from a video and returns
    an image or raises an exception.

    After the image is extracted the play head
    in the video file is advanced one frame. That is,
    successive calls to `Image.Video.image_from_video/2`
    will return successive frames - not the same frame.

    ### Arguments

    * `video` is any `t:VideoCapture.t/0`.

    * `options` is a keyword list of options.

    ### Options

    * `unit` is either `:frame` or `:millisecond` with a
      non-negative integer offset. For example `frame: 3`.
      The default is `[]` which means that no seek is performed
      and the extracted image is taken from the current
      position in the file or video stream. Note that seeking
      is not guaranteed to be accurate. If frame accuracy is
      required the recommended process is:

      * Open the video file with `Image.Video.open/1`
      * Scrub forward to the required freame with `Image.Video.scrub/2`
      * Then capture the frame with `Image.Video.image_from_video/1`

    ### Returns

    * `image` or

    * raises an exception.

    ### Notes

    Seeking cannot be performed on image streams such as
    webcams.  Therefore no options may be provided when
    extracting images from an image stream.

    """
    @spec image_from_video!(VideoCapture.t(), seek_options()) :: Vimage.t() | no_return()

    def image_from_video!(%VideoCapture{} = video, options \\ []) do
      case image_from_video(video, options) do
        {:ok, image} -> image
        {:error, reason} -> raise Image.Error, reason
      end
    end

    @doc """
    Returns a list of known (valid but not necessarily
    available for use in the current OpenCV configuration)
    backend video processors.

    See the [OpenCV documentation](https://docs.opencv.org/4.x/d4/d15/group__videoio__flags__base.html#ga023786be1ee68a9105bf2e48c700294d)
    for more information on video processor backends.

    ### Example

        iex> Image.Video.known_backends() |> Enum.sort()
        [:android, :any, :aravis, :avfoundation, :cmu1394, :dc1394, :dshow, :ffmpeg,
         :fireware, :firewire, :giganetix, :gphoto2, :gstreamer, :ieee1394, :images,
         :intel_mfx, :intelperc, :msmf, :obsensor, :opencv_mjpeg, :openni, :openni2,
         :openni2_astra, :openni2_asus, :openni_asus, :pvapi, :qt, :realsense, :ueye,
         :unicap, :v4l, :v4l2, :vfw, :winrt, :xiapi, :xine]

    """
    @spec known_backends :: list(Options.Video.backend())
    def known_backends do
      Map.keys(Options.Video.known_backends())
    end

    @doc false
    def known_backend_values do
      Map.keys(Options.Video.inverted_known_backends())
    end

    @doc """
    Returns a boolean indicating if the specified
    backend is known (valid but not necessarily
    available for use in the current OpenCV configuration).

    ### Examples

        iex> Image.Video.known_backend?(:avfoundation)
        true
        iex> Image.Video.known_backend?(:invalid)
        false
        iex> Image.Video.known_backend?(1200)
        true
        iex> Image.Video.known_backend?(-1)
        false

    """
    @spec known_backend?(Options.Video.backend()) :: boolean()
    def known_backend?(backend) when is_atom(backend) do
      backend in known_backends()
    end

    def known_backend?(backend) when is_integer(backend) do
      backend in known_backend_values()
    end

    @doc """
    Returns a list of available (configured and
    available for use) backend video processors.

    See the [OpenCV documentation](https://docs.opencv.org/4.x/d4/d15/group__videoio__flags__base.html#ga023786be1ee68a9105bf2e48c700294d)
    for more information on video processor backends.

    """
    @spec available_backends :: list(Options.Video.backend())
    def available_backends do
      Options.Video.known_backends()
      |> Enum.filter(fn {_backend, value} -> Evision.VideoIORegistry.hasBackend(value) end)
      |> Keyword.keys()
    end

    @doc """
    Returns a boolean indicating if the specified
    backend is available (configured and
    available for use).

    """
    @spec available_backend?(any) :: boolean()
    def available_backend?(backend) do
      backend in available_backends()
    end

    ### Helpers

    defp video_closed_error do
      "Video is not open"
    end
  end
end
