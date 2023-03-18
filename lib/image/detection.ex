defmodule Image.Detection do
  @moduledoc """
  Object detection based upon the [YOLO V8](https://docs.ultralytics.com)
  ML model.

  The code is heavily inspired by Hans Elias (@hansihe) and
  his [talk](https://www.youtube.com/watch?v=OsxGB6MbA8o&t=1s) at the
  Elixir Warsaw meetup in March 2023.

  The YOLO model is built as follows:

    pip3.10 install ultralytics onnyx
    yolo export model=yolov8n.pt format=onnx imgsz=640

  THe "n" model is the smallest - we can maybe tolerate a larger one.
  And we need to find way to host the model or download the .onnx from
  somewhere.

  The source models are stored at https://github.com/ultralytics/assets/releases

  """
end