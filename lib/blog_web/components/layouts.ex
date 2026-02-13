defmodule BlogWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.
  """

  use BlogWeb, :component

  embed_templates "layouts/*"

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
