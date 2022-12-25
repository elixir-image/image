if Image.bumblebee_configured?() do
  defmodule Image.Generation do
    @moduledoc """
    Implements image generation functions using [Axon](https://hex.pm/packages/axon)
    machine learning models managed by [Bumblebee](https://hex.pm/packages/bumblebee).

    ### Configuration

    The machine learning model to be used is configurable however
    only Stable Diffusion is currently supported.

    The default configuration is:

        # runtime.exs
        config :image, :generator,
          repository_id: "CompVis/stable-diffusion-v1-4",
          scheduler: {:hf, "CompVis/stable-diffusion-v1-4", subdir: "scheduler"},
          featurizer: {:hf, "CompVis/stable-diffusion-v1-4", subdir: "feature_extractor"},
          safety_checker: {:hf, "CompVis/stable-diffusion-v1-4", subdir: "safety_checker"},
          autostart: false

    ### Autostart

    If `autostart: true` is configured (the default is `false`) then
    a process is started under a supervisor to execute the generation
    requests.  If running the process under an application
    supervision tree is desired, set `autostart: false`. In that
    case the function `Image.Generation.generator/2` can be
    used to return a `t:Supervisor.child_spec/0`.

    ### Adding a image generation server to an application supervision tree

    To add image generation to an application supervision tree,
    use `Image.Generation.generator/2` to return a child spec:
    For example:

        # Application.ex
        def start(_type, _args) do
          children = [
            # default classifier configuration
            Image.Generation.generator()
          ]

          Supervisor.start_link(
            children,
            strategy: :one_for_one
          )
        end

    ### Starting a supervised image generation process

    If a dynamically started image generation process is
    required one can be started under a supervisor with:

        iex> Supervisor.start_link([Image.Generation.generator()], strategy: :one_for_one)

    """

    alias Vix.Vips.Image, as: Vimage

    @default_options [
      num_steps: 25,
      num_images_per_prompt: 1
    ]

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

    * `options` is a keyword list of options.

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
    def generator(generator \\ Application.get_env(:image, :generator, []), options \\ [])

    def generator(:default, options) do
      generator(Application.get_env(:image, :generator, []), options)
    end

    def generator(generator, options) do
      Application.ensure_all_started(:exla)
      generator = Keyword.merge(@default_generator, generator)
      {name, options} = Keyword.pop(options, :name, Image.Generation.Server)

      {Nx.Serving,
       serving: Image.Generation.serving(generator, options), name: name, batch_timeout: 100}
    end

    @doc false
    def serving(generator, options \\ []) do
      options = Keyword.validate!(options, @default_options)
      repository_id = generator[:repository_id]

      {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "openai/clip-vit-large-patch14"})

      {:ok, clip} = Bumblebee.load_model({:hf, repository_id, subdir: "text_encoder"})

      {:ok, unet} =
        Bumblebee.load_model({:hf, repository_id, subdir: "unet"},
          params_filename: "diffusion_pytorch_model.bin"
        )

      {:ok, vae} =
        Bumblebee.load_model({:hf, repository_id, subdir: "vae"},
          architecture: :decoder,
          params_filename: "diffusion_pytorch_model.bin"
        )

      {:ok, scheduler} = Bumblebee.load_scheduler(generator[:scheduler])
      {:ok, featurizer} = Bumblebee.load_featurizer(generator[:featurizer])
      {:ok, safety_checker} = Bumblebee.load_model(generator[:safety_checker])

      Bumblebee.Diffusion.StableDiffusion.text_to_image(clip, unet, vae, tokenizer, scheduler,
        num_steps: options[:num_steps],
        num_images_per_prompt: options[:num_images_per_prompt],
        safety_checker: safety_checker,
        safety_checker_featurizer: featurizer,
        compile: [batch_size: 1, sequence_length: 60],
        defn_options: [compiler: EXLA]
      )
    end

    @doc """
    Generates an image from a textual description using [Bumblebee's](https://hex.pm/packages/bumblebee)
    suport of the [Stable Diffusion](https://github.com/CompVis/stable-diffusion) model.

    ### Arguments

    * `prompt` is a `t:String.t/0` description of the scene to
      be generated.

    * `options` is a keyword list of options. The default is
      `negative_prompt: ""`.

    ### Options

    * `:negative_prompt` is a `t:String.t/0` that tells Stable Diffusion what you
      don't want to see in the generated images. When specified, it guides
      the generation process not to include things in the image according
      to a given text.

    ### Example

        iex> Image.Generation.text_to_image "impressionist purple numbat in the style of monet"
        [%Vix.Vips.Image{ref: #Reference<0.1281915998.296878104.76045>}]

    """
    @spec text_to_image(prompt :: String.t(), options :: Keyword.t()) :: [Vimage.t()]
    def text_to_image(prompt, options \\ [])

    def text_to_image("", _options) do
      {:error, "No prompt was provided to guide image generation"}
    end

    def text_to_image(prompt, options) when is_binary(prompt) and is_list(options) do
      {server, options} = Keyword.pop(options, :server, Image.Generation.Server)
      negative_prompt = Keyword.get(options, :negative_prompt, "")

      server
      |> Nx.Serving.batched_run(%{prompt: prompt, negative_prompt: negative_prompt})
      |> Map.fetch!(:results)
      |> Enum.map(fn %{image: tensor} ->
        {:ok, image} = Image.from_nx(tensor)
        image
      end)
    end
  end
end
