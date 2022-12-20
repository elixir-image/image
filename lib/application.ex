defmodule Image.Application do
  @moduledoc false

  # This env var, if set, will prevent `libvips`
  # from loading untrusted loaders.  We set this to
  # true if it is not otherwise set.
  # See https://github.com/kipcole9/image/issues/9
  @untrusted_env_var "VIPS_BLOCK_UNTRUSTED"

  @default_classification_model {:hf, "microsoft/resnet-50"}
  @default_classification_featurizer {:hf, "microsoft/resnet-50"}

  use Application

  def start(_type, _args) do
    Image.SetSafeLoader.set(@untrusted_env_var)

    children = children(Code.ensure_loaded?(Bumblebee))

    Supervisor.start_link(
      children,
      strategy: :one_for_one
    )
  end

  # When Bumblebee is available
  def children(true) do
    Application.ensure_all_started(:exla)

    model = Application.get_env(:image, :classification_model, @default_classification_model)

    featurizer =
      Application.get_env(:image, :classification_featurizer, @default_classification_featurizer)

    [
      {Nx.Serving,
       serving: Image.Classification.serving(model, featurizer),
       name: Image.Classification.Serving,
       batch_timeout: 100}
    ]
  end

  # When bumblebee is not available
  def children(false) do
    []
  end
end

defmodule Image.SetSafeLoader do
  @moduledoc false

  def set(env_var) do
    unless System.get_env(env_var) do
      System.put_env(env_var, "TRUE")
    end

    {:ok, env_var}
  end
end
