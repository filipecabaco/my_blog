defmodule Blog.Feed do
  alias Blog.Posts

  def build() do
    entries = Enum.map(Posts.list_post(nil), &prepare_entry/1)

    feed = [{:feed, %{}, header() ++ entries}]

    feed
    |> Enum.reduce([], &build_entity/2)
    |> :xmerl.export_simple(:xmerl_xml)
    |> List.flatten()
    |> to_string()
  end

  defp build_entity({tag, attributes, content}, acc) when is_list(content),
    do: [{tag, prepare_attributes(attributes), Enum.reduce(content, [], &build_entity/2)}] ++ acc

  defp build_entity({tag, attributes, nil}, acc), do: acc ++ [{tag, prepare_attributes(attributes), ['']}]

  defp build_entity({tag, attributes, content}, acc),
    do: acc ++ [{tag, prepare_attributes(attributes), [to_charlist(content)]}]

  defp prepare_attributes(attributes), do: Enum.map(attributes, fn {k, v} -> {k, to_charlist(v)} end)

  defp header() do
    [
      {:title, %{}, "Filipe Cabaco Blog"},
      {:subtitle, %{}, "My improvised adventures with Elixir and other languages"},
      {:link, %{href: "https://filipecabaco.com/atom", rel: "self"}, nil},
      {:link, %{href: "https://filipecabaco.com"}, nil},
      {:id, %{}, "filipecabaco.com"},
      {:updated, %{}, DateTime.new!(~D[2022-07-30], ~T[00:00:00]) |> DateTime.to_iso8601()},
      {:author, %{}, [{:name, %{}, "Filipe Cabaco"}]}
    ]
  end

  defp prepare_entry(name) do
    name = String.replace(name, ".md", "")
    post = Posts.get_post(name, nil)
    description = Posts.description(post)
    title = Posts.title(post)
    link = "https://filipecabaco.com/post/#{name}"

    date =
      name
      |> then(&Regex.run(~r/(\d{4}-\d{2}-\d{2})/, &1))
      |> Enum.at(1)
      |> then(&Date.from_iso8601!(&1))
      |> then(&DateTime.new!(&1, ~T[00:00:00]))
      |> then(&DateTime.to_iso8601/1)

    {:entry, %{},
     [
       {:id, %{}, link},
       {:title, %{}, title},
       {:updated, %{}, date},
       {:content, %{}, description},
       {:link, %{href: link}, nil}
     ]}
  end
end
