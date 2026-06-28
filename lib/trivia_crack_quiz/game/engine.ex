defmodule TriviaCrackQuiz.Game do
  @moduledoc """
  Funciones puras para transformar el estado de una partida de trivia.

  Autor: Anthony Briceño
  """

  @min_players 3
  @round_time_ms 10_000
  @results_time_ms 5_000
  # Las preguntas de respuesta por teclado (quick_answer) son mas dificiles de
  # contestar a tiempo, asi que reciben segundos extra sobre el tiempo base.
  @quick_answer_extra_ms 4_000

  @doc """
  Tiempo (ms) que dura una ronda segun el tipo de pregunta. Las de respuesta
  abierta (`:quick_answer`) reciben tiempo extra; el resto usa el tiempo base.
  """
  def question_time_ms(%{type: :quick_answer}), do: @round_time_ms + @quick_answer_extra_ms
  def question_time_ms(_question), do: @round_time_ms

  @doc """
  Crea el estado inicial de una partida.

  `filters` limita el banco de preguntas con dos listas opcionales:

    * `:categories` - solo preguntas de esas categorias (lista de atoms)
    * `:types` - solo preguntas de esos tipos (lista de atoms)

  Una lista vacia no restringe (cuenta como "todas"). Si la combinacion de
  filtros deja el banco sin preguntas, se usa el banco completo para no quedar
  sin nada que preguntar. Se aceptan tambien las formas antiguas: un atom de
  categoria o `:all`.
  """
  @max_rounds 10
  # Una respuesta sorpresa correcta da 20% mas de puntos que una normal.
  @surprise_bonus 1.2

  def new_state(
        questions \\ TriviaCrackQuiz.QuestionBank.load_questions(),
        filters \\ %{}
      ) do
    filters = normalize_filters(filters)

    %{
      phase: :waiting,
      players: %{},
      round: 0,
      max_rounds: @max_rounds,
      round_started_at: nil,
      round_time_ms: @round_time_ms,
      results_time_ms: @results_time_ms,
      round_results: nil,
      filters: filters,
      # Si la sala activo "sorpresa", se reserva una ronda al azar para una
      # pregunta de categoria aleatoria (ignora el filtro de categorias).
      surprise_round: surprise_round(filters[:surprise], @max_rounds),
      all_questions: questions,
      questions: filter_questions(questions, filters),
      current_question: nil,
      used_question_ids: MapSet.new(),
      last_category: nil,
      answers: %{},
      winner: nil
    }
  end

  # Elige en que ronda caera la unica pregunta sorpresa, o nil si no hay.
  defp surprise_round(true, max_rounds), do: Enum.random(1..max_rounds)
  defp surprise_round(_other, _max_rounds), do: nil

  @doc "Lista de categorias disponibles en el banco de preguntas dado."
  def available_categories(questions) do
    questions
    |> Enum.map(& &1.category)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc "Lista de tipos de pregunta disponibles en el banco dado."
  def available_types(questions) do
    questions
    |> Enum.map(& &1.type)
    |> Enum.uniq()
    |> Enum.sort()
  end

  # Acepta el formato nuevo (mapa con :categories/:types) y los viejos (un atom
  # de categoria, o :all) para no romper llamadas existentes.
  defp normalize_filters(:all), do: %{categories: [], types: [], surprise: false}
  defp normalize_filters(nil), do: %{categories: [], types: [], surprise: false}

  defp normalize_filters(%{} = filters) do
    %{
      categories: List.wrap(Map.get(filters, :categories, [])),
      types: List.wrap(Map.get(filters, :types, [])),
      surprise: Map.get(filters, :surprise, false) == true
    }
  end

  defp normalize_filters(category) when is_atom(category),
    do: %{categories: [category], types: [], surprise: false}

  # Filtra el banco por categorias y tipos. Cada lista vacia no restringe. Si la
  # combinacion deja cero preguntas, devuelve el banco completo.
  defp filter_questions(questions, %{categories: categories, types: types}) do
    filtered =
      Enum.filter(questions, fn q ->
        category_ok?(q, categories) and type_ok?(q, types)
      end)

    if filtered == [], do: questions, else: filtered
  end

  defp category_ok?(_question, []), do: true
  defp category_ok?(question, categories), do: question.category in categories

  defp type_ok?(_question, []), do: true
  defp type_ok?(question, types), do: question.type in types

  @max_name_length 20

  # Si el jugador ya existia (por ejemplo tras refrescar la pagina), conserva
  # su puntaje y solo actualiza nombre y estado de conexion. El nombre se
  # saneca aqui (en el servidor) para no depender de la validacion del
  # navegador: sin espacios sobrantes, con tope de largo y un valor por
  # defecto si llega vacio.
  def add_player(state, player_id, name) do
    clean_name = sanitize_name(name)

    player =
      case state.players[player_id] do
        nil -> %{name: clean_name, score: 0, connected?: true, last_action: :joined}
        existing -> %{existing | name: clean_name, connected?: true, last_action: :joined}
      end

    put_in(state, [:players, player_id], player)
  end

  defp sanitize_name(name) do
    cleaned =
      name
      |> to_string()
      |> String.trim()
      |> String.slice(0, @max_name_length)

    if cleaned == "", do: "Jugador", else: cleaned
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
    next_round_number = state.round + 1
    surprise? = next_round_number == Map.get(state, :surprise_round)
    question = select_question(state, surprise?) |> Map.put(:surprise, surprise?)
    now = System.monotonic_time(:millisecond)

    %{
      state
      | phase: :playing,
        round: next_round_number,
        round_started_at: now,
        round_time_ms: question_time_ms(question),
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
    surprise? = Map.get(question, :surprise, false)

    results =
      Map.new(state.answers, fn {player_id, answer} ->
        correct? = correct_answer?(question, answer.answer)

        points =
          if correct? do
            base = score_answer(state.round_started_at, answer.answered_at)
            if surprise?, do: round(base * @surprise_bonus), else: base
          else
            0
          end

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

  # Vuelve la sala a espera vacia para que otros puedan entrar de nuevo,
  # conservando la categoria elegida al crearla.
  def reopen_room(state) do
    new_state(all_questions(state), filters(state))
  end

  # Vuelve a la sala de espera conservando a los jugadores registrados, con
  # puntajes en cero, el banco completo de su categoria otra vez disponible y
  # el mismo filtro de categoria.
  def reset(state) do
    players =
      Map.new(state.players, fn {player_id, player} ->
        {player_id, %{player | score: 0, last_action: :joined}}
      end)

    %{new_state(all_questions(state), filters(state)) | players: players}
  end

  # Banco completo original (sin filtrar) y categoria de la sala. Tienen valores
  # por defecto para tolerar estados viejos que no traian estos campos.
  defp all_questions(state), do: Map.get(state, :all_questions) || state.questions
  defp filters(state), do: Map.get(state, :filters, %{categories: [], types: []})

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
    |> Map.drop([:questions, :all_questions, :round_timer_ref, :empty_room_timer_ref, :monitors])
    |> Map.update!(:answers, fn answers ->
      Map.new(answers, fn {player_id, _answer} -> {player_id, :answered} end)
    end)
    |> hide_current_answer()
  end

  defp hide_current_answer(%{current_question: nil} = state), do: state

  defp hide_current_answer(%{current_question: question} = state) do
    # No enviar al navegador la respuesta correcta ni las alternativas validas;
    # la pista (hint) si puede viajar porque el jugador puede revelarla.
    %{state | current_question: Map.drop(question, [:answer, :accept])}
  end

  # Pregunta normal: del banco ya filtrado por la sala, evitando repetir
  # categoria consecutiva.
  defp select_question(state, false) do
    state
    |> available_questions(state.questions)
    |> avoid_last_category(state.last_category)
    |> Enum.random()
  end

  # Pregunta sorpresa: categoria aleatoria entre TODAS (ignora el filtro de
  # categorias), pero respeta los tipos elegidos en la sala.
  defp select_question(state, true) do
    pool =
      state.all_questions
      |> Enum.filter(&type_ok?(&1, state.filters.types))
      |> case do
        [] -> state.all_questions
        filtered -> filtered
      end

    available_questions(state, pool) |> Enum.random()
  end

  # Quita las preguntas ya usadas; si no queda ninguna, reusa el pool completo.
  defp available_questions(state, pool) do
    available =
      Enum.reject(pool, fn question ->
        MapSet.member?(state.used_question_ids, question.id)
      end)

    if available == [], do: pool, else: available
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

  @doc """
  True si la partida termino en empate: dos o mas jugadores comparten el
  puntaje mas alto y ese puntaje es mayor que cero (si todos quedaron en 0
  nadie compitio, no se considera empate de campeones).
  """
  def tie?(state) do
    case top_scorers(state) do
      [] -> false
      [_single] -> false
      [{_id, player} | _] = leaders -> length(leaders) > 1 and player.score > 0
    end
  end

  # Jugadores que comparten el puntaje mas alto.
  defp top_scorers(state) when map_size(state.players) == 0, do: []

  defp top_scorers(state) do
    max_score =
      state.players
      |> Enum.map(fn {_id, player} -> player.score end)
      |> Enum.max()

    Enum.filter(state.players, fn {_id, player} -> player.score == max_score end)
  end

  @doc """
  Decide si la respuesta enviada es correcta para la pregunta.

  Acepta la respuesta oficial (`answer`) y cualquier variante listada en
  `accept`. En preguntas de tipo `:quick_answer` (respuesta por teclado) ademas
  tolera errores de tipeo pequenos: si el texto difiere en a lo mas un caracter
  de alguna respuesta valida, se da por correcto. Los tipos de opcion (clic) se
  comparan de forma exacta normalizada, sin tolerancia, porque no se tipean.
  """
  def correct_answer?(question, submitted) do
    submitted_norm = normalize(submitted)
    valid = accepted_answers(question)

    cond do
      Enum.any?(valid, &(&1 == submitted_norm)) ->
        true

      question.type == :quick_answer ->
        # Solo respuestas tipeadas toleran un error de tipeo. Se evita en
        # respuestas muy cortas (1-2 letras) para no aceptar cosas erroneas.
        Enum.any?(valid, fn answer ->
          String.length(answer) >= 3 and levenshtein(answer, submitted_norm) <= 1
        end)

      true ->
        false
    end
  end

  # Lista normalizada de respuestas validas: la oficial mas las alternativas.
  defp accepted_answers(question) do
    extra = Map.get(question, :accept) || []

    [question.answer | extra]
    |> Enum.map(&normalize/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  # Distancia de edicion (Levenshtein): minimo de inserciones, borrados o
  # sustituciones de un caracter para convertir una cadena en otra. Se usa para
  # tolerar un error de tipeo. Implementacion clasica por programacion dinamica,
  # calculando la matriz fila por fila.
  defp levenshtein(a, b) do
    b_chars = String.graphemes(b)
    # Fila 0: costo de transformar "" en cada prefijo de b (puros insertados).
    first_row = Enum.to_list(0..length(b_chars))

    a
    |> String.graphemes()
    |> Enum.with_index(1)
    |> Enum.reduce(first_row, fn {char_a, i}, prev_row ->
      build_row(char_a, b_chars, prev_row, i)
    end)
    |> List.last()
  end

  # Calcula una fila de la matriz de Levenshtein a partir de la fila anterior.
  defp build_row(char_a, b_chars, prev_row, row_index) do
    b_chars
    |> Enum.zip(Enum.zip(prev_row, tl(prev_row)))
    |> Enum.reduce([row_index], fn {char_b, {diag, up}}, [left | _] = acc ->
      cost = if char_a == char_b, do: 0, else: 1
      value = Enum.min([left + 1, up + 1, diag + cost])
      [value | acc]
    end)
    |> Enum.reverse()
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
