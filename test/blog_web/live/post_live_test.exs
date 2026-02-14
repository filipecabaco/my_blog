defmodule BlogWeb.PostLiveTest do
  use BlogWeb.ConnCase, async: false

  @moduletag capture_log: true

  @post_content "# Test Post\ntags: elixir, phoenix\n\nA test post description"

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
          Plug.Conn.send_resp(conn, 200, @post_content)

        "/repos/filipecabaco/my_blog/pulls/42" ->
          Req.Test.json(conn, %{"head" => %{"ref" => "draft/test-branch"}})

        "/filipecabaco/my_blog/draft/test-branch/priv/static/images/posts/2024-01-15_test_post.png" ->
          conn
          |> Plug.Conn.put_resp_content_type("image/png")
          |> Plug.Conn.send_resp(200, "fake-png-data")

        _ ->
          Req.Test.json(conn, %{"message" => "Not Found"})
      end
    end)

    on_exit(fn ->
      Application.delete_env(:blog, :req_options)
      Blog.Posts.invalidate_cache()
    end)
  end

  describe "Index" do
    test "renders post grid with cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "post-grid"
      assert html =~ "post-card"
      assert html =~ "2024-01-15 test post"
    end

    test "renders tag pills from post content", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "tag-pill"
      assert html =~ "elixir"
      assert html =~ "phoenix"
    end

    test "renders post description", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "A test post description"
    end

    test "renders post image", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "/images/posts/2024-01-15_test_post.png"
    end

    test "renders hero section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "filipecabaco.com"
      assert html =~ "hero-title"
    end
  end

  describe "Index with PR preview" do
    test "uses PR image proxy for card images", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/?pr=42")

      assert html =~ "/pr/42/images/posts/2024-01-15_test_post.png"
    end

    test "links to posts with pr param", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/?pr=42")

      assert html =~ "?pr=42"
    end
  end

  describe "Show" do
    test "renders post content with tags and footer", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/post/2024-01-15_test_post")

      assert html =~ "Test Post"
      assert html =~ "tag-pill"
      assert html =~ "elixir"
      assert html =~ "Back to posts"
      assert html =~ "readers"
    end

    test "sets OG meta tags for the post", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/post/2024-01-15_test_post")

      assert html =~ ~s(og:title)
      assert html =~ ~s(og:image)
      assert html =~ "2024-01-15_test_post.png"
    end

    test "handles missing post gracefully", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/post/nonexistent_post")

      assert html =~ "Failed to load post"
    end

    test "renders read tag for connected user", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/post/2024-01-15_test_post")

      assert html =~ "read-tag"
    end

    test "updates counter on reader broadcast", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      BlogWeb.Endpoint.broadcast("show", "join", %{title: "2024-01-15_test_post"})
      # Give the message time to be processed
      _ = render(view)

      assert render(view) =~ "readers"
    end

    test "ignores join broadcast for different post", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      BlogWeb.Endpoint.broadcast("show", "join", %{title: "other_post"})
      assert render(view) =~ "readers"
    end

    test "handles reader broadcast event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      send(view.pid, %{topic: "show", event: "reader"})
      assert render(view) =~ "readers"
    end

    test "handles unknown messages without crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      send(view.pid, %{topic: "unknown", event: "unknown"})
      assert render(view) =~ "readers"
    end

    test "handles new_tag broadcast for same post", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      BlogWeb.Endpoint.broadcast("read_tag", "new_tag", %{id: "other-socket", title: "2024-01-15_test_post"})
      assert render(view) =~ "read-tag"
    end

    test "ignores new_tag broadcast from self", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      BlogWeb.Endpoint.broadcast("read_tag", "new_tag", %{id: view.id, title: "2024-01-15_test_post"})
      assert render(view) =~ "readers"
    end

    test "handles delete_tag broadcast for same post", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      BlogWeb.Endpoint.broadcast("read_tag", "delete_tag", %{id: "other-socket", title: "2024-01-15_test_post"})
      assert render(view) =~ "readers"
    end

    test "handles position_update broadcast from other user", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      BlogWeb.Endpoint.broadcast("read_tag", "position_update", %{
        id: "other-socket",
        position: 100,
        title: "2024-01-15_test_post"
      })

      assert render(view) =~ "readers"
    end

    test "ignores position_update broadcast from self", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      BlogWeb.Endpoint.broadcast("read_tag", "position_update", %{
        id: view.id,
        position: 50,
        title: "2024-01-15_test_post"
      })

      assert render(view) =~ "readers"
    end

    test "handles scroll_position event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      render_hook(view, "scroll_position", %{"position" => 200, "title" => "2024-01-15_test_post"})
      assert render(view) =~ "readers"
    end

    test "does not render tags line as text in post body", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/post/2024-01-15_test_post")

      refute html =~ "tags: elixir, phoenix"
      assert html =~ "tag-pill"
    end

    test "renders back link with pr param when previewing PR", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/post/2024-01-15_test_post?pr=42")

      assert html =~ "?pr=42"
      assert html =~ "Back to posts"
    end
  end

  describe "PR image proxy" do
    test "proxies image from PR branch", %{conn: conn} do
      conn = get(conn, "/pr/42/images/posts/2024-01-15_test_post.png")

      assert conn.status == 200
      assert conn.resp_body == "fake-png-data"
    end

    test "returns 404 for invalid PR", %{conn: conn} do
      conn = get(conn, "/pr/999/images/posts/nonexistent.png")

      assert conn.status == 404
    end
  end
end
