defmodule TriviaCrackQuizWeb.LobbyLive do
  use TriviaCrackQuizWeb, :live_view

  alias TriviaCrackQuiz.Rooms

  # Solo para mostrar las etiquetas de los filtros en la lista de salas. La
  # eleccion de filtros vive en CrearSalaLive.
  @categories [
    {:arte, "🎨 Arte"},
    {:ciencia, "🔬 Ciencia"},
    {:deportes, "⚽ Deportes"},
    {:historia, "🏛️ Historia"},
    {:tecnologia, "💻 Tecnología"},
    {:cultura_general, "🌎 Cultura General"}
  ]

  @types [
    {:multiple_choice, "🔘 Opción múltiple"},
    {:true_false, "✅ Verdadero/Falso"},
    {:quick_answer, "⌨️ Escribir"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Rooms.subscribe_lobby()
      :timer.send_interval(2000, :refresh)
    end

    {:ok, assign(socket, :rooms, Rooms.list())}
  end

  # Union aleatoria: cualquier sala libre, sin filtros. Para elegir por
  # caracteristicas, el jugador mira "Salas activas".
  @impl true
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
    <main class="game-shell min-h-screen text-slate-800">
      <Layouts.flash_group flash={@flash} />
      <div class="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-6 px-4 py-10 sm:px-6">
        <header class="flex flex-col items-center gap-3 text-center">
          <div class="flex h-16 w-16 items-center justify-center rounded-2xl bg-white/15 text-white shadow-lg backdrop-blur">
            <.icon name="hero-puzzle-piece" class="h-9 w-9" />
          </div>
          
          <h1 class="text-4xl font-black tracking-tight text-white drop-shadow">Preguntados</h1>
          
          <p class="text-sm font-semibold text-white/80">Trivia Crack Quiz Multiplayer</p>
          
          <.link
            navigate={~p"/tablero"}
            class="mt-1 inline-flex items-center gap-1.5 rounded-full bg-white/15 px-4 py-1.5 text-sm font-bold text-white backdrop-blur transition hover:scale-105"
          >
            <.icon name="hero-tv" class="h-4 w-4" /> Ver tablero en vivo
          </.link>
        </header>
        
        <section class="game-card p-6">
          <div class="mb-4 flex items-center justify-between gap-3">
            <h2 class="flex items-center gap-2 text-lg font-black text-slate-800">
              <.icon name="hero-home-modern" class="h-5 w-5 text-indigo-500" /> Salas activas
            </h2>
            
            <span class="rounded-full bg-indigo-100 px-3 py-1 text-xs font-bold text-indigo-700">
              {length(@rooms)} {if length(@rooms) == 1, do: "sala", else: "salas"}
            </span>
          </div>
          
          <p
            :if={@rooms == []}
            class="flex flex-col items-center gap-3 rounded-2xl border-2 border-dashed border-slate-200 px-4 py-10 text-center text-sm font-semibold text-slate-400"
          >
            <.icon name="hero-sparkles" class="h-8 w-8 text-indigo-300" />
            No hay salas todavía. Crea la primera.
          </p>
          
          <ul :if={@rooms != []} class="space-y-2">
            <li
              :for={room <- @rooms}
              class="flex items-center justify-between gap-3 rounded-2xl border-2 border-slate-100 bg-slate-50 px-4 py-3"
            >
              <div class="min-w-0">
                <p class="flex items-center gap-2 truncate text-sm font-black text-slate-800">
                  <.icon name="hero-flag" class="h-4 w-4 shrink-0 text-indigo-500" /> {room.id}
                </p>
                
                <p class="text-xs font-semibold text-slate-500">{filters_label(room.filters)}</p>
                
                <p class="text-xs font-semibold text-slate-400">
                  {phase_label(room.phase)} · {room.players}/{room.max_players} jugadores
                </p>
              </div>
              
              <.link
                :if={joinable?(room)}
                navigate={~p"/sala/#{room.id}"}
                class="game-btn-primary shrink-0 px-4 py-2 text-sm"
              >
                Entrar
              </.link>
              <span
                :if={not joinable?(room)}
                class="shrink-0 rounded-full bg-slate-200 px-4 py-2 text-sm font-bold text-slate-500"
              >
                {status_label(room)}
              </span>
            </li>
          </ul>
        </section>
        
        <section class="grid gap-3 sm:grid-cols-2">
          <%!-- Crear sala lleva a la pantalla de configuracion (nombre + filtros). --%>
          <.link
            navigate={~p"/crear"}
            class="game-card flex flex-col items-center justify-center px-5 py-6 text-center transition hover:scale-[1.02]"
          >
            <span class="flex h-12 w-12 items-center justify-center rounded-xl bg-indigo-50 text-indigo-600">
              <.icon name="hero-plus-circle" class="h-7 w-7" />
            </span> <span class="mt-3 block text-base font-black text-slate-800">Crear sala</span>
            <span class="block text-xs font-semibold text-slate-500">
              Elige nombre, categorías y tipos
            </span>
          </.link> <%!-- Aleatorio: entra a cualquier sala libre, sin filtros. --%>
          <button
            type="button"
            phx-click="random"
            id="random-join-btn"
            class="game-btn-warm flex flex-col items-center justify-center px-5 py-6 text-center"
          >
            <.icon name="hero-arrow-path-rounded-square" class="h-10 w-10" />
            <span class="mt-2 block text-base font-black">Unirse aleatorio</span>
            <span class="block text-xs font-semibold text-white/85">
              Te metemos en cualquier sala libre
            </span>
          </button>
        </section>
      </div>
    </main>
    """
  end

  # Etiqueta de los filtros de una sala para la lista de salas activas.
  defp filters_label(%{categories: [], types: []}), do: "🎲 Todas las categorías y tipos"

  defp filters_label(%{categories: categories, types: types}) do
    [labels_for(categories, @categories), labels_for(types, @types)]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" · ")
  end

  defp filters_label(_), do: "🎲 Todas las categorías y tipos"

  defp labels_for([], _options), do: ""

  defp labels_for(values, options) do
    options
    |> Enum.filter(fn {atom, _label} -> atom in values end)
    |> Enum.map_join(", ", fn {_atom, label} -> label end)
  end

  defp joinable?(room), do: room.phase == :waiting and room.players < room.max_players

  defp status_label(%{players: players, max_players: max}) when players >= max, do: "Llena"
  defp status_label(%{phase: :waiting}), do: "Esperando"
  defp status_label(_room), do: "En juego"

  defp phase_label(:waiting), do: "Esperando"
  defp phase_label(:playing), do: "Jugando"
  defp phase_label(:round_results), do: "Resultados"
  defp phase_label(:finished), do: "Terminada"
  defp phase_label(_), do: "—"
end
