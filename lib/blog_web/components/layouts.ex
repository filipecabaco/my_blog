defmodule BlogWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.
  """

  use BlogWeb, :component

  embed_templates "layouts/*"

  attr :slug, :string, required: true
  attr :cell, :integer, default: 14
  attr :gap, :integer, default: 6
  attr :class, :string, default: "mark"

  @doc "The per-post patch-panel mark, drawn inline from the slug."
  def mark(assigns) do
    extent = Blog.Mark.extent(assigns.cell, assigns.gap)
    assigns = assign(assigns, extent: extent, rects: Blog.Mark.rects(assigns.slug, assigns.cell, assigns.gap))

    ~H"""
    <svg class={@class} width={@extent} height={@extent} viewBox={"0 0 #{@extent} #{@extent}"} aria-hidden="true" focusable="false">
      {Phoenix.HTML.raw(@rects)}
    </svg>
    """
  end

  attr :kind, :atom, required: true
  attr :flash, :map, required: true

  def flash(assigns) do
    message = Phoenix.Flash.get(assigns.flash, assigns.kind)
    assigns = assign(assigns, :message, message)

    ~H"""
    <%= if @message do %>
      <p class={"alert alert-#{@kind}"} role="alert" phx-click="lv:clear-flash" phx-value-key={@kind}>
        {@message}
      </p>
    <% end %>
    """
  end
end
