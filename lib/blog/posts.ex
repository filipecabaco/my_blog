defmodule Blog.Posts do
  use Agent
  @url "https://api.github.com/repos/filipecabaco/my_blog/contents/posts"
  ## Starts the agent
  def start_link(_), do: Agent.start_link(fn -> %{titles: [], posts: %{}} end, name: __MODULE__)

  ## Fetches list of posts from memory otherwise makes a request
  def list_post do
    Agent.get_and_update(__MODULE__, fn
      %{titles: []} = state ->
        titles = fetch_titles()
        {titles, %{state | titles: titles}}

      %{titles: titles} = state ->
        {titles, state}
    end)
  end

  ## Fetches post from memory otherwise makes a request
  def get_post!(title) do
    Agent.get_and_update(__MODULE__, fn
      %{posts: posts} = state when not is_map_key(posts, title) ->
        post = fetch_post(title)
        {post, %{state | posts: %{title => post}}}

      %{posts: %{^title => post}} = state ->
        {post, state}
    end)
  end

  defp fetch_titles do
    @url
    |> Req.get!(headers: headers())
    |> then(& &1.body)
    |> Enum.map(& &1["name"])
  end

  defp fetch_post(title) do
    "#{@url}/#{title}.md"
    |> Req.get!(headers: headers())
    |> then(& &1.body["download_url"])
    |> Req.get!(headers: headers())
    |> then(&Earmark.as_html!(&1.body))
  end

  defp headers(), do: [{"Authorization", "Bearer #{token()}"}]

  # Going to use a token for good measure
  defp token, do: Application.get_env(:blog, :github_token)
end
