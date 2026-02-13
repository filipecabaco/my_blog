defmodule Blog.Posts do
  use Agent
  @url "https://api.github.com/repos/filipecabaco/my_blog/contents/posts"
  def start_link(_), do: Agent.start_link(fn -> %{titles: [], posts: %{}} end, name: __MODULE__)

  def list_post(nil) do
    Agent.get_and_update(__MODULE__, fn
      %{titles: []} = state ->
        titles = fetch_titles("master")
        {titles, %{state | titles: titles}}

      %{titles: titles} = state ->
        {titles, state}
    end)
  end

  def list_post(branch), do: fetch_titles(branch)

  def get_post(title, branch \\ nil)

  def get_post(title, nil) do
    Agent.get_and_update(__MODULE__, fn
      %{posts: posts} = state when not is_map_key(posts, title) ->
        post = fetch_post(title, "master")
        {post, %{state | posts: %{title => post}}}

      %{posts: %{^title => post}} = state ->
        {post, state}
    end)
  end

  def get_post(title, branch), do: fetch_post(title, branch)

  def title(post) do
    [_, title] = Regex.run(~r/#(.*)/, post)
    String.trim(title)
  end

  def description(post) do
    [_, description] = Regex.run(~r/# .*\n\n(.*)/, post)
    String.trim(description)
  end

  def parse(post) do
    Earmark.as_html!(post)
  end

  defp fetch_titles(branch) do
    case Req.get(@url, headers: headers(), params: [ref: branch]) do
      {:ok, %{body: body}} when is_list(body) ->
        body |> Enum.map(& &1["name"]) |> Enum.sort(:desc)

      {:ok, %{body: %{"message" => message, "status" => status}}} when status == 401 ->
        IO.warn("GitHub API authentication failed: #{message}")
        IO.inspect(Application.get_env(:blog, :github_token), label: "Token being used (first 10 chars)")
        []

      {:ok, %{body: body}} ->
        IO.inspect(body, label: "Unexpected response format from GitHub API")
        []

      {:error, reason} ->
        IO.warn("Failed to fetch titles from GitHub: #{inspect(reason)}")
        []
    end
  end

  defp fetch_post(title, branch) do
    case Req.get("#{@url}/#{title}.md", headers: headers(), params: [ref: branch]) do
      {:ok, %{body: %{"download_url" => download_url}}} ->
        case Req.get(download_url, headers: headers(), params: [ref: branch]) do
          {:ok, %{body: body}} ->
            body

          {:error, reason} ->
            {:error, "Failed to fetch post content: #{inspect(reason)}"}
        end

      {:ok, %{body: %{"message" => message}}} ->
        {:error, message}

      {:error, reason} ->
        {:error, "Failed to fetch post metadata: #{inspect(reason)}"}
    end
  end

  defp headers(), do: [{"Authorization", "Bearer #{token()}"}]

  defp token, do: Application.get_env(:blog, :github_token, "")
end
