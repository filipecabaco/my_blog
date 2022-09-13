# Realtime Updates with LiveView

One of the main advantages of LiveView over other implementations is the fact that realtime operations become a state update. In this post I'm going to detail how you can implement a realtime feature by adding a anonymous "ghost" to track where other users are when reading in this blog. We will tackle process creation, socket connection and Elixir <=> JS interoperability so get ready for a really long post.

Do not forget that all of the code from this post and others is in this [repository](https://github.com/filipecabaco/my_blog).

## Starting out our idea

The idea will be to track where each user is in the page vertically by reacting to JS events, sending them to Elixir and update all connected users so we require a couple of moving pieces to achieve it:

- Store data for each connected socket
- React upon user entering and exiting
- Handle JS events by updating state on all connected users

We will tackle this bottom up so our story is a bit clearer.

## Storing user data

Usually in other stacks this would be some sort of persistency (in-memory or with an external system) that would guarantee atomic operations on the state which would increase complexity. Fortunately we're in Beam land where we can have that by using one of our best friends: Processes. This means that we will have one process per connected LiveView socket which will be updated as new events are received.

### GenServer for one, GenServer for all!

#### One is the loneliest number

GenServers will be our abstraction of choice to build our persistency layer so we will create a simple GenServer with the state we require which:

- the socket
- title of the post
- random color
- the initial position set to 0

```elixir
defmodule Blog.ReadTag do
  use GenServer

  def init(args), do: {:ok, args}
  def start_link(%{name: name, socket: socket}), do: GenServer.start_link(__MODULE__, %{title: nil, color: random_rgb(), socket: socket, position: 0}, name: name)

  def handle_call(:get_state, _, state), do: {:reply, state, state}
  def handle_call(:get_position, _, %{position: pos} = state), do: {:reply, pos, state}

  def handle_cast({:set_title, title}, state), do: {:noreply, %{state | title: title}}
  def handle_cast({:set_position, pos}, state), do: {:noreply, %{state | position: pos}}

  defp random_rgb do
    Stream.repeatedly(fn -> Enum.random(0..255) end)
    |> Enum.take(3)
    |> Enum.join(", ")
    |> then(&"rgba(#{&1}, 0.5)")
  end
end
```

Notice that we also will receive the name that will attributed to the running process. That detail will become clearer in a bit.

And now with some simple commands we are able to start our child process and access it state:

```elixir
iex(1)> Blog.ReadTag.start_link(%{name: Blog.ReadTag, socket: nil})
{:ok, #PID<0.628.0>}
iex(2)> GenServer.call(Blog.ReadTag, :get_state)
%{color: "rgba(188, 35, 5, 0.5)", position: 0, socket: nil, title: nil}
```

We are now able to store one user which is progress but how can we have one process per connected user? Do we create a pool of empty processes preemptively and set the state as needed? Do we have all the data within one process with a list or a map? Or do we use the Beam superpowers?

I think you know the answer.

#### The power of multiplication

Usually when you start a GenServer process it will be within the context of a supervisor that will boot up a single instance of said process and ensure that the strategy is applied during the start of your application:

```elixir
defmodule Blog.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Blog.ReadTag.ReadTag, %{name: Blog.ReadTag, socket: nil}},
    ]
    opts = [strategy: :one_for_one, name: Blog.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

But we want to create our child processes dynamically based on our needs and, as usual, Elixir offers just the right tool for the job. [Dynamic Supervisor](https://hexdocs.pm/elixir/1.14/DynamicSupervisor.html) are Supervisors that let you receive a child specification (aka a GenServer) and handle their lifecycle fully in a dynamic way.

```elixir
defmodule Blog.ReadTag.Supervisor do
  use DynamicSupervisor
  alias Blog.ReadTag

  def init(_), do: DynamicSupervisor.init(strategy: :one_for_one)
  def start_link(_), do: DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)

  def start(socket, title), do: DynamicSupervisor.start_child(__MODULE__, {ReadTag, %{name: {:global, socket.id}, socket: socket}})
  def terminate(id), do: DynamicSupervisor.terminate_child(__MODULE__, :global.whereis_name(id))
