# Atom feeding and xmerl

Any good blog needs to support some sort of feed standard so we will build our own using a neat moodule from Erlang called xmerl. We will learn a bit about Erlang interoperability and also see how we can create XML content without adding extra dependencies to our code.

Do not forget that all of the code from this post and others is in this [repository](https://github.com/filipecabaco/my_blog).

## Atoms for XML

Atom feed is a really common web standard on how you can share a news feed in a way platforms understand them and consume them. Both Atom and RSS are the de facto ways of doing that but we're opting with Atom since it's the newer version. Both of them share one technical detail that will make a lot of developers shiver in fear: they use XML (queue evil laugh).

Fortunately, in the land of the OTP, this isn't scary! In true OTP fashion and due to the battle tested nature of Erlang, this is a solved problem that we can take advantage of in Elixir! This beautiful module is called [`xmerl`](https://www.erlang.org/doc/man/xmerl.html).

### Atom content

First lets define our content. This is an example of some Atom content taken from [w3c](https://validator.w3.org/feed/docs/atom.html):

```xml
<?xml version="1.0" encoding="utf-8" ?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Example Feed</title>
  <link href="http://example.org/" />
  <updated>2003-12-13T18:30:02Z</updated>
  <author>
    <name>John Doe</name>
  </author>
  <id>urn:uuid:60a76c80-d399-11d9-b93C-0003939e0af6</id>

  <entry>
    <title>Atom-Powered Robots Run Amok</title>
    <link href="http://example.org/2003/12/13/atom03" />
    <id>urn:uuid:1225c695-cfb8-4ebb-aaaa-80da344efa6a</id>
    <updated>2003-12-13T18:30:02Z</updated>
    <summary>Some text.</summary>
  </entry>

</feed>
```

So our job know is to transform this into a Elixir structure where we represent the tag name, attribute and content in a sequencial manner. To do so we will use nested lists of three element tuples so we can capture the hierarchy and all the information required:

```elixir
content = [
      {:feed, [{:title, "Example feed", %{}}], %{xmlns: "http://www.w3.org/2005/Atom"}}
    ]
```

On the first element of the tuple we have the tag, second element the tag attributes and finally the content that can be a string or another list of content to be processed.

We can build this by steps per post automatically where we start with a "set in stone" header and then build each entry seperatly. For our header we will have the following information:

```elixir
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
```

After that we can tackle each element individually where we will run all posts, extract relevant information and get it into the proposed format:

```elixir
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
```

👍
So now we have a big nested list with all our content organized into our proposed structure ready to be consumed by xmerl... or is it?

### Erlang interoperability showing up

One of the biggest differences between Erlang and Elixir are Strings. Strings in Elixir are UTF-8 encoded and you can do a lot of cool stuff with that fact but this is not the case with Erlang... Erlang module commonly use charlists which is a list of integer that then can then be represented as a string but this has consequences due to the enconding differences:

```elixir
iex(1)> IO.inspect("👍", binaries: :as_binaries)
<<240, 159, 145, 141>>
"👍"
```

As you can see, an emoji is actually a list of 4 integer values that are "hidden" by the UTF-8 enconding native to Elixir. This difference is really important to Erlang and Elixir interoperability and actually presents an issues to our current problem! If we were to use a String in xmerl we would see the following error:

```elixir
** (FunctionClauseError) no function clause matching in :xmerl_lib.expand_element/4

    The following arguments were given to :xmerl_lib.expand_element/4:

        # 1
        "https://filipecabaco.com/post/2022-07-16_making_my_blog"

        # 2
        1

        # 3
        [id: 1, entry: 1, feed: 1]

        # 4
        false
```

How do we fix this? Elixir shows again some great standard library development where it actually provides you with a simple function called (`to_charlist/1`)[https://hexdocs.pm/elixir/Kernel.html#to_charlist/1] which transforms all our UTF-8 Elixir strings into Erlang charlists:

```elixir
iex(2)> to_charlist("👍")
[128077]
```

Please do check the official Elixir lang page to know more about [Binaries, strings, and charlists
](https://elixir-lang.org/getting-started/binaries-strings-and-char-lists.html)

With this new found knowledge we can easily interop with our Erlang module:

```elixir
iex(3)> :xmerl.export_simple([{:potato,[{:a, 'a'}], []}], :xmerl_xml)
['<?xml version="1.0"?>', [['<', 'potato', [[' ', 'a', '="', 'a', '"']], '/>']]]
```

As you can see, this last string looks "weird" because xmerl is actually returning an nested list of strings so we need to flatten it... Which again is easy with Elixir and our powerful standard library for List manipulation and the function [`List.flatten/1`](https://hexdocs.pm/elixir/List.html#flatten/1)

```elixir
iex(4)> List.flatten(:xmerl.export_simple([{:potato,[{:a, 'a'}], []}], :xmerl_xml))
'<?xml version="1.0"?><potato a="a"/>'
```

### Make it all work

So now we have a basic structure that represents our feed elements and we understand Erlang interoperability to build our XML file... So we need to mix all of it!

```elixir
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

```

Lets check each step:

1. We build each entries and header into our format
2. Reduce every element using build_entity which:
   1. If the content is a list, reduce using build_entity/2 again and add to the accumulator
   2. If content is not a list, convert the String into a Charlist and add to the accumulator
   3. In all scenarios, transform our map into a list of tuples with the proper transformation of the value into a Charlist
3. Export it using `:xmerl` that then will use `xmerl_xml` module to build the content
4. Flatten the nested list into a single charlist
5. Convert from a Charlist into a String

Please do note the awesome guard `is_list/1`! Elixir has a lot of useful guards that can be used to really go into our pattern matching powers. Check more of them in the [Guards](https://hexdocs.pm/elixir/patterns-and-guards.html#guards) section in the official docs.

And we're done! We have a simple way of converting an Elixir structure into XML content without a single external dependency.

We end up with the following XML:

```xml
iex(7)> IO.puts(Blog.Feed.build())
<?xml version="1.0"?>
<feed>
    <author>
      <name>Filipe Cabaco</name>
    </author>
    <title>Filipe Cabaco Blog</title>
    <subtitle>My improvised adventures with Elixir and other languages</subtitle>
    <link href="https://filipecabaco.com/atom" rel="self"></link>
    <link href="https://filipecabaco.com"></link>
    <id>filipecabaco.com</id>
    <updated>2022-07-30T00:00:00Z</updated>
    <entry>
      <id>https://filipecabaco.com/post/2022-07-16_making_my_blog</id>
      <title>Making my blog</title>
      <updated>2022-07-16T00:00:00Z</updated>
      <content>For years I've wanted to write down and share what I'm coding but always postponed it. That time has ended! It's time for me to try and be more proactive and share some of my discoveries, weirdnesses and joys of coding.
      </content>
    </entry>
</feed>
```

So we only need to expose it in a new controller (`lib/blog_web/controllers/feed_controller.ex`) that will return the XML body and set it in our router (`lib/blog_web/router.ex`):

```elixir
defmodule BlogWeb.FeedController do
  use BlogWeb, :controller
  alias Blog.Feed

  def index(conn, _) do
    conn
    |> put_resp_content_type("application/atom+xml")
    |> text(Feed.build())
  end
end
```

```elixir
defmodule BlogWeb.Router do
  # ...
  scope "/", BlogWeb do
    pipe_through(:browser)
    #...
    get("/atom", FeedController, :index)
    #...
  end
#...
end
```

Ending up with our XML feed as expected
![Image showing XML content to be sent to the feed](/images/img8.png)

### Warnings holding us back

During this we will try to use xmerl but you will find the following warning:

```elixir
:xmerl.export_simple/2 defined in application :xmerl is used by the current application but the current application does not depend on :xmerl. To fix this, you must do one of:

  1. If :xmerl is part of Erlang/Elixir, you must include it under :extra_applications inside "def application" in your mix.exs

  2. If :xmerl is a dependency, make sure it is listed under "def deps" in your mix.exs

  3. In case you don't want to add a requirement to :xmerl, you may optionally skip this warning by adding [xref: [exclude: [:xmerl]]] to your "def project" in mix.exs
```

This happens because we're calling xmerl which is actually an application that our code should depend on to start properly. You can see this as an extra security to ensure we always bot up our main service with all required modules.

To fix this you only need to warn in the `mix.exs` file that we will need this as an `extra_application` as the warning tells us (check more at [mix compile.app](https://hexdocs.pm/mix/1.12/Mix.Tasks.Compile.App.html) docs):

```elixir
def application do
  [
    mod: {Blog.Application, []},
    extra_applications: [:logger, :runtime_tools, :xmerl]
  ]
end
```

## Conclusion

- Erlang OTP has a lot of tools that can be used out of the box, xmerl it's just the start!
- The Elixir language as a ton of awesome standard library functions that make our life so easy
  - Guards are insanely powerful for pattern matching
  - [Kernel](https://hexdocs.pm/elixir/Kernel.html) has a ton of functions that allow us to interoperate with Erlang easily
  - List and Enum modules are pure awesomeness 🤯
- Erlang interoperability seems tricky at first but the biggest caveat is the fact that Erlang mostly works with Charlists vs Strings so you "just" need to transform it.
