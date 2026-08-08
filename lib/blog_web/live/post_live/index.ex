defmodule BlogWeb.PostLive.Index do
  use BlogWeb, :live_view

  alias Blog.Posts
  alias Blog.ReadTag
  import BlogWeb.Layouts, only: [flash: 1, mark: 1]

  @impl true
  def mount(params, _, socket) do
    if connected?(socket), do: BlogWeb.Endpoint.subscribe("read_tag")

    pr = Map.get(params, "pr")
    branch = if pr, do: resolve_branch(pr)

    {:ok,
     assign(socket, %{
       posts: list_post(branch),
       pr: pr,
       reading_now: ReadTag.Supervisor.count()
     })}
  end

  @impl true
  def handle_info(%{topic: "read_tag"}, socket) do
    {:noreply, assign(socket, :reading_now, ReadTag.Supervisor.count())}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp resolve_branch(pr_number) do
    case Posts.pr_branch(pr_number) do
      {:ok, branch} -> branch
      {:error, _} -> nil
    end
  end

  @impl true
  def render(%{posts: []} = assigns) do
    ~H"""
    <main class="frame" id="main">
      <section class="notice">
        <h1 class="notice__title">Nothing to read yet</h1>
        <p class="notice__body">
          Posts are pulled from GitHub and none came back. If you are running this
          locally, set <code>GITHUB_API_TOKEN</code> and restart.
        </p>
        <div class="notice__actions">
          <a class="button" href="https://github.com/filipecabaco/my_blog">Read them on GitHub</a>
        </div>
      </section>
    </main>
    """
  end

  def render(assigns) do
    [lead | rest] = assigns.posts
    assigns = assign(assigns, lead: lead, rest: Enum.with_index(rest, 2))

    ~H"""
    <main class="frame" id="main">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <div class="rail lead__rail">
        <span class="label">Latest</span>
        <span class="plate">01</span>
        <span :if={@reading_now > 0} class="plate presence__count">{@reading_now} reading now</span>
      </div>

      <.link navigate={post_path(@lead, @pr)} class="lead">
        <div class="lead__head">
          <h2 class="lead__title">{@lead.title}</h2>
          <.mark slug={@lead.slug} cell={18} gap={8} />
        </div>
        <p class="lead__summary">{@lead.description}</p>
        <div class="lead__foot">
          <time class="plate" datetime={@lead.date}>{@lead.date}</time>
          <span class="plate">{@lead.reading_time} min</span>
        </div>
      </.link>

      <section :if={@rest != []} class="register">
        <header class="register__head">
          <span class="label">Earlier</span>
          <span class="label">Duration</span>
        </header>

        <.link :for={{post, index} <- @rest} navigate={post_path(post, @pr)} class="entry">
          <span class="entry__no">{index |> Integer.to_string() |> String.pad_leading(2, "0")}</span>
          <div class="entry__body">
            <h3 class="entry__title">{post.title}</h3>
            <p class="entry__summary">{post.description}</p>
          </div>
          <div class="entry__meta">
            <time class="plate" datetime={post.date}>{post.date}</time>
            <span class="plate">{post.reading_time} min</span>
          </div>
        </.link>
      </section>
    </main>
    """
  end

  defp post_path(post, nil), do: ~p"/post/#{post.slug}"
  defp post_path(post, pr), do: ~p"/post/#{post.slug}?pr=#{pr}"

  defp list_post(branch) do
    Posts.list_post(branch)
    |> Enum.map(&String.replace(&1, ".md", ""))
    |> Enum.map(&summarise(&1, branch))
  end

  defp summarise(slug, branch) do
    case Posts.get_post(slug, branch) do
      content when is_binary(content) ->
        %{
          slug: slug,
          title: Posts.display_title(slug, content),
          date: Posts.date(slug),
          description: Posts.description(content),
          reading_time: Posts.reading_time(content)
        }

      _ ->
        %{slug: slug, title: Posts.display_title(slug, ""), date: Posts.date(slug), description: "", reading_time: 1}
    end
  end
end