end
```

With this code we can create multiple processes, one per "simulated socket":

```elixir
iex(1)> Enum.each(1..5, &Blog.ReadTag.Supervisor.start(%{id: &1}, "test"))
:ok
```

![Supervision tree after starting 5 child processes](/images/img9.png)

**Note:** Now there's is a hugely important detail we should be aware of, we took a shortcut by using the [:global](https://www.erlang.org/doc/man/global.html) name registry. We could have created our own [Registry](https://hexdocs.pm/elixir/1.14/Registry.html) which would be a better approach to ensure we have separate names for separate contexts.

In our use case we're going to set the name of the process with the id of the socket by using the process name of `{:global, socket.id}` and we can find our processes by doing `:global_whereis_name(name)`.

Lets add a couple of helper methods so we can talk with our child processes in a more streamlined way based on their socket IDs and post title:

```elixir
defmodule Blog.ReadTag.Supervisor do
  use DynamicSupervisor
  alias Blog.ReadTag

  def init(_), do: DynamicSupervisor.init(strategy: :one_for_one)
  def start_link(_), do: DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)

  def start(socket, title), do: DynamicSupervisor.start_child(__MODULE__, {ReadTag, %{name: {:global, socket.id}, socket: socket}})
  def terminate(id), do: DynamicSupervisor.terminate_child(__MODULE__, :global.whereis_name(id))

  @doc """
  Fetches the socket for a given socket id
  """
  def get_socket(id), do: GenServer.call(:global.whereis_name(id), :get_state).socket
  @doc """
  Fetches the state for a given socket id
  """
  def get_state(id) do
    pid = :global.whereis_name(id)
    if pid != :undefined, do: GenServer.call(pid, :get_state)
  end

  @doc """
  Sets the title for a given socket id and title
  """
  def set_title(id, title), do: GenServer.cast(:global.whereis_name(id), {:set_title, title})

  @doc """
  Sets the position for a given socket id and position
  """
  def set_position(id, position), do: GenServer.cast(:global.whereis_name(id), {:set_position, position})

  @doc """
  Gets all processes for a given title
  """
  def get_for_title(title) do
    :global.registered_names()
    |> Enum.map(&get_state/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&(&1.title == title))
  end
end
```

Now it's time to connect the dots by creating a process whenever a new client enters a blog post:

```elixir
defmodule BlogWeb.PostLive.Show do
  use BlogWeb, :live_view

  alias Blog.Posts
  alias Blog.ReadTag.Supervisor

  @impl true
  def mount(%{"title" => title}, _, socket) do
    #...
    # We check if the socket is connected and if connected we start our child process for the given socket and title
    if connected?(socket), do: Supervisor.start(socket, title)
    #...
  end
  # ...
end
```

That is it, we now have state per connected socket but what happens on disconnect? What if a user closes the tab or his browser crashes?

We need to have a way to control LiveView connections to ensure we kill stale processes.

#### The Terminator

How can we check what processes to keep alive and which ones to kill? Fortunately LiveView has another great trick up its sleave. Each socket connection is a process by itself and you can access the PID of said connection. If a connection dies, the process will also die and we can use that to our advantage:

```elixir
%Phoenix.LiveView.Socket{
  root_pid: pid(), # This is our friend that lives and dies based on the connection status
}
Process.alive?(root_pid) # This determines if the socket is still connected or not
```

So lets create our Terminator GenServer, a simple process that will check our `:global` registry and see what is the status of each connection from our sockets:

```elixir
defmodule Blog.ReadTag.Monitor do
  use GenServer
  alias Blog.ReadTag.Supervisor

  def init(_), do: {:ok, nil, {:continue, []}}
  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def handle_continue(_, state) do
    Process.send(self(), :clean, [])
    {:noreply, state}
  end

  def handle_info(:clean, state) do
    Enum.each(:global.registered_names(), fn id ->
      %{title: title, socket: %{root_pid: root_pid, id: id}} = Supervisor.get_state(id)

      unless Process.alive?(root_pid), do: Supervisor.terminate(id)
    end)

    Process.send_after(self(), :clean, 100)
    {:noreply, state}
  end
