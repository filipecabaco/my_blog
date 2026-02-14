defmodule BlogWeb.Components.ReadTag do
  use BlogWeb, :live_component
  alias Blog.ReadTag.Supervisor

  @impl true
  def update(%{title: title, owner_id: owner_id, id: id}, socket) do
    case Supervisor.get_state(owner_id) do
      nil ->
        {:ok, assign(socket, %{title: title, id: id, read_tag: nil, style: "", class: ""})}

      read_tag ->
        is_self = socket.id == read_tag.socket.id
        style = if is_self, do: "", else: "top: #{read_tag.position}px;"
        class = if is_self, do: "read-tag read-tag--self", else: "read-tag"

        {:ok, assign(socket, %{title: title, read_tag: read_tag, id: id, style: style, class: class})}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={@class} style={@style} id={@id} phx-hook={@read_tag && "ReadTag"} title={@title} />
    """
  end
end
