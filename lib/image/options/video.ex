if Image.evision_configured?() do
  defmodule Image.Options.Video do
    @moduledoc """
    Options and option validation for `Image.Video.stream!/2`.

    """

    @type backend ::
            :any
            | :vfw
            | :v4l
            | :v4l2
            | :firewire
            | :fireware
            | :ieee1394
            | :dc1394
            | :cmu1394
            | :qt
            | :unicap
            | :dshow
            | :pvapi
            | :openni
            | :openni_asus
            | :android
            | :xiapi
            | :avfoundation
            | :giganetix
            | :msmf
            | :winrt
            | :intelperc
            | :realsense
            | :openni2
            | :openni2_asus
            | :openni2_astra
            | :gphoto2
            | :gstreamer
            | :ffmpeg
            | :images
            | :aravis
            | :opencv_mjpeg
            | :intel_mfx
            | :xine
            | :ueye
            | :obsensor
            | pos_integer()

    @type open_options :: [
            {:backend, backend()}
          ]

    # See https://docs.opencv.org/4.x/d4/d15/group__videoio__flags__base.html#ga023786be1ee68a9105bf2e48c700294d
    @backend_map %{
      any: 0,
      vfw: 200,
      v4l: 200,
      v4l2: 200,
      firewire: 300,
      fireware: 300,
      ieee1394: 300,
      dc1394: 300,
      cmu1394: 300,
      qt: 500,
      unicap: 600,
      dshow: 700,
      pvapi: 800,
      openni: 900,
      openni_asus: 910,
      android: 1000,
      xiapi: 1100,
      avfoundation: 1200,
      giganetix: 1300,
      msmf: 1400,
      winrt: 1410,
      intelperc: 1500,
      realsense: 1500,
      openni2: 1600,
      openni2_asus: 1610,
      openni2_astra: 1620,
      gphoto2: 1700,
      gstreamer: 1800,
      ffmpeg: 1900,
      images: 2000,
      aravis: 2100,
      opencv_mjpeg: 2200,
      intel_mfx: 2300,
      xine: 2400,
      ueye: 2500,
      obsensor: 2600
    }

    @inverted_backend_map Map.new(@backend_map, fn {key, val} -> {val, key} end)
    @any_backend Map.fetch!(@backend_map, :any)

    def known_backends do
      @backend_map
    end

    @doc false
    def inverted_known_backends do
      @inverted_backend_map
    end

    def validate_open_options([]) do
      {:ok, @any_backend}
    end

    def validate_open_options(backend: backend) when is_atom(backend) do
      case Map.fetch(known_backends(), backend) do
        {:ok, backend} -> {:ok, backend}
        :error -> {:error, "Invalid or unknown backend #{inspect(backend)}"}
      end
    end

    def validate_open_options(backend: backend) when is_integer(backend) do
      case Map.has_key?(inverted_known_backends(), backend) do
        true -> {:ok, backend}
        false -> {:error, "Invalid or unknown backend #{inspect(backend)}"}
      end
    end

    # Its a video stream, no options may be provided
    def validate_stream_options(%Evision.VideoCapture{frame_count: frame}, []) when frame == 0.0 do
      {:ok, {nil, nil, nil, nil}}
    end

    def validate_stream_options(%Evision.VideoCapture{frame_count: frame_count}, []) do
      {:ok, {:frame, 0, trunc(frame_count) - 1, 1}}
    end

    def validate_stream_options(%Evision.VideoCapture{} = video,
          frame: %Range{first: first, last: last} = range
        )
        when first >= 0 and last > first do
      %{frame_count: frame_count} = video
      max_frame = trunc(frame_count) - 1
      step = Map.get(range, :step, 1)

      if first <= max_frame and last <= max_frame do
        {:ok, {:frame, first, last, step}}
      else
        {:error,
         "Requested range #{inspect(range)} is not in the maximal range 0..#{inspect(max_frame)}"}
      end
    end

    def validate_stream_options(%Evision.VideoCapture{} = video,
          millisecond: %Range{first: first, last: last} = range
        )
        when first >= 0 and last > first do
      %{frame_count: frame_count, fps: fps} = video
      max_millis = trunc(frame_count * fps * 1_000) - 1
      step = Map.get(range, :step, 1)

      if first <= max_millis and last <= max_millis do
        {:ok, {:millisecond, first, last, step}}
      else
        {:error,
         "Requestged range #{inspect(range)} is not in the maximum range 0..#{inspect(max_millis)}"}
      end
    end

    def validate_stream_options(%Evision.VideoCapture{} = video,
          frame: %Range{first: first, last: last} = range
        ) do
      %{frame_count: frame_count} = video
      step = abs(Map.get(range, :step, 1))
      first = if first < 0, do: trunc(frame_count + first), else: first
      last = if last < 0, do: trunc(frame_count + last), else: last

      validate_stream_options(video, frame: Range.new(first, last, step))
    end

    def validate_stream_options(%Evision.VideoCapture{} = video,
          millisecond: %Range{first: first, last: last} = range
        )
        when first < 0 and last < 0 and last > first do
      %{frame_count: frame_count, fps: fps} = video
      max_millis = trunc(frame_count * fps * 1_000)
      step = abs(Map.get(range, :step, 1))
      first = if first < 0, do: max_millis + first, else: first
      last = if last < 0, do: max_millis + last, else: last

      validate_stream_options(video, millisecond: Range.new(first, last, step))
    end

    def validate_stream_options!(video, options) do
      case validate_stream_options(video, options) do
        {:ok, options} -> options
        {:error, reason} -> raise Image.Error, reason
      end
    end
  end
end
