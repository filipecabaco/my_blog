defmodule Blog.Statistics do
  use GenServer

  def start_link(path), do: GenServer.start_link(__MODULE__, path, name: __MODULE__, spawn_opt: [fullsweep_after: 20])

  @impl true
  def init(path) do
    :ok = File.mkdir_p(path)
    {:ok, :statistics} = :dets.open_file(:statistics, [{:file, to_charlist("#{path}statistics")}])
    :telemetry.attach(__MODULE__, [:blog, :visit], &Blog.Statistics.handle_event/4, nil)
    {:ok, nil}
  end

  @impl true
  def terminate(_reason, _state) do
    :telemetry.detach(__MODULE__)
    :dets.close(:statistics)
  end

  @impl true
  def handle_info({:EXIT, _pid, reason}, state) do
    :dets.close(:statistics)
    {:stop, reason, state}
  end

  @impl true
  def handle_call({:fetch, title}, _, state) do
    counter =
      case :dets.lookup(:statistics, to_charlist(title)) do
        [{_, counter}] -> counter
        _ -> 0
      end

    {:reply, counter, state}
  end

  def fetch(title), do: GenServer.call(__MODULE__, {:fetch, title})
  def handle_event([:blog, :visit], _, %{title: title}, _) do
    key = to_charlist(title)
    :dets.insert_new(:statistics, {key, 0})
    :dets.update_counter(:statistics, key, 1)
  end
end
