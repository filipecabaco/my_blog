defmodule Blog.FeedTest do
  use ExUnit.Case, async: true

  alias Blog.Feed

  describe "build/0" do
    test "returns valid XML string" do
      xml = Feed.build()
      assert is_binary(xml)
      assert xml =~ "<?xml"
      assert xml =~ "<feed"
      assert xml =~ "Filipe Cabaco Blog"
    end

    test "includes feed metadata" do
      xml = Feed.build()
      assert xml =~ "<title>Filipe Cabaco Blog</title>"
      assert xml =~ "<subtitle>"
      assert xml =~ "filipecabaco.com"
    end
  end
end
