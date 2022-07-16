defmodule BlogWeb.PostLive.Show do
  use BlogWeb, :live_view

  alias Blog.Posts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"title" => title}, _, socket) do
    post = Posts.get_post!(title)
    description = Posts.description(post)

    {:noreply,
     socket
     |> assign(:page_title, Phoenix.Naming.humanize(title))
     |> assign(:title, title)
     |> assign(:description, description)
     |> assign(:post, Posts.parse(post))}
  end
end
