defmodule TriviaCrackQuizWeb.GameLive do
  use TriviaCrackQuizWeb, :live_view

  alias TriviaCrackQuiz.GameServer

  @impl true
  def mount(_params, session, socket) do
    session_player_id = session["player_id"] || new_player_id()

    if connected?(socket) do
      GameServer.subscribe()
      # Tic local de cada cliente para refrescar la cuenta regresiva.
      :timer.send_interval(1000, :tick)
    end

    # Si el navegador ya estaba en la partida (refresco de pagina), se
    # reengancha automaticamente conservando nombre y puntaje.
    state =
      if connected?(socket) do
        GameServer.reconnect(session_player_id)
      else
        GameServer.state()
      end

    joined? = Map.has_key?(state.players, session_player_id)

    socket =
      socket
      |> assign(:state, state)
      |> assign(:session_player_id, session_player_id)
      |> assign(:player_id, if(joined?, do: session_player_id))
      |> assign(:player_name, if(joined?, do: state.players[session_player_id].name, else: ""))
      |> assign(:answer, "")
      |> assign(:notice, nil)
      |> assign_time_left()

    {:ok, socket}
  end

  @impl true
  def handle_event("join", %{"player" => %{"name" => name}}, socket) do
    player_id = socket.assigns.session_player_id
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

  def handle_event("reset", _params, socket) do
    state = GameServer.reset()

    {:noreply,
     socket
     |> assign(:state, state)
     |> assign(:notice, "Nueva partida lista, esperando jugadores")
     |> assign_time_left()}
  end

  @impl true
  def handle_info({:game_state, state}, socket) do
    {:noreply,
     socket
     |> assign(:state, state)
     |> assign_time_left()}
  end

  def handle_info(:tick, socket) do
    {:noreply, assign_time_left(socket)}
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
            <.question_panel
              :if={@state.phase == :playing}
              state={@state}
              player_id={@player_id}
              time_left={@time_left}
            />
            <.results_panel
              :if={@state.phase == :round_results}
              state={@state}
              player_id={@player_id}
            />
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
                  <p class="flex min-w-0 items-center gap-2 truncate font-semibold">
                    <span
                      class={[
                        "inline-block h-2 w-2 shrink-0 rounded-full",
                        (player.connected? && "bg-emerald-400") || "bg-slate-600"
                      ]}
                      title={(player.connected? && "Conectado") || "Desconectado"}
                    />
                    <span class="truncate">
                      {player.name}
                      <span :if={id == @player_id} class="text-xs text-slate-400">(tu)</span>
                    </span>
                  </p>
                  <p class="shrink-0 text-cyan-300">{player.score} pts</p>
                </div>
                <p class="mt-1 text-xs text-slate-400">{player.last_action}</p>
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
    assigns = assign(assigns, :answered?, Map.has_key?(assigns.state.answers, assigns.player_id))

    ~H"""
    <div class="space-y-6">
      <div class="flex items-start justify-between gap-4">
        <div>
          <p class="text-sm font-semibold uppercase tracking-wide text-cyan-300">
            {@state.current_question.category} - {@state.current_question.type}
          </p>
          <h2 class="mt-3 text-3xl font-bold text-white">{@state.current_question.text}</h2>
        </div>
        <div
          :if={@time_left}
          class={[
            "shrink-0 rounded-lg border px-4 py-2 text-center",
            (@time_left <= 3 && "border-rose-400/40 bg-rose-400/10") ||
              "border-white/10 bg-white/5"
          ]}
        >
          <p class="text-xs text-slate-400">Tiempo</p>
          <p class={[
            "text-3xl font-bold tabular-nums",
            (@time_left <= 3 && "text-rose-400") || "text-cyan-300"
          ]}>
            {@time_left}s
          </p>
        </div>
      </div>

      <div :if={@answered?} class="flex min-h-40 flex-col items-center justify-center text-center">
        <p class="text-xl font-semibold text-cyan-300">Respuesta enviada</p>
        <p class="mt-2 text-slate-300">
          Esperando al resto: {map_size(@state.answers)}/{map_size(@state.players)} respondieron
        </p>
      </div>

      <.form
        :if={not is_nil(@player_id) and not @answered?}
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

  defp results_panel(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <p class="text-sm font-semibold uppercase tracking-wide text-cyan-300">
          Resultados de la ronda {@state.round}
        </p>
        <h2 class="mt-3 text-2xl font-bold text-white">{@state.round_results.question.text}</h2>
        <p class="mt-3 text-lg">
          <span class="text-slate-400">Respuesta correcta:</span>
          <span class="font-semibold text-emerald-300">{@state.round_results.question.answer}</span>
        </p>
      </div>

      <div class="space-y-2">
        <div
          :for={{id, player} <- Enum.sort_by(@state.players, fn {_id, p} -> -p.score end)}
          class="flex items-center justify-between gap-3 rounded-lg border border-white/10 bg-slate-900 px-4 py-3"
        >
          <p class="min-w-0 truncate font-semibold">
            {player.name}
            <span :if={id == @player_id} class="text-xs text-slate-400">(tu)</span>
          </p>
          <p :if={result = @state.round_results.results[id]} class="shrink-0 text-sm">
            <span :if={result.correct?} class="font-semibold text-emerald-300">
              ✓ {result.answer} (+{result.points})
            </span>
            <span :if={not result.correct?} class="font-semibold text-rose-300">
              ✗ {result.answer}
            </span>
          </p>
          <p
            :if={is_nil(@state.round_results.results[id])}
            class="shrink-0 text-sm text-slate-500"
          >
            Sin respuesta
          </p>
        </div>
      </div>

      <p class="text-sm text-slate-400">La siguiente pregunta aparecera en unos segundos...</p>
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

      <div class="mt-8 w-full max-w-md space-y-2 text-left">
        <div
          :for={
            {{_id, player}, position} <-
              @state.players
              |> Enum.sort_by(fn {_id, player} -> -player.score end)
              |> Enum.with_index(1)
          }
          class={[
            "flex items-center justify-between gap-3 rounded-lg border px-4 py-3",
            (position == 1 && "border-amber-300/40 bg-amber-300/10") ||
              "border-white/10 bg-slate-900"
          ]}
        >
          <p class="min-w-0 truncate font-semibold">
            <span class={[
              "mr-2 tabular-nums",
              (position == 1 && "text-amber-300") || "text-slate-400"
            ]}>
              #{position}
            </span>
            {player.name}
          </p>
          <p class="shrink-0 font-semibold text-cyan-300">{player.score} pts</p>
        </div>
      </div>

      <button
        phx-click="reset"
        class="mt-8 rounded-md bg-cyan-400 px-6 py-3 font-semibold text-slate-950 hover:bg-cyan-300"
      >
        Jugar de nuevo
      </button>
    </div>
    """
  end

  defp assign_time_left(socket) do
    assign(socket, :time_left, time_left(socket.assigns.state))
  end

  # Segundos restantes de la ronda actual. El estado guarda tiempos monotonicos
  # del nodo, comparables aqui porque LiveView corre en la misma maquina virtual.
  defp time_left(%{
         phase: :playing,
         round_started_at: started_at,
         round_time_ms: round_time_ms
       })
       when is_integer(started_at) do
    remaining_ms = started_at + round_time_ms - System.monotonic_time(:millisecond)
    max(div(remaining_ms + 999, 1000), 0)
  end

  defp time_left(_state), do: nil

  defp new_player_id do
    System.unique_integer([:positive])
    |> Integer.to_string()
  end
end
