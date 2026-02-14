defmodule BlogWeb.SitemapController do
  use Phoenix.Controller, formats: []

  import Plug.Conn

  alias Blog.Sitemap

  def index(conn, _) do
    conn
    |> put_resp_content_type("application/xml")
    |> text(Sitemap.build())
  end
end
