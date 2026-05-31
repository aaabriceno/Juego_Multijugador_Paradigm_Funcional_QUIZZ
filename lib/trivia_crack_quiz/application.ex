defmodule TriviaCrackQuiz.Application do
  # Este modulo arranca la aplicacion OTP del juego.
  # Aqui se define que procesos se inician y quedan supervisados.
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TriviaCrackQuizWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:trivia_crack_quiz, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TriviaCrackQuiz.PubSub},
      TriviaCrackQuiz.GameServer,
      TriviaCrackQuizWeb.Endpoint
    ]

    # Si un proceso falla, el supervisor lo reinicia de forma independiente.
    opts = [strategy: :one_for_one, name: TriviaCrackQuiz.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Phoenix llama a esta funcion cuando cambia la configuracion del endpoint.
  @impl true
  def config_change(changed, _new, removed) do
    TriviaCrackQuizWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
