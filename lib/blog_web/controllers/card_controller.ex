defmodule BlogWeb.CardController do
  use BlogWeb, :controller

  alias Blog.Card
  alias Blog.Posts

  def root(conn, _params) do
    post = %{
      title: "Notes on the BEAM and real-time systems",
      date: "",
      reading_time: nil
    }

    deliver(conn, "filipecabaco.com", post)
  end

  def show(conn, %{"slug" => slug} = params) do
    slug = String.replace_suffix(slug, ".png", "")
    branch = params |> Map.get("pr") |> branch()

    case Posts.get_post(slug, branch) do
      content when is_binary(content) ->
        post = %{
          title: Posts.display_title(slug, content),
          date: Posts.date(slug),
          reading_time: Posts.reading_time(content)
        }

        deliver(conn, slug, post)

      _ ->
        send_resp(conn, 404, "")
    end
  end

  defp branch(nil), do: nil

  defp branch(pr) do
    case Posts.pr_branch(pr) do
      {:ok, branch} -> branch
      {:error, _} -> nil
    end
  end

  defp deliver(conn, slug, post) do
    case Card.png(slug, post) do
      {:ok, png, revision} ->
        conn
        |> put_resp_content_type("image/png")
        |> put_resp_header("cache-control", "public, max-age=3600")
        |> put_resp_header("etag", ~s("#{revision}"))
        |> send_resp(200, png)

      {:error, _reason} ->
        send_resp(conn, 500, "")
    end
  end
end
