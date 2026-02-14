defmodule BlogWeb.PRImageController do
  use Phoenix.Controller, formats: []

  import Plug.Conn

  alias Blog.Posts

  def show(conn, %{"pr" => pr, "path" => path}) do
    image_path = Enum.join(path, "/")

    with {:ok, branch} <- Posts.pr_branch(pr),
         {:ok, body} <- fetch_image(branch, image_path) do
      content_type = MIME.from_path(image_path)

      conn
      |> put_resp_content_type(content_type)
      |> send_resp(200, body)
    else
      _ ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Not found")
    end
  end

  defp fetch_image(branch, path) do
    url = "https://raw.githubusercontent.com/filipecabaco/my_blog/#{branch}/priv/static/images/#{path}"

    opts =
      [url: url]
      |> Keyword.merge(Application.get_env(:blog, :req_options, []))

    case Req.get(Req.new(opts)) do
      {:ok, %{status: 200, body: body}} when is_binary(body) -> {:ok, body}
      _ -> {:error, :not_found}
    end
  end
end