end
```

This creates a "scheduled" task that runs every 100ms to check if the `root_pid` of all existing sockets are alive or dead. If dead, we request our supervisor to kill it's child 😱.

**Note:** There's a cool trick with this GenServer which is the return of `init/1`. By returning the tuple `{:continue, []}` we're informing the GenServer that after everything is properly started with the proccess we want to run some code in our `handle_continue/2` function. In this scenario we're sending a message to ourselves to kickstart the cleanup scheduled process.

And now we fully control the lifecycle from start => middle => end of life of our processes so lets move to our component that will use all of this information.

## The Ghost Tag

### Drawing Casper

Lets first create our component so we can draw a simple html component based on the title and the read tag information extracted from a targetted process:

```elixir
defmodule BlogWeb.Components.ReadTag do
  use BlogWeb, :live_component
  alias Blog.ReadTag.Supervisor
  @impl true
  def update(%{title: title, owner_id: owner_id, id: id}, socket) do
    {:ok, assign(socket, %{title: title, read_tag: Supervisor.get_state(owner_id), id: id, self_id: socket.id})}
  end

  @impl true
  def render(%{read_tag: read_tag, self_id: self_id} = assigns) when not is_nil(read_tag) do
    style = "margin-left: -10vw; width: 2rem; background-color: #{read_tag.color}; border-top-right-radius: 1rem 40%; border-bottom-right-radius: 1rem 40%;"

    style =
      if(self_id == read_tag.socket.id) do
        "position: sticky;  position: -webkit-sticky; top: 0px; #{style}"
      else
        "position: absolute; top: #{read_tag.position}px; #{style}"
      end

    ~H"""
    <div style={style} id={@id} phx-hook="ReadTag" title={@title}>&nbsp;</div>
    """
  end
end

```

Then we check our parent view to assign the correct information (all our read tags per post title) and draw our component:

```elixir
defmodule BlogWeb.PostLive.Show do
  use BlogWeb, :live_view

  alias Blog.Posts
  alias Blog.ReadTag.Supervisor

  @impl true
  def mount(%{"title" => title}, _, socket) do
    if connected?(socket), do: Supervisor.start(socket, title)
    {:ok, assign(socket, %{read_tags: Supervisor.get_for_title(title)})}
  end
  # ...
end
```

```html
<%= for read_tag <- @read_tags do %> <.live_component
module={BlogWeb.Components.ReadTag} id={"read_tag_#{read_tag.socket.id}"}
title={@title} owner_id={read_tag.socket.id} /> <% end %> <%= raw(@post) %>
```

Now for each user in a given blog post we are able to create a div with their color and position
![Image showing the read tag on the side](/images/img10.png)

### Adding and Removing ghosts

It's time to react to friends arriving and leaving our post and we're going to use PubSub for that end. We will create a new topic to track read_tag events and sprinkle calls to our PubSub:

```elixir
defmodule Blog.ReadTag.Supervisor do
  use DynamicSupervisor
  alias Blog.ReadTag
  # ...
  def start(socket, title) do
    DynamicSupervisor.start_child(__MODULE__, {ReadTag, %{name: {:global, socket.id}, socket: socket, title: title}})
    BlogWeb.Endpoint.broadcast!("read_tag", "new_tag", %{id: socket.id, title: title}) # On new child, broadcast to pubsub
  end
  # ...
end
```

```elixir
defmodule Blog.ReadTag.Monitor do
  use GenServer
  alias Blog.ReadTag.Supervisor
  # ...
  def handle_info(:clean, state) do
    Enum.each(:global.registered_names(), fn id ->
      %{title: title, socket: %{root_pid: root_pid, id: id}} = Supervisor.get_state(id)

      unless Process.alive?(root_pid) do
        Supervisor.terminate(id)
        BlogWeb.Endpoint.broadcast!("read_tag", "delete_tag", %{id: id, title: title}) # On child killed, broadcast to pubsub
      end
    end)

    Process.send_after(self(), :clean, 100)
    {:noreply, state}
  end
