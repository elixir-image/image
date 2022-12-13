if Image.ml_configured?() do
  defmodule Image.Classification do
    alias Vix.Vips.Image, as: Vimage

    @min_score 0.5

    @doc false
    def serving(model, featurizer) do
      {:ok, model_info} = Bumblebee.load_model(model)
      {:ok, featurizer} = Bumblebee.load_featurizer(featurizer)

      Bumblebee.Vision.image_classification(model_info, featurizer,
        top_k: 1,
        compile: [batch_size: 10],
        defn_options: [compiler: EXLA]
      )
    end

    @doc """
    Classify an image using a machine learning
    model.

    ### Arguments

    * `image` is any `t:Vix.Vips.Image.t/0`.

    * `backend` is any valid Nx backend. The default is
      `Nx.default_backend/0`.

    ### Returns

    * A map containing the estimations of the image
      classification.

    ### Examples

        iex> {:ok, image} = Image.open ("./test/support/images/San-Francisco-2018-04-2549.jpg")
        iex> Image.Classification.classify(image)
        %{predictions: [%{label: "suspension bridge", score: 0.9412655830383301}]}

    """

    # Based upon: https://github.com/cocoa-xu/evision/issues/80

    @spec classify(image :: Vimage.t(), backend :: Nx.Backend.t()) ::
            %{predictions: [%{label: String.t(), score: float()}]} | {:error, Image.error_message()}

    def classify(%Vimage{} = image, backend \\ Nx.default_backend()) do
      with {:ok, mat} <- Image.to_evision(image, false) do
        binary = Evision.Mat.to_nx(mat, backend)
        Nx.Serving.batched_run(Image.Serving, binary)
      end
    end

    @doc """
    Classify an image using a machine learning
    model and return the labels that meet a minimum
    score.

    ### Arguments

    * `image` is any `t:Vix.Vips.Image.t/0`.

    * `options` is a keyword list of options.

    ### Options

    * `:backend` is any valid Nx backend. The default is
      `Nx.default_backend/0`.

    * `:min_score` is the minimum score, a float between `0`
      and `1`, which a label must match in order to be
      returned.

    ### Returns

    * A list of labels. The list may be empty if there
      are no predictions that exceed the `:min_score`.

    * `{:error, reason}`

    ### Examples

        iex> {:ok, image} = Image.open ("./test/support/images/lamborghini-forsennato-concept.jpg")
        iex> Image.Classification.labels(image)
        ["sports car", "sport car"]

    """
    @spec labels(image :: Vimage.t(), options :: Keyword.t()) ::
            [String.t()] | {:error, Image.error_message()}

    def labels(%Vimage{} = image, options \\ []) do
      backend = Keyword.get(options, :backend, Nx.default_backend())
      min_score = Keyword.get(options, :min_score, @min_score)

      with %{predictions: predictions} <- classify(image, backend) do
        predictions
        |> Enum.filter(fn %{score: score} -> score >= min_score end)
        |> Enum.flat_map(fn %{label: label} -> String.split(label, ", ") end)
      end
    end
  end
end
