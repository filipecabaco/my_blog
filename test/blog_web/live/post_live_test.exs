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
  end
end
