defmodule TeamShopping.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TeamShoppingWeb.Telemetry,
      TeamShopping.Repo,
      {DNSCluster, query: Application.get_env(:team_shopping, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TeamShopping.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: TeamShopping.Finch},
      # Start a worker by calling: TeamShopping.Worker.start_link(arg)
      # {TeamShopping.Worker, arg},
      # Start to serve requests, typically the last entry
      TeamShoppingWeb.Endpoint,
      {AshAuthentication.Supervisor, otp_app: :team_shopping}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TeamShopping.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TeamShoppingWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
