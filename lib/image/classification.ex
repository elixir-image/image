if Image.bumblebee_configured?() do
  defmodule Image.Classification do
    @moduledoc """
    Implements image classification functions using [Axon](https://hex.pm/packages/axon)
    machine learning models managed by [Bumblebee](https://hex.pm/packages/bumblebee).

    Image classification refers to the task of extracting information from an image.
    In this module, the information extracted is one or more labels desribing the
    image. Typically something like "sports car" or "Blenheim spaniel". The labels
    returns depend on the machine learning model used.

    ### Configuration

    The machine learning model to be used is configurable.
    The `:model` and `:featurizer` may be any model supported by Bumblebee. The
    `:name` is the name given to the classification service process.

    The default configuration is:

        # runtime.exs
        config :image, :classifier,
          model: {:hf, "microsoft/resnet-50"},
          featurizer:  {:hf, "microsoft/resnet-50"},
          name: Image.Classification.Server,
          autostart: true

    ### Autostart

    If `autostart: true` is configured (the default) then a process
    is started under a supervisor to execute the classification
    requests.  If running the process under an application
    supervision tree is desired, set `autostart: false`. In that
    case the function `classifer/1` can be
    used to return a `t:Supervisor.child_spec/0`.

    ### Adding a classification server to an application supervision tree

    To add image classification to an application supervision tree,
    use `Image.Classification.classifier/1` to return a child spec:
    For example:

        # Application.ex
        def start(_type, _args) do
          children = [
            # default classifier configuration
            Image.Classification.classifier()

            # custom classifier configuration
            Image.Classification.classifier(model: {:hf, "google/vit-base-patch16-224"},
              featurizer: {:hf, "google/vit-base-patch16-224"})
          ]

          Supervisor.start_link(
            children,
            strategy: :one_for_one
          )
        end

    ### Note

    This module is only available if the optional dependency
    [Bumblebee](https://hex.pm/packages/bumblebee) is configured in
    `mix.exs`.

    """

    alias Vix.Vips.Image, as: Vimage

    @min_score 0.5

    @default_classifier [
      model: {:hf, "microsoft/resnet-50"},
      featurizer: {:hf, "microsoft/resnet-50"},
      name: Image.Classification.Server,
      autostart: true
    ]

    @default_classifier_name @default_classifier[:name]

    @doc """
    Returns a child spec suitable for starting an image classification
    process as part of a supervision tree.

    ### Arguments

    * `configuration` is a keyword list.The default is
      `Application.get_env(:image, :classifier, [])`.

    ### Configuration keys

    * `:model` is any supported machine learning model for image
      classification supported by Bumblebee.

    * `:featurizer` is any supported machine learning model for image
      featurization supported by Bumblebee.

    * `:featurizer_module` is the module name of a featurizer known
      to Bumblee. Bumblebee will attempt to infer the featurizer module
      name but it may not always be able to do so. Specify only if
      Bumblebee is unable to resolve a featurizer module name.
      [Bumblebee.Vision.VitFeaturizer](https://hexdocs.pm/bumblebee/Bumblebee.Vision.VitFeaturizer.html)
      may be an appropriate choice when a featurizer module is required.

    * `:name` is the name given to the classification process when
      it is started.

    ### Default configuration

    The default configuration is:
    ```elixir
    [
      model: {:hf, "microsoft/resnet-50"},
      featurizer: {:hf, "microsoft/resnet-50"},
      name: Image.Classification.Server
    ]
    ```

    """
    @spec classifier(configuration :: Keyword.t()) :: {Nx.Serving, Keyword.t()}
    def classifier(classifier \\ Application.get_env(:image, :classifier, [])) do
      Application.ensure_all_started(:exla)
      classifier = Keyword.merge(@default_classifier, classifier)

      model = classifier[:model]
      featurizer = classifier[:featurizer]
      featurizer_module = classifier[:featurizer_module]

      case Image.Classification.serving(model, featurizer, featurizer_module) do
        {:error, error} ->
          {:error, error}

        serving ->
          {Nx.Serving, serving: serving, name: classifier[:name], batch_timeout: 100}
      end
    end

    @doc false
    def serving(model, featurizer, featurizer_module) do
      with {:ok, model_info} <- Bumblebee.load_model(model),
           {:ok, featurizer} = load_featurizer(featurizer, featurizer_module) do
        Bumblebee.Vision.image_classification(model_info, featurizer,
          compile: [batch_size: 10],
          defn_options: [compiler: EXLA]
        )
      end
    end

    defp load_featurizer(featurizer, nil = _featurizer_module) do
       Bumblebee.load_featurizer(featurizer)
    end

    defp load_featurizer(featurizer, featurizer_module) do
       Bumblebee.load_featurizer(featurizer, module: featurizer_module)
    end

    @doc """
    Classify an image using a machine learning
    model.

    ### Arguments

    * `image` is any `t:Vix.Vips.Image.t/0`.

    * `options` is a keyword list of options

    ### Options

    * `:backend` is any valid `Nx` backend. The default is
      `Nx.default_backend/0`.

    * `:server` is the name of the process performing the
      classification service. The default is `#{inspect(@default_classifier_name)}`.

    ### Returns

    * A map containing the predictions of the image
      classification.

    ### Example

        iex> puppy = Image.open!("./test/support/images/puppy.webp")
        iex> %{predictions: [%{label: "Blenheim spaniel", score: _} | _rest]} =
        ...>   Image.Classification.classify(puppy)

    """

    @dialyzer {:nowarn_function, {:classify, 1}}
    @dialyzer {:nowarn_function, {:classify, 2}}

    @doc since: "0.18.0"

    @spec classify(image :: Vimage.t(), Keyword.t()) ::
            %{predictions: [%{label: String.t(), score: float()}]} | {:error, Image.error_message()}

    def classify(%Vimage{} = image, options \\ []) do
      backend = Keyword.get(options, :backend, Nx.default_backend())
      server = Keyword.get(options, :server, @default_classifier_name)

      with {:ok, flattened} <- Image.flatten(image),
           {:ok, srgb} <- Image.to_colorspace(flattened, :srgb),
           {:ok, tensor} <- Image.to_nx(srgb, shape: :hwc, backend: backend) do
        Nx.Serving.batched_run(server, tensor)
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

    * `:backend` is any valid `Nx` backend. The default is
      `Nx.default_backend/0`.

    * `:min_score` is the minimum score, a float between `0.0`
      and `1.0`, which a label must match in order to be
      returned.

    ### Returns

    * A list of labels. The list may be empty if there
      are no predictions that exceed the `:min_score`.

    * `{:error, reason}`

    ### Example

        iex> {:ok, image} = Image.open ("./test/support/images/lamborghini-forsennato-concept.jpg")
        iex> Image.Classification.labels(image)
        ["sports car", "sport car"]

    """
    @dialyzer {:nowarn_function, {:labels, 1}}
    @dialyzer {:nowarn_function, {:labels, 2}}

    @doc since: "0.18.0"

    @spec labels(image :: Vimage.t(), options :: Keyword.t()) ::
            [String.t()] | {:error, Image.error_message()}

    def labels(%Vimage{} = image, options \\ []) do
      {min_score, options} = Keyword.pop(options, :min_score, @min_score)

      with %{predictions: predictions} <- classify(image, options) do
        predictions
        |> Enum.filter(fn %{score: score} -> score >= min_score end)
        |> Enum.flat_map(fn %{label: label} -> String.split(label, ", ") end)
      end
    end
  end
end
