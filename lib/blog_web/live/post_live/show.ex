defmodule BlogWeb.PostLive.Show do
  use BlogWeb, :live_view

  alias Blog.Posts
  alias Blog.ReadTag.Supervisor

  @impl true
  def mount(%{"title" => title}, _, socket) do
    if connected?(socket) do
      Supervisor.start(socket, title)
      Supervisor.set_title(socket.id, title)
    end

    BlogWeb.Endpoint.subscribe("show")
    BlogWeb.Endpoint.subscribe("read_tag")
    {:ok, assign(socket, %{counter: Blog.Statistics.fetch(title), read_tags: Supervisor.get_for_title(title)})}
  end

  @impl true
  def handle_params(%{"title" => title} = params, _, socket) do
    branch = Map.get(params, "branch")
    post = Posts.get_post(title, branch)
    description = Posts.description(post)

    {:noreply,
     socket
     |> assign(:page_title, Phoenix.Naming.humanize(title))
     |> assign(:title, title)
     |> assign(:description, description)
     |> assign(:post, Posts.parse(post))}
  end

  @impl true
  def handle_info(%{event: "reader"}, socket) do
    title = socket.assigns.title
    :telemetry.execute([:blog, :visit], %{}, %{title: title})
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
end
