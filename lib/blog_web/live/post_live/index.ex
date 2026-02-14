defmodule BlogWeb.PostLive.Index do
  use BlogWeb, :live_view

  alias Blog.Posts
  import BlogWeb.Layouts, only: [flash: 1]

  @impl true
  def mount(params, _, socket) do
    pr = Map.get(params, "pr")

    branch =
      case pr do
        nil -> nil
        pr_number -> resolve_branch(pr_number)
      end

    {:ok, assign(socket, %{posts: list_post(branch), pr: pr})}
  end

  defp resolve_branch(pr_number) do
    case Posts.pr_branch(pr_number) do
      {:ok, branch} -> branch
      {:error, _} -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="container" style="max-width: 1200px;">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <%= if Enum.empty?(@posts) do %>
        <p>No posts found. Please ensure GITHUB_API_TOKEN is set correctly.</p>
      <% else %>
        <section class="hero">
          <h1 class="hero-title">filipecabaco.com</h1>
          <p class="hero-subtitle">Building things, breaking things, writing about it</p>
        </section>

        <div class="post-grid">
          <%= for post <- @posts do %>
            <% path = if @pr, do: ~p"/post/#{post.title}?pr=#{@pr}", else: ~p"/post/#{post.title}" %>
            <% image_src = if @pr, do: "/pr/#{@pr}/images/posts/#{post.title}.png", else: "/images/posts/#{post.title}.png" %>
            <article class="post-card">
              <.link navigate={path} class="post-card-link">
                <img src={image_src} alt={post.label} class="post-card-image" loading="lazy" />
                <div class="post-card-content">
                  <h2 class="post-card-title">{post.label}</h2>
                  <p class="post-card-description">{post.description}</p>
                  <div class="post-card-meta">
                    <div class="post-card-tags">
                      <%= for tag <- post.tags do %>
                        <span class="tag-pill">{tag}</span>
                      <% end %>
                    </div>
                    <span class="post-card-reading-time">{post.reading_time} min read</span>
                  </div>
                </div>
              </.link>
            </article>
          <% end %>
        </div>
      <% end %>
    </main>
    """
  end

  defp list_post(branch) do
    Posts.list_post(branch)
    |> Enum.map(&String.replace(&1, ".md", ""))
    |> Enum.map(fn title ->
      case Posts.get_post(title, branch) do
        content when is_binary(content) ->
          %{
            title: title,
            label: Phoenix.Naming.humanize(title),
            tags: Posts.tags(content),
            description: Posts.description(content),
            reading_time: Posts.reading_time(content)
          }

        _ ->
          %{title: title, label: Phoenix.Naming.humanize(title), tags: [], description: "", reading_time: 1}
      end
    end)
  end
end
