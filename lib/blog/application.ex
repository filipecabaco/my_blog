defmodule Blog.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BlogWeb.Telemetry,
      {Phoenix.PubSub, name: Blog.PubSub},
      BlogWeb.Endpoint,
      Blog.Posts,
      {Blog.Statistics, "/tmp/blog/"},
      {Registry, keys: :unique, name: Blog.ReadTag.Registry},
      Blog.ReadTag.Supervisor,
      Blog.ReadTag.Monitor
    ]

    opts = [strategy: :one_for_one, name: Blog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    BlogWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
