defmodule BlogWeb.PostLive.Show do
  use BlogWeb, :live_view

  alias Blog.Posts
  alias Blog.ReadTag.Supervisor
  import BlogWeb.Layouts, only: [flash: 1]

  @impl true
  def mount(%{"title" => title}, _, socket) do
    if connected?(socket), do: Supervisor.start(socket, title)

    BlogWeb.Endpoint.subscribe("show")
    BlogWeb.Endpoint.subscribe("read_tag")

    {:ok,
     assign(socket, %{
       counter: Blog.Statistics.fetch(title),
       read_tags: Supervisor.get_for_title(title),
       socket_id: socket.id,
       title: title,
       page_title: title,
       post_title: title,
       description: "",
       reading_time: 0,
       headings: [],
       published_date: Posts.published_date(title),
       date: Posts.date(title),
       neighbours: %{previous: nil, next: nil},
       og_article: false,
       post: nil,
       pr: nil
     })}
  end

  @impl true
  def handle_params(%{"title" => title} = params, _, socket) do
    pr = Map.get(params, "pr")
    branch = if pr, do: resolve_branch(pr)

    socket =
      socket
      |> assign(:title, title)
      |> assign(:pr, pr)
      |> assign(:date, Posts.date(title))
      |> assign(:published_date, Posts.published_date(title))
      |> assign(:neighbours, neighbours(title, branch))

    case Posts.get_post(title, branch) do
      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:page_title, Posts.display_title(title, ""))
         |> assign(:post_title, Posts.display_title(title, ""))
         |> assign(:description, "")
         |> assign(:reading_time, 0)
         |> assign(:headings, [])
         |> assign(:og_article, false)
         |> assign(:post, nil)}

      content ->
        {html, headings} =
          case Posts.render(content) do
            {:ok, html, headings} -> {html, headings}
            {:error, _} -> {"<p>This post could not be rendered.</p>", []}
          end

        display_title = Posts.display_title(title, content)

        {:noreply,
         socket
         |> assign(:page_title, display_title)
         |> assign(:post_title, display_title)
         |> assign(:description, Posts.description(content))
         |> assign(:reading_time, Posts.reading_time(content))
         |> assign(:headings, headings)
         |> assign(:og_article, true)
         |> assign(:post, html)}
    end
  end

  @impl true
  def handle_info(%{event: "reader"}, %{assigns: %{pr: nil, title: title}} = socket) do
    :telemetry.execute([:blog, :visit], %{}, %{title: title})
    BlogWeb.Endpoint.broadcast("show", "join", %{title: title})
    {:noreply, socket}
  end

  def handle_info(%{event: "reader"}, %{assigns: %{title: title}} = socket) do
    BlogWeb.Endpoint.broadcast("show", "join", %{title: title})
    {:noreply, socket}
  end

  def handle_info(%{topic: "show", event: "join", payload: %{title: title}}, %{assigns: %{title: title}} = socket) do
    {:noreply, assign(socket, :counter, Blog.Statistics.fetch(title))}
  end

  def handle_info(%{topic: "read_tag", event: "position_update", payload: %{id: id}}, %{id: id} = socket) do
    {:noreply, socket}
  end

  def handle_info(%{topic: "read_tag", event: "position_update", payload: %{id: id, position: position, title: title}}, %{assigns: %{title: title}} = socket) do
    {:noreply, push_event(socket, "update_tag", %{id: "lamp-#{id}", position: position})}
  end

  def handle_info(%{topic: "read_tag", event: "new_tag", payload: %{id: id}}, %{id: id} = socket) do
    {:noreply, socket}
  end

  def handle_info(%{topic: "read_tag", event: "new_tag", payload: %{title: title}}, %{assigns: %{title: title}} = socket) do
    {:noreply, assign(socket, %{read_tags: Supervisor.get_for_title(title)})}
  end

  def handle_info(%{topic: "read_tag", event: "delete_tag", payload: %{title: title}}, %{assigns: %{title: title}} = socket) do
    {:noreply, assign(socket, %{read_tags: Supervisor.get_for_title(title)})}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("scroll_position", %{"position" => position, "title" => title}, socket) do
    Supervisor.set_position(socket.id, position)
    BlogWeb.Endpoint.broadcast!("read_tag", "position_update", %{id: socket.id, position: position, title: title})
    {:noreply, socket}
  end

  @impl true
  def render(%{post: nil} = assigns) do
    ~H"""
    <main class="frame" id="main">
      <section class="notice">
        <span class="label">Error 404</span>
        <h1 class="notice__title">No post at this address</h1>
        <p class="notice__body">
          Nothing is published under <code>{@title}</code>. It may have been renamed,
          or the link may have lost a character on the way here.
        </p>
        <div class="notice__actions">
          <.link class="button" navigate={~p"/"}>See everything published</.link>
        </div>
      </section>
    </main>
    """
  end

  def render(assigns) do
    ~H"""
    <main class="frame" id="main">
      <aside class="rail post__rail">
        <div class="rail__sticky">
          <div class="rail__block">
            <span class="label">Published</span>
            <time class="rail__value" datetime={@date}>{@date}</time>
          </div>

          <div class="rail__block">
            <span class="label">Duration</span>
            <span class="rail__value">{@reading_time} min</span>
          </div>

          <.presence read_tags={@read_tags} socket_id={@socket_id} title={@title} />

          <nav :if={@headings != []} class="rail__block rail__contents" aria-label="Contents">
            <span class="label">Contents</span>
            <ol class="contents">
              <li :for={heading <- @headings} data-level={heading.level}>
                <a href={"##{heading.id}"}>{heading.text}</a>
              </li>
            </ol>
          </nav>
        </div>
      </aside>

      <article class="post">
        <.flash kind={:info} flash={@flash} />
        <.flash kind={:error} flash={@flash} />

        <header class="post__header">
          <h1 class="post__title">{@post_title}</h1>
        </header>

        <div class="prose">{raw(@post)}</div>

        <footer class="post__footer">
          <.link navigate={if @pr, do: ~p"/?pr=#{@pr}", else: ~p"/"} class="masthead__link">
            &larr; All posts
          </.link>
          <span class="plate">{@counter} all-time readers</span>
        </footer>

        <nav :if={@neighbours.previous || @neighbours.next} class="post__nav" aria-label="Nearby posts">
          <.link :if={@neighbours.previous} navigate={~p"/post/#{@neighbours.previous.slug}"}>
            <span class="label">Previous</span>
            <span class="post__nav-title">{@neighbours.previous.title}</span>
          </.link>
          <.link :if={@neighbours.next} navigate={~p"/post/#{@neighbours.next.slug}"}>
            <span class="label">Next</span>
            <span class="post__nav-title">{@neighbours.next.title}</span>
          </.link>
        </nav>
      </article>
    </main>
    """
  end

  attr :read_tags, :list, required: true
  attr :socket_id, :string, required: true
  attr :title, :string, required: true

  defp presence(assigns) do
    assigns = assign(assigns, others: Enum.reject(assigns.read_tags, &(&1.socket.id == assigns.socket_id)))

    ~H"""
    <div class="rail__block presence" id="presence" phx-hook="Presence" data-title={@title}>
      <span class="label">Reading now</span>
      <span class="presence__count">{length(@read_tags)}</span>
      <div class="presence__track" aria-hidden="true">
        <span class="presence__progress" />
        <span :for={tag <- @others} id={"lamp-#{tag.socket.id}"} class="presence__lamp" style={"--at: #{tag.position}"} />
        <span class="presence__lamp presence__lamp--self" />
      </div>
    </div>
    """
  end

  defp resolve_branch(pr_number) do
    case Posts.pr_branch(pr_number) do
      {:ok, branch} -> branch
      {:error, _} -> nil
    end
  end

  # Slugs are sorted newest first.
  defp neighbours(slug, branch) do
    slugs = Posts.list_post(branch) |> Enum.map(&String.replace(&1, ".md", ""))

    case Enum.find_index(slugs, &(&1 == slug)) do
      nil ->
        %{previous: nil, next: nil}

      index ->
        %{
          next: slugs |> Enum.at(index - 1) |> summarise(branch, index > 0),
          previous: slugs |> Enum.at(index + 1) |> summarise(branch, true)
        }
    end
  end

  defp summarise(nil, _branch, _allowed), do: nil
  defp summarise(_slug, _branch, false), do: nil

  defp summarise(slug, branch, true) do
    content = if is_binary(post = Posts.get_post(slug, branch)), do: post, else: ""
    %{slug: slug, title: Posts.display_title(slug, content)}
  end
end
