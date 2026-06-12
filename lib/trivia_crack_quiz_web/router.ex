defmodule TriviaCrackQuizWeb.Router do
  use TriviaCrackQuizWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TriviaCrackQuizWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :ensure_player_id
  end

  # Asigna un identificador estable por navegador en la sesion (cookie).
  # Asi un refresco de pagina conserva al mismo jugador en vez de crear uno nuevo.
  defp ensure_player_id(conn, _opts) do
    if get_session(conn, :player_id) do
      conn
    else
      put_session(conn, :player_id, Base.url_encode64(:crypto.strong_rand_bytes(9)))
    end
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TriviaCrackQuizWeb do
    pipe_through :browser

    live "/", GameLive, :index
  end

  # Aqui se podrian agregar otras rutas, por ejemplo una API JSON.
  # scope "/api", TriviaCrackQuizWeb do
  #   pipe_through :api
  # end

  # Activa LiveDashboard solo en desarrollo para monitorear la aplicacion.
  if Application.compile_env(:trivia_crack_quiz, :dev_routes) do
    # En produccion deberia protegerse con autenticacion para que solo entren
    # administradores.
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TriviaCrackQuizWeb.Telemetry
    end
  end
end
