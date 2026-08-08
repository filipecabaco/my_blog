defmodule Blog.Mark do
  @moduledoc """
  The per-post mark: a 5x5 patch panel whose lit cells come from the slug's
  hash, so a post always draws the same figure and no two posts match.
  """

  import Bitwise

  @grid 5

  @doc """
  `{column, row, lit?}` for every cell, reading left to right, top to bottom.
  """
  @spec cells(String.t()) :: [{non_neg_integer(), non_neg_integer(), boolean()}]
  def cells(slug) do
    count = @grid * @grid
    <<bits::size(^count), _rest::bitstring>> = :crypto.hash(:sha256, slug)

    for index <- 0..(count - 1) do
      {rem(index, @grid), div(index, @grid), (bits >>> index &&& 1) == 1}
    end
  end

  @doc """
  The mark as SVG rects sized to a `@grid`-square viewBox of `size`.
  """
  @spec rects(String.t(), pos_integer(), pos_integer()) :: String.t()
  def rects(slug, cell, gap) do
    slug
    |> cells()
    |> Enum.map_join("", fn {column, row, lit} ->
      x = column * (cell + gap)
      y = row * (cell + gap)
      class = if lit, do: "lit", else: "dark"
      ~s(<rect class="#{class}" x="#{x}" y="#{y}" width="#{cell}" height="#{cell}" rx="2" />)
    end)
  end

  @doc """
  Width and height of a mark drawn with the given cell and gap.
  """
  @spec extent(pos_integer(), pos_integer()) :: pos_integer()
  def extent(cell, gap), do: @grid * cell + (@grid - 1) * gap
end
