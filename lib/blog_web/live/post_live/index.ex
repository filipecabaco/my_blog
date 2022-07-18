defmodule BlogWeb.PostLive.Index do
  use BlogWeb, :live_view

  alias Blog.Posts

  @impl true
  def mount(params, _session, socket) do
    branch = Map.get(params, "branch")
    socket = socket |> assign(:posts, list_post(branch)) |> assign(:branch, branch)
    {:ok, socket}
  end

  defp list_post(branch) do
    Posts.list_post(branch)
    |> Enum.map(&String.replace(&1, ".md", ""))
    |> Enum.map(&%{title: &1, label: Phoenix.Naming.humanize(&1)})
  end
end
