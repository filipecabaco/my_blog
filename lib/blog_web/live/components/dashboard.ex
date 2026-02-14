defmodule BlogWeb.Components.Dashboard do
  use BlogWeb, :live_component

  alias Blog.Posts
  alias Blog.Statistics

  @impl true
  def update(_, socket) do
    metrics =
      Posts.list_post(nil)
      |> Enum.map(&String.replace(&1, ".md", ""))
      |> Enum.map(fn title ->
        label = title |> String.split("_") |> Enum.drop(1) |> Enum.join(" ")
        %{title: label, views: Statistics.fetch(title)}
      end)

    max_views = metrics |> Enum.map(& &1.views) |> Enum.max(fn -> 1 end)

    spec =
      VegaLite.new(
        width: :container,
        height: :container,
        padding: [left: 20, right: 20, top: 20, bottom: 40],
        background: "transparent",
        autosize: [type: :fit, contains: :padding]
      )
      |> VegaLite.config(
        view: [stroke: "transparent"],
        axis: [
          label_color: "#8b949e",
          title_color: "#8b949e",
          grid_color: "transparent",
          domain_color: "transparent",
          tick_color: "transparent",
          label_font: "SF Mono, monospace",
          title_font: "SF Mono, monospace",
          label_font_size: 12
        ]
      )
      |> VegaLite.data_from_values(metrics)
      |> VegaLite.mark(:bar,
        corner_radius_end: 3,
        stroke: "transparent",
        height: [band: 0.6],
        color: "#30363d"
      )
      |> VegaLite.encode_field(:y, "title",
        type: :nominal,
        title: nil,
        sort: "-x",
        axis: [
          label_limit: 280,
          label_font_size: 13,
          label_padding: 10,
          grid: false
        ]
      )
      |> VegaLite.encode_field(:x, "views",
        type: :quantitative,
        title: nil,
        scale: [domain: [0, max_views * 1.1]],
        axis: [
          label_font_size: 12,
          grid: false,
          label_angle: 0,
          tick_min_step: 1,
          format: "d"
        ]
      )
      |> VegaLite.encode_field(:tooltip, "views", type: :quantitative, title: "Views")
      |> VegaLite.to_spec()

    {:ok, push_event(socket, "draw", %{"spec" => spec})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="container dashboard-container">
      <section class="dashboard-header">
        <h1 class="dashboard-title">Analytics</h1>
        <p class="dashboard-subtitle">Post views</p>
      </section>
      <div class="dashboard-panel">
        <div class="dashboard-chart" id="graph" phx-hook="Dashboard" />
      </div>
      <div style="margin-top: 2rem; text-align: center;">
        <.link navigate={~p"/"} class="back-link">Back to posts</.link>
      </div>
    </main>
    """
  end
end
