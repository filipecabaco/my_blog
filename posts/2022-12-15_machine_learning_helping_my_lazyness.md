# Machine Learning Helping My Lazyness
tags: elixir, machine-learning

Writing blog posts can be a bit tricky, annoying, and a lot of other things but the worst part is the laziness of finishing it...

We're going to be smart about it and we'll try to automate it using machine learning with a new library just released for the Elixir ecosystem called [Bumblebee](https://github.com/elixir-nx/bumblebee).

## Adding a dash of machine intelligence

Installing couldn't be easier than following the guides in the repository... In our `mix.exs` we add a new dependency:

```elixir
def deps do
  [
    # a lot of other dependencies ...
    {:bumblebee, "~> 0.1.1"},
    {:exla, ">= 0.0.0"}
  ]
end
```

Next in our `config.exs` you add a new line configuring the backend NX will use:

```elixir
config :nx, default_backend: EXLA.Backend
```

And now we can start coding and use machine learning to be fully lazy with our writing!

## Revving up the engine

We'll now boot up our ML by starting the processes needed to load our [model](https://huggingface.co/docs/transformers/main_classes/model) and [tokenizer](https://huggingface.co/docs/transformers/main_classes/tokenizer) in our `application.ex`

Since we want text generation we're going to use [GPT2](https://huggingface.co/gpt2) for that effect. Bumblebee has a lot of helpers that can improve our life and one of them is related to Text processing tasks in the module [Bumblebee.Text]. One of the methods is called [`generation/3`](https://hexdocs.pm/bumblebee/Bumblebee.Text.html#generation/3) where one of the mandatory options we need to set is the maximum length of the generated text or the number of new tokens (words) will be generated.

```elixir
def start(_type, _args) do
    children = [
      # ... other children
      ml_child_spec()
    ]

    opts = [strategy: :one_for_one, name: Blog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp ml_child_spec() do
    {:ok, model_info} = Bumblebee.load_model({:hf, "gpt2"})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "gpt2"})

    serving =
      Bumblebee.Text.generation(model_info, tokenizer,
        max_new_tokens: 100,
        compile: [batch_size: 10, sequence_length: 100],
        defn_options: [compiler: EXLA]
      )

    {Nx.Serving, serving: serving, name: Blog.Serving, batch_timeout: 100}
  end
```

To note that `defn_options` will tell NX to compile this during application startup so you can have it ready to go whenever you need to run it. This can increase your startup time and it will depend on the model you are using so be aware of that.
## Let the laziness begin!

Now we need to call our [`NX.Serving.batched_run/2`](https://hexdocs.pm/nx/Nx.Serving.html#batched_run/2) which is a really smart implementation by the NX developers. This is a really smart wrap to batch requests to our ML worker and uses the given models to generate our blog text.

Let's build a module to do that in `lib/blog/lazy.ex`
```elixir
defmodule Blog.Lazy do
  def generate(input), do: Nx.Serving.batched_run(Blog.Serving, input)
end
```

And now we can run `iex -S mix` and try it out!
```elixir
iex(1)> Blog.Lazy.generate("And that is it! Our blog post can now be automated and we can start our path to lazy writing. Next steps could be")
```

> In bold is the generated text!

And that is it! Our blog post can now be automated and we can start our path to lazy writing. Next steps could be **to create a new blog post and add a new post title.\n\nWe can also create a new blog post and add a new post title.\n\nWe can also create a new blog post and add a new post title.\n\nWe can also create a new blog post and add a new post title.\n\nWe can also create a new blog post and add a new post title.\n\nWe can also create a new blog post and add a new post title.\n\n**


... I think that the path for my lazy writing is still not here but I'm hopeful we will get there with [Bumblebee](https://github.com/elixir-nx/bumblebee) by my side 🐝❤️.

## One last thing

Be aware that ML can take time so it's a good practice to wrap the call to our model in a Task, please check out the Phoenix example, especially this [line](https://github.com/elixir-nx/bumblebee/blob/main/examples/phoenix/text_classification.exs#L110).

Do check the video from [José Valim about this release](https://youtu.be/g3oyh3g1AtQ) to be mindblown and get a better explanation of what is happening.

## Conclusion
- We need around 20 lines of code to start using Machine Learning in Elixir
- [Hugging Face](https://huggingface.co/) is an awesome repository of models that we now have easy access to
- In one simple command we can run our models in a batched, production-ready way!
- My smallest post was about the highly complex subject of ML... Bumblebee is pure gold and I'm speechless!
