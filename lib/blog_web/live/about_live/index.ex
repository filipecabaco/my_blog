defmodule BlogWeb.AboutLive.Index do
  use BlogWeb, :live_view

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "About")}

  @impl true
  def render(assigns) do
    ~H"""
    <main class="frame" id="main">
      <aside class="rail post__rail">
        <div class="rail__sticky">
          <div class="rail__block">
            <span class="label">Elsewhere</span>
            <a class="rail__value" href="https://github.com/filipecabaco">GitHub</a>
            <a class="rail__value" href="https://bsky.app/profile/filipecabaco.com">Bluesky</a>
            <a class="rail__value" href="https://www.linkedin.com/in/filipecabaco">LinkedIn</a>
          </div>
          <div class="rail__block">
            <span class="label">This site</span>
            <a class="rail__value" href="https://github.com/filipecabaco/my_blog">Source</a>
            <a class="rail__value" href="/atom">Atom feed</a>
          </div>
        </div>
      </aside>

      <article class="post">
        <header class="post__header">
          <span class="label">About</span>
          <h1 class="post__title">Filipe Cabaço</h1>
          <p class="post__standfirst">
            Notes on the BEAM, real-time systems, and the things that break when
            you put them in front of people.
          </p>
        </header>

        <div class="prose">
          <p>
            I build real-time infrastructure in Elixir, mostly the kind that has to
            stay up while thousands of connections come and go. Lisbon based.
          </p>
          <p>
            What ends up here is whatever I had to work out the hard way: process
            design, distribution, the gap between a thing that runs on a laptop and
            a thing that survives contact with real traffic.
          </p>
          <p>
            This blog runs on Phoenix LiveView and holds a process for every reader
            currently on a page. That is what the marks in the left margin of a post
            are: other people, roughly where they have read to.
          </p>
        </div>

        <footer class="post__footer">
          <.link navigate={~p"/"} class="masthead__link">&larr; All posts</.link>
          <a class="masthead__link" href="mailto:filipecabaco@gmail.com">filipecabaco@gmail.com</a>
        </footer>
      </article>
    </main>
    """
  end
end
