defmodule Blog.Images.Strategies.TerminalOutput do
  @moduledoc """
  Generates terminal/console output styled images.
  """

  @behaviour Blog.Images.Strategy

  @impl true
  def generate(post_content, post_title) do
    # TODO: Implement terminal output rendering
    # For now, fallback to typographic card
    Blog.Images.Strategies.TypographicCard.generate(post_content, post_title)
  end
end
