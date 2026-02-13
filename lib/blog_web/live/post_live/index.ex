defmodule BlogWeb.PostLive.Index do
  use BlogWeb, :live_view

  alias Blog.Posts
  import BlogWeb.Layouts, only: [flash: 1]

  @impl true
  def mount(params, _, socket) do
    branch = Map.get(params, "branch")
    {:ok, assign(socket, %{posts: list_post(branch), branch: branch})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="container">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <%= if Enum.empty?(@posts) do %>
        <p>No posts found. Please ensure GITHUB_API_TOKEN is set correctly.</p>
      <% else %>
        <ul>
          <%= for post <- @posts do %>
            <% path = if @branch, do: ~p"/post/#{post.title}?branch=#{@branch}", else: ~p"/post/#{post.title}" %>
            <li>
              <.link navigate={path}>{post.label}</.link>
              <%= for tag <- post.tags do %>
                <span class="tag-pill">{tag}</span>
              <% end %>
            </li>
          <% end %>
        </ul>
      <% end %>
    </main>
    """
  end

  defp list_post(branch) do
    Posts.list_post(branch)
    |> Enum.map(&String.replace(&1, ".md", ""))
    |> Enum.map(fn title ->
      tags =
        case Posts.get_post(title, branch) do
          content when is_binary(content) -> Posts.tags(content)
          _ -> []
        end

      %{title: title, label: Phoenix.Naming.humanize(title), tags: tags}
    end)
  end
end
