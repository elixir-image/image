if Image.xav_configured?() do
  defmodule Image.Video do
    @moduledoc """
    Functions to extract frames from a video file or device as
    images using [Xav](https://hex.pm/packages/xav), an Elixir
    wrapper around FFmpeg.

    Frames can be extracted by frame number or by millisecond
    offset with `Image.Video.image_from_video/2`. Streams of
    frames can be produced with `Image.Video.stream!/2`.

    A video must first be opened with `Image.Video.open/2`. The
    underlying Xav reader is garbage-collected, so explicit
    `close/1` is no longer required, but the function is provided
    as a no-op for source compatibility.

    The pattern can be wrapped by `Image.Video.with_video/2` which
    opens a video, executes a function with the video reference,
    and (since closing is no longer required) simply discards the
    reference at the end.

    ## Note

    This module is only available if the optional dependency
    [Xav](https://hex.pm/packages/xav) is in your `mix.exs`. Xav
    in turn requires FFmpeg ≥ 6.0 to be installed on the system.

    ## Migration from the eVision-backed implementation

    Earlier releases of `Image` used `:evision` (OpenCV) for
    video frame extraction. From version 0.66.0 the implementation
    is FFmpeg-based via `:xav`. The public function shapes are the
    same with these intentional differences:

    * The opaque video struct is `%Image.Video{}` rather than
      `%Evision.VideoCapture{}`. Pattern-match on the new struct
      module if your code does so.

    * Backend selection (the `:backend` option to `open/2`) has
      been removed. FFmpeg is the only backend.

    * Camera input is now opened with a device path string rather
      than an integer index. `:default_camera` still works on
      Linux (resolves to `/dev/video0`) and on macOS (resolves to
      AVFoundation device 0). Other camera indices need an
      explicit device string.

    * Frame-based seeking (`seek(video, frame: n)` and
      `image_from_video(video, frame: n)`) is now implemented as
      a time-based seek to `n / fps` followed by zero or more
      `next_frame` calls to land on the exact frame. For
      keyframe-only files this is exact; for inter-frame
      compressed files (the common case) the behaviour is the
      same since FFmpeg seeks to the nearest keyframe and decodes
      forward.

    """

    alias Vix.Vips.Image, as: Vimage

    @typedoc """
    The valid options for `Image.Video.seek/2` and
    `Image.Video.image_from_video/2`.
    """
    @type seek_options :: [frame: non_neg_integer()] | [millisecond: non_neg_integer()]

    @typedoc """
    A video source. Either a file path / URL accepted by FFmpeg,
    `:default_camera` for the system's first webcam, or an
    explicit device path / integer index.
    """
    @type source :: Path.t() | :default_camera | non_neg_integer() | String.t()

    @typedoc """
    Options for `Image.Video.open/2`. Currently empty — the
    `:backend` option supported by the previous eVision-backed
    implementation has been removed.
    """
    @type open_options :: []

    @typedoc """
    Options for `Image.Video.stream!/2`.
    """
    @type stream_options :: [
            {:start, non_neg_integer()}
            | {:finish, integer()}
            | {:step, pos_integer()}
            | {:frame, non_neg_integer() | nil}
            | {:millisecond, non_neg_integer() | nil}
          ]

    @typedoc """
    The representation of an open video.

    `:reader` holds the underlying `Xav.Reader` struct. The
    derived `:fps`, `:duration_seconds`, `:frame_count`, `:width`,
    and `:height` fields are computed at open time so callers can
    pattern-match without re-querying FFmpeg.
    """
    @type t :: %__MODULE__{
            reader: Xav.Reader.t() | nil,
            source: source(),
            fps: float(),
            duration_seconds: float(),
            frame_count: non_neg_integer(),
            width: pos_integer() | nil,
            height: pos_integer() | nil
          }

    defstruct [:reader, :source, :fps, :duration_seconds, :frame_count, :width, :height]

    @doc subject: "Guard"
    @doc "Guards that a frame offset is valid for a video"
    defguard is_frame(frame, frame_count)
             when (is_integer(frame) and frame >= 0 and frame <= frame_count - 1) or
                    (is_integer(frame) and frame_count == 0)

    @doc subject: "Guard"
    @doc "Guards that a millisecond count is valid for a video"
    defguard is_valid_millis(millis, duration_seconds)
             when is_integer(millis) and millis >= 0 and
                    (millis <= trunc(duration_seconds * 1000) - 1 or duration_seconds == 0)

    @doc subject: "Guard"
    @doc "Guards that a stream identifier is valid for a video device"
    defguard is_stream(stream_id)
             when (is_integer(stream_id) and stream_id >= 0) or stream_id == :default_camera

    # ----- with_video --------------------------------------------------------

    @doc """
    Opens a video, calls the given function with the video
    reference, and discards the reference when the function
    returns.

    ### Arguments

    * `source` is the filename of a video file, a URL accepted
      by FFmpeg, or a device specifier — see `open/2`.

    * `fun` is a 1-arity function called with the open
      `%Image.Video{}` struct.

    ### Returns

    * The result of `fun.(video)` or

    * `{:error, reason}` if the video could not be opened.

    ### Example

        iex> result = Image.Video.with_video("./test/support/video/video_sample.mp4", &Image.Video.image_from_video/1)
        iex> match?({:ok, %Vix.Vips.Image{}}, result)
        true

    """
    @doc subject: "Load and save"
    @spec with_video(source(), (t() -> any())) :: any()
    def with_video(source, fun) when is_function(fun, 1) do
      case open(source) do
        {:ok, video} ->
          try do
            fun.(video)
          after
            close(video)
          end

        {:error, _} = err ->
          err
      end
    end

    # ----- open / open! ------------------------------------------------------

    @doc """
    Opens a video for frame extraction.

    ### Arguments

    * `source` is one of:

      * a file path to a video file;
      * a URL accepted by FFmpeg (`http://`, `https://`,
        `rtmp://`, `rtsp://`, …);
      * the atom `:default_camera` for the system's first webcam.
        Resolves to `/dev/video0` on Linux. On macOS this is
        passed to FFmpeg's AVFoundation input;
      * a non-negative integer camera index. Resolves to
        `/dev/videoN` on Linux. Use a device path string on
        other platforms;
      * a device path string interpreted by FFmpeg directly.

    * `options` is a keyword list. Currently no options are
      defined; the `:backend` option supported by previous
      releases has been removed.

    ### Returns

    * `{:ok, %Image.Video{}}` on success or

    * `{:error, %Image.Error{}}`.

    ### Example

        iex> {:ok, video} = Image.Video.open("./test/support/video/video_sample.mp4")
        iex> video.fps
        30.0

    """
    @doc subject: "Load and save"
    @spec open(source(), open_options()) :: {:ok, t()} | {:error, Image.error()}
    def open(source, options \\ [])

    def open(source, _options) when is_binary(source) do
      do_open(source, source, device?: false)
    end

    def open(:default_camera, _options) do
      device = default_camera_path()
      do_open(device, :default_camera, device?: true)
    end

    def open(camera, _options) when is_integer(camera) and camera >= 0 do
      device = camera_path(camera)
      do_open(device, camera, device?: true)
    end

    @doc """
    Opens a video for frame extraction, raising on error.

    See `open/2`.
    """
    @doc subject: "Load and save"
    @spec open!(source()) :: t() | no_return()
    def open!(source) do
      case open(source) do
        {:ok, video} -> video
        {:error, error} -> raise error
      end
    end

    defp do_open(path_or_device, source, xav_options) do
      case Xav.Reader.new(path_or_device, xav_options) do
        {:ok, reader} ->
          {:ok, build(reader, source)}

        {:error, reason} ->
          {:error,
           Image.Error.wrap(reason,
             operation: :video_open,
             path: path_or_device
           )}
      end
    end

    defp build(%Xav.Reader{} = reader, source) do
      fps = framerate_to_fps(reader.framerate)
      duration_seconds = reader.duration * 1.0

      %__MODULE__{
        reader: reader,
        source: source,
        fps: fps,
        duration_seconds: duration_seconds,
        frame_count: trunc(fps * duration_seconds),
        width: nil,
        height: nil
      }
    end

    defp framerate_to_fps({num, den}) when is_integer(num) and is_integer(den) and den > 0,
      do: num / den

    defp framerate_to_fps(_), do: 0.0

    # ----- close -------------------------------------------------------------

    @doc """
    Closes a video.

    Xav's reader is garbage-collected so explicit close is not
    required. This function is provided for source compatibility
    with the previous implementation: it returns
    `{:ok, %Image.Video{reader: nil}}` so subsequent operations
    against the same struct will fail with a clear error.

    ### Arguments

    * `video` is any `t:Image.Video.t/0` returned from `open/2`.

    ### Returns

    * `{:ok, video}` where `video.reader` is now `nil`.

    """
    @doc subject: "Load and save"
    @spec close(t()) :: {:ok, t()}
    def close(%__MODULE__{} = video) do
      {:ok, %{video | reader: nil}}
    end

    @doc """
    Closes a video, raising on error.

    See `close/1`.
    """
    @doc subject: "Load and save"
    @spec close!(t()) :: t()
    def close!(%__MODULE__{} = video) do
      {:ok, closed} = close(video)
      closed
    end

    # ----- stream! -----------------------------------------------------------

    @doc """
    Returns a `Stream` of images from a video.

    ### Arguments

    * `video` is any `t:Image.Video.t/0` returned from `open/2`.

    * `options` is a keyword list of options.

    ### Options

    * `:frame` — start frame offset (default `0`).

    * `:millisecond` — start millisecond offset.

    * `:start` — same as `:frame` (kept for back-compat).

    * `:finish` — last frame offset, inclusive. Default `-1`
      (meaning to the end of the video).

    * `:step` — number of frames to advance between yielded
      frames. Default `1`.

    Only one of `:frame` / `:millisecond` may be supplied.

    ### Returns

    * A `Stream` that produces `t:Vix.Vips.Image.t/0` images
      lazily as enumerated.

    ### Example

        iex> video = Image.Video.open!("./test/support/video/video_sample.mp4")
        iex> video |> Image.Video.stream!(start: 0, finish: 2) |> Enum.count()
        3

    """
    @doc subject: "Load and save"
    @spec stream!(t(), stream_options()) :: Enumerable.t()
    def stream!(video, options \\ [])

    def stream!(%__MODULE__{reader: nil}, _options) do
      raise Image.Error,
        reason: :video_closed,
        message: "Video has been closed"
    end

    def stream!(%__MODULE__{} = video, options) do
      start_frame = start_frame(video, options)
      finish_frame = finish_frame(video, options)
      step = Keyword.get(options, :step, 1)

      Stream.resource(
        fn -> {video, start_frame, finish_frame, step, true} end,
        &advance_stream/1,
        fn _state -> :ok end
      )
    end

    defp start_frame(video, options) do
      cond do
        ms = Keyword.get(options, :millisecond) -> millisecond_to_frame(video, ms)
        frame = Keyword.get(options, :frame) -> frame
        true -> Keyword.get(options, :start, 0)
      end
    end

    defp finish_frame(video, options) do
      case Keyword.get(options, :finish, -1) do
        -1 -> video.frame_count - 1
        n when is_integer(n) and n >= 0 -> n
      end
    end

    defp advance_stream({video, current, finish, _step, _seek_first}) when current > finish do
      {:halt, video}
    end

    defp advance_stream({video, current, finish, step, true}) do
      _ = seek_to_frame(video, current)
      emit_current_frame(video, current, finish, step)
    end

    defp advance_stream({video, current, finish, step, false}) do
      # Advance step - 1 frames (already at the previous yielded frame),
      # then yield.
      Enum.each(1..(step - 1)//1, fn _ -> Xav.Reader.next_frame(video.reader) end)
      emit_current_frame(video, current, finish, step)
    end

    defp emit_current_frame(video, current, finish, step) do
      case Xav.Reader.next_frame(video.reader) do
        {:ok, frame} ->
          {:ok, image} = frame_to_image(frame)
          {[image], {video, current + step, finish, step, false}}

        {:error, :eof} ->
          {:halt, video}
      end
    end

    # ----- seek --------------------------------------------------------------

    @doc """
    Seeks the video head to a frame or millisecond offset.

    Note that seeking is not supported on live video streams
    such as a webcam.

    ### Arguments

    * `video` is any `t:Image.Video.t/0` returned from `open/2`.

    * `options` is a keyword list with **exactly one** of:

      * `frame: non_neg_integer()` — seek to a frame offset.

      * `millisecond: non_neg_integer()` — seek to a millisecond
        offset.

    ### Returns

    * `{:ok, video}` on success or

    * `{:error, %Image.Error{}}`.

    ### Example

        iex> {:ok, video} = Image.Video.open("./test/support/video/video_sample.mp4")
        iex> {:ok, _} = Image.Video.seek(video, frame: 0)
        iex> {:ok, _} = Image.Video.seek(video, millisecond: 1_000)
        iex> {:error, %Image.Error{reason: :negative_offset}} = Image.Video.seek(video, frame: -1)
        iex> :ok
        :ok

    """
    @doc subject: "Operation"
    @spec seek(t(), seek_options()) :: {:ok, t()} | {:error, Image.error()}
    def seek(video, options)

    def seek(%__MODULE__{reader: nil}, _options) do
      {:error, video_closed_error()}
    end

    def seek(%__MODULE__{} = video, [{:frame, frame}])
        when is_frame(frame, video.frame_count) do
      seconds = frame / max(video.fps, 1.0)

      case Xav.Reader.seek(video.reader, seconds) do
        :ok -> {:ok, video}
        {:error, reason} -> {:error, Image.Error.wrap(reason, operation: :video_seek)}
      end
    end

    def seek(%__MODULE__{} = video, [{:millisecond, millis}])
        when is_valid_millis(millis, video.duration_seconds) do
      case Xav.Reader.seek(video.reader, millis / 1000) do
        :ok -> {:ok, video}
        {:error, reason} -> {:error, Image.Error.wrap(reason, operation: :video_seek)}
      end
    end

    def seek(%__MODULE__{}, [{unit, offset}])
        when unit in [:frame, :millisecond] and is_integer(offset) and offset < 0 do
      message =
        "Offset for #{inspect(unit)} must be a non-negative integer. Found #{inspect(offset)}"

      {:error, %Image.Error{reason: :negative_offset, value: offset, message: message}}
    end

    def seek(%__MODULE__{}, [{unit, _offset}]) when unit in [:frame, :millisecond] do
      {:error,
       %Image.Error{
         reason: :frame_out_of_range,
         message: "Offset for #{inspect(unit)} is too large"
       }}
    end

    def seek(%__MODULE__{}, options) do
      message =
        "Options must be either `frame: frame_offset` or " <>
          "`millisecond: millisecond_offset`. Found #{inspect(options)}"

      {:error, %Image.Error{reason: :invalid_seek_options, value: options, message: message}}
    end

    @doc """
    Seeks the video head to a frame or millisecond offset,
    raising on error. See `seek/2`.
    """
    @doc subject: "Operation"
    @spec seek!(t(), seek_options()) :: t() | no_return()
    def seek!(video, options) do
      case seek(video, options) do
        {:ok, video} -> video
        {:error, error} -> raise error
      end
    end

    # ----- scrub -------------------------------------------------------------

    @doc """
    Advances the video head by `frames` frames without
    decoding them as images.

    ### Arguments

    * `video` is any `t:Image.Video.t/0` returned from `open/2`.

    * `frames` is the number of frames to advance.

    ### Returns

    * `{:ok, video}` after advancing or

    * `{:error, %Image.Error{}}`.

    """
    @doc subject: "Operation"
    @spec scrub(t(), pos_integer()) :: {:ok, t()} | {:error, Image.error()}
    def scrub(%__MODULE__{reader: nil}, _frames) do
      {:error, video_closed_error()}
    end

    def scrub(%__MODULE__{} = video, frames)
        when is_integer(frames) and frames > 0 do
      Enum.each(1..frames, fn _ -> Xav.Reader.next_frame(video.reader) end)
      {:ok, video}
    end

    # ----- image_from_video --------------------------------------------------

    @doc """
    Reads a single frame from a video as an `t:Vix.Vips.Image.t/0`.

    ### Arguments

    * `video` is any `t:Image.Video.t/0` returned from `open/2`.

    * `options` is `[]`, `[frame: n]`, or `[millisecond: n]`.

    ### Returns

    * `{:ok, image}` or

    * `{:error, %Image.Error{}}`.

    ### Example

        iex> {:ok, video} = Image.Video.open("./test/support/video/video_sample.mp4")
        iex> {:ok, _image} = Image.Video.image_from_video(video)
        iex> {:ok, _image} = Image.Video.image_from_video(video, frame: 0)
        iex> {:ok, _image} = Image.Video.image_from_video(video, millisecond: 1_000)
        iex> {:error, %Image.Error{reason: :negative_offset}} = Image.Video.image_from_video(video, frame: -1)
        iex> {:error, %Image.Error{reason: :frame_out_of_range}} = Image.Video.image_from_video(video, frame: 500)
        iex> :ok
        :ok

    """
    @doc subject: "Operation"
    @spec image_from_video(t(), seek_options()) ::
            {:ok, Vimage.t()} | {:error, Image.error()}
    def image_from_video(video, options \\ [])

    def image_from_video(%__MODULE__{reader: nil}, _options) do
      {:error, video_closed_error()}
    end

    def image_from_video(%__MODULE__{} = video, []) do
      case Xav.Reader.next_frame(video.reader) do
        {:ok, frame} ->
          frame_to_image(frame)

        {:error, :eof} ->
          {:error,
           %Image.Error{
             reason: :end_of_stream,
             message: "Reached end of video stream"
           }}
      end
    end

    def image_from_video(%__MODULE__{} = video, options) do
      with {:ok, video} <- seek(video, options) do
        image_from_video(video, [])
      end
    end

    @doc """
    Reads a single frame from a video as an
    `t:Vix.Vips.Image.t/0`, raising on error. See
    `image_from_video/2`.
    """
    @doc subject: "Operation"
    @spec image_from_video!(t(), seek_options()) :: Vimage.t() | no_return()
    def image_from_video!(video, options \\ []) do
      case image_from_video(video, options) do
        {:ok, image} -> image
        {:error, error} -> raise error
      end
    end

    # ----- frame conversion --------------------------------------------------

    @doc false
    def frame_to_image(%Xav.Frame{
          type: :video,
          data: data,
          width: width,
          height: height,
          format: format
        })
        when format in [:rgb24, :bgr24] do
      bands = 3

      case Vix.Vips.Image.new_from_binary(data, width, height, bands, :VIPS_FORMAT_UCHAR) do
        {:ok, image} ->
          if format == :bgr24 do
            with {:ok, swapped} <- Vix.Vips.Operation.bandjoin([image[2], image[1], image[0]]) do
              {:ok, swapped}
            end
          else
            {:ok, image}
          end

        {:error, reason} ->
          {:error, Image.Error.wrap(reason, operation: :frame_to_image)}
      end
    end

    def frame_to_image(%Xav.Frame{format: format}) do
      {:error,
       %Image.Error{
         reason: :unsupported_frame_format,
         value: format,
         message: "Unsupported video frame format: #{inspect(format)}"
       }}
    end

    # ----- helpers -----------------------------------------------------------

    defp millisecond_to_frame(%__MODULE__{fps: fps}, millis) do
      trunc(millis / 1000 * fps)
    end

    defp seek_to_frame(%__MODULE__{} = video, 0), do: {:ok, video}

    defp seek_to_frame(%__MODULE__{} = video, frame) do
      seconds = frame / max(video.fps, 1.0)
      _ = Xav.Reader.seek(video.reader, seconds)
      {:ok, video}
    end

    defp default_camera_path do
      case :os.type() do
        {:unix, :darwin} -> "0"
        {:unix, _} -> "/dev/video0"
        {:win32, _} -> "video=0"
      end
    end

    defp camera_path(index) do
      case :os.type() do
        {:unix, :darwin} -> Integer.to_string(index)
        {:unix, _} -> "/dev/video#{index}"
        {:win32, _} -> "video=#{index}"
      end
    end

    defp video_closed_error do
      %Image.Error{
        reason: :video_closed,
        message: "Video has been closed"
      }
    end
  end
end
