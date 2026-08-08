# Making my blog

For years I've wanted to write down and share what I'm coding but always postponed it. That time has ended! It's time for me to try and be more proactive and share some of my discoveries, weirdnesses and joys of coding.

In this post I'm going to do a quick dive on my approach to build this blog and detail some of the things I found out along the way.

Do not forget that all of the code from this post and others is in this [repository](https://github.com/filipecabaco/my_blog)

### Starting the project

As every person thinking about building their blog, we need to always rewrite and reinvent the whell 😅. So, to comply with that tradition, I've opted to use my framework of choice for the last couple of years: [Phoenix](https://www.phoenixframework.org/).

I will create my project with LiveView (`--live`) and no database (`--no-ecto`):
```
mix phx.new --live --no-ecto blog
```

### No Database, no problem

And why no database? Because I wanted to keep it simple on the deployment side and most of the content will be a static asset. As such I chosen to just have Github store my posts. So, to list all posts I just list them from the API and then fetch them with [Req](https://hex.pm/packages/req) and finally use [Earmark](https://hex.pm/packages/earmark) to parse them into HTML

```
defmodule Blog.Posts do
  @url "https://api.github.com/repos/filipecabaco/my_blog/contents/posts"

  def list_post, do: Req.get!(@url).body |> Enum.map(& &1["name"])

  def get_post!(title),
    do:
      Req.get!("#{@url}/#{title}.md")
      |> then(& &1.body["download_url"])
      |> Req.get!()
      |> then(&Earmark.as_html!(&1.body))
end
```

### Listing Posts
On a normal blog you would expect to be able to see the posts available, so I need to assign the filenames into the view:

![Title of the post with snake_case and the extension .md](/images/img1.png)

This isn't the most friendly name... So lets clean it up with some code where I list the posts, remove the file extension and then send to the template two pieces of information, the title so we can build the link properly and a more readable post name:

```
Posts.list_post()
|> Enum.map(&String.replace(&1, ".md", ""))
|> Enum.map(&%{title: &1, label: Phoenix.Naming.humanize(&1)})
```

[`humanize/1`](https://hexdocs.pm/phoenix/Phoenix.Naming.html) is a great function to do some quick magic and available out of the box! Check other functions that could be useful at [Phoenix.Naming](https://hexdocs.pm/phoenix/Phoenix.Naming.html) module.

And here's the result!

![Title of the post all clean](/images/img2.png)

### Showing a Post

Finally I just need a quick way of receiving the parsed HTML and post it into my view. First instinct was to just send it with `<%= @post %>` but...
![Image showing HTML raw content not properly rendered](/images/img3.png)

This doesn't look quite right... Fortunately there's a method that can help us with that! [`raw/1`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.html#raw/1) Can help you with this where it will properly render the HTML on the template:
```
<%= raw @post %>
```

Leading us to the final result
![Image showing the post properly rendered](/images/img4.png)

And that is it! Not adding more bells and whistles (for now) and found out a couple of really cool methods from Phoenix!

## Conclusion

* Even building a blog with static content can be a cool journey of discovery
* `Req` is impressively easy to work with and really good for quickly doing calls
* `Phoenix.Naming` has some cool trick in it!
* `raw/1` could be used to dynamically load HTML content into your views
