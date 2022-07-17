# Statistics on the cheap

In an homage to 90's websites I wanted to add a read counter but with a modern twist... DETS, GenServer, Telemetry, Phoenix.LiveView, Phoenix.PubSub we will create a counter that has live updates so we can track how many people actually read the content 🧐.

Do not forget that all of the code from this post and others is in this [repository](https://github.com/filipecabaco/my_blog)

## What is DETS

If you worked with Elixir or Erlang you've heard about [ETS](https://www.erlang.org/doc/man/ets.html) for sure, a Term storage where you can save some information in-memory. This could be a great way to store information temporarily but I want something a bit more long-term that doesn't dissapear with a restart.

That's where [DETS](https://www.erlang.org/doc/man/dets.html) enters! It's a flavour of ETS but disk based.

So lets start our small adventure

## Starting DETS

First I will create a new statistics module that will save our metrics into our persistency layer and it should be able to start on its own and later receive telemetry events so we will need a [GenServer](https://hexdocs.pm/elixir/1.13/GenServer.html) that will properly start our DETS table on start:
```elixir
defmodule Blog.Statistics do
  use GenServer

  def start_link(path), do: GenServer.start_link(__MODULE__, path, name: __MODULE__)

  @impl true
  def init(path) do
    :ok = File.mkdir_p(path) # Create folders on given path if required
    {:ok, :statistics} = :dets.open_file(:statistics, [{:file, to_charlist("#{path}/statistics")}])

    # Create a counter for each available post
    Enum.each(Posts.list_post(), fn title ->
      key = title |> String.replace(".md", "") |> to_charlist()
      if :dets.lookup(:statistics, key) == [], do: :dets.insert_new(:statistics, {key, 0})
    end)

    {:ok, nil}
  end

  @impl true
  def terminate(_reason, _state), do: :dets.close(:statistics) # Close file
end
```

Please notice the fact that we need to use [`to_charlist/1`](https://hexdocs.pm/elixir/1.13.4/Kernel.html#to_charlist/1) since we're interacting with an Erlang module which only works with charlists (check more in [Elixir School](https://elixirschool.com/en/lessons/intermediate/erlang)). Then we initialize one counter per title we have if they are still not present in our DETS file. Another important detail is the fact that we need to close the file properly otherwise it might corrupt your data.

Finally we do a quick method to fetch our statistics on request:
```elixir
defmodule Blog.Statistics do
# ...
  @impl true
  def handle_call(:fetch, _, state), do: {:reply, Keyword.get(:dets.lookup(:statistics, :counter), :counter), state}

  def fetch(title), do: GenServer.call(__MODULE__, {:fetch, title})
end
```
We're also adding an helping method to make the call to our system more user friendly - `Blog.Statistics.fetch("title")` instead of `GenServer.call(Blog.Statistics, {:fetch, "title"})`

## Setting up telemetry

Now we use another super power from the Beam community, the [telemetry](https://hex.pm/packages/telemetry) package. This awesome package allows you to dispatch and capture metrics in a really lightweight way.

To use it we need to attach our function that will track visits in our `lib/blog/statistics.ex` module:
``` elixir
defmodule Blog.Statistics do

  @impl true
  def init(path) do
    # ...
    :telemetry.attach(__MODULE__, [:blog, :visit], &Blog.Statistics.handle_event/4, nil) # Attach visit event to our handler function
  end

  def handle_event([:blog, :visit], _measurements, _metadata, _config), do: IO.puts("!")
end
```

We will later refine our `handle_event/4` to be a bit more useful but to see if this works we can jump into `iex` and check:
```elixir
iex(1)> :telemetry.execute([:blog, :visit], %{}, %{})
!
:ok
iex(2)>
```

Success! Now we need to trigger our event whenever a new person checks our blog. We will use the fact that we're using LiveView to track our users metrics with a neat LiveView trick - JS interoperability!
## Tracking Users (without being too intrusive)
First things first, we only want to track users that have been in our page longer than 10 seconds so we'll go to our `assets/js/app.js` and implement that:
``` javascript
//...
// connect if there are any LiveViews on the page
liveSocket.connect()
setTimeout(() => liveSocket.main.channel.push('reader', { csrf_token: csrfToken }), 10000) // Send CSRF token after 10 seconds
window.liveSocket = liveSocket

```
We're using the main channel to push an event of type `reader` with the `csrf_token` as the body, which we might want to use in the future, of said event to our LiveView and now it's a matter of catching it in said LiveView and emit our telemetry event:
```elixir
defmodule BlogWeb.PostLive.Show do
  # ...
  @impl true
  def handle_info("reader", socket) do
    :telemetry.execute([:blog, :visit], %{}, %{title: socket.assigns.title})
    {:noreply, socket}
  end
end
```

And that is it! Now when a user stays for longer than 10 seconds in our page we will emit a telemetry event to update our counter! That empty map `%{}` in the second argument is reserved for other telemetry you might want to send but we won't use it since we don't have any metric worth of measuring at the moment.

For more about JS interop I highly advice to check this [Phoenix Live View documentation](https://hexdocs.pm/phoenix_live_view/js-interop.html).

## Share with everyone

Now time to build our Altavista homage and add our counter at the bottom of the Post so people know how many have read it. To achieve it we just need to send that information to every client whenever the JS event is received. The changes will happen on `lib/blog_web/live/post_live/show.ex` and `lib/blog_web/live/post_live/show.html.heex`:

```elixir
defmodule BlogWeb.PostLive.Show do
  # ...
  @impl true
  def mount(%{"title" => title}, _session, socket) do
    BlogWeb.Endpoint.subscribe("show") # 1. Subscribe to topic
    {:ok, assign(socket, :counter, Blog.Statistics.fetch(title))}
  end
  # ...
   @impl true
  def handle_info(%{event: "reader"}, socket) do
    title = socket.assigns.title
    :telemetry.execute([:blog, :visit], %{}, %{title: title}) # 2. Broadcast telemetry event to update counter
    BlogWeb.Endpoint.broadcast("show", "join", %{title: title}) # 3. Broadcast to everyone something changed
    {:noreply, socket}
  end
  # 4. Receive event, matching if the title argument is the same
  def handle_info(%{event: "join", payload: %{title: title}}, %{assigns: %{title: title}} = socket) do
    {:noreply, assign(socket, :counter, Blog.Statistics.fetch(title))}
  end
  # 5. Fallback handle info to avoid no match errors
  def handle_info(_, socket), do: {:noreply, socket}
end
```
```html
<div>Total readers: <%=@counter%></div>
```
Phoenix has an awesome way to announce everyone else that something new happened called [Phoenix.PubSub](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html) so we subscribe to that and emit an event so all other connected clients can update their state with the new counter value! That has been started with the name `Blog.PubSub` on our `lib/blog/application.ex` and can be accessed via our `BlogWeb.Endpoint` module which creates really useful helper functions.

Now looking at the code with the knowledge that we have PubSub capabilities we can go step by step:
1. We subscribe our view to "show" topic
2. When we receive the JS event we emit a telemetry event to increment our counter
3. Broadcast to all subscribers that there has been an update
4. We receive an event where we pattern match to check if the title in the event is the same as the title our page is in and if so, update our state to reflect the new counter
5. Add an extra `handle_info/2` to catch non-matching events so our system doesn't send no match errors

And we get this end result:
![Gif showing counter increment as one page is refreshed](/images/img5.gif)

## Caveats
Do not forget that all of this information is stored in your disk, so you need to be careful to ensure that your disk is persisted on deploy. A lot of platforms use the concept of Volumes to achieve this. In my case, I'm using fly.io [Volumes](https://fly.io/docs/reference/volumes/) to achieve it.

## Conclusion
* DETS can be an awesome tool available out of the box to store less ephemeral data.
* Elixir to Erlang interop requires Charlists so be careful!
* telemetry event dispatching and capture can be a powerful tool to track metrics all around your system, you just need to attach a method and you're set!
* JS to Elixir communication can be quite easy and useful.
* Phoenix has an awesome PubSub module that can be used to sync all connected users.
