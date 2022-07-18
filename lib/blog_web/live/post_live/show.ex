defmodule BlogWeb.PostLive.Show do
  use BlogWeb, :live_view

  alias Blog.Posts

  @impl true
  def mount(%{"title" => title}, _session, socket) do
    BlogWeb.Endpoint.subscribe("show")
    {:ok, assign(socket, :counter, Blog.Statistics.fetch(title))}
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

  def handle_info(%{event: "join", payload: %{title: title}}, %{assigns: %{title: title}} = socket) do
    {:noreply, assign(socket, :counter, Blog.Statistics.fetch(title))}
  end

  def handle_info(_, socket), do: {:noreply, socket}
end
