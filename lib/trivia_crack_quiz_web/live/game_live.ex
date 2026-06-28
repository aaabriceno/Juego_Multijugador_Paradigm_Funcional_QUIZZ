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
      |> assign(:show_hint, false)
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

  # Revela la pista de la pregunta actual (solo afecta la vista de este jugador).
  def handle_event("show_hint", _params, socket) do
    {:noreply, assign(socket, :show_hint, true)}
  end

  # Salida definitiva: borra al jugador de la sala (el conteo baja para todos)
  # y vuelve al lobby. El boton pide confirmacion en el navegador antes.
  def handle_event("leave", _params, socket) do
    if socket.assigns.player_id do
      GameServer.leave(socket.assigns.room_id, socket.assigns.player_id)
    end

    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  @impl true
  def handle_info({:return_to_lobby, _payload}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "La partida se canceló porque quedaste solo. Volviendo al lobby.")
     |> push_navigate(to: ~p"/")}
  end

  def handle_info(:room_closed, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "La sala se cerró por inactividad.")
     |> push_navigate(to: ~p"/")}
  end

  def handle_info({:game_state, state}, socket) do
    # Al cambiar de pregunta, se oculta de nuevo la pista para la siguiente.
    show_hint = socket.assigns.show_hint and same_question?(socket.assigns.state, state)

    {:noreply,
     socket
     |> maybe_play_phase_sound(state)
     |> assign(:state, state)
     |> assign(:show_hint, show_hint)
     |> assign_time_left()}
  end

  def handle_info(:tick, socket) do
    {:noreply, maybe_play_tick(socket)}
  end

  # Reproduce un sonido cuando la fase cambia, segun el resultado de ESTE
  # jugador: ding si acerto, buzz si fallo, fanfarria al ganar la partida.
  defp maybe_play_phase_sound(socket, new_state) do
    old_phase = socket.assigns.state.phase
    player_id = socket.assigns.player_id

    cond do
      new_state.phase == :round_results and old_phase != :round_results ->
        sound = round_result_sound(new_state, player_id)
        if sound, do: push_event(socket, "play_sound", %{name: sound}), else: socket

      new_state.phase == :finished and old_phase != :finished ->
        push_event(socket, "play_sound", %{name: "fanfare"})

      true ->
        socket
    end
  end

  defp round_result_sound(_state, nil), do: nil

  defp round_result_sound(state, player_id) do
    case get_in(state, [:round_results, :results, player_id]) do
      %{correct?: true} -> "ding"
      %{correct?: false} -> "buzz"
      _ -> nil
    end
  end

  # Tic de audio en los ultimos 3 segundos de la ronda, una vez por segundo.
  defp maybe_play_tick(socket) do
    socket = assign_time_left(socket)
    time_left = socket.assigns.time_left

    if socket.assigns.state.phase == :playing and is_integer(time_left) and
         time_left in 1..3 do
      push_event(socket, "play_sound", %{name: "tick"})
    else
      socket
    end
  end

  # Etiqueta de los filtros de la sala (categorias + tipos) para el encabezado.
  # Sin filtros = todas las preguntas.
  @all_categories [:arte, :ciencia, :deportes, :historia, :tecnologia, :cultura_general]

  # Categorias realmente en juego en la sala: las filtradas, o todas si no se
  # filtro ninguna.
  defp categories_in_play(state) do
    case state[:filters] do
      %{categories: [_ | _] = categories} -> categories
      _ -> @all_categories
    end
  end

  # Tipos filtrados de la sala (vacio = todos, no se muestra chip de tipo).
  defp types_in_play(state) do
    case state[:filters] do
      %{types: types} -> types
      _ -> []
    end
  end

  defp room_filters_label(%{categories: [], types: []}), do: "🎲 Todas"

  defp room_filters_label(%{categories: categories, types: types}) do
    cat_part = Enum.map_join(categories, ", ", &category_style(&1).label)
    type_part = Enum.map_join(types, ", ", &type_label/1)

    [cat_part, type_part]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" · ")
    |> case do
      "" -> "🎲 Todas"
      label -> label
    end
  end

  defp room_filters_label(_), do: "🎲 Todas"

  # True si ambos estados muestran la misma pregunta (mismo id). Sirve para
  # decidir si conservar la pista revelada o resetearla al cambiar de ronda.
  defp same_question?(old_state, new_state) do
    question_id(old_state) == question_id(new_state)
  end

  defp question_id(%{current_question: %{id: id}}), do: id
  defp question_id(_state), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <main
      id="game-root"
      phx-hook="PlaysSound"
      class="game-shell min-h-screen text-slate-800"
    >
      <Layouts.flash_group flash={@flash} />
      <div class="mx-auto flex min-h-screen w-full max-w-6xl flex-col gap-5 px-4 py-6 sm:px-6 lg:px-8">
        <header class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div class="flex items-center gap-3">
            <button
              :if={@player_id}
              phx-click="leave"
              data-confirm="¿Seguro que quieres salir de la partida? Perderás tu lugar y tu puntaje."
              class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-white/15 text-white backdrop-blur transition hover:scale-105"
              title="Salir de la partida"
            >
              <.icon name="hero-arrow-left" class="h-5 w-5" />
            </button>
            <.link
              :if={is_nil(@player_id)}
              navigate={~p"/"}
              class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-white/15 text-white backdrop-blur transition hover:scale-105"
              title="Volver al lobby"
            >
              <.icon name="hero-arrow-left" class="h-5 w-5" />
            </.link>
            <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-white/15 text-white backdrop-blur">
              <.icon name="hero-puzzle-piece" class="h-7 w-7" />
            </div>
            <div>
              <h1 class="text-3xl font-black tracking-tight text-white drop-shadow sm:text-4xl">
                Preguntados
              </h1>
              <p class="flex items-center gap-1.5 text-sm font-semibold text-white/80">
                <.icon name="hero-flag" class="h-4 w-4" /> {@room_id}
                <span class="rounded-full bg-white/20 px-2 py-0.5 text-xs">
                  {room_filters_label(@state[:filters])}
                </span>
              </p>
            </div>
          </div>
          <div class="grid grid-cols-3 gap-2 text-center text-sm">
            <div class="game-stat-pill px-4 py-2">
              <p class="text-xs font-semibold uppercase text-white/70">Fase</p>
              <p class="font-bold text-white">{phase_label(@state.phase)}</p>
            </div>
            <div class="game-stat-pill px-4 py-2">
              <p class="text-xs font-semibold uppercase text-white/70">Ronda</p>
              <p class="font-bold text-white">{@state.round}/{@state.max_rounds}</p>
            </div>
            <div class="game-stat-pill px-4 py-2">
              <p class="text-xs font-semibold uppercase text-white/70">Jugadores</p>
              <p class="font-bold text-white">{TriviaCrackQuiz.Game.connected_count(@state)}</p>
            </div>
          </div>
        </header>

        <section
          :if={@notice}
          class="flex items-center gap-2 rounded-2xl bg-white/90 px-5 py-3 text-sm font-semibold text-indigo-700 shadow-lg"
        >
          <.icon name="hero-chat-bubble-left-ellipsis" class="h-5 w-5 shrink-0" />
          {@notice}
        </section>

        <div class="grid flex-1 gap-5 lg:grid-cols-[minmax(0,1fr)_330px]">
          <section class="game-card p-6">
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

          <aside class="game-card self-start p-5">
            <div class="mb-4 flex items-center justify-between">
              <h2 class="flex items-center gap-2 text-lg font-black text-slate-800">
                <.icon name="hero-trophy" class="h-5 w-5 text-amber-500" /> Marcador
              </h2>
              <button
                :if={@state.phase == :waiting}
                phx-click="start"
                class="flex items-center gap-1 rounded-full bg-gradient-to-r from-amber-400 to-orange-500 px-4 py-2 text-sm font-bold text-white shadow-md transition hover:scale-105"
              >
                <.icon name="hero-play" class="h-4 w-4" /> Iniciar
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
                id={"score-#{id}"}
                class={[
                  "rounded-2xl border-2 px-3 py-2.5 transition-all duration-500",
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
                      <.icon
                        :if={position == 1 and player.score > 0}
                        name="hero-star"
                        class="mr-0.5 inline h-4 w-4 text-amber-400"
                      />
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
      <span class="mx-auto flex h-16 w-16 items-center justify-center rounded-2xl bg-indigo-50 text-indigo-600">
        <.icon name="hero-user-plus" class="h-9 w-9" />
      </span>
      <h2 class="mt-4 text-3xl font-black text-slate-800">Únete a la partida</h2>
      <p class="mt-2 text-slate-500">Elige un nombre y compite respondiendo preguntas.</p>
      <.form for={%{}} as={:player} phx-submit="join" id="join-form" class="mt-8 space-y-4">
        <input
          name="player[name]"
          type="text"
          required
          maxlength="20"
          placeholder="Tu nombre de jugador"
          class="w-full rounded-2xl border-2 border-slate-200 bg-white px-5 py-4 text-center text-lg font-semibold text-slate-800 outline-none transition focus:border-indigo-400"
        />
        <button class="game-btn-primary w-full px-5 py-4 text-lg">
          Entrar
        </button>
      </.form>
    </div>
    """
  end

  defp waiting_panel(assigns) do
    ~H"""
    <div class="flex min-h-80 flex-col items-center justify-center py-8 text-center">
      <span class="flex h-16 w-16 animate-pulse items-center justify-center rounded-2xl bg-indigo-50 text-indigo-500">
        <.icon name="hero-clock" class="h-9 w-9" />
      </span>
      <h2 class="mt-4 text-3xl font-black text-slate-800">Esperando jugadores...</h2>
      <p class="mt-2 max-w-md text-slate-500">
        La partida inicia cuando existan al menos 3 jugadores registrados.
      </p>
      <p class="mt-6 text-6xl font-black text-indigo-600">
        {TriviaCrackQuiz.Game.connected_count(@state)}<span class="text-3xl text-slate-300">/3</span>
      </p>

      <div class="mt-10">
        <p class="text-xs font-bold uppercase tracking-wide text-slate-400">Categorías en juego</p>
        <div class="mt-3 flex flex-wrap justify-center gap-2">
          <span
            :for={category <- categories_in_play(@state)}
            class={[
              "flex items-center gap-1.5 rounded-full px-4 py-1.5 text-sm font-bold text-white shadow",
              category_style(category).chip
            ]}
          >
            <.icon name={category_style(category).icon} class="h-4 w-4" />
            {category_style(category).label}
          </span>
        </div>

        <div :if={types_in_play(@state) != []} class="mt-5">
          <p class="text-xs font-bold uppercase tracking-wide text-slate-400">Tipos en juego</p>
          <div class="mt-3 flex flex-wrap justify-center gap-2">
            <span
              :for={type <- types_in_play(@state)}
              class="rounded-full bg-slate-100 px-4 py-1.5 text-sm font-bold text-slate-600"
            >
              {type_label(type)}
            </span>
          </div>
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
      |> assign(:bar_color, time_bar_color(assigns.time_left, total_seconds))

    ~H"""
    <div class="space-y-5">
      <div
        :if={@state.current_question[:surprise]}
        class="flex items-center justify-center gap-2 rounded-2xl bg-gradient-to-r from-fuchsia-500 to-amber-400 px-5 py-2 text-center text-sm font-black uppercase tracking-wide text-white shadow"
      >
        🎁 ¡Pregunta sorpresa! +20% de puntos
      </div>

      <div class={["flex items-center justify-between gap-3 rounded-2xl px-5 py-3", @style.chip]}>
        <p class="flex items-center gap-2 text-lg font-black text-white">
          <.icon name={@style.icon} class="h-6 w-6" /> {@style.label}
        </p>
        <p class="rounded-full bg-white/25 px-3 py-1 text-xs font-bold uppercase tracking-wide text-white">
          {type_label(@state.current_question.type)}
        </p>
      </div>

      <div :if={@time_left}>
        <div class="flex items-center justify-between text-sm font-bold">
          <span class="text-slate-400">Tiempo restante</span>
          <span class={[
            "flex items-center gap-1 tabular-nums text-lg",
            (@time_left <= 3 && "animate-pulse text-rose-500") || "text-indigo-600"
          ]}>
            <.icon name="hero-clock" class="h-5 w-5" /> {@time_left}s
          </span>
        </div>
        <div class="mt-1 h-3 w-full overflow-hidden rounded-full bg-slate-100">
          <div
            class={["h-full rounded-full transition-all duration-1000 ease-linear", @bar_color]}
            style={"width: #{@time_percent}%"}
          />
        </div>
      </div>

      <%!-- Cuenta regresiva dramatica: numero grande que late en los ultimos 3s.
            La key fuerza a re-disparar la animacion cada segundo. --%>
      <div
        :if={is_integer(@time_left) and @time_left <= 3 and @time_left > 0 and not @answered?}
        class="pointer-events-none flex justify-center"
      >
        <span
          id={"countdown-#{@time_left}"}
          class="animate-count-pulse text-7xl font-black text-rose-500 drop-shadow-lg"
        >
          {@time_left}
        </span>
      </div>

      <h2 class="text-center text-2xl font-black leading-snug text-slate-800 sm:text-3xl">
        {@state.current_question.text}
      </h2>

      <div
        :if={@answered?}
        class="flex min-h-40 flex-col items-center justify-center rounded-2xl bg-indigo-50 py-8 text-center"
      >
        <.icon name="hero-check-circle" class="h-12 w-12 text-indigo-600" />
        <p class="mt-2 text-xl font-black text-indigo-700">Respuesta enviada</p>
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

          <%!-- Pista opcional: solo si la pregunta trae hint. Se revela con el
                boton; mientras tanto solo se ofrece la ayuda. --%>
          <div :if={@state.current_question[:hint]} class="mt-3 text-center">
            <button
              :if={not @show_hint}
              type="button"
              phx-click="show_hint"
              class="rounded-full border-2 border-amber-300 bg-amber-50 px-4 py-1.5 text-sm font-bold text-amber-700 transition hover:scale-105"
            >
              💡 Ver pista
            </button>
            <p
              :if={@show_hint}
              class="rounded-2xl bg-amber-50 px-4 py-2 text-sm font-semibold text-amber-800"
            >
              💡 {@state.current_question.hint}
            </p>
          </div>

          <button class="game-btn-primary mt-3 w-full px-5 py-4 text-lg">
            Responder
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
        <p class="flex items-center justify-center gap-2 text-sm font-black uppercase tracking-wide text-white">
          <.icon name={@style.icon} class="h-5 w-5" /> Resultados de la ronda {@state.round}
        </p>
      </div>

      <div class={[
        "rounded-2xl px-5 py-4 text-center transition",
        (@my_result && @my_result.correct? && "animate-pop-in bg-emerald-50 ring-2 ring-emerald-300") ||
          (@my_result && not @my_result.correct? &&
             "animate-shake bg-rose-50 ring-2 ring-rose-300") ||
          "bg-slate-50"
      ]}>
        <.icon
          :if={@my_result && @my_result.correct?}
          name="hero-check-badge"
          class="mx-auto h-12 w-12 text-emerald-500"
        />
        <.icon
          :if={@my_result && not @my_result.correct?}
          name="hero-x-circle"
          class="mx-auto h-12 w-12 text-rose-500"
        />
        <.icon :if={is_nil(@my_result)} name="hero-clock" class="mx-auto h-12 w-12 text-slate-400" />
        <p
          :if={@my_result && @my_result.correct?}
          class="mt-1 text-lg font-black text-emerald-600"
        >
          ¡Correcto! +{@my_result.points}
        </p>
        <p
          :if={@my_result && not @my_result.correct?}
          class="mt-1 text-lg font-black text-rose-500"
        >
          ¡Fallaste!
        </p>
        <h2 class="mt-2 text-xl font-bold text-slate-700">
          {@state.round_results.question.text}
        </h2>
        <p class="mt-3 inline-flex items-center gap-2 rounded-full bg-emerald-100 px-5 py-2 text-lg font-black text-emerald-700">
          <.icon name="hero-check" class="h-5 w-5" />
          {@state.round_results.question.answer}
        </p>
      </div>

      <div class="space-y-2">
        <div
          :for={{id, player} <- Enum.sort_by(@state.players, fn {_id, p} -> -p.score end)}
          class={[
            "relative flex items-center gap-3 rounded-2xl border-2 px-4 py-2.5",
            (id == @player_id && "border-indigo-300 bg-indigo-50") || "border-slate-100 bg-white"
          ]}
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
          <span
            :if={(r = @state.round_results.results[id]) && r.correct?}
            class="pointer-events-none absolute right-4 -top-1 animate-float-up text-sm font-black text-emerald-500"
          >
            +{r.points}
          </span>
          <p :if={result = @state.round_results.results[id]} class="shrink-0 text-sm font-bold">
            <span :if={result.correct?} class="inline-flex items-center gap-1 text-emerald-600">
              <.icon name="hero-check" class="h-4 w-4" />
              {result.answer} <span class="text-emerald-500">+{result.points}</span>
            </span>
            <span :if={not result.correct?} class="inline-flex items-center gap-1 text-rose-500">
              <.icon name="hero-x-mark" class="h-4 w-4" />
              {result.answer}
            </span>
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

    # El podio reordena el top 3 visualmente como 2-1-3 (plata, oro, bronce)
    # para que el campeon quede al centro y mas alto.
    podium = Enum.take(ranking, 3)

    assigns =
      assigns
      |> assign(:ranking, ranking)
      |> assign(:podium, podium_layout(podium))
      |> assign(:rest, Enum.drop(ranking, 3))
      |> assign(:tie?, TriviaCrackQuiz.Game.tie?(assigns.state))

    ~H"""
    <div
      :if={@state.winner}
      id="confetti"
      phx-hook="Confetti"
      class="pointer-events-none fixed inset-0 z-50"
    />

    <div class="flex min-h-80 flex-col items-center justify-center py-8 text-center">
      <.icon name="hero-trophy" class="h-16 w-16 animate-bounce text-amber-500" />
      <p class="mt-3 text-sm font-black uppercase tracking-wide text-indigo-500">
        Partida finalizada
      </p>
      <h2 class="mt-1 text-3xl font-black text-slate-800">
        <%= cond do %>
          <% @tie? -> %>
            ¡Empate! 🤝
          <% @state.winner -> %>
            ¡Ganó {@state.winner.name}!
          <% true -> %>
            Sin ganador
        <% end %>
      </h2>

      <%!-- Podio: 2do a la izquierda, 1ro al centro (mas alto), 3ro a la derecha. --%>
      <div :if={@podium != []} class="mt-8 flex items-end justify-center gap-3 sm:gap-5">
        <div
          :for={{{id, player}, position} <- @podium}
          class="animate-pop-in flex w-24 flex-col items-center sm:w-28"
          style={"animation-delay: #{podium_delay(position)}ms"}
        >
          <span class={[
            "flex h-8 w-8 items-center justify-center rounded-full text-xs font-black text-white shadow",
            podium_medal_bg(position)
          ]}>
            {position}
          </span>
          <span class={[
            "mt-1 flex h-12 w-12 items-center justify-center rounded-full text-base font-black text-white shadow-lg",
            avatar_color(id)
          ]}>
            {avatar_initial(player.name)}
          </span>
          <p class="mt-1 w-full truncate text-sm font-bold text-slate-800">{player.name}</p>
          <p class="text-xs font-black text-indigo-600">{player.score} pts</p>
          <div class={[
            "mt-2 w-full rounded-t-xl",
            podium_bar(position)
          ]} />
        </div>
      </div>

      <div :if={@rest != []} class="mt-6 w-full max-w-md space-y-2 text-left">
        <div
          :for={{{id, player}, position} <- @rest}
          class="flex items-center gap-3 rounded-2xl border-2 border-slate-100 bg-slate-50 px-4 py-3"
        >
          <span class="w-8 text-center font-black text-slate-400">{position}º</span>
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

      <div class="mt-8 flex flex-col items-center gap-3 sm:flex-row">
        <button
          phx-click="reset"
          class="game-btn-primary flex items-center gap-2 px-8 py-4 text-lg"
        >
          <.icon name="hero-arrow-path" class="h-5 w-5" /> Jugar de nuevo
        </button>
        <button
          phx-click="leave"
          class="flex items-center gap-2 rounded-2xl border-2 border-slate-200 bg-white px-8 py-4 text-lg font-bold text-slate-600 transition hover:border-indigo-300 hover:bg-slate-50"
        >
          <.icon name="hero-home" class="h-5 w-5" /> Volver al lobby
        </button>
      </div>
    </div>
    """
  end

  # Reordena el top 3 como [2do, 1ro, 3ro] para el podio centrado. Con menos de
  # 3 jugadores conserva el orden disponible.
  defp podium_layout([first, second, third]), do: [second, first, third]
  defp podium_layout(podium), do: podium

  # Alturas del bloque del podio segun el puesto.
  defp podium_bar(1), do: "h-16 bg-gradient-to-b from-amber-300 to-amber-500"
  defp podium_bar(2), do: "h-12 bg-gradient-to-b from-slate-200 to-slate-400"
  defp podium_bar(3), do: "h-8 bg-gradient-to-b from-orange-300 to-orange-500"
  defp podium_bar(_), do: "h-6 bg-slate-200"

  # Entrada escalonada: primero el campeon, luego plata y bronce.
  defp podium_delay(1), do: 0
  defp podium_delay(2), do: 150
  defp podium_delay(3), do: 300
  defp podium_delay(_), do: 0

  # Color de la barra de tiempo segun cuanto queda: verde (>60%), ambar
  # (30-60%) y rojo (<30%), para subir la tension al acercarse el final.
  defp time_bar_color(time_left, total_seconds)
       when is_integer(time_left) and total_seconds > 0 do
    ratio = time_left / total_seconds

    cond do
      ratio > 0.6 -> "bg-gradient-to-r from-emerald-400 to-teal-500"
      ratio > 0.3 -> "bg-gradient-to-r from-amber-400 to-orange-500"
      true -> "bg-rose-500"
    end
  end

  defp time_bar_color(_time_left, _total), do: "bg-gradient-to-r from-indigo-500 to-purple-500"

  # Identidad visual de cada categoria, inspirada en Preguntados.
  # Las clases van como cadenas completas para que Tailwind las detecte.
  defp category_style(:arte),
    do: %{
      label: "Arte",
      icon: "hero-paint-brush",
      chip: "bg-rose-500",
      option_hover: "hover:border-rose-400"
    }

  defp category_style(:ciencia),
    do: %{
      label: "Ciencia",
      icon: "hero-beaker",
      chip: "bg-emerald-500",
      option_hover: "hover:border-emerald-400"
    }

  defp category_style(:deportes),
    do: %{
      label: "Deportes",
      icon: "hero-trophy",
      chip: "bg-orange-500",
      option_hover: "hover:border-orange-400"
    }

  defp category_style(:historia),
    do: %{
      label: "Historia",
      icon: "hero-building-library",
      chip: "bg-amber-500",
      option_hover: "hover:border-amber-400"
    }

  defp category_style(:tecnologia),
    do: %{
      label: "Tecnología",
      icon: "hero-cpu-chip",
      chip: "bg-sky-500",
      option_hover: "hover:border-sky-400"
    }

  defp category_style(:cultura_general),
    do: %{
      label: "Cultura General",
      icon: "hero-globe-americas",
      chip: "bg-violet-500",
      option_hover: "hover:border-violet-400"
    }

  defp category_style(other),
    do: %{
      label: to_string(other),
      icon: "hero-question-mark-circle",
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
  defp action_label(:correct), do: "acertó"
  defp action_label(:incorrect), do: "falló"
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

  defp podium_medal_bg(1), do: "bg-gradient-to-br from-amber-400 to-amber-600"
  defp podium_medal_bg(2), do: "bg-gradient-to-br from-slate-300 to-slate-500"
  defp podium_medal_bg(3), do: "bg-gradient-to-br from-orange-400 to-orange-600"
  defp podium_medal_bg(_), do: "bg-slate-400"

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
