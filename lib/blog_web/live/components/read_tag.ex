defmodule BlogWeb.Components.ReadTag do
  use BlogWeb, :live_component
  alias Blog.ReadTag.Supervisor

  @impl true
  def update(%{title: title, owner_id: owner_id, id: id}, socket) do
    read_tag = Supervisor.get_state(owner_id)
    self_id = socket.id

    tag_style = "margin-left: -10vw; width: 2rem; background-color: #{read_tag.color}; border-top-right-radius: 1rem 40%; border-bottom-right-radius: 1rem 40%;"

    style =
      if(self_id == read_tag.socket.id) do
        "position: sticky;  position: -webkit-sticky; top: 0px; #{tag_style}"
      else
        "position: absolute; top: #{read_tag.position}px; #{tag_style}"
      end

    {:ok, assign(socket, %{title: title, read_tag: read_tag, id: id, self_id: self_id, style: style})}
  end

  @impl true
  def render(assigns) when not is_nil(assigns.read_tag) do
    ~H"""
    <div style={@style} id={@id} phx-hook="ReadTag" title={@title}>&nbsp;</div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div></div>
    """
  end
end
