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

  defp stub_github(titles, post_contents \\ %{}) do
    Req.Test.stub(Blog.Posts, fn conn ->
      case conn.request_path do
        "/repos/filipecabaco/my_blog/contents/posts" ->
          Req.Test.json(conn, Enum.map(titles, &%{"name" => &1}))

        "/repos/filipecabaco/my_blog/contents/posts/" <> filename ->
          title = String.replace(filename, ".md", "")

          if Map.has_key?(post_contents, title) do
            Req.Test.json(conn, %{
              "download_url" => "http://test.local/raw/#{filename}"
            })
          else
            Req.Test.json(conn, %{"message" => "Not Found"})
          end

        "/raw/" <> filename ->
          title = String.replace(filename, ".md", "")
          Plug.Conn.send_resp(conn, 200, Map.get(post_contents, title, ""))

        _ ->
          Req.Test.json(conn, %{"message" => "Not Found"})
      end
    end)

    Req.Test.allow(Blog.Posts, self(), Process.whereis(Blog.Posts))
  end

  describe "refresh/0" do
    test "fetches and caches titles and posts from GitHub API" do
      stub_github(
        ["2024-01-15_hello_world.md", "2024-01-10_another_post.md"],
        %{"2024-01-15_hello_world" => "# Hello World\n\nFirst post", "2024-01-10_another_post" => "# Another\n\nSecond"}
      )

      Posts.refresh()

      assert Posts.list_post(nil) == ["2024-01-15_hello_world.md", "2024-01-10_another_post.md"]
      assert Posts.get_post("2024-01-15_hello_world") == "# Hello World\n\nFirst post"
      assert Posts.get_post("2024-01-10_another_post") == "# Another\n\nSecond"
    end

    test "handles GitHub API authentication failure gracefully" do
      Req.Test.stub(Blog.Posts, fn conn ->
        Req.Test.json(conn, %{"message" => "Bad credentials", "status" => 401})
      end)

      Req.Test.allow(Blog.Posts, self(), Process.whereis(Blog.Posts))
      Posts.refresh()

      assert Posts.list_post(nil) == []
    end
  end

  describe "list_post/1" do
    test "returns cached titles after refresh" do
      stub_github(["2024-01-15_cached.md"])
      Posts.refresh()

      assert Posts.list_post(nil) == ["2024-01-15_cached.md"]
    end

    test "returns empty list on empty cache" do
      assert Posts.list_post(nil) == []
    end

    test "does not make HTTP calls on cache hit" do
      call_count = :counters.new(1, [:atomics])

      Req.Test.stub(Blog.Posts, fn conn ->
        :counters.add(call_count, 1, 1)

        case conn.request_path do
          "/repos/filipecabaco/my_blog/contents/posts" ->
            Req.Test.json(conn, [%{"name" => "2024-01-15_cached.md"}])

          _ ->
            Req.Test.json(conn, %{"message" => "Not Found"})
        end
      end)

      Req.Test.allow(Blog.Posts, self(), Process.whereis(Blog.Posts))
      Posts.refresh()
      count_after_refresh = :counters.get(call_count, 1)

      assert Posts.list_post(nil) == ["2024-01-15_cached.md"]
      assert Posts.list_post(nil) == ["2024-01-15_cached.md"]

      assert :counters.get(call_count, 1) == count_after_refresh
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
    test "returns cached post content after refresh" do
      stub_github(
        ["2024-01-15_hello.md"],
        %{"2024-01-15_hello" => "# Hello World\n\nThis is my post"}
      )

      Posts.refresh()

      assert Posts.get_post("2024-01-15_hello") == "# Hello World\n\nThis is my post"
    end

    test "returns error on empty cache" do
      assert Posts.get_post("nonexistent") == {:error, "not yet loaded"}
    end

    test "does not cache error responses during refresh" do
      stub_github(["2024-01-15_missing.md"])

      Posts.refresh()

      assert Posts.get_post("2024-01-15_missing") == {:error, "not yet loaded"}
    end

    test "fetches from specific branch without caching" do
      Req.Test.stub(Blog.Posts, fn conn ->
        case conn.request_path do
          "/repos/filipecabaco/my_blog/contents/posts/branch_post.md" ->
            Req.Test.json(conn, %{
              "download_url" => "http://test.local/raw/branch_post.md"
            })

          "/raw/branch_post.md" ->
            Plug.Conn.send_resp(conn, 200, "# Branch Post\n\nContent")
        end
      end)

      assert Posts.get_post("branch_post", "feature-branch") == "# Branch Post\n\nContent"
    end
  end
end
