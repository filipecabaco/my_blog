defmodule Blog.Feed do
  require Logger
  alias Blog.Posts

  def build do
    Posts.list_post(nil)
    |> Enum.map(&prepare_entry/1)
    |> Enum.reject(&is_nil/1)
    |> then(fn entries ->
      [{:feed, %{}, header() ++ entries}]
      |> Enum.reduce([], &build_entity/2)
      |> :xmerl.export_simple(:xmerl_xml)
      |> List.flatten()
      |> to_string()
    end)
  end

  defp build_entity({tag, attributes, content}, acc) when is_list(content),
    do: [{tag, prepare_attributes(attributes), Enum.reduce(content, [], &build_entity/2)}] ++ acc

  defp build_entity({tag, attributes, nil}, acc),
    do: acc ++ [{tag, prepare_attributes(attributes), ~c""}]

  defp build_entity({tag, attributes, content}, acc),
    do: acc ++ [{tag, prepare_attributes(attributes), [to_charlist(content)]}]

  defp prepare_attributes(attributes),
    do: Enum.map(attributes, fn {k, v} -> {k, to_charlist(v)} end)

  defp header do
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

    with post when is_binary(post) <- Posts.get_post(name, nil),
         date when not is_nil(date) <- parse_date(name) do
      description = Posts.description(post)
      title = Posts.title(post)
      link = "https://filipecabaco.com/post/#{name}"

      {:entry, %{},
       [
         {:id, %{}, link},
         {:title, %{}, title},
         {:updated, %{}, date},
         {:content, %{}, description},
         {:link, %{href: link}, nil}
       ]}
    else
      {:error, reason} ->
        Logger.warning("Skipping feed entry for #{name}: #{reason}")
        nil

      nil ->
        Logger.warning("Skipping feed entry for #{name}: could not parse date")
        nil
    end
  end

  defp parse_date(name) do
    case Regex.run(~r/(\d{4}-\d{2}-\d{2})/, name) do
      [_, date_string] ->
        date_string
        |> Date.from_iso8601!()
        |> DateTime.new!(~T[00:00:00])
        |> DateTime.to_iso8601()

      nil ->
        nil
    end
  end
end
