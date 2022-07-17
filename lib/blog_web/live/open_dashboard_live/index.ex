defmodule BlogWeb.OpenDashboardLive.Index do
  use BlogWeb, :live_view
  alias BlogWeb.Components.Dashboard

  @impl true
  def mount(_params, _session, socket) do
    BlogWeb.Endpoint.subscribe("show")
    {:ok, socket}
  end

  @impl true
  def handle_info(%{event: "join"}, socket) do
    send_update(Dashboard, id: "dashboard")
    {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}
end
