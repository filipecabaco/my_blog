defmodule Blog.Feed do
  require Logger
  alias Blog.Posts

  def build do
    Posts.list_post(nil)
    |> Enum.map(&prepare_entry/1)
    |> Enum.reject(&is_nil/1)
    |> then(fn entries ->
      [{:feed, %{xmlns: "http://www.w3.org/2005/Atom"}, header(entries) ++ entries}]
      |> Enum.reduce([], &build_entity/2)
      |> :xmerl.export_simple(:xmerl_xml)
      |> List.flatten()
      |> to_string()
    end)
  end

  defp build_entity({tag, attributes, content}, acc) when is_list(content),
    do: acc ++ [{tag, prepare_attributes(attributes), Enum.reduce(content, [], &build_entity/2)}]

  defp build_entity({tag, attributes, nil}, acc),
    do: acc ++ [{tag, prepare_attributes(attributes), ~c""}]

  defp build_entity({tag, attributes, content}, acc),
    do: acc ++ [{tag, prepare_attributes(attributes), [to_charlist(content)]}]

  defp prepare_attributes(attributes),
    do: Enum.map(attributes, fn {k, v} -> {k, to_charlist(v)} end)

  defp header(entries) do
    latest_date = latest_updated(entries)

    [
      {:title, %{}, "Filipe Cabaco Blog"},
      {:subtitle, %{}, "My improvised adventures with Elixir and other languages"},
      {:link, %{href: "https://filipecabaco.com/atom", rel: "self"}, nil},
      {:link, %{href: "https://filipecabaco.com"}, nil},
      {:id, %{}, "filipecabaco.com"},
      {:updated, %{}, latest_date},
      {:author, %{}, [{:name, %{}, "Filipe Cabaco"}]}
    ]
  end

  defp latest_updated(entries) do
    entries
    |> Enum.flat_map(fn {:entry, _, children} ->
      Enum.flat_map(children, fn
        {:updated, _, date} when is_binary(date) -> [date]
        _ -> []
      end)
    end)
    |> Enum.max(fn -> DateTime.utc_now() |> DateTime.to_iso8601() end)
  end

  defp prepare_entry(name) do
    name = String.replace(name, ".md", "")

    with post when is_binary(post) <- Posts.get_post(name, nil),
         date when not is_nil(date) <- parse_date(name) do
      description = Posts.description(post)
      title = Posts.title(post)
      link = "https://filipecabaco.com/post/#{name}"

      tags = Posts.tags(post)
      categories = Enum.map(tags, fn tag -> {:category, %{term: tag}, nil} end)

      image = "https://filipecabaco.com/images/posts/#{name}.png"

      {:entry, %{},
       [
         {:id, %{}, link},
         {:title, %{}, title},
         {:updated, %{}, date},
         {:summary, %{type: "text"}, description},
         {:link, %{href: link}, nil},
         {:link, %{href: image, rel: "enclosure", type: "image/png"}, nil}
       ] ++ categories}
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
