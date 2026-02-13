defmodule Blog.PostsIntegrationTest do
  use ExUnit.Case, async: false

  alias Blog.Posts

  @moduletag capture_log: true

  setup do
    Posts.invalidate_cache()
    Application.put_env(:blog, :req_options, plug: {Req.Test, Blog.Posts})

    on_exit(fn ->
      Application.delete_env(:blog, :req_options)
      Posts.invalidate_cache()
    end)

    :ok
  end

  describe "list_post/1" do
    test "fetches and caches post titles from GitHub API" do
      Req.Test.stub(Blog.Posts, fn conn ->
        assert conn.request_path == "/repos/filipecabaco/my_blog/contents/posts"

        Req.Test.json(conn, [
          %{"name" => "2024-01-15_hello_world.md"},
          %{"name" => "2024-01-10_another_post.md"}
        ])
      end)

      titles = Posts.list_post(nil)
      assert titles == ["2024-01-15_hello_world.md", "2024-01-10_another_post.md"]
    end

    test "returns cached titles on subsequent calls" do
      call_count = :counters.new(1, [:atomics])

      Req.Test.stub(Blog.Posts, fn conn ->
        :counters.add(call_count, 1, 1)

        Req.Test.json(conn, [
          %{"name" => "2024-01-15_cached.md"}
        ])
      end)

      assert Posts.list_post(nil) == ["2024-01-15_cached.md"]
      assert Posts.list_post(nil) == ["2024-01-15_cached.md"]
      assert :counters.get(call_count, 1) == 1
    end

    test "returns empty list on authentication failure" do
      Req.Test.stub(Blog.Posts, fn conn ->
        Req.Test.json(conn, %{"message" => "Bad credentials", "status" => 401})
      end)

      assert Posts.list_post(nil) == []
    end

    test "fetches from specific branch without caching" do
      call_count = :counters.new(1, [:atomics])

      Req.Test.stub(Blog.Posts, fn conn ->
        :counters.add(call_count, 1, 1)
        Req.Test.json(conn, [%{"name" => "2024-01-20_draft.md"}])
      end)

      assert Posts.list_post("feature-branch") == ["2024-01-20_draft.md"]
      assert Posts.list_post("feature-branch") == ["2024-01-20_draft.md"]
      assert :counters.get(call_count, 1) == 2
    end
  end

  describe "get_post/2" do
    test "fetches post content through download_url" do
      Req.Test.stub(Blog.Posts, fn conn ->
        case conn.request_path do
          "/repos/filipecabaco/my_blog/contents/posts/2024-01-15_hello.md" ->
            Req.Test.json(conn, %{
              "download_url" => "http://test.local/raw/hello.md"
            })

          "/raw/hello.md" ->
            Plug.Conn.send_resp(conn, 200, "# Hello World\n\nThis is my post")
        end
      end)

      assert Posts.get_post("2024-01-15_hello") == "# Hello World\n\nThis is my post"
    end

    test "returns error on missing post" do
      Req.Test.stub(Blog.Posts, fn conn ->
        Req.Test.json(conn, %{"message" => "Not Found"})
      end)

      assert Posts.get_post("nonexistent") == {:error, "Not Found"}
    end

    test "caches successful post fetches" do
      call_count = :counters.new(1, [:atomics])

      Req.Test.stub(Blog.Posts, fn conn ->
        :counters.add(call_count, 1, 1)

        case conn.request_path do
          "/repos/filipecabaco/my_blog/contents/posts/cached_post.md" ->
            Req.Test.json(conn, %{
              "download_url" => "http://test.local/raw/cached.md"
            })

          "/raw/cached.md" ->
            Plug.Conn.send_resp(conn, 200, "# Cached\n\nContent")
        end
      end)

      assert Posts.get_post("cached_post") == "# Cached\n\nContent"
      assert Posts.get_post("cached_post") == "# Cached\n\nContent"
      assert :counters.get(call_count, 1) == 2
    end

    test "does not cache error responses" do
      call_count = :counters.new(1, [:atomics])

      Req.Test.stub(Blog.Posts, fn conn ->
        :counters.add(call_count, 1, 1)
        Req.Test.json(conn, %{"message" => "Not Found"})
      end)

      assert Posts.get_post("missing") == {:error, "Not Found"}
      assert Posts.get_post("missing") == {:error, "Not Found"}
      assert :counters.get(call_count, 1) == 2
    end
  end
end
