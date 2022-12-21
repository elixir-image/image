defmodule Image.Application do
  @moduledoc false

  # This env var, if set, will prevent `libvips`
  # from loading untrusted loaders.  We set this to
  # true if it is not otherwise set.
  # See https://github.com/kipcole9/image/issues/9
  @untrusted_env_var "VIPS_BLOCK_UNTRUSTED"

  use Application

  def start(_type, _args) do
    Image.SetSafeLoader.set(@untrusted_env_var)

    Supervisor.start_link(
      children(Code.ensure_loaded?(Bumblebee)),
      strategy: :one_for_one
    )
  end

  # When Bumblebee is available
  def children(true) do
    classifer_enabled? = Application.get_env(:image, :classifer, [enabled: true]) |> Keyword.get(:enabled)
    generator_enabled? = Application.get_env(:image, :generator, [enabled: false]) |> Keyword.get(:enabled)

    children = if classifer_enabled?, do: [image_classifier()], else: []
    if generator_enabled?, do: [image_generator() | children], else: children
  end

  # When bumblebee is not available
  def children(false) do
    []
  end

  @default_classifier [
    model: {:hf, "microsoft/resnet-50"},
    featurizer: {:hf, "microsoft/resnet-50"},
    enabled: true
  ]

  def image_classifier(classifier \\ Application.get_env(:image, :classifier, [])) do
    Application.ensure_all_started(:exla)
    classifier = Keyword.merge(@default_classifier, classifier)

    {Nx.Serving,
     serving: Image.Classification.serving(classifier[:model], classifier[:featurizer]),
     name: Image.Classification.Serving,
     batch_timeout: 100}
  end

  @default_generator [
    repository_id: "CompVis/stable-diffusion-v1-4",
    scheduler: {:hf, "CompVis/stable-diffusion-v1-4", subdir: "scheduler"},
    featurizer: {:hf, "CompVis/stable-diffusion-v1-4", subdir: "feature_extractor"},
    safety_checker: {:hf, "CompVis/stable-diffusion-v1-4", subdir: "safety_checker"}
  ]

  def image_generator(generator \\ Application.get_env(:image, :generator, []), options \\ []) do
    Application.ensure_all_started(:exla)
    generator = Keyword.merge(@default_generator, generator)

    {Nx.Serving,
     serving: Image.Generation.serving(generator, options),
     name: Image.Generation.Serving,
     batch_timeout: 100}
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
