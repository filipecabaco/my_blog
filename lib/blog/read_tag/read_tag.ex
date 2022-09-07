defmodule Blog.ReadTag do
  use GenServer

  def init(args), do: {:ok, args}
  def start_link(%{name: name, socket: socket}), do: GenServer.start_link(__MODULE__, %{title: nil, color: random_rgb(), socket: socket, position: 0}, name: name)

  def handle_call(:get_state, _, state), do: {:reply, state, state}
  def handle_call(:get_socket, _, state), do: {:reply, state.socket, state}
  def handle_call(:get_position, _, %{position: pos} = state), do: {:reply, pos, state}

  def handle_cast({:set_title, title}, state), do: {:noreply, %{state | title: title}}
  def handle_cast({:set_position, pos}, state), do: {:noreply, %{state | position: pos}}

  defp random_rgb do
    Stream.repeatedly(fn -> Enum.random(0..255) end)
    |> Enum.take(3)
    |> Enum.join(", ")
    |> then(&"rgba(#{&1}, 0.5)")
  end
end
