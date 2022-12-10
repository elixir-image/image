defmodule Image.Application do
  @moduledoc false

  # This env var, if set, will prevent `libvips`
  # from loading untrusted loaders.  We set this to
  # true if it is not otherwise set.
  # See https://github.com/kipcole9/image/issues/9
  @untrusted_env_var "VIPS_BLOCK_UNTRUSTED"

  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [
        {Image.SetSafeLoader, var: @untrusted_env_var, name: :check_safe_image_loading},
        {Nx.Serving, serving: Image.Classification.serving(), name: Image.Serving, batch_timeout: 100}
      ],
      strategy: :one_for_one
    )
  end
end

defmodule Image.SetSafeLoader do
  use GenServer

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(args) do
    env_var = args[:var]

    unless System.get_env(env_var) do
      System.put_env(env_var, "TRUE")
    end

    {:ok, env_var}
  end
end

