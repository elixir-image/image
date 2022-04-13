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
      {:vix, "~> 0.8"},
      {:sweet_xml, "~> 0.7"},
      {:nx, "~> 0.1", optional: true}
    ]
  end
end
