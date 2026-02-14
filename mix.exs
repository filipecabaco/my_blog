defmodule Blog.MixProject do
  use Mix.Project

  def project do
    [
      app: :blog,
      version: "0.1.0",
      elixir: "~> 1.19",
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: [
        summary: [threshold: 84],
        ignore_modules: [
          BlogWeb.ErrorHTML,
          BlogWeb.Router.Helpers,
          BlogWeb
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Blog.Application, []},
      extra_applications: [:logger, :runtime_tools, :xmerl]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_html, "~> 4.3"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:phoenix_live_view, "~> 1.1"},
      {:lazy_html, ">= 0.0.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.1"},
      {:jason, "~> 1.4"},
      {:bandit, "~> 1.6"},
      {:earmark, "~> 1.4"},
      {:req, "~> 0.5"},
      {:vega_lite, "~> 0.1"},
      {:castore, "~> 1.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"],
      "assets.deploy": ["compile", "esbuild blog --minify", "phx.digest"]
    ]
  end
end
