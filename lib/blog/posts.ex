defmodule Blog.Posts do
  @moduledoc """
  Manages blog posts fetched from GitHub with ETS-based caching.

  Posts are cached in memory using ETS for better reliability and performance.
  The cache survives process crashes and can be shared across the application.
  """
  require Logger

  @url "https://api.github.com/repos/filipecabaco/my_blog/contents/posts"
  @table __MODULE__

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[]]},
      type: :worker,
      restart: :permanent
    }
  end

  def start_link(_opts) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    :ignore
  end

  @doc """
  Lists all post filenames from GitHub.

  ## Parameters
    - `nil` - Uses cached titles if available, otherwise fetches from master branch
    - `branch` - Fetches titles directly from the specified branch

  ## Returns
    - List of post filenames (strings) sorted in descending order
  """
  @spec list_post(String.t() | nil) :: [String.t()]
  def list_post(nil) do
    case :ets.lookup(@table, :titles) do
      [{:titles, titles}] ->
        titles

      [] ->
        titles = fetch_titles("master")
        :ets.insert(@table, {:titles, titles})
        titles
    end
  end

  def list_post(branch), do: fetch_titles(branch)

  @doc """
  Retrieves a post's content from GitHub.

  ## Parameters
    - `title` - The post filename (without .md extension)
    - `branch` - Optional branch name (defaults to nil for master/cached version)

  ## Returns
    - Post content as string on success
    - `{:error, reason}` tuple on failure
  """
  @spec get_post(String.t(), String.t() | nil) :: String.t() | {:error, String.t()}
  def get_post(title, branch \\ nil)

  def get_post(title, nil) do
    case :ets.lookup(@table, {:post, title}) do
      [{_, post}] ->
        post

      [] ->
        case fetch_post(title, "master") do
          {:error, _} = error ->
            error

          post ->
            :ets.insert(@table, {{:post, title}, post})
            post
        end
    end
  end

  def get_post(title, branch), do: fetch_post(title, branch)

  @doc """
  Extracts the title from a markdown post.

  ## Parameters
    - `post` - The markdown content as a string

  ## Returns
    - Extracted title as string, or empty string if not found
  """
  @spec title(String.t()) :: String.t()
  def title(post) do
    case Regex.run(~r/#(.*)/, post) do
      [_, title] -> String.trim(title)
      nil -> ""
    end
  end

  @doc """
  Extracts the description from a markdown post.

  ## Parameters
    - `post` - The markdown content as a string

  ## Returns
    - Extracted description as string, or empty string if not found
  """
  @spec description(String.t()) :: String.t()
  def description(post) do
    case Regex.run(~r/# .*\n\n(.*)/, post) do
      [_, description] -> String.trim(description)
      nil -> ""
    end
  end

  @doc """
  Parses markdown content to HTML.

  ## Parameters
    - `post` - The markdown content as a string

  ## Returns
    - HTML string on success
    - `{:error, reason}` on parse failure
  """
  @spec parse(String.t()) :: String.t() | {:error, String.t()}
  def parse(post) do
    case Earmark.as_html(post) do
      {:ok, html, _warnings} ->
        html

      {:error, _html, errors} ->
        Logger.error("Failed to parse markdown: #{inspect(errors)}")
        {:error, "Failed to parse markdown"}
    end
  end

  # Private functions

  @spec fetch_titles(String.t()) :: [String.t()]
  defp fetch_titles(branch) do
    with {:ok, %{body: body}} when is_list(body) <-
           Req.get(@url, headers: headers(), params: [ref: branch]) do
      body
      |> Enum.map(& &1["name"])
      |> Enum.sort(:desc)
    else
      {:ok, %{body: %{"message" => message, "status" => 401}}} ->
        Logger.warning("GitHub API authentication failed: #{message}")
        token = Application.get_env(:blog, :github_token, "")
        Logger.debug("Token being used (first 10 chars): #{String.slice(token, 0, 10)}")
        []

      {:ok, %{body: body}} ->
        Logger.warning("Unexpected response format from GitHub API: #{inspect(body)}")
        []

      {:error, reason} ->
        Logger.warning("Failed to fetch titles from GitHub: #{inspect(reason)}")
        []
    end
  end

  @spec fetch_post(String.t(), String.t()) :: String.t() | {:error, String.t()}
  defp fetch_post(title, branch) do
    with {:ok, %{body: %{"download_url" => download_url}}} <-
           Req.get("#{@url}/#{title}.md", headers: headers(), params: [ref: branch]),
         {:ok, %{body: body}} when is_binary(body) <-
           Req.get(download_url, headers: headers()) do
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

  @spec headers() :: [{String.t(), String.t()}]
  defp headers, do: [{"Authorization", "Bearer #{token()}"}]

  @spec token() :: String.t()
  defp token, do: Application.get_env(:blog, :github_token, "")
end
