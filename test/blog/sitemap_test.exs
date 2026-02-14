defmodule Blog.SitemapTest do
  use ExUnit.Case, async: false

  alias Blog.Sitemap

  @post_content """
  # Test Post Title
  tags: elixir, phoenix

  This is the post description paragraph.
  """

  @second_post_content """
  # Another Post
  tags: backend

  Second post description.
  """

  setup do
    Blog.Posts.invalidate_cache()
    Application.put_env(:blog, :req_options, plug: {Req.Test, Blog.Posts})

    on_exit(fn ->
      Application.delete_env(:blog, :req_options)
      Blog.Posts.invalidate_cache()
    end)
  end

  defp stub_posts(posts) do
    Req.Test.stub(Blog.Posts, fn conn ->
      case conn.request_path do
        "/repos/filipecabaco/my_blog/contents/posts" ->
          entries = Enum.map(posts, fn {name, _content} -> %{"name" => "#{name}.md"} end)
          Req.Test.json(conn, entries)

        "/repos/filipecabaco/my_blog/contents/posts/" <> filename ->
          name = String.replace(filename, ".md", "")

          case List.keyfind(posts, name, 0) do
            {_, _content} ->
              Req.Test.json(conn, %{
                "download_url" => "http://test.local/raw/#{name}.md"
              })

            nil ->
              Plug.Conn.send_resp(conn, 404, "Not found")
          end

        "/raw/" <> filename ->
          name = String.replace(filename, ".md", "")

          case List.keyfind(posts, name, 0) do
            {_, content} -> Plug.Conn.send_resp(conn, 200, content)
            nil -> Plug.Conn.send_resp(conn, 404, "Not found")
          end
      end
    end)

    Req.Test.allow(Blog.Posts, self(), Process.whereis(Blog.Posts))
  end

  describe "build/0" do
    test "returns valid XML with urlset element" do
      stub_posts([{"2024-01-15_test_post", @post_content}])
      Blog.Posts.refresh()

      xml = Sitemap.build()

      assert xml =~ ~s(<?xml version="1.0" encoding="UTF-8"?>)
      assert xml =~ ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">)
      assert xml =~ "</urlset>"
    end

    test "includes homepage entry with weekly changefreq and priority 1.0" do
      stub_posts([{"2024-01-15_test_post", @post_content}])
      Blog.Posts.refresh()

      xml = Sitemap.build()

      assert xml =~ "<loc>https://filipecabaco.com</loc>"
      assert xml =~ "<changefreq>weekly</changefreq>"
      assert xml =~ "<priority>1.0</priority>"
    end

    test "includes post entries with correct URL and lastmod" do
      stub_posts([{"2024-01-15_test_post", @post_content}])
      Blog.Posts.refresh()

      xml = Sitemap.build()

      assert xml =~ "<loc>https://filipecabaco.com/post/2024-01-15_test_post</loc>"
      assert xml =~ "<lastmod>2024-01-15</lastmod>"
      assert xml =~ "<changefreq>yearly</changefreq>"
      assert xml =~ "<priority>0.8</priority>"
    end

    test "includes multiple posts" do
      stub_posts([
        {"2024-03-20_newer_post", @second_post_content},
        {"2023-06-01_older_post", @post_content}
      ])

      Blog.Posts.refresh()

      xml = Sitemap.build()

      assert xml =~ "2024-03-20_newer_post"
      assert xml =~ "2023-06-01_older_post"
      assert xml =~ "<lastmod>2024-03-20</lastmod>"
      assert xml =~ "<lastmod>2023-06-01</lastmod>"
    end

    test "skips posts without a parseable date in the filename" do
      stub_posts([{"no_date_post", @post_content}])
      Blog.Posts.refresh()

      xml = Sitemap.build()

      refute xml =~ "no_date_post"
      # Homepage should still be present
      assert xml =~ "<loc>https://filipecabaco.com</loc>"
    end

    test "returns sitemap with only homepage when no posts exist" do
      stub_posts([])
      Blog.Posts.refresh()

      xml = Sitemap.build()

      assert xml =~ "<loc>https://filipecabaco.com</loc>"
      # Only one <url> block (the homepage)
      assert length(String.split(xml, "<url>")) == 2
    end
  end
end
