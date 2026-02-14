defmodule Blog.ReadTag.Supervisor do
  use DynamicSupervisor
  alias Blog.ReadTag

  def init(_), do: DynamicSupervisor.init(strategy: :one_for_one)
  def start_link(_), do: DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)

  def start(socket, title) do
    DynamicSupervisor.start_child(__MODULE__, {ReadTag, %{name: ReadTag.via(socket.id), socket: socket, title: title}})
    BlogWeb.Endpoint.broadcast!("read_tag", "new_tag", %{id: socket.id, title: title})
  end

  def terminate(id) do
    case Registry.lookup(Blog.ReadTag.Registry, id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> :ok
    end
  end

  def get_socket(id) do
    case get_state(id) do
      %{socket: socket} -> socket
      nil -> nil
    end
  end

  def get_state(id) do
    case Registry.lookup(Blog.ReadTag.Registry, id) do
      [{pid, _}] ->
        try do
          GenServer.call(pid, :get_state)
        catch
          :exit, _ -> nil
        end

      [] ->
        nil
    end
  end

  def set_title(id, title), do: GenServer.cast(ReadTag.via(id), {:set_title, title})
  def set_position(id, position), do: GenServer.cast(ReadTag.via(id), {:set_position, position})

  def get_for_title(title) do
    Registry.select(Blog.ReadTag.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.map(&get_state/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&(&1.title == title))
  end
end
