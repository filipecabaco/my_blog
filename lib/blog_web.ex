defmodule BlogWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use BlogWeb, :controller
      use BlogWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [atom: BlogWeb.FeedView, html: BlogWeb.ErrorView, json: BlogWeb.ErrorView],
        root_layout: false

      import Plug.Conn
      alias BlogWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.Component

      unquote(view_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  def component do
    quote do
      use Phoenix.Component

      unquote(view_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  defp view_helpers do
    quote do
      import Phoenix.HTML
      import Phoenix.HTML.Form
      use PhoenixHTMLHelpers
      import Phoenix.LiveView.Helpers

      # Import verified routes for ~p
      use Phoenix.VerifiedRoutes,
        endpoint: BlogWeb.Endpoint,
        router: BlogWeb.Router,
        statics: BlogWeb.static_paths()

      alias BlogWeb.Router.Helpers, as: Routes
    end
  end

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
