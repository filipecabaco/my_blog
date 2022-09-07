defmodule Blog.ReadTag.Supervisor do
  use DynamicSupervisor
  alias Blog.ReadTag
  @impl true

  def init(_), do: DynamicSupervisor.init(strategy: :one_for_one)
  def start_link(_), do: DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)

  def start(socket, title) do
    DynamicSupervisor.start_child(__MODULE__, {ReadTag, %{name: {:global, socket.id}, socket: socket}})
    BlogWeb.Endpoint.broadcast!("read_tag", "new_tag", %{id: socket.id, title: title})
  end

  def terminate(id), do: DynamicSupervisor.terminate_child(__MODULE__, :global.whereis_name(id))

  def get_socket(id), do: GenServer.call(:global.whereis_name(id), :get_socket)

  def get_state(id) do
    pid = :global.whereis_name(id)
    if pid != :undefined, do: GenServer.call(pid, :get_state)
  end

  def set_title(id, title), do: GenServer.cast(:global.whereis_name(id), {:set_title, title})
  def set_position(id, position), do: GenServer.cast(:global.whereis_name(id), {:set_position, position})

  def get_for_title(title) do
    :global.registered_names()
    |> Enum.map(&get_state/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&(&1.title == title))
  end
end
