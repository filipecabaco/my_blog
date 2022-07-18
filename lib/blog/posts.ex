defmodule Blog.Posts do
  use Agent
  @url "https://api.github.com/repos/filipecabaco/my_blog/contents/posts"
  def start_link(_), do: Agent.start_link(fn -> %{titles: [], posts: %{}} end, name: __MODULE__)

  def list_post(), do: list_post(nil)

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

  def description(post) do
    [_, description] = Regex.run(~r/# .*\n\n(.*)/, post)
    description
  end

  def parse(post) do
    Earmark.as_html!(post)
  end

  defp fetch_titles(branch) do
    @url
    |> Req.get!(headers: headers(), params: [ref: branch])
    |> then(& &1.body)
    |> Enum.map(& &1["name"])
    |> Enum.sort(:desc)
  end

  defp fetch_post(title, branch) do
    "#{@url}/#{title}.md"
    |> IO.inspect()
    |> Req.get!(headers: headers(), params: [ref: branch])
    |> IO.inspect()
    |> then(& &1.body["download_url"])
    |> Req.get!(headers: headers(), params: [ref: branch])
    |> then(& &1.body)
  end

  defp headers(), do: [{"Authorization", "Bearer #{token()}"}]

  # Going to use a token for good measure
  defp token, do: Application.get_env(:blog, :github_token)
end