end
```

And then we need to react to our event on the parent view of our components:

```elixir
defmodule BlogWeb.PostLive.Show do
  use BlogWeb, :live_view

  alias Blog.Posts
  alias Blog.ReadTag.Supervisor

  @impl true
  def mount(%{"title" => title}, _, socket) do
    if connected?(socket), do: Supervisor.start(socket, title)

    # Subscribe to the PubSub topic
    BlogWeb.Endpoint.subscribe("read_tag")
    {:ok, assign(socket, %{read_tags: Supervisor.get_for_title(title)})}
  end
  #...
  # We're matching to see if we're the owner of the event to ignore it
  def handle_info(%{topic: "read_tag", event: "new_tag", payload: %{id: id}}, %{id: id} = socket) do
    {:noreply, socket}
  end

  # On user joining, we're updating the view assigns by fetching all sockets connected to a given title
  def handle_info(%{topic: "read_tag", event: "new_tag", payload: %{title: title}}, %{assigns: %{title: title}} = socket) do
    {:noreply, assign(socket, %{read_tags: Supervisor.get_for_title(title)})}
  end
  # On user leaving, we're updating the view assigns by fetching all sockets connected to a given title
  def handle_info(%{topic: "read_tag", event: "delete_tag", payload: %{title: title}}, %{assigns: %{title: title}} = socket) do
    {:noreply, assign(socket, %{read_tags: Supervisor.get_for_title(title)})}
  end

  def handle_info(_, socket), do: {:noreply, socket}
end
```

And that is it, whenever a user joins, the elements are updated to add or remove elements.
![Page elements updating on joining and leaving of a user](/images/img11.gif)

### Paranormal activity

Time for the JS <=> Elixir interoperability! We need to send en event from JS to Elixir to update the position of our tag element and we need to react to an event from Elixir to JS by adding an handle event callback.

We will achieve this by creating a new hook to be used only by this component:

```javascript
const ReadTag = {
  mounted() {
    let scrolling = false
    addEventListener('scroll', () => {
      scrolling = true
    })
    // Receive event from Elixir and modify position of target element
    this.handleEvent('update_tag', (event) => {
      let tag = document.getElementById(event.id)
      if (tag) {
        tag.style.top = `${event.position}px`
      }
    })
    // Cheap way of throttling scroll events
    setInterval(() => {
      if (scrolling) {
        scrolling = false
        // Send event to Elixir with the title and the position
        this.pushEvent('scroll_position', {
          position: window.scrollY,
          title: this.el.title,
        })
      }
    }, 50)
  },
}

export default ReadTag
```

Then we need to send and handle this events in our parent view:

```elixir
defmodule BlogWeb.PostLive.Show do
  use BlogWeb, :live_view
  # ...
  alias Blog.ReadTag.Supervisor
  # ...

  # We're matching to see if we're the owner of the event to ignore it
  def handle_info(%{topic: "read_tag", event: "position_update", payload: %{id: id}}, %{id: id} = socket) do
    {:noreply, socket}
  end
  # Send event back to JS to update the element associated with the owner of the event
  def handle_info(%{topic: "read_tag", event: "position_update", payload: %{id: id, position: position, title: title}}, %{assigns: %{title: title}} = socket) do
    {:noreply, push_event(socket, "update_tag", %{id: "read_tag_#{id}", position: position})}
  end
  # ...
  # Receive event from JS on position update
  @impl true
  def handle_event("scroll_position", %{"position" => position, "title" => title}, socket) do
    Supervisor.set_position(socket.id, position) # Update our process state
    BlogWeb.Endpoint.broadcast!("read_tag", "position_update", %{id: socket.id, position: position, title: title}) # Emit to PubSub a position update
    {:noreply, socket}
  end
end
```

And now our ghosts walk in our page! Quite a long journey but we just achieved realtime communication with around 200 lines of code without an external system and using only Phoenix, LiveView and Elixir as dependencies.
![Read tags moving in our page](/images/img12.gif)

Hope you enjoy it and that this post triggered your imagination on what LiveView is capable of.

## Conclusion

- We can use processes as a way to store locally status of users
- Dynamic supervisor is the way to go to create processes in a dynamic way
- LiveView has a great way to track socket connection by checking if the socket connection process is still alive
- PubSub keeps being our friend to update statuses in our view
- JS <=> Elixir interoperability it's the gift that keeps on giving and allowing us to really make fun reactive interactions with low amounts of code
