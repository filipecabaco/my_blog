defmodule Blog.Sitemap do
  alias Blog.Posts

  @base_url "https://filipecabaco.com"

  def build do
    posts =
      Posts.list_post(nil)
      |> Enum.map(fn name ->
        name = String.replace(name, ".md", "")
        date = parse_date(name)
        {name, date}
      end)
      |> Enum.reject(fn {_, date} -> is_nil(date) end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <url>
        <loc>#{@base_url}</loc>
        <changefreq>weekly</changefreq>
        <priority>1.0</priority>
      </url>
    #{Enum.map_join(posts, "\n", &post_entry/1)}
    </urlset>
    """
    |> String.trim()
  end

  defp post_entry({name, date}) do
    """
      <url>
        <loc>#{@base_url}/post/#{name}</loc>
        <lastmod>#{date}</lastmod>
        <changefreq>yearly</changefreq>
        <priority>0.8</priority>
      </url>\
    """
  end

  defp parse_date(name) do
    case Regex.run(~r/^(\d{4}-\d{2}-\d{2})/, name) do
      [_, date] -> date
      nil -> nil
    end
  end
end
