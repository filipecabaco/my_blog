defmodule Blog.Images do
  @moduledoc """
  Image generation for blog posts using strategy pattern.
  Selects appropriate generation approach based on post tags and content.
  """

  alias Blog.Posts

  @strategies %{
    code_screenshot: Blog.Images.Strategies.CodeScreenshot,
    chart_preview: Blog.Images.Strategies.ChartPreview,
    architecture_diagram: Blog.Images.Strategies.ArchitectureDiagram,
    terminal_output: Blog.Images.Strategies.TerminalOutput,
    ui_screenshot: Blog.Images.Strategies.UIScreenshot,
    typographic_card: Blog.Images.Strategies.TypographicCard
  }

  @tag_strategy_mapping %{
    "backend" => :code_screenshot,
    "web" => :code_screenshot,
    "real-time" => :code_screenshot,
    "data-visualization" => :chart_preview,
    "machine-learning" => :architecture_diagram,
    "applications" => :ui_screenshot,
    "frontend" => :code_screenshot,
    "data" => :architecture_diagram
  }

  @doc """
  Generate image for a blog post.
  Returns the URL path to the generated image.
  """
  @spec generate_for_post(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_for_post(post_content, post_title) do
    strategy = select_strategy(post_content)
    generate(strategy, post_content, post_title)
  end

  @doc """
  Get image URL for a post. Returns placeholder if image doesn't exist.
  """
  @spec image_url_for_post(String.t()) :: String.t()
  def image_url_for_post(post_title) do
    image_path = image_path(post_title)

    if File.exists?(image_path) do
      "/images/generated/#{post_title}.png"
    else
      "/images/placeholder.png"
    end
  end

  # Private functions

  defp select_strategy(post_content) do
    tags = Posts.tags(post_content)
    metadata = extract_metadata(post_content)

    cond do
      # Check explicit override
      Map.has_key?(metadata, :image_strategy) ->
        String.to_atom(metadata.image_strategy)

      # Check tag-based mapping
      strategy = find_strategy_by_tags(tags) ->
        strategy

      # Fallback to typographic card
      true ->
        :typographic_card
    end
  end

  defp find_strategy_by_tags([]), do: nil

  defp find_strategy_by_tags(tags) do
    Enum.find_value(tags, fn tag ->
      Map.get(@tag_strategy_mapping, tag)
    end)
  end

  defp extract_metadata(_post_content) do
    # Extract metadata from post frontmatter
    # For now, return empty map - will enhance later
    %{}
  end

  defp generate(strategy_name, post_content, post_title) do
    strategy_module = Map.get(@strategies, strategy_name)

    if strategy_module do
      strategy_module.generate(post_content, post_title)
    else
      # Fallback to typographic card if strategy not found
      Blog.Images.Strategies.TypographicCard.generate(post_content, post_title)
    end
  end

  defp image_path(post_title) do
    Path.join([
      :code.priv_dir(:blog),
      "static",
      "images",
      "generated",
      "#{post_title}.png"
    ])
  end
end
