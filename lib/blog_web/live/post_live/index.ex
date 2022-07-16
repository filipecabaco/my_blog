defmodule BlogWeb.PostLive.Index do
  use BlogWeb, :live_view

  alias Blog.Posts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :posts, list_post())}
  end

  defp list_post do
    Posts.list_post()
    |> Enum.map(&String.replace(&1, ".md", ""))
    |> Enum.map(&%{title: &1, label: Phoenix.Naming.humanize(&1)})
  end
end
