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

    Req.Test.allow(__MODULE__, self(), Process.whereis(Blog.Posts))
    Blog.Posts.refresh()

    on_exit(fn ->
      Application.delete_env(:blog, :req_options)
      Blog.Posts.invalidate_cache()
    end)
  end

  test "renders the readership page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/open_dashboard")

    assert html =~ "Readership"
    assert html =~ "Open stats"
    assert html =~ "Total views"
  end

  test "renders the empty state when nothing has been read", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/open_dashboard")

    assert html =~ "stats__empty" or html =~ "bars"
  end

  test "renders bars once a post has views", %{conn: conn} do
    :telemetry.execute([:blog, :visit], %{}, %{title: "2024-01-15_test_post"})

    {:ok, _view, html} = live(conn, ~p"/open_dashboard")

    assert html =~ "bar__meter"
    assert html =~ "Test Post"
  end

  test "handles join broadcast by re-rendering", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/open_dashboard")

    BlogWeb.Endpoint.broadcast("show", "join", %{title: "some_post"})
    assert render(view) =~ "Readership"
  end

  test "handles unknown messages without crashing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/open_dashboard")

    send(view.pid, %{topic: "show", event: "other"})
    assert render(view) =~ "Readership"
  end
end
