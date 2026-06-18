defmodule TriviaCrackQuizWeb.LobbyLive do
  use TriviaCrackQuizWeb, :live_view

  alias TriviaCrackQuiz.Rooms

  @impl true
  def mount(_params, _session, socket) do
    # El lobby se refresca solo cuando se crean salas o cambian de tamano.
    # Suscribirse aqui (y no en cada GameServer) mantiene la vista en vivo.
    if connected?(socket) do
      Rooms.subscribe_lobby()
      # Tic periodico para reflejar cambios de fase/jugadores dentro de salas
      # ya existentes (uniones/salidas no siempre emiten evento de lobby).
      :timer.send_interval(2000, :refresh)
    end

    {:ok, assign(socket, :rooms, Rooms.list())}
  end

  @impl true
  # Crear sala con nombre escrito por el usuario (opcional). Vacio -> aleatorio.
  def handle_event("create_named", %{"room" => %{"name" => name}}, socket) do
    room_id = Rooms.create_named(name)
    {:noreply, push_navigate(socket, to: ~p"/sala/#{room_id}")}
  end

  def handle_event("random", _params, socket) do
    room_id = Rooms.random_open()
    {:noreply, push_navigate(socket, to: ~p"/sala/#{room_id}")}
  end

  @impl true
  def handle_info(:rooms_changed, socket) do
    {:noreply, assign(socket, :rooms, Rooms.list())}
  end

  def handle_info(:refresh, socket) do
    {:noreply, assign(socket, :rooms, Rooms.list())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-gradient-to-b from-indigo-600 via-purple-600 to-fuchsia-600 text-slate-800">
      <div class="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-6 px-4 py-10 sm:px-6">
        <header class="flex flex-col items-center gap-3 text-center">
          <span class="text-6xl drop-shadow">🧠</span>
          <h1 class="text-4xl font-black tracking-tight text-white drop-shadow">Preguntados</h1>
          <p class="text-sm font-semibold text-white/80">Trivia Crack Quiz Multiplayer</p>
        </header>

        <section class="rounded-3xl bg-white p-6 shadow-2xl">
          <div class="mb-4 flex items-center justify-between">
            <h2 class="text-lg font-black text-slate-800">🚪 Salas activas</h2>
            <span class="rounded-full bg-indigo-100 px-3 py-1 text-xs font-bold text-indigo-700">
              {length(@rooms)} en juego
            </span>
          </div>

          <p
            :if={@rooms == []}
            class="rounded-2xl border-2 border-dashed border-slate-200 px-4 py-8 text-center text-sm font-semibold text-slate-400"
          >
            No hay salas todavía. ¡Crea la primera! 🎉
          </p>

          <ul :if={@rooms != []} class="space-y-2">
            <li
              :for={room <- @rooms}
              class="flex items-center justify-between rounded-2xl border-2 border-slate-100 bg-slate-50 px-4 py-3"
            >
              <div class="min-w-0">
                <p class="truncate text-sm font-black text-slate-800">🎯 {room.id}</p>
                <p class="text-xs font-semibold text-slate-500">
                  {phase_label(room.phase)} · {room.players}/{room.max_players} jugadores
                </p>
              </div>
              <.link
                :if={joinable?(room)}
                navigate={~p"/sala/#{room.id}"}
                class="rounded-full bg-gradient-to-r from-indigo-500 to-purple-600 px-4 py-2 text-sm font-bold text-white shadow-md transition hover:scale-105"
              >
                Entrar
              </.link>
              <span
                :if={not joinable?(room)}
                class="rounded-full bg-slate-200 px-4 py-2 text-sm font-bold text-slate-500"
              >
                {full_label(room)}
              </span>
            </li>
          </ul>
        </section>

        <section class="grid gap-3 sm:grid-cols-2">
          <.form
            for={%{}}
            as={:room}
            phx-submit="create_named"
            class="flex flex-col rounded-3xl bg-white px-5 py-6 text-center shadow-2xl"
          >
            <span class="block text-4xl">➕</span>
            <span class="mt-2 block text-base font-black text-slate-800">Crear sala</span>
            <input
              name="room[name]"
              type="text"
              maxlength="30"
              placeholder="Nombre (opcional)"
              class="mt-3 w-full rounded-xl border-2 border-slate-200 px-3 py-2 text-center text-sm font-semibold text-slate-800 outline-none transition focus:border-indigo-400"
            />
            <button class="mt-3 rounded-xl bg-gradient-to-r from-indigo-500 to-purple-600 px-4 py-2 text-sm font-black text-white shadow transition hover:scale-105">
              Crear y entrar
            </button>
          </.form>

          <button
            phx-click="random"
            class="rounded-3xl bg-gradient-to-br from-amber-400 to-orange-500 px-5 py-6 text-center text-white shadow-2xl transition hover:scale-105"
          >
            <span class="block text-4xl">🎲</span>
            <span class="mt-2 block text-base font-black">Unirse aleatorio</span>
            <span class="block text-xs font-semibold text-white/80">Te metemos en una sala libre</span>
          </button>
        </section>
      </div>
    </main>
    """
  end

  # Solo se puede entrar si la sala espera jugadores y tiene cupo. Las partidas
  # en curso o llenas no aceptan nuevos jugadores desde el lobby.
  defp joinable?(room), do: room.phase == :waiting and room.players < room.max_players

  defp full_label(%{players: players, max_players: max}) when players >= max, do: "Llena"
  defp full_label(_room), do: "En juego"

  defp phase_label(:waiting), do: "Esperando"
  defp phase_label(:playing), do: "Jugando"
  defp phase_label(:round_results), do: "Resultados"
  defp phase_label(:finished), do: "Terminada"
  defp phase_label(_), do: "—"
end
