defmodule Seshat.Mixfile do
  use Mix.Project

  def project do
    [app: :seshat,
     version: "0.1.0",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:msgpax, "~> 0.8"}]
  end
end
