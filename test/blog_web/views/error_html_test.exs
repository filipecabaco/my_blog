defmodule BlogWeb.ErrorHTMLTest do
  use BlogWeb.ConnCase, async: true

  test "renders 404 page", %{conn: conn} do
    conn = get(conn, "/nonexistent-route")

    assert conn.status == 404
    assert conn.resp_body =~ "Not Found"
  end

  test "renders 500 template" do
    assert BlogWeb.ErrorHTML.render("500.html", %{}) == "Internal Server Error"
  end

  test "renders 404 template" do
    assert BlogWeb.ErrorHTML.render("404.html", %{}) == "Not Found"
  end
end
