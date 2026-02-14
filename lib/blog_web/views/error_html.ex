defmodule BlogWeb.ErrorHTML do
  use BlogWeb, :view

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
