defmodule BlogWeb.PostLive.Show do
  use BlogWeb, :live_view

  alias Blog.Posts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"title" => title}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, title)
     |> assign(:post, Posts.get_post!(title))}
  end
end
