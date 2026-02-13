defmodule BlogWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, live views, and so on.
  """

  def controller do
    quote do
      use Phoenix.Controller, root_layout: false

      import Plug.Conn

      use Phoenix.VerifiedRoutes,
        endpoint: BlogWeb.Endpoint,
        router: BlogWeb.Router,
        statics: BlogWeb.static_paths()
    end
  end

  def view do
    quote do
      use Phoenix.Component

      import Phoenix.HTML

      use Phoenix.VerifiedRoutes,
        endpoint: BlogWeb.Endpoint,
        router: BlogWeb.Router,
        statics: BlogWeb.static_paths()
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      import Phoenix.HTML

      use Phoenix.VerifiedRoutes,
        endpoint: BlogWeb.Endpoint,
        router: BlogWeb.Router,
        statics: BlogWeb.static_paths()
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      import Phoenix.HTML

      use Phoenix.VerifiedRoutes,
        endpoint: BlogWeb.Endpoint,
        router: BlogWeb.Router,
        statics: BlogWeb.static_paths()
    end
  end

  def component do
    quote do
      use Phoenix.Component

      import Phoenix.HTML

      use Phoenix.VerifiedRoutes,
        endpoint: BlogWeb.Endpoint,
        router: BlogWeb.Router,
        statics: BlogWeb.static_paths()
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

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
