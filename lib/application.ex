defmodule Image.Application do
  @moduledoc false

  # This env var, if set, will prevent `libvips`
  # from loading untrusted loaders.  We set this to
  # true if it is not otherwise set.
  # See https://github.com/kipcole9/image/issues/9
  @untrusted_env_var "VIPS_BLOCK_UNTRUSTED"

  use Application

  def start(_type, _args) do
    GenServer.start_link(Image.SetSafeLoader, @untrusted_env_var, name: :check_safe_image_loading)
  end

end

defmodule Image.SetSafeLoader do
  use GenServer

  def init(env_var) do
    unless System.get_env(env_var) do
      System.put_env(env_var, "TRUE")
    end

    {:ok, env_var}
  end
end
