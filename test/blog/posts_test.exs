defmodule Blog.PostsTest do
  use ExUnit.Case, async: true

  alias Blog.Posts

  describe "title/1" do
    test "extracts title from markdown heading" do
      assert Posts.title("# My Great Post\n\nSome content") == "My Great Post"
    end

    test "trims whitespace from title" do
      assert Posts.title("#   Spaced Title  \n\nContent") == "Spaced Title"
    end

    test "returns empty string when no heading found" do
      assert Posts.title("No heading here") == ""
    end

    test "extracts first heading only" do
      assert Posts.title("# First\n\n## Second") == "First"
    end
  end

  describe "tags/1" do
    test "extracts comma-separated tags" do
      post = "# Title\ntags: elixir, phoenix, liveview\n\nDescription"
      assert Posts.tags(post) == ["elixir", "phoenix", "liveview"]
    end

    test "returns empty list when no tags line" do
      post = "# Title\n\nDescription"
      assert Posts.tags(post) == []
    end

    test "handles single tag" do
      post = "# Title\ntags: elixir\n\nDescription"
      assert Posts.tags(post) == ["elixir"]
    end

    test "trims whitespace around tags" do
      post = "# Title\ntags:  elixir ,  phoenix \n\nDescription"
      assert Posts.tags(post) == ["elixir", "phoenix"]
    end

    test "returns empty list for empty input" do
      assert Posts.tags("") == []
    end
  end

  describe "description/1" do
    test "extracts first paragraph after heading" do
      post = "# Title\n\nThis is the description\n\nMore content"
      assert Posts.description(post) == "This is the description"
    end

    test "extracts description when tags line is present" do
      post = "# Title\ntags: elixir, phoenix\n\nThis is the description\n\nMore"
      assert Posts.description(post) == "This is the description"
    end

    test "trims whitespace from description" do
      post = "# Title\n\n  Spaced description  \n\nMore"
      assert Posts.description(post) == "Spaced description"
    end

    test "returns empty string when no description found" do
      assert Posts.description("# Title") == ""
    end

    test "returns empty string for empty input" do
      assert Posts.description("") == ""
    end
  end

  describe "reading_time/1" do
    test "calculates reading time based on word count at 150 WPM" do
      post = String.duplicate("word ", 300)
      assert Posts.reading_time(post) == 2
    end

    test "returns minimum of 1 minute for short posts" do
      assert Posts.reading_time("short post") == 1
    end

    test "rounds up to next minute" do
      post = String.duplicate("word ", 200)
      assert Posts.reading_time(post) == 2
    end
  end

  describe "parse/1" do
    test "converts markdown to HTML" do
      html = Posts.parse("# Hello\n\nWorld")
      assert html =~ "<h1>"
      assert html =~ "Hello"
      assert html =~ "World</p>"
    end

    test "handles code blocks" do
      html = Posts.parse("```elixir\nIO.puts(\"hi\")\n```")
      assert html =~ "<code"
      assert html =~ "IO.puts"
    end

    test "handles links" do
      html = Posts.parse("[click](https://example.com)")
      assert html =~ "<a href=\"https://example.com\""
      assert html =~ "click"
    end

    test "handles empty input" do
      assert Posts.parse("") == ""
    end

    test "handles bold and italic" do
      html = Posts.parse("**bold** and *italic*")
      assert html =~ "<strong>bold</strong>"
      assert html =~ "<em>italic</em>"
    end
  end
end
