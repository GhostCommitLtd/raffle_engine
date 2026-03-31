defmodule RaffleEngine.MixProject do
  use Mix.Project

  def project do
    [
      app: :raffle_engine,
      version: "0.4.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: RaffleEngine.CLI],
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Deterministic, verifiable winner selection for giveaways/raffles."
  end

  defp package do
    [
      licenses: ["MIT"],
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "INTEGRATION.md",
        "CHANGELOG.md",
        "CONTRIBUTING.md",
        "LICENSE"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "INTEGRATION.md",
        "CHANGELOG.md",
        "CONTRIBUTING.md"
      ]
    ]
  end
end
