defmodule Blog.FeedTest do
  use ExUnit.Case, async: false

  alias Blog.Feed

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
    Application.put_env(:blog, :req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:blog, :req_options)
      Blog.Posts.invalidate_cache()
    end)
  end

  defp stub_posts(posts) do
    Req.Test.stub(__MODULE__, fn conn ->
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
  end

  describe "build/0" do
    test "returns valid Atom XML with xmlns" do
      stub_posts([{"2024-01-15_test_post", @post_content}])

      xml = Feed.build()

      assert xml =~ "<?xml"
      assert xml =~ ~s(<feed xmlns="http://www.w3.org/2005/Atom">)
    end

    test "includes feed header with title, subtitle, links, id, and author" do
      stub_posts([{"2024-01-15_test_post", @post_content}])

      xml = Feed.build()

      assert xml =~ "<title>Filipe Cabaco Blog</title>"
      assert xml =~ "<subtitle>My improvised adventures with Elixir and other languages</subtitle>"
      assert xml =~ ~s(href="https://filipecabaco.com/atom")
      assert xml =~ ~s(rel="self")
      assert xml =~ ~s(href="https://filipecabaco.com")
      assert xml =~ "<id>filipecabaco.com</id>"
      assert xml =~ "<name>Filipe Cabaco</name>"
    end

    test "feed updated date uses the latest entry date" do
      stub_posts([
        {"2023-06-01_older_post", @post_content},
        {"2024-03-20_newer_post", @second_post_content}
      ])

      xml = Feed.build()

      assert xml =~ "<updated>2024-03-20T00:00:00Z</updated>"
    end

    test "generates entry with id, title, updated, summary, link, and image" do
      stub_posts([{"2024-01-15_test_post", @post_content}])

      xml = Feed.build()

      assert xml =~ "<entry>"
      assert xml =~ "<id>https://filipecabaco.com/post/2024-01-15_test_post</id>"
      assert xml =~ "<title>Test Post Title</title>"
      assert xml =~ "<updated>2024-01-15T00:00:00Z</updated>"
      assert xml =~ ~s(<summary type="text">This is the post description paragraph.</summary>)
      assert xml =~ ~s(href="https://filipecabaco.com/post/2024-01-15_test_post")
      assert xml =~ ~s(href="https://filipecabaco.com/images/posts/2024-01-15_test_post.png")
      assert xml =~ ~s(rel="enclosure")
      assert xml =~ ~s(type="image/png")
    end

    test "includes category elements for tags" do
      stub_posts([{"2024-01-15_test_post", @post_content}])

      xml = Feed.build()

      assert xml =~ ~s(<category term="elixir")
      assert xml =~ ~s(<category term="phoenix")
    end

    test "skips entries without a parseable date in the filename" do
      stub_posts([{"no_date_post", @post_content}])

      xml = Feed.build()

      refute xml =~ "<entry>"
      assert xml =~ "<title>Filipe Cabaco Blog</title>"
    end

    test "produces entries in correct order" do
      stub_posts([
        {"2024-03-20_newer_post", @second_post_content},
        {"2023-06-01_older_post", @post_content}
      ])

      xml = Feed.build()

      newer_pos = :binary.match(xml, "2024-03-20_newer_post") |> elem(0)
      older_pos = :binary.match(xml, "2023-06-01_older_post") |> elem(0)
      assert newer_pos < older_pos
    end

    test "header elements appear before entries" do
      stub_posts([{"2024-01-15_test_post", @post_content}])

      xml = Feed.build()

      title_pos = :binary.match(xml, "<title>Filipe Cabaco Blog</title>") |> elem(0)
      entry_pos = :binary.match(xml, "<entry>") |> elem(0)
      assert title_pos < entry_pos
    end

    test "returns valid feed with no posts" do
      stub_posts([])

      xml = Feed.build()

      assert xml =~ "<feed"
      assert xml =~ "<title>Filipe Cabaco Blog</title>"
      refute xml =~ "<entry>"
    end
  end
end
