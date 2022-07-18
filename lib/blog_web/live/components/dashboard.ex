defmodule BlogWeb.Components.Dashboard do
  use BlogWeb, :live_component

  alias Blog.Posts
  alias Blog.Statistics

  @impl true
  def update(_, socket) do
    metrics =
      Posts.list_post()
      |> Enum.map(&String.replace(&1, ".md", ""))
      |> Enum.map(fn title -> %{x: title, y: Statistics.fetch(title)} end)

    spec =
      VegaLite.new(title: "Visits", width: :container, height: :container, padding: 5)
      |> VegaLite.data_from_values(metrics)
      |> VegaLite.mark(:bar, color: "#98EED5")
      |> VegaLite.encode_field(:x, "x", type: :nominal, title: "Title")
      |> VegaLite.encode_field(:y, "y", type: :quantitative, title: "Views")
      |> VegaLite.to_spec()

    {:ok, push_event(socket, "draw", %{"spec" => spec})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="width:80%; height: 500px" id="graph" phx-hook="Dashboard"/>
    """
  end
end
