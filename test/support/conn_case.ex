defmodule BlogWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint BlogWeb.Endpoint

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      use Phoenix.VerifiedRoutes,
        endpoint: BlogWeb.Endpoint,
        router: BlogWeb.Router,
        statics: BlogWeb.static_paths()
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
