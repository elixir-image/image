if Image.bumblebee_configured?() do
  defmodule Image.Generation do

    @default_options [
      num_steps: 20,
      num_images_per_prompt: 1
    ]

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

    def text_to_image(prompt, options \\ [])

    def text_to_image("", _options) do
      {:error, "No prompt was provided to guide image generation"}
    end

    def text_to_image(prompt, options) when is_binary(prompt) and is_list(options) do
      {server, options} = Keyword.pop(options, :server, Image.Generation.Server)
      {negative_prompt, _options} = Keyword.pop(options, :negative_prompt, "")

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