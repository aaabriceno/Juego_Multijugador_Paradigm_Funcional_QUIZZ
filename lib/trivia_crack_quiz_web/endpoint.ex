defmodule TriviaCrackQuizWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :trivia_crack_quiz

  # La sesion se guarda en una cookie firmada.
  # Esto permite leer su contenido, pero evita que sea alterado.
  # Si quisieramos cifrarla, se agregaria :encryption_salt.
  @session_options [
    store: :cookie,
    key: "_trivia_crack_quiz_key",
    signing_salt: "Hahe+KmG",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # Sirve desde "/" los archivos estaticos ubicados en "priv/static".
  #
  # Cuando la recarga de codigo esta desactivada, por ejemplo en produccion,
  # se habilita `gzip` para servir archivos comprimidos generados con
  # `phx.digest`.
  plug Plug.Static,
    at: "/",
    from: :trivia_crack_quiz,
    gzip: not code_reloading?,
    only: TriviaCrackQuizWeb.static_paths(),
    raise_on_missing_only: code_reloading?

  # La recarga de codigo se activa en desarrollo desde la configuracion
  # :code_reloader del endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug TriviaCrackQuizWeb.Router
end
