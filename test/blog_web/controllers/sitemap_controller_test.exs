defmodule BlogWeb.SitemapControllerTest do
  use BlogWeb.ConnCase, async: false

  @moduletag capture_log: true

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
          Plug.Conn.send_resp(conn, 200, "# Test Post\ntags: elixir\n\nA test post")
      end
    end)

    Req.Test.allow(Blog.Posts, self(), Process.whereis(Blog.Posts))
    Blog.Posts.refresh()

    on_exit(fn ->
      Application.delete_env(:blog, :req_options)
      Blog.Posts.invalidate_cache()
    end)
  end

  test "returns XML with correct content type", %{conn: conn} do
    conn = get(conn, "/sitemap.xml")

    assert response_content_type(conn, :xml) =~ "application/xml"
    body = response(conn, 200)
    assert body =~ "<?xml"
    assert body =~ "<urlset"
  end

  test "includes homepage URL", %{conn: conn} do
    conn = get(conn, "/sitemap.xml")
    body = response(conn, 200)

    assert body =~ "<loc>https://filipecabaco.com</loc>"
  end

  test "includes post entries", %{conn: conn} do
    conn = get(conn, "/sitemap.xml")
    body = response(conn, 200)

    assert body =~ "2024-01-15_test_post"
    assert body =~ "<lastmod>2024-01-15</lastmod>"
  end
end
