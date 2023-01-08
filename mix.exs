defmodule Image.MixProject do
  use Mix.Project

  @version "0.21.0"
  @app_name "image"

  def project do
    [
      app: String.to_atom(@app_name),
      version: @version,
      elixir: "~> 1.12",
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      source_url: "https://github.com/kipcole9/image",
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
        plt_add_apps: ~w(mix nx plug evision bumblebee)a
      ],
      compilers: Mix.compilers()
    ]
  end

  defp description do
    """
    An approachable image processing library primarily based upon Vix and libvips that
    is NIF-based, fast, multi-threaded, pipelined and has a low memory
    footprint.
    """
  end

  def application do
    [
      mod: {Image.Application, []},
      extra_applications: [:logger, :inets, :crypto]
    ]
  end

  defp deps do
    [
      {:vix, "~> 0.15"},
      # {:vix, github: "akash-akya/vix", branch: "dev"},
      # {:vix, github: "akash-akya/vix"},
      # {:vix, github: "kipcole9/vix", branch: "binwrite"},
      # {:vix, path: "../vix"},

      # Kino for rendering in Livebook
      if(Version.compare(System.version(), "1.13.0") in [:gt, :eq],
        do: {:kino, "~> 0.7", optional: true}
      ),

      # eVision OpenCV bindings
      {:evision, ">= 0.1.14", optional: true},
      {:sweet_xml, "~> 0.7"},
      {:phoenix_html, "~> 3.2 or ~> 2.14"},

      # For streaming writes
      {:plug, "~> 1.13", optional: true},

      # For NX interchange testing and
      # Bumblebee for image classification
      if(otp_release() >= 24,
        do: [
          {:nx, "~> 0.4.1", optional: true},
          {:bumblebee, "~> 0.1.0", optional: true},
          {:exla, "~> 0.4.1", optional: true}
        ]
      ),

      # For testing and benchmarking
      {:temp, "~> 0.4", only: [:test, :dev], runtime: false},
      {:benchee, "~> 1.0", only: :dev, runtime: false, optional: true},

      # For release management
      {:ex_doc, "~> 0.18", only: [:release, :dev, :docs]},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false, optional: true},

      # For testing HTTP streaming
      {:ex_aws_s3, "~> 2.3", optional: true, only: [:dev, :test]},
      {:hackney, "~> 1.18", optional: true, only: [:dev, :test]},
      {:jason, "~> 1.4", optional: true}

      # Only used for benchmarking
      # {:mogrify, "~> 0.9.1", only: :dev, optional: true}
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  defp package do
    [
      maintainers: ["Kip Cole"],
      licenses: ["Apache-2.0"],
      links: links(),
      files: [
        "lib",
        "priv",
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
      "libvips" => "https://www.libvips.org",
      "eVision (OpenCV)" => "https://github.com/cocoa-xu/evision"
    }
  end

  def docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      logo: "logo.jpg",
      extra_section: "Guides",
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

  @enum_modules [
    Image.BandFormat,
    Image.BlendMode,
    Image.CombineMode,
    Image.Interpretation,
    Image.Kernel
  ]

  defp groups_for_modules do
    [
      Exif: [Image.Exif],
      Xmp: [Image.Xmp],
      Kino: [Image.Kino],
      Options: ~r/Image.Options.*/,
      Enums: @enum_modules
    ]
  end

  defp otp_release do
    :erlang.system_info(:otp_release)
    |> List.to_integer()
  end

  defp preferred_cli_env() do
    []
  end

  def aliases do
    []
  end

  defp elixirc_paths(:test), do: ["lib", "src", "mix", "test"]
  defp elixirc_paths(:dev), do: ["lib", "src", "mix", "bench"]
  defp elixirc_paths(:release), do: ["lib", "src"]
  defp elixirc_paths(_), do: ["lib", "src"]
end
