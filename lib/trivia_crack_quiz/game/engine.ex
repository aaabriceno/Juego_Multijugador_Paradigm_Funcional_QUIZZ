defmodule TriviaCrackQuiz.Game do
  @moduledoc """
  Funciones puras para transformar el estado de una partida de trivia.

  Autor: Anthony Briceño
  """

  @min_players 3
  @round_time_ms 10_000
  @results_time_ms 5_000

  def new_state(questions \\ TriviaCrackQuiz.QuestionBank.load_questions()) do
    %{
      phase: :waiting,
      players: %{},
      round: 0,
      max_rounds: 10,
      round_started_at: nil,
      round_time_ms: @round_time_ms,
      results_time_ms: @results_time_ms,
      round_results: nil,
      questions: questions,
      current_question: nil,
      used_question_ids: MapSet.new(),
      last_category: nil,
      answers: %{},
      winner: nil
    }
  end

  # Si el jugador ya existia (por ejemplo tras refrescar la pagina), conserva
  # su puntaje y solo actualiza nombre y estado de conexion.
  def add_player(state, player_id, name) do
    player =
      case state.players[player_id] do
        nil -> %{name: name, score: 0, connected?: true, last_action: :joined}
        existing -> %{existing | name: name, connected?: true, last_action: :joined}
      end

    put_in(state, [:players, player_id], player)
  end

  def set_connected(state, player_id, connected?) do
    case state.players[player_id] do
      nil ->
        state

      player ->
        last_action = if connected?, do: :reconnected, else: :disconnected

        put_in(
          state,
          [:players, player_id],
          %{player | connected?: connected?, last_action: last_action}
        )
    end
  end

  def join(state, player_id, name), do: add_player(state, player_id, name)

  # Cuenta solo los jugadores conectados. El conteo visible (lobby, marcador)
  # usa esto para no mostrar "fantasmas" que cerraron la pestana.
  def connected_count(state) do
    Enum.count(state.players, fn {_id, player} -> player.connected? end)
  end

  # Saca al jugador de la partida de forma definitiva (boton "Salir"), a
  # diferencia de set_connected que solo lo marca desconectado. Tambien limpia
  # su respuesta pendiente de la ronda actual para no dejar rastros.
  def remove_player(state, player_id) do
    state
    |> Map.update!(:players, &Map.delete(&1, player_id))
    |> Map.update!(:answers, &Map.delete(&1, player_id))
  end

  def ready_to_start?(state) do
    map_size(state.players) >= @min_players
  end

  def start(state) do
    if ready_to_start?(state) do
      next_question(%{state | phase: :playing})
    else
      {:error, :not_enough_players, state}
    end
  end

  def next_question(%{round: round, max_rounds: max_rounds} = state) when round >= max_rounds do
    finish(state)
  end

  def next_question(state) do
    question = select_question(state)
    now = System.monotonic_time(:millisecond)

    %{
      state
      | phase: :playing,
        round: state.round + 1,
        round_started_at: now,
        current_question: question,
        used_question_ids: MapSet.put(state.used_question_ids, question.id),
        last_category: question.category,
        answers: %{},
        round_results: nil
    }
  end

  def next_round(state), do: next_question(state)

  def register_answer(
        %{phase: :playing, current_question: question} = state,
        player_id,
        submitted_answer
      )
      when not is_nil(question) do
    answered_at = System.monotonic_time(:millisecond)

    state
    |> put_in([:answers, player_id], %{answer: submitted_answer, answered_at: answered_at})
    |> put_in([:players, player_id, :last_action], :answered)
  end

  def register_answer(state, _player_id, _submitted_answer), do: state

  def answer(state, player_id, submitted_answer),
    do: register_answer(state, player_id, submitted_answer)

  # Solo espera a los jugadores conectados; un desconectado no debe bloquear
  # el cierre anticipado de la ronda.
  def all_players_answered?(state) do
    connected = Enum.count(state.players, fn {_id, player} -> player.connected? end)
    connected > 0 and map_size(state.answers) >= connected
  end

  def evaluate_round(%{phase: :playing, current_question: question} = state)
      when not is_nil(question) do
    results =
      Map.new(state.answers, fn {player_id, answer} ->
        correct? = normalize(answer.answer) == normalize(question.answer)

        points =
          if correct?, do: score_answer(state.round_started_at, answer.answered_at), else: 0

        {player_id, %{answer: answer.answer, correct?: correct?, points: points}}
      end)

    players =
      Enum.reduce(results, state.players, fn {player_id, result}, acc ->
        acc
        |> update_in([player_id, :score], &((&1 || 0) + result.points))
        |> put_in([player_id, :last_action], if(result.correct?, do: :correct, else: :incorrect))
      end)

    %{
      state
      | phase: :round_results,
        players: players,
        answers: %{},
        round_results: %{question: question, results: results}
    }
  end

  def evaluate_round(state), do: state

  # Tras contar puntos de una ronda: solo el ultimo jugador conectado debe
  # abandonar la partida; con 2 o mas conectados el juego sigue.
  def lone_player_remaining?(%{phase: :round_results} = state) do
    connected_count(state) == 1
  end

  def lone_player_remaining?(_state), do: false

  # Vuelve la sala a espera vacia para que otros puedan entrar de nuevo.
  def reopen_room(state) do
    new_state(state.questions)
  end

  # Vuelve a la sala de espera conservando a los jugadores registrados, con
  # puntajes en cero y banco de preguntas completo otra vez disponible.
  def reset(state) do
    players =
      Map.new(state.players, fn {player_id, player} ->
        {player_id, %{player | score: 0, last_action: :joined}}
      end)

    %{new_state(state.questions) | players: players}
  end

  def finish(state) do
    %{
      state
      | phase: :finished,
        current_question: nil,
        answers: %{},
        round_results: nil,
        winner: winner(state)
    }
  end

  # Estado que viaja a los clientes: sin banco de preguntas, sin la respuesta
  # correcta de la pregunta actual y sin el contenido de las respuestas ajenas
  # (solo se expone quien ya respondio). Todo lo que llegue al navegador es
  # visible en el WebSocket, aunque la vista no lo muestre.
  def visible_state(state) do
    state
    |> Map.drop([:questions, :round_timer_ref, :empty_room_timer_ref, :monitors])
    |> Map.update!(:answers, fn answers ->
      Map.new(answers, fn {player_id, _answer} -> {player_id, :answered} end)
    end)
    |> hide_current_answer()
  end

  defp hide_current_answer(%{current_question: nil} = state), do: state

  defp hide_current_answer(%{current_question: question} = state) do
    %{state | current_question: Map.delete(question, :answer)}
  end

  defp select_question(state) do
    state
    |> available_questions()
    |> avoid_last_category(state.last_category)
    |> Enum.random()
  end

  defp available_questions(state) do
    available =
      Enum.reject(state.questions, fn question ->
        MapSet.member?(state.used_question_ids, question.id)
      end)

    if available == [], do: state.questions, else: available
  end

  defp avoid_last_category(questions, nil), do: questions

  defp avoid_last_category(questions, last_category) do
    other_categories = Enum.reject(questions, &(&1.category == last_category))

    if other_categories == [], do: questions, else: other_categories
  end

  defp score_answer(nil, _answered_at), do: 100

  # Bonus de rapidez: 50 puntos si responde al instante, baja a 0 al agotar
  # los 10 segundos de la ronda.
  defp score_answer(started_at, answered_at) do
    elapsed = max(answered_at - started_at, 0)
    speed_bonus = max(50 - div(elapsed, 200), 0)
    100 + speed_bonus
  end

  defp winner(state) do
    state.players
    |> Enum.max_by(fn {_id, player} -> player.score end, fn -> nil end)
    |> case do
      nil -> nil
      {player_id, player} -> Map.put(player, :id, player_id)
    end
  end

  # Compara respuestas sin distinguir mayusculas, espacios sobrantes ni tildes:
  # "Dalí" y "dali" cuentan como la misma respuesta. La descomposicion NFD
  # separa cada letra acentuada en letra base + marca diacritica, y luego las
  # marcas se eliminan.
  defp normalize(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.downcase()
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{Mn}/u, "")
  end
end
