defmodule Blog.Images.Strategies.CodeScreenshot do
  @moduledoc """
  Generates syntax-highlighted code screenshot images.
  Extracts code blocks from posts and renders them with styling.
  """

  @behaviour Blog.Images.Strategy

  @impl true
  def generate(post_content, post_title) do
    # TODO: Implement code screenshot generation
    # For now, fallback to typographic card
    Blog.Images.Strategies.TypographicCard.generate(post_content, post_title)
  end
end
