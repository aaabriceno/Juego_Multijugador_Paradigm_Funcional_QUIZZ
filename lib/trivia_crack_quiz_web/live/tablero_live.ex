defmodule TriviaCrackQuizWeb.TableroLive do
  @moduledoc """
  Tablero espectador: muestra todas las salas activas en tiempo real, cada una
  con sus jugadores ordenados por puntaje, fase y ronda. No se juega aqui; solo
  se observa como van las partidas.
  """
  use TriviaCrackQuizWeb, :live_view

  alias TriviaCrackQuiz.Rooms

  @refresh_ms 1_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Rooms.subscribe_lobby()
      # Tic frecuente para reflejar el cambio de puntajes dentro de las salas
      # (las altas/bajas de sala llegan ademas por el evento del lobby).
      :timer.send_interval(@refresh_ms, :refresh)
    end

    {:ok, assign(socket, :rooms, Rooms.list())}
  end

  @impl true
  def handle_info(:rooms_changed, socket), do: {:noreply, assign(socket, :rooms, Rooms.list())}
  def handle_info(:refresh, socket), do: {:noreply, assign(socket, :rooms, Rooms.list())}

  @impl true
  def render(assigns) do
    ~H"""
    <main class="game-shell min-h-screen text-slate-800">
      <Layouts.flash_group flash={@flash} />
      <div class="mx-auto flex min-h-screen w-full max-w-6xl flex-col gap-6 px-4 py-10 sm:px-6">
        <header class="flex items-center gap-3">
          <.link
            navigate={~p"/"}
            class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-white/15 text-xl text-white backdrop-blur transition hover:scale-105"
            title="Volver al lobby"
          >
            ←
          </.link>
          <div>
            <h1 class="text-3xl font-black tracking-tight text-white drop-shadow">Tablero en vivo</h1>
            
            <p class="text-sm font-semibold text-white/80">
              {length(@rooms)} {if length(@rooms) == 1, do: "sala activa", else: "salas activas"}
            </p>
          </div>
        </header>
        
        <p
          :if={@rooms == []}
          class="game-card flex flex-col items-center gap-3 px-4 py-12 text-center text-sm font-semibold text-slate-400"
        >
          <.icon name="hero-tv" class="h-8 w-8 text-indigo-300" /> No hay salas activas para mostrar.
        </p>
        
        <div :if={@rooms != []} class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <section :for={room <- @rooms} class="game-card flex flex-col p-5">
            <div class="flex items-center justify-between gap-2">
              <h2 class="flex items-center gap-1.5 truncate text-base font-black text-slate-800">
                <.icon name="hero-flag" class="h-4 w-4 shrink-0 text-indigo-500" /> {room.id}
              </h2>
              
              <span class={[
                "shrink-0 rounded-full px-2.5 py-1 text-xs font-bold",
                phase_badge(room.phase)
              ]}>
                {phase_label(room.phase)}
              </span>
            </div>
            
            <p class="mt-1 text-xs font-semibold text-slate-400">
              Ronda {room.round}/{room.max_rounds} · {room.players}/{room.max_players} conectados
            </p>
            
            <ul class="mt-3 space-y-1.5">
              <li
                :for={{player, idx} <- Enum.with_index(room.roster, 1)}
                class="flex items-center gap-2 rounded-xl bg-slate-50 px-3 py-2"
              >
                <span class="w-5 text-center text-xs font-black text-slate-400">{medal(idx)}</span>
                <span class={[
                  "h-2 w-2 shrink-0 rounded-full",
                  (player.connected? && "bg-emerald-400") || "bg-slate-300"
                ]} />
                <span class="min-w-0 flex-1 truncate text-sm font-bold text-slate-700">
                  {player.name}
                </span>
                <span class="shrink-0 text-sm font-black text-indigo-600">{player.score}</span>
              </li>
              
              <li
                :if={room.roster == []}
                class="rounded-xl bg-slate-50 px-3 py-2 text-center text-xs font-semibold text-slate-400"
              >
                Sin jugadores aún
              </li>
            </ul>
          </section>
        </div>
      </div>
    </main>
    """
  end

  defp medal(1), do: "🥇"
  defp medal(2), do: "🥈"
  defp medal(3), do: "🥉"
  defp medal(n), do: "#{n}º"

  defp phase_badge(:playing), do: "bg-emerald-100 text-emerald-700"
  defp phase_badge(:round_results), do: "bg-amber-100 text-amber-700"
  defp phase_badge(:finished), do: "bg-indigo-100 text-indigo-700"
  defp phase_badge(_), do: "bg-slate-100 text-slate-500"

  defp phase_label(:waiting), do: "Esperando"
  defp phase_label(:playing), do: "Jugando"
  defp phase_label(:round_results), do: "Resultados"
  defp phase_label(:finished), do: "Terminada"
  defp phase_label(_), do: "—"
end
