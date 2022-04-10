defmodule Image.MixProject do
  use Mix.Project

  def project do
    [
      app: :image,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # {:vix, github: "akash-akya/vix", branch: "vips-blob" },
      {:vix, "~> 0.6"},
      {:sweet_xml, "~> 0.7"}
    ]
  end
end
