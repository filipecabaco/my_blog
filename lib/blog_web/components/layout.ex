defmodule BlogWeb.Components.Layout do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <main class="container">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
      {render_slot(@inner_content)}
    </main>
    """
  end

  attr :kind, :atom, required: true
  attr :flash, :map, required: true

  defp flash(assigns) do
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
