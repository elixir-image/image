if match?({:module, _module}, Code.ensure_compiled(Evision)) do
  defmodule Image.Options.Video do
    @moduledoc """
    Options and option validation for `Image.Video.stream!/2`.

    """

    # Its a video stream, no options may be provided
    def validate_stream_options(%Evision.VideoCapture{frame_count: 0.0}, []) do
      {:ok, {nil, nil, nil, nil}}
    end

    def validate_stream_options(%Evision.VideoCapture{frame_count: frame_count}, []) do
      {:ok, {:frame, 0, trunc(frame_count) - 1, 1}}
    end

    def validate_stream_options(%Evision.VideoCapture{} = video, frame: first..last = range)
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

    def validate_stream_options(%Evision.VideoCapture{} = video, millisecond: first..last = range)
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

    def validate_stream_options(%Evision.VideoCapture{} = video, frame: first..last = range) do
      %{frame_count: frame_count} = video
      step = abs(Map.get(range, :step, 1))
      first = if first < 0, do: trunc(frame_count + first), else: first
      last = if last < 0, do: trunc(frame_count + last), else: last

      validate_stream_options(video, frame: Range.new(first, last, step))
    end

    def validate_stream_options(%Evision.VideoCapture{} = video, millisecond: first..last = range)
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
