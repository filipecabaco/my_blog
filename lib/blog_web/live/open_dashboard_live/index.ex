defmodule BlogWeb.OpenDashboardLive.Index do
  use BlogWeb, :live_view

  alias Blog.Posts
  alias Blog.Statistics

  @impl true
  def mount(_params, _session, socket) do
    BlogWeb.Endpoint.subscribe("show")
    {:ok, socket |> assign(:page_title, "Readership") |> load()}
  end

  @impl true
  def handle_info(%{event: "join"}, socket), do: {:noreply, load(socket)}
  def handle_info(_, socket), do: {:noreply, socket}

  defp load(socket) do
    metrics = metrics()
    assign(socket, metrics: metrics, total: metrics |> Enum.map(& &1.views) |> Enum.sum())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="frame" id="main">
      <aside class="rail post__rail">
        <div class="rail__sticky">
          <div class="rail__block">
            <span class="label">Total views</span>
            <span class="rail__value">{@total}</span>
          </div>
          <div class="rail__block">
            <span class="label">Posts</span>
            <span class="rail__value">{length(@metrics)}</span>
          </div>
        </div>
      </aside>

      <section class="stats">
        <header class="stats__header">
          <span class="label">Open stats</span>
          <h1 class="stats__title">Readership</h1>
          <p class="stats__lede">
            Every view counted since this blog started, updating live. There is no
            analytics vendor behind it: the counter is a process, and this page
            subscribes to it.
          </p>
        </header>

        <p :if={@total == 0} class="stats__empty">
          No views recorded yet. The counter starts at zero every time the store
          is created, so a fresh machine reads empty until someone arrives.
        </p>

        <div :if={@total > 0} class="bars">
          <.link :for={metric <- @metrics} navigate={~p"/post/#{metric.slug}"} class="bar">
            <span class="bar__label">{metric.title}</span>
            <span class="bar__value">{metric.views}</span>
            <span class="bar__meter">
              <span class="bar__fill" style={"--fill: #{metric.share}"} />
            </span>
          </.link>
        </div>
      </section>
    </main>
    """
  end

  defp metrics do
    metrics =
      Posts.list_post(nil)
      |> Enum.map(&String.replace(&1, ".md", ""))
      |> Enum.map(fn slug ->
        content = if is_binary(post = Posts.get_post(slug, nil)), do: post, else: ""
        %{slug: slug, title: Posts.display_title(slug, content), views: Statistics.fetch(slug)}
      end)
      |> Enum.sort_by(& &1.views, :desc)

    max = metrics |> Enum.map(& &1.views) |> Enum.max(fn -> 0 end)

    Enum.map(metrics, &Map.put(&1, :share, share(&1.views, max)))
  end

  defp share(_views, 0), do: 0.0
  defp share(views, max), do: Float.round(views / max, 4)
end
