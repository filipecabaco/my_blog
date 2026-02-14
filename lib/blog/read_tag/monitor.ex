defmodule Blog.ReadTag.Monitor do
  use GenServer
  alias Blog.ReadTag.Supervisor

  def init(_), do: {:ok, nil, {:continue, []}}
  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def handle_continue(_, state) do
    Process.send(self(), :clean, [])
    {:noreply, state}
  end

  def handle_info(:clean, state) do
    Registry.select(Blog.ReadTag.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.each(fn id ->
      case Supervisor.get_state(id) do
        %{title: title, socket: %{root_pid: root_pid, id: id}} ->
          unless Process.alive?(root_pid) do
            Supervisor.terminate(id)
            BlogWeb.Endpoint.broadcast!("read_tag", "delete_tag", %{id: id, title: title})
          end

        nil ->
          :ok
      end
    end)

    Process.send_after(self(), :clean, :timer.seconds(5))
    {:noreply, state}
  end
end
