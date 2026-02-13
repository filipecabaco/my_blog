defmodule BlogWeb.FeedController do
  use Phoenix.Controller, formats: []

  import Plug.Conn

  alias Blog.Feed

  def index(conn, _) do
    conn
    |> put_resp_content_type("application/atom+xml")
    |> text(Feed.build())
  end
end
