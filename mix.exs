defmodule SpringBoard.Mixfile do
  use Mix.Project

  def project do
    [app: :springboard,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [
          :logger,
          :postgrex,
          :ectoo,
          :comeonin,
          :tzdata,
          :phoenix,
        ]
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:macaddr, github: "gleber/erlang-macaddr"},
     {:hashids, "~> 2.0"},
     {:mex, "~> 0.0.5", only: :dev},
     {:vex, "~> 0.5.4"},
     {:redix, "~> 0.3.3"},
     {:remodel, "~> 0.0.1"},
     {:comeonin, "~> 1.3.2"},
     {:blaguth, github: "rpip/blaguth"},
     {:macaddr, github: "gleber/erlang-macaddr"},
     {:hashids, "~> 2.0"},
     {:inflex, "~> 1.5.0"},
     {:ectoo, "~> 0.0.4"},
     {:erlman, github: "bbense/erlman", only: :dev},
     {:scrivener, "~> 1.1.1"},
     {:pigeon, github: "rpip/pigeon"},
     {:exfirebase, "~> 0.4.0"},
     {:phoenix, "~> 1.0.3"}
    ]
  end
end
