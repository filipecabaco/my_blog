defmodule BlogWeb.PostLive.Index do
  use BlogWeb, :live_view

  alias Blog.Posts

  @impl true
  def mount(params, _, socket) do
    branch = Map.get(params, "branch")
    {:ok, assign(socket, %{posts: list_post(branch), branch: branch})}
  end

  defp list_post(branch) do
    Posts.list_post(branch)
    |> Enum.map(&String.replace(&1, ".md", ""))
    |> Enum.map(&%{title: &1, label: Phoenix.Naming.humanize(&1)})
  end
end
