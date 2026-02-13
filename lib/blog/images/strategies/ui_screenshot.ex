defmodule Blog.Images.Strategies.UIScreenshot do
  @moduledoc """
  Handles UI screenshot images.
  Typically uses manually provided screenshots with fallback generation.
  """

  @behaviour Blog.Images.Strategy

  @impl true
  def generate(post_content, post_title) do
    # TODO: Check for manual screenshot, generate placeholder if not found
    # For now, fallback to typographic card
    Blog.Images.Strategies.TypographicCard.generate(post_content, post_title)
  end
end
