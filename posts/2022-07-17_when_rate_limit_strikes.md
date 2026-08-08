# When Rate limit strikes!

Well that was quick... Github API warned me that I've spent all my Rate limiting due to the fact that I'm using their Public API without Authorization and well that is expected... To handle this problem I'm going to use a really basic solution: I will cache whatever information I want from their API and store it in memory and I will use only what Elixir has without extra dependencies to do so.

Do not forget that all of the code from this post and others is in this [repository](https://github.com/filipecabaco/my_blog)

## Setting up my cache
Since I need to deploy the application each time I'm posting new content it's not a problem to have no TTL functionality and let it live for as long as it wants.

As such, I'm going to use [Agent](https://hexdocs.pm/elixir/1.13.4/Agent.html) .

On my `lib/blog/posts.ex` I will start my Agent with some minimum state
```elixir
defmodule Blog.Posts do
  use Agent

  ## Starts the agent with the name of Blog.Posts and state of %{titles: [], posts: %{}}
  def start_link(_) do
    Agent.start_link(fn -> %{titles: [], posts: %{}} end, name: __MODULE__)
  end
end
```

Then I start it on my `lib/blog/application.ex`
```elixir
def start(_type, _args) do
    children = [
      BlogWeb.Telemetry,
      {Phoenix.PubSub, name: Blog.PubSub},
      BlogWeb.Endpoint,
      # Start it as any other child process
      Blog.Posts
    ]

    opts = [strategy: :one_for_one, name: Blog.Supervisor]
    Supervisor.start_link(children, opts)
  end
```
## Using my cache
With the Agent processes started I can now query and update it as I need to. We'll start by checking if we have titles. On my `lib/blog/posts.ex` file I will change my functions to check the state of my agent and fetch only if required:
```elixir
defmodule Blog.Posts do
  # ...

  # Fetches list of posts from memory otherwise makes a request
  def list_post do
    Agent.get_and_update(__MODULE__, fn
      %{titles: []} = state ->
        titles = fetch_titles()
        {titles, %{state | titles: titles}}

      %{titles: titles} = state ->
        {titles, state}
    end)
  end

  defp fetch_titles do
    @url
    |> Req.get!(headers: headers())
    |> then(& &1.body)
    |> Enum.map(& &1["name"])
  end

  defp headers(), do: [{"Authorization", "Bearer #{token()}"}]

  # Going to use a token for good measure
  defp token, do: Application.get_env(:blog, :github_token)
end

```

As you can see I match against an empty list on the state, meaning nothing was fetched yet, and only run a request at that point in time, updating my state with the response.

I follow the same approach for my posts in `lib/blog/posts.ex`:

```elixir
defmodule Blog.Posts do
  ## ...
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
```

In this one we match again but use the [`is_map_key/2`](https://hexdocs.pm/elixir/1.12/Kernel.html#is_map_key/2) guard to check of the state has the title we want to fetch.

And that is it! Without extra dependencies we added a simple caching system that does what we need.

## Caveats

This is a really simplistic approach that does not handle cache invalidation. We can still implement that mechanism on top of an Agent where we can have a process checking the state and deleting the state when approriate but for this type of scenario I highly advice to check more solid solutions like [ConCache](https://github.com/sasa1977/con_cache).

## Conclusion
* Elixir has a lot of tooling out of the box that takes advantages of processes
* You can use Agent for simple state management, check your use cases first
