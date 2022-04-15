defmodule Image.MixProject do
  use Mix.Project

  def project do
    [
      app: :image,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:vix, path: "../vix"},
      {:sweet_xml, "~> 0.7"},
      {:nx, "~> 0.1", optional: true},
      {:temp, "~> 0.4", only: :test, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "src", "dev", "mix/support/units", "mix/tasks", "test"]
  defp elixirc_paths(:dev), do: ["lib", "mix", "src", "dev", "bench"]
  defp elixirc_paths(:release), do: ["lib", "dev", "src"]
  defp elixirc_paths(_), do: ["lib", "src"]
end
