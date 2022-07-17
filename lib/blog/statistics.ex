defmodule Blog.Statistics do
  use GenServer
  alias Blog.Posts
  def start_link(path), do: GenServer.start_link(__MODULE__, path, name: __MODULE__)

  @impl true
  def init(path) do
    :ok = File.mkdir_p(path)
    {:ok, :statistics} = :dets.open_file(:statistics, [{:file, to_charlist("#{path}/statistics")}])

    Enum.each(Posts.list_post(), fn title ->
      key = title |> String.replace(".md", "") |> to_charlist()
      if :dets.lookup(:statistics, key) == [], do: :dets.insert_new(:statistics, {key, 0})
    end)

    :telemetry.attach(__MODULE__, [:blog, :visit], &Blog.Statistics.handle_event/4, nil)
    {:ok, nil}
  end

  @impl true
  def terminate(_reason, _state), do: :dets.close(:statistics)

  @impl true
  def handle_call({:fetch, title}, _, state) do
    [{_, counter}] = :dets.lookup(:statistics, to_charlist(title))
    {:reply, counter, state}
  end

  def fetch(title), do: GenServer.call(__MODULE__, {:fetch, title})
  def handle_event([:blog, :visit], _, %{title: title}, _), do: :dets.update_counter(:statistics, to_charlist(title), 1)
end
