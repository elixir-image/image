defmodule Image.Detection do
  @moduledoc """
  Object detection based upon the [YOLO V8](https://docs.ultralytics.com)
  ML model.

  THIS IS AN EXPERIMENTAL MODULE. Please do not use in production. Testing
  is not yet complete.

  The code is an adaptation of the livecoding demo by Hans Elias (@hansihe) at
  his [talk](https://www.youtube.com/watch?v=OsxGB6MbA8o&t=1s) at the
  Elixir Warsaw meetup in March 2023.

  ### Accessing the Yolo V8 model

  The YOLO v8 model is GPL 3.0 licensed and must be built separately. Python
  3.10 is required (apparently it won't work with 3.11).

  ```bash
    pip3.10 install ultralytics onnyx
    yolo export model=yolov8n.pt format=onnx imgsz=640
  ```

  The "n" model is the smallest - we can maybe tolerate a larger one.
  And we need to find way to host the model or download the .onnx from
  somewhere.

  ### Dependencies

  * The dependencies for this module include some dependencies from github
    for now, including forks of `axon_onnx` and @hansihe's `yolov8_elixir`.
    Therefore this module can only be used by cloning the repo and checking out
    the `detection` branch. It can be configured by:

  ```elixir
  def deps do
    [
      {:image, github: "elixir-image/image", branch: "detect"}
    ]
  end
  ```

  ### References

  * The original talk by @hansihe is at https://www.youtube.com/watch?v=OsxGB6MbA8o&t=1s
  * The original models are stored at https://github.com/ultralytics/assets/releases
  * References: https://learnopencv.com/ultralytics-yolov8/

  """

  alias Vix.Vips.Image, as: Vimage

  @yolo_model_image_size 640

  @doc """
  Detect objects in an image.

  ### Arguments

  * `image` is any `t:Vimage.t/0` that might be
    returned by `Image.open/2`, `Image.from_kino/1` or
    `Image.from_binary/1`.

  * `model_path` is the path to a Yolo `.onnx` model
    file. The default is "priv/models/yolov8n.onnx".
    Note that this model must be user-provided. See the
    instructions in the `Image.Detection` module docs.

  ### Returns

  * `{:ok, image_with_bounding_boxes_and_labels}` or

  * `{:error, reason}`

  """
  @spec detect(image :: Vimage.t(), model_path: Path.t()) ::
    {:ok, Vimage.t()} | {:error, Image.error_message()}

  def detect(%Vimage{} = image, model_path \\ default_model_path()) do
    # Import the model and extract the
    # prediction function and its parameters.
    {model, params} = AxonOnnx.import(model_path)
    {_init_fn, predict_fn} = Axon.build(model, compiler: EXLA)

    # Flatten out any alpha band then resize the image
    # so the longest edge is the same as the model size,
    # then add a black border to expand the shorter dimension
    # so the overall image conforms to the model requirements.
    prepared_image =
      image
      |> Image.flatten!()
      |> Image.thumbnail!(@yolo_model_image_size)
      |> Image.embed!(@yolo_model_image_size, @yolo_model_image_size)

    # Move the image to Nx. This is nothing more
    # than moving a pointer under the covers
    # so its efficient. Then conform the data to
    # the shape and type required for the model.
    # Last we add an additional axis that represents
    # the batch (we use only a batch of 1).
    batch =
      prepared_image
      |> Image.to_nx!()
      |> Nx.transpose(axes: [2, 0, 1])
      |> Nx.as_type(:f32)
      |> Nx.divide(255)
      |> Nx.new_axis(0)

    # Run the prediction model, extract
    # the only batch that was sent
    # and transpose the axis back to
    # {width, height} layout for further
    # image processing.
    result =
      predict_fn.(params, batch)[0]
      |> Nx.transpose(axes: [1, 0])

    # Filter the data by certainty,
    # zip with the class names, draw
    # bounding boxes and labels and the
    # trim off the extra pixels we added
    # earlier to get back to the original
    # image shape.
    result
    |> Yolo.NMS.nms(0.5)
    |> Enum.zip(classes())
    |> draw_bbox_with_labels(prepared_image)
    |> Image.trim()
  end

  @doc """
  Detect objects in an image or raises and
  exception.

  ### Arguments

  * `image` is any `t:Vimage.t/0` that might be
    returned by `Image.open/2`, `Image.from_kino/1` or
    `Image.from_binary/1`.

  * `model_path` is the path to a Yolo `.onnx` model
    file. The default is "priv/models/yolov8n.onnx".
    Note that this model must be user-provided. See the
    instructions in the `Image.Detection` module docs.

  ### Returns

  * `image_with_bounding_boxes_and_labels` or

  * raises and exception.

  """
  @spec detect!(image :: Vimage.t(), model_path: Path.t()) ::
    Vimage.t() | no_return()

  def detect!(%Vimage{} = image, model_path \\ default_model_path()) do
    case detect(image, model_path) do
      {:ok, image} -> image
      {:error, reason} -> raise Image.Error, reason
    end
  end

  defp default_model_path do
    path =
      :image
      |> Application.app_dir("priv/models/")
      |> Path.join("yolov8n.onnx")

    if File.exists?(path) do
      path
    else
      raise ArgumentError,
        """
        The default model was not found at #{inspect path}.

        To install the model ensure python3.10 is installed
        then:

        pip3.10 install ultralytics onnyx
        yolo export model=yolov8n.pt format=onnx imgsz=640

        And move the resulting yolov8n.onnx file to the
        #{inspect path}.
        """
    end
  end

  # Draws bounding boxes with labels
  def draw_bbox_with_labels(object_boxes, image) do
    Enum.reduce(object_boxes, image, fn {boxes, class_name}, image ->
      Enum.reduce(boxes, image, fn [cx, cy, w, h | _probs], image ->
        {:ok, bounding_box_image} =
          Image.Shape.rect(round(w), round(h), stroke_color: :red, stroke_width: 4)

        {:ok, text_image} =
          Image.Text.text(class_name, text_fill_color: :red, font_size: 20, padding: 5)

        image
        |> Image.compose!(bounding_box_image,
          x: round(cx - w / 2),
          y: round(cy - h / 2))
        |> Image.compose!(text_image,
          x: min(max(round(cx - w / 2), 0),  @yolo_model_image_size),
          y: min(max(round(cy - h / 2), 0),  @yolo_model_image_size)
        )
      end)
    end)
  end

  def filter_predictions(bboxes, thresh \\ 0.5) do
    boxes = Nx.slice(bboxes, [0, 0], [8400, 4])
    probs = Nx.slice(bboxes, [0, 4], [8400, 80])
    max_prob = Nx.reduce_max(probs, axes: [1])

    sorted_idxs =
      Nx.argsort(max_prob, direction: :desc)

    boxes =
      [boxes, Nx.new_axis(max_prob, 1)]
      |> Nx.concatenate(axis: 1)
      |> Nx.take(sorted_idxs)

    boxes
    |> Nx.to_list()
    |> Enum.take_while(fn [_, _, _, _, prob] -> prob > thresh end)
  end

  def classes do
    """
    person
    bicycle
    car
    motorbike
    aeroplane
    bus
    train
    truck
    boat
    traffic light
    fire hydrant
    stop sign
    parking meter
    bench
    bird
    cat
    dog
    horse
    sheep
    cow
    elephant
    bear
    zebra
    giraffe
    backpack
    umbrella
    handbag
    tie
    suitcase
    frisbee
    skis
    snowboard
    sports ball
    kite
    baseball bat
    baseball glove
    skateboard
    surfboard
    tennis racket
    bottle
    wine glass
    cup
    fork
    knife
    spoon
    bowl
    banana
    apple
    sandwich
    orange
    broccoli
    carrot
    hot dog
    pizza
    donut
    cake
    chair
    sofa
    pottedplant
    bed
    diningtable
    toilet
    tvmonitor
    laptop
    mouse
    remote
    keyboard
    cell phone
    microwave
    oven
    toaster
    sink
    refrigerator
    book
    clock
    vase
    scissors
    teddy bear
    hair drier
    toothbrush
    """
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
  end
end
