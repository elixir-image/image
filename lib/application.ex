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

    if Code.ensure_loaded?(Bumblebee) do
      Application.ensure_all_started(:exla)

      Supervisor.start_link(
        [
          {Nx.Serving, serving: Image.Classification.serving(), name: Image.Serving, batch_timeout: 100}
        ],
        strategy: :one_for_one
      )
    end
  end
end

defmodule Image.SetSafeLoader do
  def set(env_var) do
    unless System.get_env(env_var) do
      System.put_env(env_var, "TRUE")
    end

    {:ok, env_var}
  end
end

