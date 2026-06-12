defmodule TriviaCrackQuiz.Application do
  # Este modulo arranca la aplicacion OTP del juego.
  # Aqui se define que procesos se inician y quedan supervisados.
  @moduledoc false

  use Application

  require Logger

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
    result = Supervisor.start_link(children, opts)

    log_lan_url()
    result
  end

  # Detecta la IP de esta maquina en la red local y muestra la URL que deben
  # usar los demas jugadores. La IP la asigna el router de turno, asi que
  # cambia segun la red (casa, universidad, etc.) sin tocar la configuracion.
  defp log_lan_url do
    endpoint_config = Application.get_env(:trivia_crack_quiz, TriviaCrackQuizWeb.Endpoint, [])
    server? = Phoenix.Endpoint.server?(:trivia_crack_quiz, TriviaCrackQuizWeb.Endpoint)

    with true <- server?,
         ip when ip != nil <- lan_ip() do
      port = get_in(endpoint_config, [:http, :port]) || 4000
      Logger.info("Otros jugadores pueden entrar desde: http://#{ip}:#{port}")
    else
      _ -> :ok
    end
  end

  defp lan_ip do
    {:ok, ifaddrs} = :inet.getifaddrs()

    addresses =
      for {_interface, opts} <- ifaddrs,
          {:addr, {_, _, _, _} = addr} <- opts,
          private_lan_address?(addr),
          do: addr

    # Prefiere los rangos domesticos/institucionales tipicos antes que redes
    # virtuales como la de Docker (172.17.x.x).
    addresses
    |> Enum.sort_by(fn
      {192, 168, _, _} -> 0
      {10, _, _, _} -> 1
      _ -> 2
    end)
    |> List.first()
    |> case do
      nil -> nil
      {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
    end
  end

  defp private_lan_address?({192, 168, _, _}), do: true
  defp private_lan_address?({10, _, _, _}), do: true
  defp private_lan_address?({172, second, _, _}) when second in 16..31, do: true
  defp private_lan_address?(_addr), do: false

  # Phoenix llama a esta funcion cuando cambia la configuracion del endpoint.
  @impl true
  def config_change(changed, _new, removed) do
    TriviaCrackQuizWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
