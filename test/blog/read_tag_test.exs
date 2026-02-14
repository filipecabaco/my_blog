defmodule Blog.ReadTagTest do
  use ExUnit.Case, async: false

  alias Blog.ReadTag

  setup do
    name = :"test_tag_#{System.unique_integer()}"
    socket = %{id: "test-socket-id", root_pid: self()}

    {:ok, pid} = ReadTag.start_link(%{name: name, socket: socket, title: "test_post"})

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    %{pid: pid, name: name}
  end

  test "stores initial state with title, socket, and position", %{pid: pid} do
    state = GenServer.call(pid, :get_state)

    assert state.title == "test_post"
    assert state.position == 0
    assert state.socket.id == "test-socket-id"
    assert is_binary(state.color)
  end

  test "get_position returns current position", %{pid: pid} do
    assert GenServer.call(pid, :get_position) == 0
  end

  test "set_position updates position", %{pid: pid} do
    GenServer.cast(pid, {:set_position, 42})
    assert GenServer.call(pid, :get_position) == 42
  end

  test "set_title updates title", %{pid: pid} do
    GenServer.cast(pid, {:set_title, "new_post"})
    state = GenServer.call(pid, :get_state)
    assert state.title == "new_post"
  end
end
