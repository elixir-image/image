defmodule Image.Application do
  @moduledoc false

  # This env var, if set, will prevent `libvips` from loading untrusted
  # loaders. We set it to "TRUE" unless the user has explicitly set
  # something else. See https://github.com/kipcole9/image/issues/9
  @untrusted_env_var "VIPS_BLOCK_UNTRUSTED"

  use Application

  @doc false
  def start(_type, _args) do
    set_safe_loader()

    Supervisor.start_link(
      [],
      strategy: :one_for_one,
      name: Image.Supervisor
    )
  end

  # Sets `VIPS_BLOCK_UNTRUSTED=TRUE` in the environment unless the user
  # has already set it themselves. Prevents libvips from loading
  # untrusted format loaders, which is the secure default.
  defp set_safe_loader do
    unless System.get_env(@untrusted_env_var) do
      System.put_env(@untrusted_env_var, "TRUE")
    end

    :ok
  end
end
