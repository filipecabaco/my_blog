defmodule Blog.Images.Strategies.ArchitectureDiagram do
  @moduledoc """
  Generates architecture/flow diagram images from Mermaid blocks.
  """

  @behaviour Blog.Images.Strategy

  @impl true
  def generate(post_content, post_title) do
    # TODO: Implement Mermaid diagram rendering
    # For now, fallback to typographic card
    Blog.Images.Strategies.TypographicCard.generate(post_content, post_title)
  end
end
