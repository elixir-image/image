defmodule Image.Application do
  @moduledoc false

  # This env var, if set, will prevent `libvips`
  # from loading untrusted loaders.  We set this to
  # true if it is not otherwise set.
  # See https://github.com/kipcole9/image/issues/9
  @untrusted_env_var "VIPS_BLOCK_UNTRUSTED"

  use Application
  require Logger

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
  if Image.bumblebee_configured?() do
    @services [
      {{Image.Classification, :classifier, []}, true},
      {{Image.Generation, :generator, []}, false}
    ]

    defp children(true) do
      Enum.reduce(@services, [], fn {{module, function, args}, start?}, acc ->
        if autostart?(function, start?) do
          case apply(module, function, args) do
            {:error, reason} ->
              Logger.warning("Cannot autostart #{inspect(function)}. Error: #{inspect(reason)}")
              acc

            server ->
              [server | acc]
          end
        else
          acc
        end
      end)
    end
  end

  # When bumblebee is not available
  defp children(_) do
    []
  end

  @doc false
  def autostart?(service, start?) do
    :image
    |> Application.get_env(service, autostart: start?)
    |> Keyword.get(:autostart)
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
