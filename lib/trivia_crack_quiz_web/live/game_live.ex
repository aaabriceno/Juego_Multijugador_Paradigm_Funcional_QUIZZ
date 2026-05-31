defmodule TriviaCrackQuizWeb.GameLive do
  use TriviaCrackQuizWeb, :live_view

  alias TriviaCrackQuiz.GameServer

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: GameServer.subscribe()

    socket =
      socket
      |> assign(:state, GameServer.state())
      |> assign(:player_id, nil)
      |> assign(:player_name, "")
      |> assign(:answer, "")
      |> assign(:notice, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("join", %{"player" => %{"name" => name}}, socket) do
    player_id = socket.assigns.player_id || new_player_id()
    state = GameServer.join(player_id, String.trim(name))

    {:noreply,
     socket
     |> assign(:player_id, player_id)
     |> assign(:player_name, name)
     |> assign(:state, state)
     |> assign(:notice, "Jugador registrado")}
  end

  def handle_event("start", _params, socket) do
    case GameServer.start_game() do
      {:ok, state} ->
        {:noreply, assign(socket, :state, state)}

      {:error, :not_enough_players, state} ->
        {:noreply,
         socket
         |> assign(:state, state)
         |> assign(:notice, "Se necesitan al menos 3 jugadores")}
    end
  end

  def handle_event("answer", %{"answer" => answer}, socket) do
    state = GameServer.answer(socket.assigns.player_id, answer)

    {:noreply,
     socket
     |> assign(:state, state)
     |> assign(:answer, "")
     |> assign(:notice, "Respuesta enviada")}
  end

  @impl true
  def handle_info({:game_state, state}, socket) do
    {:noreply, assign(socket, :state, state)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-slate-950 text-slate-100">
      <div class="mx-auto flex min-h-screen w-full max-w-6xl flex-col gap-6 px-4 py-6 sm:px-6 lg:px-8">
        <header class="flex flex-col gap-4 border-b border-white/10 pb-5 md:flex-row md:items-end md:justify-between">
          <div>
            <p class="text-sm font-semibold uppercase tracking-wide text-cyan-300">
              Trivia Crack Quiz Multiplayer
            </p>
            <h1 class="mt-2 text-3xl font-bold text-white sm:text-4xl">Sala de preguntas</h1>
          </div>
          <div class="grid grid-cols-3 gap-2 text-center text-sm">
            <div class="rounded-lg border border-white/10 bg-white/5 px-4 py-3">
              <p class="text-slate-400">Fase</p>
              <p class="font-semibold">{@state.phase}</p>
            </div>
            <div class="rounded-lg border border-white/10 bg-white/5 px-4 py-3">
              <p class="text-slate-400">Ronda</p>
              <p class="font-semibold">{@state.round}/{@state.max_rounds}</p>
            </div>
            <div class="rounded-lg border border-white/10 bg-white/5 px-4 py-3">
              <p class="text-slate-400">Jugadores</p>
              <p class="font-semibold">{map_size(@state.players)}</p>
            </div>
          </div>
        </header>

        <section
          :if={@notice}
          class="rounded-lg border border-cyan-400/30 bg-cyan-400/10 px-4 py-3 text-sm text-cyan-100"
        >
          {@notice}
        </section>

        <div class="grid flex-1 gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
          <section class="rounded-lg border border-white/10 bg-white/[0.04] p-5">
            <.join_panel :if={is_nil(@player_id)} />
            <.waiting_panel :if={@state.phase == :waiting and not is_nil(@player_id)} state={@state} />
            <.question_panel :if={@state.phase == :playing} state={@state} player_id={@player_id} />
            <.finished_panel :if={@state.phase == :finished} state={@state} />
          </section>

          <aside class="rounded-lg border border-white/10 bg-white/[0.04] p-5">
            <div class="mb-4 flex items-center justify-between">
              <h2 class="text-lg font-semibold text-white">Marcador</h2>
              <button
                :if={@state.phase == :waiting}
                phx-click="start"
                class="rounded-md bg-cyan-400 px-3 py-2 text-sm font-semibold text-slate-950 hover:bg-cyan-300"
              >
                Iniciar
              </button>
            </div>

            <div class="space-y-3">
              <div
                :for={
                  {id, player} <- Enum.sort_by(@state.players, fn {_id, player} -> -player.score end)
                }
                class="rounded-lg border border-white/10 bg-slate-900 px-4 py-3"
              >
                <div class="flex items-center justify-between gap-3">
                  <p class="min-w-0 truncate font-semibold">{player.name}</p>
                  <p class="shrink-0 text-cyan-300">{player.score} pts</p>
                </div>
                <p class="mt-1 text-xs text-slate-400">{id} - {player.last_action}</p>
              </div>
            </div>
          </aside>
        </div>
      </div>
    </main>
    """
  end

  defp join_panel(assigns) do
    ~H"""
    <div class="mx-auto flex max-w-md flex-col justify-center py-12">
      <h2 class="text-2xl font-bold text-white">Unirse a la sala</h2>
      <.form for={%{}} as={:player} phx-submit="join" class="mt-6 space-y-4">
        <input
          name="player[name]"
          type="text"
          required
          placeholder="Nombre del jugador"
          class="w-full rounded-md border border-white/10 bg-slate-900 px-4 py-3 text-white outline-none focus:border-cyan-300"
        />
        <button class="w-full rounded-md bg-cyan-400 px-4 py-3 font-semibold text-slate-950 hover:bg-cyan-300">
          Entrar
        </button>
      </.form>
    </div>
    """
  end

  defp waiting_panel(assigns) do
    ~H"""
    <div class="flex min-h-80 flex-col items-center justify-center text-center">
      <h2 class="text-2xl font-bold text-white">Esperando jugadores</h2>
      <p class="mt-3 max-w-md text-slate-300">
        La partida inicia cuando existan al menos 3 jugadores registrados.
      </p>
      <p class="mt-6 text-5xl font-bold text-cyan-300">{map_size(@state.players)}/3</p>
    </div>
    """
  end

  defp question_panel(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <p class="text-sm font-semibold uppercase tracking-wide text-cyan-300">
          {@state.current_question.category} - {@state.current_question.type}
        </p>
        <h2 class="mt-3 text-3xl font-bold text-white">{@state.current_question.text}</h2>
      </div>

      <.form
        :if={not is_nil(@player_id)}
        for={%{}}
        phx-submit="answer"
        class="grid gap-3 sm:grid-cols-2"
      >
        <button
          :for={option <- @state.current_question.options}
          name="answer"
          value={option}
          class="rounded-lg border border-white/10 bg-slate-900 px-4 py-4 text-left font-semibold text-white hover:border-cyan-300 hover:bg-cyan-400/10"
        >
          {option}
        </button>

        <div :if={@state.current_question.options == []} class="sm:col-span-2">
          <input
            name="answer"
            type="text"
            required
            placeholder="Escribe tu respuesta"
            class="w-full rounded-md border border-white/10 bg-slate-900 px-4 py-3 text-white outline-none focus:border-cyan-300"
          />
          <button class="mt-3 rounded-md bg-cyan-400 px-4 py-3 font-semibold text-slate-950 hover:bg-cyan-300">
            Responder
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp finished_panel(assigns) do
    ~H"""
    <div class="flex min-h-80 flex-col items-center justify-center text-center">
      <p class="text-sm font-semibold uppercase tracking-wide text-cyan-300">Partida finalizada</p>
      <h2 class="mt-3 text-3xl font-bold text-white">
        Ganador: {if @state.winner, do: @state.winner.name, else: "Sin ganador"}
      </h2>
    </div>
    """
  end

  defp new_player_id do
    System.unique_integer([:positive])
    |> Integer.to_string()
  end
end
