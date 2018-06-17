defmodule Extus.Mixfile do
  use Mix.Project

  def project do
    [app: :extus,
     version: "0.1.0",
     elixir: "~> 1.4",
     description: "An implementation of resumable upload protocol TUS in Elixir",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     package: package(),
     source_url: "https://github.com/bluzky/extus"
   ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [
      mod: {ExTus.App, []},
      extra_applications: [:logger]
    ]
  end

  def package() do
    [
      licenses: ["MIT"],
      maintainers: ["Dung Nguyen", "bluesky.1289@gmail.com"],
      links: %{github: "https://github.com/bluzky/extus"}
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:persistent_ets, "~> 0.1.0"},
      {:plug, "~> 1.3"},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:hackney, "~> 1.12.1"},
    ]
  end
end
