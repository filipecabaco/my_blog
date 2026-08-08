defmodule BlogWeb.PostLiveTest do
  use BlogWeb.ConnCase, async: false

  @moduletag capture_log: true

  @post_content "# Test Post\ntags: elixir, phoenix\n\nA test post description"

  setup do
    Blog.Posts.invalidate_cache()
    Application.put_env(:blog, :req_options, plug: {Req.Test, Blog.Posts})

    Req.Test.stub(Blog.Posts, fn conn ->
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

    Req.Test.allow(Blog.Posts, self(), Process.whereis(Blog.Posts))
    Blog.Posts.refresh()

    on_exit(fn ->
      Application.delete_env(:blog, :req_options)
      Blog.Posts.invalidate_cache()
    end)
  end

  describe "Index" do
    test "renders the register of posts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "lead__title"
      assert html =~ "Test Post"
    end

    test "renders post description", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "A test post description"
    end

    test "displays reading time", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "1 min"
    end

    test "renders the post mark rather than a card image", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~s(class="mark")
      refute html =~ "/images/posts/2024-01-15_test_post.png"
    end

    test "lands straight on content, with the bio on its own page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      refute html =~ "hero-title"
      assert html =~ ~s(href="/about")
    end

    test "includes WebSite JSON-LD structured data on homepage", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~s(application/ld+json)
      assert html =~ ~s("@type":"WebSite")
      assert html =~ ~s("name":"Filipe Cabaco Blog")
    end
  end

  describe "Index with PR preview" do
    test "serves the card for the PR branch", %{conn: conn} do
      conn = get(conn, "/images/posts/2024-01-15_test_post.png?pr=42")

      assert conn.status == 200
      assert Plug.Conn.get_resp_header(conn, "content-type") == ["image/png; charset=utf-8"]
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
      assert html =~ "All posts"
      assert html =~ "all-time readers"
    end

    test "sets OG meta tags for the post", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/post/2024-01-15_test_post")

      assert html =~ ~s(og:title)
      assert html =~ ~s(og:image)
      assert html =~ "2024-01-15_test_post.png"
    end

    test "includes BlogPosting JSON-LD structured data", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/post/2024-01-15_test_post")

      assert html =~ ~s(application/ld+json)
      assert html =~ ~s("@type":"BlogPosting")
      assert html =~ ~s("headline":"Test Post")
      assert html =~ ~s("datePublished":"2024-01-15T00:00:00+00:00")
      assert html =~ ~s("name":"Filipe Cabaco")
      refute html =~ ~s("keywords")
    end

    test "handles missing post gracefully", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/post/nonexistent_post")

      assert html =~ "No post at this address"
      refute html =~ "0 min"
    end

    test "renders a presence lamp for the connected reader", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/post/2024-01-15_test_post")

      assert html =~ "presence__lamp"
      assert html =~ "Reading now"
    end

    test "updates counter on reader broadcast", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      BlogWeb.Endpoint.broadcast("show", "join", %{title: "2024-01-15_test_post"})
      # Give the message time to be processed
      _ = render(view)

      assert render(view) =~ "all-time readers"
    end

    test "ignores join broadcast for different post", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      BlogWeb.Endpoint.broadcast("show", "join", %{title: "other_post"})
      assert render(view) =~ "all-time readers"
    end

    test "handles reader broadcast event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      send(view.pid, %{topic: "show", event: "reader"})
      assert render(view) =~ "all-time readers"
    end

    test "handles unknown messages without crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      send(view.pid, %{topic: "unknown", event: "unknown"})
      assert render(view) =~ "all-time readers"
    end

    test "handles new_tag broadcast for same post", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      BlogWeb.Endpoint.broadcast("read_tag", "new_tag", %{id: "other-socket", title: "2024-01-15_test_post"})
      assert render(view) =~ "presence__lamp"
    end

    test "ignores new_tag broadcast from self", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      BlogWeb.Endpoint.broadcast("read_tag", "new_tag", %{id: view.id, title: "2024-01-15_test_post"})
      assert render(view) =~ "all-time readers"
    end

    test "handles delete_tag broadcast for same post", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      BlogWeb.Endpoint.broadcast("read_tag", "delete_tag", %{id: "other-socket", title: "2024-01-15_test_post"})
      assert render(view) =~ "all-time readers"
    end

    test "handles position_update broadcast from other user", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      BlogWeb.Endpoint.broadcast("read_tag", "position_update", %{
        id: "other-socket",
        position: 100,
        title: "2024-01-15_test_post"
      })

      assert render(view) =~ "all-time readers"
    end

    test "ignores position_update broadcast from self", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      BlogWeb.Endpoint.broadcast("read_tag", "position_update", %{
        id: view.id,
        position: 50,
        title: "2024-01-15_test_post"
      })

      assert render(view) =~ "all-time readers"
    end

    test "handles scroll_position event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/post/2024-01-15_test_post")

      render_hook(view, "scroll_position", %{"position" => 200, "title" => "2024-01-15_test_post"})
      assert render(view) =~ "all-time readers"
    end

    test "does not render tags line as text in post body", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/post/2024-01-15_test_post")

      refute html =~ "tags: elixir, phoenix"
      refute html =~ ~s(class="tag")
    end

    test "does not track statistics for PR preview posts", %{conn: conn} do
      title = "2024-01-15_test_post"
      counter_before = Blog.Statistics.fetch(title)

      {:ok, view, _html} = live(conn, ~p"/post/#{title}?pr=42")
      send(view.pid, %{topic: "show", event: "reader"})
      _ = render(view)

      assert Blog.Statistics.fetch(title) == counter_before
    end

    test "tracks statistics for regular posts", %{conn: conn} do
      title = "2024-01-15_test_post"
      counter_before = Blog.Statistics.fetch(title)

      {:ok, view, _html} = live(conn, ~p"/post/#{title}")
      send(view.pid, %{topic: "show", event: "reader"})
      _ = render(view)

      assert Blog.Statistics.fetch(title) == counter_before + 1
    end

    test "renders back link with pr param when previewing PR", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/post/2024-01-15_test_post?pr=42")

      assert html =~ "?pr=42"
      assert html =~ "All posts"
    end

    test "displays reading time", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/post/2024-01-15_test_post")

      assert html =~ "1 min"
    end
  end

  describe "Static render OG tags (crawler/Slack unfurl)" do
    test "includes post-specific OG tags on static render", %{conn: conn} do
      conn = get(conn, ~p"/post/2024-01-15_test_post")
      html = html_response(conn, 200)

      assert html =~ ~s(property="og:title" content="Test Post")
      assert html =~ ~s(property="og:image")
      assert html =~ "2024-01-15_test_post.png"
      assert html =~ ~s(property="og:type" content="article")
      assert html =~ ~s(property="og:url")
      assert html =~ "/post/2024-01-15_test_post"
    end

    test "does not fall back to homepage OG tags on static render of a post", %{conn: conn} do
      conn = get(conn, ~p"/post/2024-01-15_test_post")
      html = html_response(conn, 200)

      refute html =~ ~s(property="og:type" content="website")
    end

    test "does not advertise a missing post as an article", %{conn: conn} do
      conn = get(conn, ~p"/post/nonexistent_post")
      html = html_response(conn, 200)

      refute html =~ ~s(property="og:type" content="article")
      refute html =~ "/images/posts/nonexistent_post.png"
      assert html =~ ~s(property="og:type" content="website")
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
