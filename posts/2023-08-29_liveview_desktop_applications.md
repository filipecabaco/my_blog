# Machile learning, LiveView powered Desktop Applications

There are multiple ways to interact with your software and one of the most common ones is Desktop applications. It's a very tricky area but a recent project has made it a lot easier - [Tauri](https://tauri.app/). In this post we're going to build a Liveview applications that uses Bumblebee and a new proof of concept library to install [Tauri](https://tauri.app/) in your Phoenix project called [ex_tauri](https://github.com/filipecabaco/ex_tauri)


## In the beggining, there was the Web App
> All the code is available at [Grammarlocal](https://github.com/filipecabaco/grammarlocal) repository

First we create a new application which I will be creating Grammarlocal the usual way.
`mix phx.new grammarlocal  --no-gettext --no-mailer --no-dashboard --no-gettext --no-ecto`

Then we build a really basic UI using Liveview
![Simple UI with a basic text area](/images/img13.png)
```elixir
defmodule GrammarlocalWeb.InputLive do
  use GrammarlocalWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:output, "")
      |> assign(:input, "")
      |> assign(:loading, false)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <textarea
        phx-blur="run"
        class="rounded-xl border border-slate-200 shadow w-full h-auto p-3 resize-none mb-10"
        rows="10"
      ><%= @input %></textarea>
      <div :if={@loading} class="w-full flex justify-center">
        <img src={~p"/images/loading.png"} class="animate-spin-slow" width="42" />
      </div>
      <div :if={!@loading} class="w-full p-3"><%= @output %></div>
    </div>
    """
  end
end
```

## Time to make it smart

Now we'll need to make it smart by using our usual suspect ([Bumblebee](https://github.com/elixir-nx/bumblebee)) and using a special model from [Grammarly](grammarly/coedit-large).

We load the model and prepare the serving before using it.
```elixir
defmodule Grammarlocal.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Nx.global_default_backend(EXLA.Backend)

    {:ok, model} = Bumblebee.load_model({:hf, "grammarly/coedit-large"})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "grammarly/coedit-large"})
    {:ok, generation_config} = Bumblebee.load_generation_config({:hf, "grammarly/coedit-large"})

    generation_config = %{generation_config | max_new_tokens: 1500}

    serving =
      Bumblebee.Text.generation(model, tokenizer, generation_config,
        defn_options: [compiler: EXLA]
      )

    children = [
      GrammarlocalWeb.Telemetry,
      {Phoenix.PubSub, name: Grammarlocal.PubSub},
      GrammarlocalWeb.Endpoint,
      {Nx.Serving, serving: serving, name: Grammarlocal.Serving, batch_timeout: 100}
    ]

    opts = [strategy: :one_for_one, name: Grammarlocal.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Then we go back to our `GrammarlocalWeb.InputLive` module and handle the events as expected
```elixir

  def handle_event("run", %{"value" => value}, socket) do
    Task.async(fn -> Nx.Serving.batched_run({:local, Grammarlocal.Serving}, value) end)
    {:noreply, socket |> assign(:input, value) |> assign(:loading, true)}
  end

  def handle_info({_, %{results: [%{text: text}]}}, socket) do
    {:noreply, socket |> assign(:output, text) |> assign(:loading, false)}
  end

  def handle_info({:DOWN, _, _, _, :normal}, socket), do: {:noreply, socket}
```
This will run the model in a Task, capture the result from running said model and handle the Task shutdown process.

In the end, we have a web application that is able to receive text and run it against a model that will apply ortographic corrections based on the model we just provided it!

## Desktop time

Now comes the "new thing" from this post - have this as a Desktop application you could install locally and distribute.

For that effect we will use [Tauri](https://tauri.app/). We could pull all dependencies and go along that path no issue but I've created a proof of concept to install [Tauri](https://tauri.app/) in your project easily with the library [ex_tauri](https://github.com/filipecabaco/ex_tauri).

### How it works?

The [ex_tauri](https://github.com/filipecabaco/ex_tauri) will be your friend and install within your `_build` folder the `tauri-cli` utility that will be able to ramp up a tauri project for you.

After that we run the tauri cli which will package your Phoenix application with [Burrito](https://github.com/burrito-elixir/burrito) into a single binary to be used by tauri as a [sidecar](https://tauri.app/v1/guides/building/sidecar/)

In the end, tauri will be able to grab our Phoenix binary, start it up, wait for it to be up and running on the specified port and open a web view with your Liveview application in all it's glory!

### Let's do it!
Let's add our dependency
```elixir
defp deps do
    [
      {:ex_tauri, git: "https://github.com/filipecabaco/ex_tauri"}
    ]
end
```

Add the config for tauri in our `config.exs`
```elixir
config :ex_tauri,
    version: "1.4.0",
    app_name: "Example Desktop",
    host: "localhost",
    port: 4000
```

Then we need to add a release configuration to our mix.exs
```elixir
  def project do
    [
      app: :grammarlocal,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: [
        # We need this to be named desktop for this PoC
        desktop: [
          steps: [:assemble, &Burrito.wrap/1],
          burrito: [
            targets: [
              # At the moment we still need this really specific names
              "aarch64-apple-darwin": [os: :darwin, cpu: :aarch64]
            ]
          ]
        ]
      ]
    ]
  end
```

Now you just need to run `mix tauri.install` which will install all the dependecies in your `_build` folder and also create a new folder called `src-tauri` that has all the required code to start up your tauri application.

## Run it!

After you have everything installed, you can run the command `mix ex_tauri dev`. All the arguments from `mix ex_tauri` will be forwarded to the tauri cli so you can explore other commands like `mix ex_tauri info` that gives you some information regarding your tauri application.

But with `mix ex_tauri dev` you will be able to see your application up and running in your Desktop and have your own local Grammarly.

![Desktop application running with a Webview showing Liveview](/images/img14.gif)

## Web View vs Native

Both approaches to the same problem are fine as long as you are aware of the limitations and, more importantly, have fun building stuff regardless of the approach 😁.

## Acknowledgments

* [Tauri App](tauri.app) for building it and providing a ton of support to find the right way to build the PoC
* [Digit / Doawoo](https://twitter.com/doawoo) for [Burrito](https://github.com/burrito-elixir/burrito) which enables us to build the binary to be used as a sidecar
* [Kevin Pan / Feng19](https://twitter.com/kevin52069370) for their example that heavily inspired the approach taken with their [phx_new_desktop](https://github.com/feng19/phx_new_desktop) repository
* [yos](https://twitter.com/r8code) for a [great discussion](https://twitter.com/r8code/status/1692573451767394313?s=20) and bringing Feng19 example into the mix (no pun intended)
* [Jonatan Kłosko](https://github.com/jonatanklosko) for helping me fix some misuses of Bumblebee on my side and just being an MVP in our community when it comes to ML
* [Phoenix Framework Tailwind](https://github.com/phoenixframework/tailwind) which was a big inspiration on the approach to be taken when it came to install an outside package and use it within an Elixir project

## Conclusion

* LiveView makes building reactive applications so easy that it's worth the effort to bring it to a new environment
* Bumblebee is still an excellent tool that makes ML approachable and easy to work with
* Tauri is awesome and greatly simplifies building and distributing apps
* A new (still badly coded) library to help you get started with Liveview Desktop applications is available 🎉
* This application was used to check some content of this blog 😆