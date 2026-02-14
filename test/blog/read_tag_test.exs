defmodule Blog.ReadTagTest do
  use ExUnit.Case, async: false

  alias Blog.ReadTag

  setup do
    id = "test-socket-#{System.unique_integer([:positive])}"
    socket = %{id: id, root_pid: self()}

    {:ok, pid} = ReadTag.start_link(%{name: ReadTag.via(id), socket: socket, title: "test_post"})

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    %{pid: pid, id: id}
  end

  test "stores initial state with title, socket, and position", %{pid: pid} do
    state = GenServer.call(pid, :get_state)

    assert state.title == "test_post"
    assert state.position == 0
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

  test "generates a random rgba color", %{pid: pid} do
    state = GenServer.call(pid, :get_state)
    assert state.color =~ ~r/rgba\(\d+, \d+, \d+, 0\.5\)/
  end
end

defmodule Blog.ReadTag.SupervisorTest do
  use ExUnit.Case, async: false

  alias Blog.ReadTag.Supervisor

  defp start_tag(id, title) do
    socket = %{id: id, root_pid: self()}

    try do
      Supervisor.start(socket, title)
    catch
      :exit, _ -> :ok
    end

    assert Registry.lookup(Blog.ReadTag.Registry, id) != []
    id
  end

  defp cleanup(id) do
    Supervisor.terminate(id)
  end

  test "get_state returns nil for unknown id" do
    assert Supervisor.get_state("nonexistent-#{System.unique_integer()}") == nil
  end

  test "get_for_title returns empty list when no tags registered" do
    assert Supervisor.get_for_title("no_such_title_#{System.unique_integer()}") == []
  end

  test "start registers a read tag and get_state returns it" do
    id = "sup-start-#{System.unique_integer()}"
    start_tag(id, "my_post")

    state = Supervisor.get_state(id)
    assert state.title == "my_post"
    assert state.socket.id == id

    cleanup(id)
  end

  test "get_socket returns the socket for a registered tag" do
    id = "sup-socket-#{System.unique_integer()}"
    start_tag(id, "my_post")

    assert Supervisor.get_socket(id).id == id

    cleanup(id)
  end

  test "set_title updates the title of a registered tag" do
    id = "sup-title-#{System.unique_integer()}"
    start_tag(id, "original_title")

    Supervisor.set_title(id, "updated_title")
    Process.sleep(10)

    assert Supervisor.get_state(id).title == "updated_title"

    cleanup(id)
  end

  test "set_position updates the position of a registered tag" do
    id = "sup-pos-#{System.unique_integer()}"
    start_tag(id, "my_post")

    Supervisor.set_position(id, 150)
    Process.sleep(10)

    assert Supervisor.get_state(id).position == 150

    cleanup(id)
  end

  test "terminate removes a registered tag" do
    id = "sup-term-#{System.unique_integer()}"
    start_tag(id, "my_post")

    assert Supervisor.get_state(id) != nil
    Supervisor.terminate(id)
    Process.sleep(10)

    assert Supervisor.get_state(id) == nil
  end

  test "get_for_title returns tags matching the title" do
    id = "sup-filter-#{System.unique_integer()}"
    start_tag(id, "target_post")

    results = Supervisor.get_for_title("target_post")
    assert length(results) >= 1
    assert Enum.any?(results, &(&1.socket.id == id))

    cleanup(id)
  end

  test "get_for_title excludes tags with different title" do
    id = "sup-exclude-#{System.unique_integer()}"
    start_tag(id, "other_post")

    results = Supervisor.get_for_title("nonexistent_#{System.unique_integer()}")
    refute Enum.any?(results, &(&1.socket.id == id))

    cleanup(id)
  end
end

defmodule Blog.ReadTag.MonitorTest do
  use ExUnit.Case, async: false

  alias Blog.ReadTag.Supervisor

  defp start_tag_for_monitor(id, socket) do
    try do
      Supervisor.start(socket, "test_post")
    catch
      :exit, _ -> :ok
    end

    assert Registry.lookup(Blog.ReadTag.Registry, id) != []
  end

  test "clean removes tags with dead root processes" do
    id = "monitor-dead-#{System.unique_integer()}"

    dead_pid = spawn(fn -> :ok end)
    Process.sleep(10)
    refute Process.alive?(dead_pid)

    start_tag_for_monitor(id, %{id: id, root_pid: dead_pid})

    assert Supervisor.get_state(id) != nil

    send(Blog.ReadTag.Monitor, :clean)
    Process.sleep(100)

    assert Supervisor.get_state(id) == nil
  end

  test "clean keeps tags with alive root processes" do
    id = "monitor-alive-#{System.unique_integer()}"

    start_tag_for_monitor(id, %{id: id, root_pid: self()})

    send(Blog.ReadTag.Monitor, :clean)
    Process.sleep(100)

    state = Supervisor.get_state(id)
    assert state != nil
    assert state.title == "test_post"

    Supervisor.terminate(id)
  end
end
