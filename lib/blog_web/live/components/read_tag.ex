defmodule BlogWeb.Components.ReadTag do
  use BlogWeb, :live_component
  alias Blog.ReadTag.Supervisor
  @impl true
  def update(%{title: title, owner_id: owner_id, id: id}, socket) do
    {:ok, assign(socket, %{title: title, read_tag: Supervisor.get_state(owner_id), id: id, self_id: socket.id})}
  end

  @impl true
  def render(%{read_tag: read_tag, self_id: self_id} = assigns) when not is_nil(read_tag) do
    style = "margin-left: -10vw; width: 2rem; background-color: #{read_tag.color}; border-top-right-radius: 1rem 40%; border-bottom-right-radius: 1rem 40%;"

    style =
      if(self_id == read_tag.socket.id) do
        "position: sticky;  position: -webkit-sticky; top: 0px; #{style}"
      else
        "position: absolute; top: #{read_tag.position}px; #{style}"
      end

    ~H"""
    <div style={style} id={@id} phx-hook="ReadTag" title={@title}>&nbsp;</div>
    """
  end
end
