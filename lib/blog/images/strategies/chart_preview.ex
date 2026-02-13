defmodule Blog.Images.Strategies.ChartPreview do
  @moduledoc """
  Generates chart/graph preview images from Vega-lite specifications.
  """

  @behaviour Blog.Images.Strategy

  @impl true
  def generate(post_content, post_title) do
    # TODO: Implement chart rendering from Vega-lite specs
    # For now, fallback to typographic card
    Blog.Images.Strategies.TypographicCard.generate(post_content, post_title)
  end
end
