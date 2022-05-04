defmodule Image.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :image,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      source_url: "https://github.com/kipcole/image",
      docs: docs(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: preferred_cli_env(),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore_warnings",
        plt_add_apps: ~w(gettext inets jason mix plug sweet_xml ratio)a
      ],
      compilers: Mix.compilers()
    ]
  end

  defp description do
    """
    An approachable image processing library based upon Vix and libvips that
    is NIF-based, fast, multi-threaded, pipelined and has a low memory
    footprint.
    """
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:vix, "~> 0.9"},
      {:sweet_xml, "~> 0.7"},
      {:nx, "~> 0.1", optional: true},
      {:temp, "~> 0.4", only: [:test, :dev], runtime: false},
      {:benchee, "~> 1.0", only: :dev, runtime: false, optional: true},
      {:ex_doc, "~> 0.18", only: [:release, :dev]},

      # Only used for benchmarking
      {:mogrify, "~> 0.9.1", only: :dev, optional: true}
    ]
  end

  defp package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache-2.0"],
      links: links(),
      files: [
        "lib",
        "mix.exs",
        "README*",
        "CHANGELOG*",
        "LICENSE*"
      ]
    ]
  end

  def links do
    %{
      "GitHub" => "https://github.com/kipcole9/image",
      "Readme" => "https://github.com/kipcole9/image/blob/v#{@version}/README.md",
      "Changelog" => "https://github.com/kipcole9/image/blob/v#{@version}/CHANGELOG.md",
      "Vix" => "https://github.com/akash-akya/vix",
      "libvips" => "https://www.libvips.org"
    }
  end

  def docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      logo: "logo.png",
      extras: [
        "README.md",
        "LICENSE.md",
        "CHANGELOG.md",
        "guides/examples.md"
      ],
      formatters: ["html"],
      groups_for_modules: groups_for_modules(),
      skip_undefined_reference_warnings_on: ["changelog", "CHANGELOG.md"]
    ]
  end

  defp groups_for_modules do
    [
      Options: ~r/Image.Options.*/,
      Exif: ~r/Image.Exif.*/,
      Xmp: ~r/Image.Xmp/
    ]
  end

  defp preferred_cli_env() do
    []
  end

  def aliases do
    []
  end

  defp elixirc_paths(:test), do: ["lib", "src", "dev", "mix/support/units", "mix/tasks", "test"]
  defp elixirc_paths(:dev), do: ["lib", "mix", "src", "dev", "bench"]
  defp elixirc_paths(:release), do: ["lib", "dev", "src"]
  defp elixirc_paths(_), do: ["lib", "src"]
end
