defmodule TriviaCrackQuizWeb.GameLive do
  use TriviaCrackQuizWeb, :live_view

  alias TriviaCrackQuiz.GameServer

  @impl true
  def mount(%{"room_id" => room_id}, session, socket) do
    # Garantiza que la sala exista antes de entrar por URL (enlace compartido o
    # refresco tras reinicio del servidor). Si ya existe, no la duplica.
    TriviaCrackQuiz.Rooms.ensure(room_id)

    session_player_id = session["player_id"] || new_player_id()

    if connected?(socket) do
      GameServer.subscribe(room_id)
      # Tic local de cada cliente para refrescar la cuenta regresiva.
      :timer.send_interval(1000, :tick)
    end

    # Si el navegador ya estaba en la partida (refresco de pagina), se
    # reengancha automaticamente conservando nombre y puntaje.
    state =
      if connected?(socket) do
        GameServer.reconnect(room_id, session_player_id)
      else
        GameServer.state(room_id)
      end

    joined? = Map.has_key?(state.players, session_player_id)

    socket =
      socket
      |> assign(:room_id, room_id)
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
    state = GameServer.join(socket.assigns.room_id, player_id, String.trim(name))

    {:noreply,
     socket
     |> assign(:player_id, player_id)
     |> assign(:player_name, name)
     |> assign(:state, state)
     |> assign(:notice, "Jugador registrado")}
  end

  def handle_event("start", _params, socket) do
    case GameServer.start_game(socket.assigns.room_id) do
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
    state = GameServer.answer(socket.assigns.room_id, socket.assigns.player_id, answer)

    {:noreply,
     socket
     |> assign(:state, state)
     |> assign(:answer, "")
     |> assign(:notice, nil)}
  end

  def handle_event("reset", _params, socket) do
    state = GameServer.reset(socket.assigns.room_id)

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
    <main class="min-h-screen bg-gradient-to-b from-indigo-600 via-purple-600 to-fuchsia-600 text-slate-800">
      <div class="mx-auto flex min-h-screen w-full max-w-6xl flex-col gap-5 px-4 py-6 sm:px-6 lg:px-8">
        <header class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div class="flex items-center gap-3">
            <.link
              navigate={~p"/"}
              class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-white/15 text-xl text-white backdrop-blur transition hover:scale-105"
              title="Volver al lobby"
            >
              ←
            </.link>
            <span class="text-5xl drop-shadow">🧠</span>
            <div>
              <h1 class="text-3xl font-black tracking-tight text-white drop-shadow sm:text-4xl">
                Preguntados
              </h1>
              <p class="text-sm font-semibold text-white/80">🎯 {@room_id}</p>
            </div>
          </div>
          <div class="grid grid-cols-3 gap-2 text-center text-sm">
            <div class="rounded-2xl bg-white/15 px-4 py-2 backdrop-blur">
              <p class="text-xs font-semibold uppercase text-white/70">Fase</p>
              <p class="font-bold text-white">{phase_label(@state.phase)}</p>
            </div>
            <div class="rounded-2xl bg-white/15 px-4 py-2 backdrop-blur">
              <p class="text-xs font-semibold uppercase text-white/70">Ronda</p>
              <p class="font-bold text-white">{@state.round}/{@state.max_rounds}</p>
            </div>
            <div class="rounded-2xl bg-white/15 px-4 py-2 backdrop-blur">
              <p class="text-xs font-semibold uppercase text-white/70">Jugadores</p>
              <p class="font-bold text-white">{map_size(@state.players)}</p>
            </div>
          </div>
        </header>

        <section
          :if={@notice}
          class="rounded-2xl bg-white/90 px-5 py-3 text-sm font-semibold text-indigo-700 shadow-lg"
        >
          💬 {@notice}
        </section>

        <div class="grid flex-1 gap-5 lg:grid-cols-[minmax(0,1fr)_330px]">
          <section class="rounded-3xl bg-white p-6 shadow-2xl">
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

          <aside class="self-start rounded-3xl bg-white p-5 shadow-2xl">
            <div class="mb-4 flex items-center justify-between">
              <h2 class="text-lg font-black text-slate-800">🏆 Marcador</h2>
              <button
                :if={@state.phase == :waiting}
                phx-click="start"
                class="rounded-full bg-gradient-to-r from-amber-400 to-orange-500 px-4 py-2 text-sm font-bold text-white shadow-md transition hover:scale-105"
              >
                ▶ Iniciar
              </button>
            </div>

            <div class="space-y-2">
              <div
                :for={
                  {{id, player}, position} <-
                    @state.players
                    |> Enum.sort_by(fn {_id, player} -> -player.score end)
                    |> Enum.with_index(1)
                }
                class={[
                  "rounded-2xl border-2 px-3 py-2.5",
                  (id == @player_id && "border-indigo-300 bg-indigo-50") ||
                    "border-slate-100 bg-slate-50"
                ]}
              >
                <div class="flex items-center gap-3">
                  <span class={[
                    "relative flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-sm font-black text-white",
                    avatar_color(id)
                  ]}>
                    {avatar_initial(player.name)}
                    <span
                      class={[
                        "absolute -right-0.5 -top-0.5 h-3 w-3 rounded-full border-2 border-white",
                        (player.connected? && "bg-emerald-400") || "bg-slate-400"
                      ]}
                      title={(player.connected? && "Conectado") || "Desconectado"}
                    />
                  </span>
                  <div class="min-w-0 flex-1">
                    <p class="truncate text-sm font-bold text-slate-800">
                      <span :if={position == 1 and player.score > 0}>👑</span>
                      {player.name}
                      <span :if={id == @player_id} class="text-xs font-semibold text-indigo-500">
                        (tú)
                      </span>
                    </p>
                    <p class="text-xs text-slate-400">{action_label(player.last_action)}</p>
                  </div>
                  <p class="shrink-0 text-sm font-black text-indigo-600">{player.score}</p>
                </div>
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
    <div class="mx-auto flex max-w-md flex-col justify-center py-12 text-center">
      <p class="text-6xl">🎯</p>
      <h2 class="mt-4 text-3xl font-black text-slate-800">¡Únete a la partida!</h2>
      <p class="mt-2 text-slate-500">Elige un nombre y compite respondiendo preguntas.</p>
      <.form for={%{}} as={:player} phx-submit="join" class="mt-8 space-y-4">
        <input
          name="player[name]"
          type="text"
          required
          maxlength="20"
          placeholder="Tu nombre de jugador"
          class="w-full rounded-2xl border-2 border-slate-200 bg-white px-5 py-4 text-center text-lg font-semibold text-slate-800 outline-none transition focus:border-indigo-400"
        />
        <button class="w-full rounded-2xl bg-gradient-to-r from-indigo-500 to-purple-600 px-5 py-4 text-lg font-black text-white shadow-lg transition hover:scale-[1.02]">
          ¡Entrar! 🚀
        </button>
      </.form>
    </div>
    """
  end

  defp waiting_panel(assigns) do
    ~H"""
    <div class="flex min-h-80 flex-col items-center justify-center py-8 text-center">
      <p class="animate-bounce text-6xl">⏳</p>
      <h2 class="mt-4 text-3xl font-black text-slate-800">Esperando jugadores...</h2>
      <p class="mt-2 max-w-md text-slate-500">
        La partida inicia cuando existan al menos 3 jugadores registrados.
      </p>
      <p class="mt-6 text-6xl font-black text-indigo-600">
        {map_size(@state.players)}<span class="text-3xl text-slate-300">/3</span>
      </p>

      <div class="mt-10">
        <p class="text-xs font-bold uppercase tracking-wide text-slate-400">Categorías en juego</p>
        <div class="mt-3 flex flex-wrap justify-center gap-2">
          <span
            :for={category <- [:arte, :ciencia, :deportes, :historia, :tecnologia, :cultura_general]}
            class={[
              "rounded-full px-4 py-1.5 text-sm font-bold text-white shadow",
              category_style(category).chip
            ]}
          >
            {category_style(category).emoji} {category_style(category).label}
          </span>
        </div>
      </div>
    </div>
    """
  end

  defp question_panel(assigns) do
    question = assigns.state.current_question
    total_seconds = max(div(assigns.state.round_time_ms, 1000), 1)

    assigns =
      assigns
      |> assign(:answered?, Map.has_key?(assigns.state.answers, assigns.player_id))
      |> assign(:style, category_style(question.category))
      |> assign(:time_percent, round((assigns.time_left || 0) / total_seconds * 100))

    ~H"""
    <div class="space-y-5">
      <div class={["flex items-center justify-between gap-3 rounded-2xl px-5 py-3", @style.chip]}>
        <p class="flex items-center gap-2 text-lg font-black text-white">
          <span class="text-2xl">{@style.emoji}</span> {@style.label}
        </p>
        <p class="rounded-full bg-white/25 px-3 py-1 text-xs font-bold uppercase tracking-wide text-white">
          {type_label(@state.current_question.type)}
        </p>
      </div>

      <div :if={@time_left}>
        <div class="flex items-center justify-between text-sm font-bold">
          <span class="text-slate-400">Tiempo restante</span>
          <span class={[
            "tabular-nums text-lg",
            (@time_left <= 3 && "animate-pulse text-rose-500") || "text-indigo-600"
          ]}>
            ⏱ {@time_left}s
          </span>
        </div>
        <div class="mt-1 h-3 w-full overflow-hidden rounded-full bg-slate-100">
          <div
            class={[
              "h-full rounded-full transition-all duration-1000 ease-linear",
              (@time_left <= 3 && "bg-rose-500") || "bg-gradient-to-r from-indigo-500 to-purple-500"
            ]}
            style={"width: #{@time_percent}%"}
          />
        </div>
      </div>

      <h2 class="text-center text-2xl font-black leading-snug text-slate-800 sm:text-3xl">
        {@state.current_question.text}
      </h2>

      <div
        :if={@answered?}
        class="flex min-h-40 flex-col items-center justify-center rounded-2xl bg-indigo-50 py-8 text-center"
      >
        <p class="text-4xl">✅</p>
        <p class="mt-2 text-xl font-black text-indigo-700">¡Respuesta enviada!</p>
        <p class="mt-1 font-semibold text-slate-500">
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
          class={[
            "rounded-2xl border-2 border-slate-200 bg-white px-5 py-4 text-center text-lg font-bold text-slate-700 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md",
            @style.option_hover
          ]}
        >
          {option}
        </button>

        <div :if={@state.current_question.options == []} class="sm:col-span-2">
          <input
            name="answer"
            type="text"
            required
            autocomplete="off"
            placeholder="Escribe tu respuesta..."
            class="w-full rounded-2xl border-2 border-slate-200 bg-white px-5 py-4 text-center text-lg font-semibold text-slate-800 outline-none transition focus:border-indigo-400"
          />
          <button class="mt-3 w-full rounded-2xl bg-gradient-to-r from-indigo-500 to-purple-600 px-5 py-4 text-lg font-black text-white shadow-lg transition hover:scale-[1.01]">
            Responder ⚡
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp results_panel(assigns) do
    question = assigns.state.round_results.question
    my_result = assigns.state.round_results.results[assigns.player_id]

    assigns =
      assigns
      |> assign(:style, category_style(question.category))
      |> assign(:my_result, my_result)

    ~H"""
    <div class="space-y-5">
      <div class={["rounded-2xl px-5 py-3 text-center", @style.chip]}>
        <p class="text-sm font-black uppercase tracking-wide text-white">
          {@style.emoji} Resultados de la ronda {@state.round}
        </p>
      </div>

      <div class="rounded-2xl bg-slate-50 px-5 py-4 text-center">
        <p :if={@my_result && @my_result.correct?} class="text-5xl">🎉</p>
        <p :if={@my_result && not @my_result.correct?} class="text-5xl">😅</p>
        <p :if={is_nil(@my_result)} class="text-5xl">⏰</p>
        <h2 class="mt-2 text-xl font-bold text-slate-700">
          {@state.round_results.question.text}
        </h2>
        <p class="mt-3 inline-block rounded-full bg-emerald-100 px-5 py-2 text-lg font-black text-emerald-700">
          ✓ {@state.round_results.question.answer}
        </p>
      </div>

      <div class="space-y-2">
        <div
          :for={{id, player} <- Enum.sort_by(@state.players, fn {_id, p} -> -p.score end)}
          class="flex items-center gap-3 rounded-2xl border-2 border-slate-100 bg-white px-4 py-2.5"
        >
          <span class={[
            "flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-black text-white",
            avatar_color(id)
          ]}>
            {avatar_initial(player.name)}
          </span>
          <p class="min-w-0 flex-1 truncate font-bold text-slate-700">
            {player.name}
            <span :if={id == @player_id} class="text-xs font-semibold text-indigo-500">(tú)</span>
          </p>
          <p :if={result = @state.round_results.results[id]} class="shrink-0 text-sm font-bold">
            <span :if={result.correct?} class="text-emerald-600">
              ✓ {result.answer} <span class="text-emerald-500">+{result.points}</span>
            </span>
            <span :if={not result.correct?} class="text-rose-500">✗ {result.answer}</span>
          </p>
          <p
            :if={is_nil(@state.round_results.results[id])}
            class="shrink-0 text-sm font-semibold text-slate-400"
          >
            Sin respuesta
          </p>
        </div>
      </div>

      <p class="text-center text-sm font-semibold text-slate-400">
        La siguiente pregunta aparecerá en unos segundos...
      </p>
    </div>
    """
  end

  defp finished_panel(assigns) do
    ranking =
      assigns.state.players
      |> Enum.sort_by(fn {_id, player} -> -player.score end)
      |> Enum.with_index(1)

    assigns = assign(assigns, :ranking, ranking)

    ~H"""
    <div class="flex min-h-80 flex-col items-center justify-center py-8 text-center">
      <p class="text-6xl">🏆</p>
      <p class="mt-3 text-sm font-black uppercase tracking-wide text-indigo-500">
        Partida finalizada
      </p>
      <h2 class="mt-1 text-3xl font-black text-slate-800">
        {if @state.winner, do: "¡Ganó #{@state.winner.name}!", else: "Sin ganador"}
      </h2>

      <div class="mt-8 w-full max-w-md space-y-2 text-left">
        <div
          :for={{{id, player}, position} <- @ranking}
          class={[
            "flex items-center gap-3 rounded-2xl border-2 px-4 py-3",
            (position == 1 && "border-amber-300 bg-amber-50") ||
              "border-slate-100 bg-slate-50"
          ]}
        >
          <span class="w-8 text-center text-2xl">{medal(position)}</span>
          <span class={[
            "flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-sm font-black text-white",
            avatar_color(id)
          ]}>
            {avatar_initial(player.name)}
          </span>
          <p class="min-w-0 flex-1 truncate font-bold text-slate-800">{player.name}</p>
          <p class="shrink-0 font-black text-indigo-600">{player.score} pts</p>
        </div>
      </div>

      <button
        phx-click="reset"
        class="mt-8 rounded-2xl bg-gradient-to-r from-indigo-500 to-purple-600 px-8 py-4 text-lg font-black text-white shadow-lg transition hover:scale-105"
      >
        🔄 Jugar de nuevo
      </button>
    </div>
    """
  end

  # Identidad visual de cada categoria, inspirada en Preguntados.
  # Las clases van como cadenas completas para que Tailwind las detecte.
  defp category_style(:arte),
    do: %{label: "Arte", emoji: "🎨", chip: "bg-rose-500", option_hover: "hover:border-rose-400"}

  defp category_style(:ciencia),
    do: %{
      label: "Ciencia",
      emoji: "🔬",
      chip: "bg-emerald-500",
      option_hover: "hover:border-emerald-400"
    }

  defp category_style(:deportes),
    do: %{
      label: "Deportes",
      emoji: "⚽",
      chip: "bg-orange-500",
      option_hover: "hover:border-orange-400"
    }

  defp category_style(:historia),
    do: %{
      label: "Historia",
      emoji: "🏛️",
      chip: "bg-amber-500",
      option_hover: "hover:border-amber-400"
    }

  defp category_style(:tecnologia),
    do: %{
      label: "Tecnología",
      emoji: "💻",
      chip: "bg-sky-500",
      option_hover: "hover:border-sky-400"
    }

  defp category_style(:cultura_general),
    do: %{
      label: "Cultura General",
      emoji: "🌎",
      chip: "bg-violet-500",
      option_hover: "hover:border-violet-400"
    }

  defp category_style(other),
    do: %{
      label: to_string(other),
      emoji: "❓",
      chip: "bg-slate-500",
      option_hover: "hover:border-slate-400"
    }

  defp type_label(:multiple_choice), do: "Opción múltiple"
  defp type_label(:true_false), do: "Verdadero o Falso"
  defp type_label(:quick_answer), do: "Respuesta rápida"
  defp type_label(other), do: to_string(other)

  defp phase_label(:waiting), do: "En espera"
  defp phase_label(:playing), do: "Jugando"
  defp phase_label(:round_results), do: "Resultados"
  defp phase_label(:finished), do: "Final"
  defp phase_label(other), do: to_string(other)

  defp action_label(:joined), do: "se unió"
  defp action_label(:answered), do: "respondió"
  defp action_label(:correct), do: "acertó ✓"
  defp action_label(:incorrect), do: "falló ✗"
  defp action_label(:disconnected), do: "desconectado"
  defp action_label(:reconnected), do: "reconectado"
  defp action_label(other), do: to_string(other)

  defp avatar_initial(name) do
    name |> String.trim() |> String.first() |> Kernel.||("?") |> String.upcase()
  end

  @avatar_colors [
    "bg-rose-500",
    "bg-emerald-500",
    "bg-orange-500",
    "bg-sky-500",
    "bg-violet-500",
    "bg-amber-500"
  ]

  defp avatar_color(player_id) do
    Enum.at(@avatar_colors, :erlang.phash2(player_id, length(@avatar_colors)))
  end

  defp medal(1), do: "🥇"
  defp medal(2), do: "🥈"
  defp medal(3), do: "🥉"
  defp medal(_position), do: "·"

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
