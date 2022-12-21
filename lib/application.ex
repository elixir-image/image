defmodule Image.Application do
  @moduledoc false

  # This env var, if set, will prevent `libvips`
  # from loading untrusted loaders.  We set this to
  # true if it is not otherwise set.
  # See https://github.com/kipcole9/image/issues/9
  @untrusted_env_var "VIPS_BLOCK_UNTRUSTED"

  use Application

  @doc false
  def start(_type, _args) do
    Image.SetSafeLoader.set(@untrusted_env_var)

    Supervisor.start_link(
      children(Code.ensure_loaded?(Bumblebee)),
      strategy: :one_for_one,
      name: Image.Supervisor
    )
  end

  # When Bumblebee is available
  defp children(true) do
    classifer_start? = autostart?(:classifier)
    generator_start? = autostart?(:generator)

    children = if classifer_start?, do: [image_classifier()], else: []
    if generator_start?, do: [image_generator() | children], else: children
  end

  # When bumblebee is not available
  defp children(false) do
    []
  end

  defp autostart?(service) do
    :image
    |> Application.get_env(service, [autostart: true])
    |> Keyword.get(:autostart)
  end

  @default_classifier [
    model: {:hf, "microsoft/resnet-50"},
    featurizer: {:hf, "microsoft/resnet-50"},
    autostart: true
  ]

  def image_classifier(classifier \\ Application.get_env(:image, :classifier, [])) do
    Application.ensure_all_started(:exla)
    classifier = Keyword.merge(@default_classifier, classifier)

    {Nx.Serving,
     serving: Image.Classification.serving(classifier[:model], classifier[:featurizer]),
     name: Image.Classification.Server,
     batch_timeout: 100}
  end

  @default_generator [
    repository_id: "CompVis/stable-diffusion-v1-4",
    scheduler: {:hf, "CompVis/stable-diffusion-v1-4", subdir: "scheduler"},
    featurizer: {:hf, "CompVis/stable-diffusion-v1-4", subdir: "feature_extractor"},
    safety_checker: {:hf, "CompVis/stable-diffusion-v1-4", subdir: "safety_checker"},
    autostart: false
  ]

  @doc """
  Returns a child spec for service that generates images from text
  using Stable Diffusion implemented in Bumblebee.

  ### Arguments

  * `generator` is a keyword list of configuration
    options for an image generator or `:default`.

  * `options` is a keyword list of options

  ### Options

  * `:num_steps` determines the number of steps
    to execute in the generation model. The default
    is `20`. Changing this to `40` may increase image
    quality.

  * `:num_images_per_prompt` determines how many image
    alternatives are returned. The default is `1`.

  * `:name` is the name given to the child process. THe
    default is `Image.Generation.Server`.

  ### Default configuration

  If `generator` is set to `:default` the following configuration
  is used:

  ```elixir
  [
    repository_id: "CompVis/stable-diffusion-v1-4",
    scheduler: {:hf, "CompVis/stable-diffusion-v1-4", subdir: "scheduler"},
    featurizer: {:hf, "CompVis/stable-diffusion-v1-4", subdir: "feature_extractor"},
    safety_checker: {:hf, "CompVis/stable-diffusion-v1-4", subdir: "safety_checker"},
    autostart: false
  ]
  ```

  If no generator is specified (or it is set to `:default`
  then the configuration is derived from `runtime.exs` which
  is then merged into the default configuration. In
  `runtime.exs` the configuration would be specified as follows:

  ```elixir
  config :image, :generator,
    repository_id: "CompVis/stable-diffusion-v1-4",
    scheduler: {:hf, "CompVis/stable-diffusion-v1-4", subdir: "scheduler"},
    featurizer: {:hf, "CompVis/stable-diffusion-v1-4", subdir: "feature_extractor"},
    safety_checker: {:hf, "CompVis/stable-diffusion-v1-4", subdir: "safety_checker"},
    autostart: false
  ```

  ### Automatically starting the service

  The `:autostart` configuration option determines if the
  image generation service is started when the `:image` application
  is started.  The default is `false`. To cause the service to
  be started at application start, add the following to your
  `runtime.exs`:

  ```elixir
  config :image, :generator,
    autostart: true
  ```

  """
  def image_generator(generator \\ Application.get_env(:image, :generator, []), options \\ [])

  def image_generator(:default, options) do
    image_generator(Application.get_env(:image, :generator, []), options)
  end

  def image_generator(generator, options) do
    Application.ensure_all_started(:exla)
    generator = Keyword.merge(@default_generator, generator)
    {name, options} = Keyword.pop(options, :name, Image.Generation.Server)

    {Nx.Serving,
     serving: Image.Generation.serving(generator, options),
     name: name,
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
