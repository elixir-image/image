defmodule Image.Classification do
  alias Vix.Vips.Image, as: Vimage

  def serving(model \\ "microsoft/resnet-50", featurizer \\ "microsoft/resnet-50") do
    {:ok, model_info} = Bumblebee.load_model({:hf, model})
    {:ok, featurizer} = Bumblebee.load_featurizer({:hf, featurizer})

    Bumblebee.Vision.image_classification(model_info, featurizer,
      top_k: 1,
      compile: [batch_size: 10],
      defn_options: [compiler: EXLA]
    )
  end

  def classify(%Vimage{} = image) do
    with {:ok, mat} <- Image.to_evision(image) do
      binary = Evision.Mat.to_nx(mat)
      tensor = Nx.backend_transfer(binary, EXLA.Backend)
      Nx.Serving.batched_run(Image.Serving, tensor)
    end
  end

end