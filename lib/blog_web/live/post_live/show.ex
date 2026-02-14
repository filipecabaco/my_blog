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
    {:ok, assign(socket, %{counter: Blog.Statistics.fetch(title), read_tags: Supervisor.get_for_title(title)})}
  end

  @impl true
  def handle_params(%{"title" => title} = params, _, socket) do
    pr = Map.get(params, "pr")

    branch =
      case pr do
        nil -> nil
        pr_number ->
          case Posts.pr_branch(pr_number) do
            {:ok, branch} -> branch
            {:error, _} -> nil
          end
      end

    case Posts.get_post(title, branch) do
      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to load post: #{reason}")
         |> assign(:page_title, Phoenix.Naming.humanize(title))
         |> assign(:title, title)
         |> assign(:pr, pr)
         |> assign(:description, "")
         |> assign(:tags, [])
         |> assign(:reading_time, 0)
         |> assign(:post, "<p>Post not found or failed to load.</p>")}

      post ->
        parsed_post =
          case Posts.parse(post) do
            {:error, _reason} -> "<p>Failed to parse post content.</p>"
            html -> html
          end

        {:noreply,
         socket
         |> assign(:page_title, Phoenix.Naming.humanize(title))
         |> assign(:title, title)
         |> assign(:pr, pr)
         |> assign(:description, Posts.description(post))
         |> assign(:tags, Posts.tags(post))
         |> assign(:reading_time, Posts.reading_time(post))
         |> assign(:post, parsed_post)}
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
    {:noreply, push_event(socket, "update_tag", %{id: "read_tag_#{id}", position: position})}
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
  def render(assigns) do
    ~H"""
    <main class="container">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <%= for read_tag <- @read_tags do %>
        <.live_component module={BlogWeb.Components.ReadTag} id={"read_tag_#{read_tag.socket.id}"} title={@title} owner_id={read_tag.socket.id} />
      <% end %>

      <div class="post-meta">
        <%= if @tags != [] do %>
          <div class="post-tags">
            <%= for tag <- @tags do %>
              <span class="tag-pill">{tag}</span>
            <% end %>
          </div>
        <% end %>
        <span class="post-reading-time">{@reading_time} min read</span>
      </div>

      {raw(@post)}

      <div class="post-footer">
        <.link navigate={if @pr, do: ~p"/?pr=#{@pr}", else: ~p"/"}>Back to posts</.link>
        <span>{@counter} readers</span>
      </div>
    </main>
    """
  end
end
