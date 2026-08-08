defmodule Blog.Posts do
  use GenServer
  require Logger

  @url "https://api.github.com/repos/filipecabaco/my_blog/contents/posts"
  @default_branch "main"
  @table __MODULE__
  @ttl :timer.minutes(30)
  @refresh_interval :timer.minutes(25)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__, spawn_opt: [fullsweep_after: 20])
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])

    if Application.get_env(:blog, :skip_warmup, false) do
      {:ok, %{}}
    else
      {:ok, %{}, {:continue, :warmup}}
    end
  end

  @impl true
  def handle_continue(:warmup, state) do
    do_refresh()
    schedule_refresh()
    {:noreply, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    do_refresh()
    schedule_refresh()
    {:noreply, state}
  end

  @impl true
  def handle_cast(:refresh, state) do
    do_refresh()
    {:noreply, state}
  end

  @impl true
  def handle_call(:refresh, _from, state) do
    do_refresh()
    {:reply, :ok, state}
  end

  def refresh, do: GenServer.call(__MODULE__, :refresh, 30_000)

  @spec list_post(String.t() | nil) :: [String.t()]
  def list_post(nil) do
    case lookup(:titles) do
      {:ok, titles} -> titles
      :miss -> []
    end
  end

  def list_post(branch), do: fetch_titles(branch)

  @spec get_post(String.t(), String.t() | nil) :: String.t() | {:error, String.t()}
  def get_post(title, branch \\ nil)

  def get_post(title, nil) do
    case lookup({:post, title}) do
      {:ok, post} -> post
      :miss -> {:error, "not yet loaded"}
    end
  end

  def get_post(title, branch), do: fetch_post(title, branch)

  @spec pr_branch(String.t() | integer()) :: {:ok, String.t()} | {:error, String.t()}
  def pr_branch(pr_number) do
    url = "https://api.github.com/repos/filipecabaco/my_blog/pulls/#{pr_number}"

    case req_get(url) do
      {:ok, %{body: %{"head" => %{"ref" => branch}}}} ->
        {:ok, branch}

      {:ok, %{body: %{"message" => message}}} ->
        Logger.warning("Failed to resolve PR ##{pr_number}: #{message}")
        {:error, message}

      {:error, reason} ->
        Logger.error("Failed to resolve PR ##{pr_number}: #{inspect(reason)}")
        {:error, "Failed to resolve PR"}
    end
  end

  def invalidate_cache do
    if :ets.whereis(@table) != :undefined do
      :ets.delete_all_objects(@table)
    end

    :ok
  end

  @spec title(String.t()) :: String.t()
  def title(post) do
    case Regex.run(~r/#(.*)/, post) do
      [_, title] -> String.trim(title)
      nil -> ""
    end
  end

  @doc """
  The title to show for a post: the `# Heading` if there is one, otherwise the
  slug with its date prefix removed.
  """
  @spec display_title(String.t(), String.t()) :: String.t()
  def display_title(slug, content) do
    case title(content) do
      "" -> slug |> String.replace(~r/^\d{4}-\d{2}-\d{2}[_-]?/, "") |> Phoenix.Naming.humanize()
      title -> title
    end
  end

  @doc """
  The ISO date encoded in a post slug, or an empty string.
  """
  @spec date(String.t()) :: String.t()
  def date(slug) do
    case Regex.run(~r/^(\d{4}-\d{2}-\d{2})/, slug) do
      [_, date] -> date
      nil -> ""
    end
  end

  @spec description(String.t()) :: String.t()
  def description(post) do
    case Regex.run(~r/# .*\n(?:tags:.*\n)?\n(.*)/, post) do
      [_, description] -> description |> strip_markdown() |> String.trim()
      nil -> ""
    end
  end

  defp strip_markdown(text) do
    text
    |> String.replace(~r/!\[([^\]]*)\]\([^)]*\)/, "")
    |> String.replace(~r/\[([^\]]*)\]\s*\([^)]*\)/, "\\1")
    |> String.replace(~r/`([^`]*)`/, "\\1")
    |> String.replace(~r/\*\*([^*]+)\*\*/, "\\1")
    |> String.replace(~r/(?<!\w)[*_]([^*_]+)[*_](?!\w)/, "\\1")
    |> String.replace(~r/\s+/, " ")
  end

  @spec published_date(String.t()) :: String.t() | nil
  def published_date(title) do
    case Regex.run(~r/^(\d{4}-\d{2}-\d{2})/, title) do
      [_, date] -> date <> "T00:00:00+00:00"
      nil -> nil
    end
  end

  @spec reading_time(String.t()) :: pos_integer()
  def reading_time(post) do
    post
    |> String.split(~r/\s+/, trim: true)
    |> length()
    |> then(&max(ceil(&1 / 150), 1))
  end

  @spec parse(String.t()) :: String.t() | {:error, String.t()}
  def parse(post) do
    case post |> strip_tags() |> Blog.Markdown.render() do
      {:ok, html, _headings} -> html
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Renders a post as `{:ok, html, headings}`. Unlike `parse/1` this also drops
  the leading `# Title`, which the page renders itself.
  """
  @spec render(String.t()) :: {:ok, String.t(), [Blog.Markdown.heading()]} | {:error, String.t()}
  def render(post) do
    post
    |> strip_tags()
    |> then(&Regex.replace(~r/\A\s*#[^\n#][^\n]*\n/, &1, ""))
    |> Blog.Markdown.render()
  end

  defp strip_tags(post), do: Regex.replace(~r/^tags:\s*.+$/m, post, "")

  defp do_refresh do
    titles = fetch_titles(@default_branch)

    if titles != [] do
      insert(:titles, titles)

      titles
      |> Enum.map(&String.replace(&1, ".md", ""))
      |> Enum.each(fn title ->
        case fetch_post(title, @default_branch) do
          {:error, _} -> :ok
          post -> insert({:post, title}, post)
        end
      end)
    end
  rescue
    e -> Logger.warning("Cache refresh failed: #{Exception.message(e)}")
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end

  defp lookup(key) do
    case :ets.lookup(@table, key) do
      [{^key, value, inserted_at}] ->
        if System.monotonic_time(:millisecond) - inserted_at < @ttl do
          {:ok, value}
        else
          GenServer.cast(__MODULE__, :refresh)
          {:ok, value}
        end

      _ ->
        :miss
    end
  end

  defp insert(key, value) do
    :ets.insert(@table, {key, value, System.monotonic_time(:millisecond)})
  end

  defp fetch_titles(branch) do
    with {:ok, %{body: body}} when is_list(body) <-
           req_get(@url, params: [ref: branch]) do
      body
      |> Enum.map(& &1["name"])
      |> Enum.sort(:desc)
    else
      {:ok, %{body: %{"message" => message}}} ->
        Logger.warning("GitHub API authentication failed: #{message}")
        []

      {:ok, %{body: body}} ->
        Logger.warning("Unexpected GitHub API response: #{inspect(body)}")
        []

      {:error, reason} ->
        Logger.warning("Failed to fetch titles: #{inspect(reason)}")
        []
    end
  end

  defp fetch_post(title, branch) do
    with {:ok, %{body: %{"download_url" => download_url}}} <-
           req_get("#{@url}/#{title}.md", params: [ref: branch]),
         {:ok, %{body: body}} when is_binary(body) <-
           req_get(download_url) do
      body
    else
      {:ok, %{body: %{"message" => message}}} ->
        Logger.warning("Failed to fetch post #{title}: #{message}")
        {:error, message}

      {:error, reason} ->
        Logger.error("Failed to fetch post #{title}: #{inspect(reason)}")
        {:error, "Failed to fetch post content"}
    end
  end

  defp req_get(url, opts \\ []) do
    [url: url, headers: [{"Authorization", "Bearer #{token()}"}, {"Cache-Control", "no-cache"}, {"Pragma", "no-cache"}], receive_timeout: 15_000]
    |> Keyword.merge(opts)
    |> Keyword.merge(Application.get_env(:blog, :req_options, []))
    |> Req.new()
    |> Req.get()
  end

  defp token, do: Application.get_env(:blog, :github_token, "")
end
