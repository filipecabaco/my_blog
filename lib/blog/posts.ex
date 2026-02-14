defmodule Blog.Posts do
  use GenServer
  require Logger

  @url "https://api.github.com/repos/filipecabaco/my_blog/contents/posts"
  @table __MODULE__
  @ttl :timer.minutes(30)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  @spec list_post(String.t() | nil) :: [String.t()]
  def list_post(nil) do
    case lookup(:titles) do
      {:ok, titles} ->
        titles

      :miss ->
        titles = fetch_titles("master")
        insert(:titles, titles)
        titles
    end
  end

  def list_post(branch), do: fetch_titles(branch)

  @spec get_post(String.t(), String.t() | nil) :: String.t() | {:error, String.t()}
  def get_post(title, branch \\ nil)

  def get_post(title, nil) do
    case lookup({:post, title}) do
      {:ok, post} ->
        post

      :miss ->
        case fetch_post(title, "master") do
          {:error, _} = error ->
            error

          post ->
            insert({:post, title}, post)
            post
        end
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
    :ets.delete_all_objects(@table)
    :ok
  end

  @spec title(String.t()) :: String.t()
  def title(post) do
    case Regex.run(~r/#(.*)/, post) do
      [_, title] -> String.trim(title)
      nil -> ""
    end
  end

  @spec tags(String.t()) :: [String.t()]
  def tags(post) do
    case Regex.run(~r/^tags:\s*(.+)$/m, post) do
      [_, tags_string] ->
        tags_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      nil ->
        []
    end
  end

  @spec description(String.t()) :: String.t()
  def description(post) do
    case Regex.run(~r/# .*\n(?:tags:.*\n)?\n(.*)/, post) do
      [_, description] -> String.trim(description)
      nil -> ""
    end
  end

  @spec parse(String.t()) :: String.t() | {:error, String.t()}
  def parse(post) do
    stripped = Regex.replace(~r/^tags:\s*.+$/m, post, "")

    case Earmark.as_html(stripped) do
      {:ok, html, _warnings} ->
        html

      {:error, _html, errors} ->
        Logger.error("Failed to parse markdown: #{inspect(errors)}")
        {:error, "Failed to parse markdown"}
    end
  end

  defp lookup(key) do
    case :ets.lookup(@table, key) do
      [{^key, value, inserted_at}] ->
        if System.monotonic_time(:millisecond) - inserted_at < @ttl,
          do: {:ok, value},
          else: :miss

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
    [url: url, headers: [{"Authorization", "Bearer #{token()}"}]]
    |> Keyword.merge(opts)
    |> Keyword.merge(Application.get_env(:blog, :req_options, []))
    |> Req.new()
    |> Req.get()
  end

  defp token, do: Application.get_env(:blog, :github_token, "")
end
