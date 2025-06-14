defmodule Socialite.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do

    children = [
      SocialiteWeb.Telemetry,
      Socialite.Repo,
      {DNSCluster, query: Application.get_env(:socialite, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Socialite.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Socialite.Finch},
      # Start a worker by calling: Socialite.Worker.start_link(arg)
      # {Socialite.Worker, arg},
      # Start to serve requests, typically the last entry
      SocialiteWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Socialite.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SocialiteWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
