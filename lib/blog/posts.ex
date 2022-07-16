defmodule Blog.Posts do
  @url "https://api.github.com/repos/filipecabaco/my_blog/contents/posts"

  def list_post, do: @url |> Req.get!() |> then(& &1.body) |> Enum.map(& &1["name"])

  def get_post!(title),
    do:
      Req.get!("#{@url}/#{title}.md")
      |> then(& &1.body["download_url"])
      |> Req.get!()
      |> then(&Earmark.as_html!(&1.body))
end
