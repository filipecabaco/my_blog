defmodule BlogWeb.Components.ReadTag do
  use BlogWeb, :live_component
  alias Blog.ReadTag.Supervisor

  @impl true
  def update(%{title: title, owner_id: owner_id, id: id}, socket) do
    case Supervisor.get_state(owner_id) do
      nil ->
        {:ok, assign(socket, %{title: title, id: id, read_tag: nil, style: ""})}

      read_tag ->
        self_id = socket.id

        tag_style =
          "margin-left: -10vw; width: 2rem; background-color: #{read_tag.color};" <>
            " border-top-right-radius: 1rem 40%; border-bottom-right-radius: 1rem 40%;"

        style =
          if self_id == read_tag.socket.id do
            "position: sticky; position: -webkit-sticky; top: 0px; #{tag_style}"
          else
            "position: absolute; top: #{read_tag.position}px; #{tag_style}"
          end

        {:ok, assign(socket, %{title: title, read_tag: read_tag, id: id, self_id: self_id, style: style})}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style={@style} id={@id} phx-hook={@read_tag && "ReadTag"} title={@title}>
      <%= if @read_tag, do: raw("&nbsp;") %>
    </div>
    """
  end
end
