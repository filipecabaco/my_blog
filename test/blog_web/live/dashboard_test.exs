defmodule BlogWeb.DashboardTest do
  use BlogWeb.ConnCase, async: false

  @moduletag capture_log: true

  setup do
    Blog.Posts.invalidate_cache()
    Application.put_env(:blog, :req_options, plug: {Req.Test, __MODULE__})

    Req.Test.stub(__MODULE__, fn conn ->
      case conn.request_path do
        "/repos/filipecabaco/my_blog/contents/posts" ->
          Req.Test.json(conn, [%{"name" => "2024-01-15_test_post.md"}])

        "/repos/filipecabaco/my_blog/contents/posts/2024-01-15_test_post.md" ->
          Req.Test.json(conn, %{"download_url" => "http://test.local/raw/test.md"})

        "/raw/test.md" ->
          Plug.Conn.send_resp(conn, 200, "# Test Post\ntags: elixir\n\nA test post")
      end
    end)

    on_exit(fn ->
      Application.delete_env(:blog, :req_options)
      Blog.Posts.invalidate_cache()
    end)
  end

  test "renders dashboard page with chart", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/open_dashboard")

    assert html =~ "Analytics"
    assert html =~ "Post views"
    assert html =~ "dashboard-chart"
    assert html =~ "phx-hook=\"Dashboard\""
  end

  test "renders back link", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/open_dashboard")

    assert html =~ "Back to posts"
  end

  test "handles join broadcast by re-rendering dashboard", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/open_dashboard")

    BlogWeb.Endpoint.broadcast("show", "join", %{title: "some_post"})
    assert render(view) =~ "Analytics"
  end

  test "handles unknown messages without crashing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/open_dashboard")

    send(view.pid, %{topic: "show", event: "other"})
    assert render(view) =~ "Analytics"
  end
end
