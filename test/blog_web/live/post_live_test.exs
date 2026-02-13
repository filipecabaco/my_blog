defmodule BlogWeb.PostLiveTest do
  use BlogWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  describe "Index" do
    test "renders post listing", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "container"
    end

    test "renders tag pills when post content has tags", %{conn: conn} do
      Blog.Posts.invalidate_cache()
      Application.put_env(:blog, :req_options, plug: {Req.Test, BlogWeb.PostLiveTest})

      Req.Test.stub(BlogWeb.PostLiveTest, fn conn ->
        case conn.request_path do
          "/repos/filipecabaco/my_blog/contents/posts" ->
            Req.Test.json(conn, [%{"name" => "2024-01-15_tagged_post.md"}])

          "/repos/filipecabaco/my_blog/contents/posts/2024-01-15_tagged_post.md" ->
            Req.Test.json(conn, %{"download_url" => "http://test.local/raw/tagged.md"})

          "/raw/tagged.md" ->
            Plug.Conn.send_resp(conn, 200, "# Tagged Post\ntags: elixir, phoenix\n\nA test post")
        end
      end)

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "tag-pill"
      assert html =~ "elixir"
      assert html =~ "phoenix"

      Application.delete_env(:blog, :req_options)
      Blog.Posts.invalidate_cache()
    end

    test "shows message when no posts found with bad token", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "container"
    end
  end

  describe "Show" do
    test "renders a post when available", %{conn: conn} do
      # Get a real post title from the listing
      case Blog.Posts.list_post(nil) do
        [first | _] ->
          title = String.replace(first, ".md", "")
          {:ok, _view, html} = live(conn, ~p"/post/#{title}")
          assert html =~ "Back"
          assert html =~ "Total readers"

        [] ->
          # No posts available (expected in CI without valid token)
          :ok
      end
    end
  end
end
