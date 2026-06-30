defmodule TriviaCrackQuizTest do
  use ExUnit.Case

  alias TriviaCrackQuiz.Game

  test "requires at least 3 players to start" do
    state =
      Game.new_state(test_questions())
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")

    assert {:error, :not_enough_players, ^state} = Game.start(state)
  end

  test "starts when 3 players are registered" do
    state =
      Game.new_state(test_questions())
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")

    started = Game.start(state)

    assert started.phase == :playing
    assert started.round == 1
    assert started.current_question.id in [1]
    assert MapSet.member?(started.used_question_ids, started.current_question.id)
    assert started.last_category == started.current_question.category
  end

  test "adds points when the answer is correct" do
    state =
      Game.new_state(test_questions())
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.start()
      |> Game.answer("p1", "marte")
      |> Game.evaluate_round()

    assert state.players["p1"].score >= 100
    assert state.answers == %{}
  end

  test "evaluate_round enters round_results phase with per-player results" do
    state =
      Game.new_state(test_questions())
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.start()
      |> Game.answer("p1", "Marte")
      |> Game.answer("p2", "Venus")
      |> Game.evaluate_round()

    assert state.phase == :round_results
    assert state.round_results.question.answer == "Marte"
    assert state.round_results.results["p1"].correct?
    refute state.round_results.results["p2"].correct?
    refute Map.has_key?(state.round_results.results, "p3")

    next_state = Game.next_question(state)

    assert next_state.phase == :playing
    assert next_state.round_results == nil
  end

  test "visible_state hides the correct answer and other players' answers" do
    state =
      Game.new_state(test_questions())
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.start()
      |> Game.answer("p1", "Marte")

    visible = Game.visible_state(state)

    refute Map.has_key?(visible, :questions)
    refute Map.has_key?(visible.current_question, :answer)
    assert visible.answers == %{"p1" => :answered}
  end

  test "does not repeat used questions while there are available questions" do
    state =
      Game.new_state(mixed_questions())
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.start()

    first_id = state.current_question.id

    next_state =
      state
      |> Game.evaluate_round()
      |> Game.next_question()

    assert next_state.current_question.id != first_id
    assert MapSet.size(next_state.used_question_ids) == 2
  end

  test "avoids repeating the same category in consecutive rounds when possible" do
    state =
      Game.new_state(mixed_questions())
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.start()

    previous_category = state.current_question.category

    next_state =
      state
      |> Game.evaluate_round()
      |> Game.next_question()

    assert next_state.current_question.category != previous_category
  end

  test "finishes when max rounds is reached" do
    state =
      Game.new_state(mixed_questions())
      |> Map.put(:max_rounds, 2)
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.start()
      |> Game.next_question()
      |> Game.next_question()

    assert state.phase == :finished
    assert state.current_question == nil
  end

  test "accepts answers regardless of accents and casing" do
    questions = [
      %{
        id: 1,
        type: :quick_answer,
        category: :arte,
        text: "¿Cuál es el apellido del pintor de La persistencia de la memoria?",
        options: [],
        answer: "Dalí"
      }
    ]

    state =
      Game.new_state(questions)
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.start()
      |> Game.answer("p1", "dali")
      |> Game.answer("p2", "  DALÍ ")
      |> Game.answer("p3", "Picasso")
      |> Game.evaluate_round()

    assert state.round_results.results["p1"].correct?
    assert state.round_results.results["p2"].correct?
    refute state.round_results.results["p3"].correct?
  end

  test "add_player keeps the score when the player rejoins" do
    state =
      Game.new_state(test_questions())
      |> Game.join("p1", "Ana")
      |> put_in([:players, "p1", :score], 150)
      |> Game.add_player("p1", "Ana Maria")

    assert state.players["p1"].score == 150
    assert state.players["p1"].name == "Ana Maria"
    assert state.players["p1"].connected?
    assert map_size(state.players) == 1
  end

  test "set_connected marks disconnection and reconnection" do
    state =
      Game.new_state(test_questions())
      |> Game.join("p1", "Ana")
      |> Game.set_connected("p1", false)

    assert state.players["p1"].connected? == false
    assert state.players["p1"].last_action == :disconnected

    reconnected = Game.set_connected(state, "p1", true)

    assert reconnected.players["p1"].connected?
    assert reconnected.players["p1"].last_action == :reconnected

    assert Game.set_connected(state, "ghost", false) == state
  end

  test "all_players_answered? ignores disconnected players" do
    state =
      Game.new_state(test_questions())
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.start()
      |> Game.set_connected("p3", false)
      |> Game.answer("p1", "Marte")

    refute Game.all_players_answered?(state)

    assert state
           |> Game.answer("p2", "Venus")
           |> Game.all_players_answered?()
  end

  test "reset returns to waiting keeping players with zeroed scores" do
    state =
      Game.new_state(mixed_questions())
      |> Map.put(:max_rounds, 1)
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.start()
      |> Game.answer("p1", "A")
      |> Game.evaluate_round()
      |> Game.next_question()

    assert state.phase == :finished

    reset_state = Game.reset(state)

    assert reset_state.phase == :waiting
    assert reset_state.round == 0
    assert reset_state.winner == nil
    assert reset_state.used_question_ids == MapSet.new()
    assert Map.keys(reset_state.players) |> Enum.sort() == ["p1", "p2", "p3"]
    assert Enum.all?(reset_state.players, fn {_id, player} -> player.score == 0 end)
  end

  test "filter by a single category keeps only that category" do
    state = Game.new_state(mixed_questions(), %{categories: [:history]})

    assert state.filters == %{categories: [:history], types: [], surprise: false}
    assert Enum.all?(state.questions, &(&1.category == :history))
    # El banco completo se conserva para poder reabrir/reiniciar.
    assert length(state.all_questions) == length(mixed_questions())
  end

  test "filter by several categories keeps all of them" do
    state = Game.new_state(mixed_questions(), %{categories: [:history, :science]})

    assert Enum.all?(state.questions, &(&1.category in [:history, :science]))
    assert length(state.questions) == length(mixed_questions())
  end

  test "empty filters keep every question" do
    state = Game.new_state(mixed_questions(), %{})

    assert state.filters == %{categories: [], types: [], surprise: false}
    assert length(state.questions) == length(mixed_questions())
  end

  test "legacy :all and single-atom category still work" do
    assert Game.new_state(mixed_questions(), :all).filters ==
             %{categories: [], types: [], surprise: false}

    single = Game.new_state(mixed_questions(), :history)
    assert single.filters == %{categories: [:history], types: [], surprise: false}
    assert Enum.all?(single.questions, &(&1.category == :history))
  end

  test "filter by question type keeps only that type" do
    questions = typed_questions()
    state = Game.new_state(questions, %{types: [:true_false]})

    assert Enum.all?(state.questions, &(&1.type == :true_false))
    assert state.questions != []
  end

  test "filter by several types keeps all of them" do
    questions = typed_questions()
    state = Game.new_state(questions, %{types: [:true_false, :quick_answer]})

    assert Enum.all?(state.questions, &(&1.type in [:true_false, :quick_answer]))
  end

  test "combined category and type filter applies both" do
    questions = typed_questions()
    state = Game.new_state(questions, %{categories: [:science], types: [:multiple_choice]})

    assert Enum.all?(state.questions, &(&1.category == :science and &1.type == :multiple_choice))
    assert state.questions != []
  end

  test "filters with no matching question fall back to the whole bank" do
    questions = typed_questions()
    # Combinacion inexistente: historia + escribir.
    state = Game.new_state(questions, %{categories: [:history], types: [:quick_answer]})

    assert length(state.questions) == length(questions)
  end

  test "reset and reopen_room keep the room filters" do
    state =
      Game.new_state(mixed_questions(), %{categories: [:science]})
      |> Game.join("p1", "Ana")

    assert Game.reset(state).filters == %{categories: [:science], types: [], surprise: false}

    assert Game.reopen_room(state).filters == %{
             categories: [:science],
             types: [],
             surprise: false
           }

    assert Enum.all?(Game.reset(state).questions, &(&1.category == :science))
  end

  test "available_categories and available_types list what is in the bank" do
    assert Game.available_categories(mixed_questions()) == [:history, :science]

    assert Game.available_types(typed_questions()) ==
             [:multiple_choice, :quick_answer, :true_false]
  end

  test "surprise enabled reserves exactly one surprise round within range" do
    state = Game.new_state(mixed_questions(), %{surprise: true})

    assert state.filters.surprise == true
    assert state.surprise_round in 1..state.max_rounds
  end

  test "surprise disabled has no surprise round" do
    state = Game.new_state(mixed_questions(), %{categories: [:science]})
    assert state.surprise_round == nil
  end

  test "only the surprise round question is flagged as surprise" do
    # Fuerza la sorpresa en la ronda 1 para una verificacion determinista.
    state =
      Game.new_state(mixed_questions(), %{surprise: true})
      |> Map.put(:surprise_round, 1)
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.start()

    assert state.current_question.surprise == true

    next = Game.next_question(Game.evaluate_round(state))
    assert next.current_question.surprise == false
  end

  test "surprise question can come from any category, ignoring the category filter" do
    # Sala filtrada a ciencia, pero la ronda sorpresa usa todo el banco.
    questions = typed_questions()

    categories =
      for _ <- 1..40 do
        Game.new_state(questions, %{categories: [:ciencia], surprise: true})
        |> Map.put(:surprise_round, 1)
        |> Game.join("p1", "A")
        |> Game.join("p2", "B")
        |> Game.join("p3", "C")
        |> Game.start()
        |> Map.fetch!(:current_question)
        |> Map.fetch!(:category)
      end
      |> Enum.uniq()

    # Con 40 intentos sobre un banco con varias categorias, debe aparecer al
    # menos una categoria distinta de :ciencia (la sorpresa ignora el filtro).
    assert Enum.any?(categories, &(&1 != :ciencia))
  end

  test "a correct surprise answer scores exactly 20% more than a normal one" do
    base_question = [
      %{
        id: 1,
        type: :multiple_choice,
        category: :ciencia,
        text: "q",
        options: ["A", "B"],
        answer: "A"
      }
    ]

    # Anula el bonus de rapidez en ambos casos colocando el inicio de ronda
    # muy en el pasado: asi la base es fija (100) y la comparacion es exacta.
    long_ago = System.monotonic_time(:millisecond) - 1_000_000

    score = fn extra ->
      Game.new_state(base_question, extra)
      |> Map.put(:surprise_round, if(extra == %{surprise: true}, do: 1, else: nil))
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.start()
      |> Map.put(:round_started_at, long_ago)
      |> Game.answer("p1", "A")
      |> Game.evaluate_round()
      |> get_in([:round_results, :results, "p1", :points])
    end

    normal_pts = score.(%{})
    surprise_pts = score.(%{surprise: true})

    assert normal_pts == 100
    assert surprise_pts == 120
  end

  test "correct_answer? accepts the official answer and listed alternatives" do
    question = %{type: :quick_answer, answer: "38", accept: ["treinta y ocho"]}

    assert Game.correct_answer?(question, "38")
    assert Game.correct_answer?(question, "  Treinta y Ocho ")
    refute Game.correct_answer?(question, "39")
  end

  test "correct_answer? tolerates a single typo only for quick_answer" do
    quick = %{type: :quick_answer, answer: "Elixir"}
    multiple = %{type: :multiple_choice, answer: "Marte"}

    assert Game.correct_answer?(quick, "elixr")
    assert Game.correct_answer?(quick, "elexir")
    refute Game.correct_answer?(quick, "python")

    # En opcion multiple (se elige con clic) no se tolera el typo.
    refute Game.correct_answer?(multiple, "mart")
    assert Game.correct_answer?(multiple, "marte")
  end

  test "quick_answer questions get extra time over the base" do
    quick = %{type: :quick_answer}
    multiple = %{type: :multiple_choice}

    assert Game.question_time_ms(quick) > Game.question_time_ms(multiple)
    assert Game.question_time_ms(quick) - Game.question_time_ms(multiple) == 4_000
  end

  test "evaluate_round uses flexible matching for typed answers" do
    questions = [
      %{
        id: 1,
        type: :quick_answer,
        category: :tecnologia,
        text: "Lenguaje funcional sobre la BEAM",
        options: [],
        answer: "Elixir"
      }
    ]

    state =
      Game.new_state(questions)
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.start()
      |> Game.answer("p1", "elixr")
      |> Game.answer("p2", "Elixir")
      |> Game.answer("p3", "java")
      |> Game.evaluate_round()

    assert state.round_results.results["p1"].correct?
    assert state.round_results.results["p2"].correct?
    refute state.round_results.results["p3"].correct?
  end

  test "visible_state never leaks answer nor accept variants of the current question" do
    questions = [
      %{
        id: 1,
        type: :quick_answer,
        category: :tecnologia,
        text: "Pregunta abierta",
        options: [],
        answer: "Elixir",
        accept: ["elixir lang"]
      }
    ]

    visible =
      Game.new_state(questions)
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.start()
      |> Game.visible_state()

    refute Map.has_key?(visible.current_question, :answer)
    refute Map.has_key?(visible.current_question, :accept)
  end

  test "add_player sanitizes the name: trims, caps length and falls back when blank" do
    state =
      Game.new_state(test_questions())
      |> Game.join("p1", "   ")
      |> Game.join("p2", "  Ana María  ")
      |> Game.join("p3", String.duplicate("x", 50))

    assert state.players["p1"].name == "Jugador"
    assert state.players["p2"].name == "Ana María"
    assert String.length(state.players["p3"].name) == 20
  end

  test "tie? is true when two players share the top score above zero" do
    state =
      Game.new_state(test_questions())
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> put_in([:players, "p1", :score], 200)
      |> put_in([:players, "p2", :score], 200)
      |> put_in([:players, "p3", :score], 100)

    assert Game.tie?(state)
  end

  test "tie? is false with a single leader" do
    state =
      Game.new_state(test_questions())
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> put_in([:players, "p1", :score], 300)
      |> put_in([:players, "p2", :score], 100)

    refute Game.tie?(state)
  end

  test "tie? is false when everyone is tied at zero" do
    state =
      Game.new_state(test_questions())
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")

    refute Game.tie?(state)
  end

  test "remove_player deletes the player and their pending answer" do
    state =
      Game.new_state(test_questions())
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.start()
      |> Game.answer("p1", "Marte")
      |> Game.remove_player("p1")

    refute Map.has_key?(state.players, "p1")
    refute Map.has_key?(state.answers, "p1")
    assert map_size(state.players) == 2
  end

  test "connected_count ignores disconnected players" do
    state =
      Game.new_state(test_questions())
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.set_connected("p3", false)

    assert map_size(state.players) == 3
    assert Game.connected_count(state) == 2
  end

  test "lone_player_remaining? is true only with one connected player in round_results" do
    lone =
      Game.new_state(test_questions())
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.start()
      |> Game.set_connected("p2", false)
      |> Game.set_connected("p3", false)
      |> Game.evaluate_round()

    assert Game.lone_player_remaining?(lone)

    duo =
      Game.new_state(test_questions())
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.start()
      |> Game.evaluate_round()

    refute Game.lone_player_remaining?(duo)
  end

  test "reopen_room resets to empty waiting state" do
    state =
      Game.new_state(test_questions())
      |> Game.join("p1", "Ana")
      |> Game.join("p2", "Luis")
      |> Game.join("p3", "Mia")
      |> Game.start()
      |> Game.evaluate_round()

    reopened = Game.reopen_room(state)

    assert reopened.phase == :waiting
    assert reopened.players == %{}
    assert reopened.round == 0
    assert reopened.round_results == nil
  end

  defp test_questions do
    [
      %{
        id: 1,
        type: :multiple_choice,
        category: :science,
        text: "Que planeta es conocido como el planeta rojo?",
        options: ["Venus", "Marte", "Jupiter", "Saturno"],
        answer: "Marte"
      }
    ]
  end

  defp mixed_questions do
    [
      %{
        id: 1,
        type: :multiple_choice,
        category: :science,
        text: "Pregunta de ciencia 1",
        options: ["A", "B", "C", "D"],
        answer: "A"
      },
      %{
        id: 2,
        type: :multiple_choice,
        category: :history,
        text: "Pregunta de historia 1",
        options: ["A", "B", "C", "D"],
        answer: "A"
      },
      %{
        id: 3,
        type: :multiple_choice,
        category: :science,
        text: "Pregunta de ciencia 2",
        options: ["A", "B", "C", "D"],
        answer: "A"
      }
    ]
  end

  # Banco variado en categorias y tipos para probar los filtros combinados.
  defp typed_questions do
    [
      %{
        id: 1,
        type: :multiple_choice,
        category: :science,
        text: "c1",
        options: ["A"],
        answer: "A"
      },
      %{
        id: 2,
        type: :true_false,
        category: :science,
        text: "c2",
        options: ["V", "F"],
        answer: "V"
      },
      %{id: 3, type: :quick_answer, category: :science, text: "c3", options: [], answer: "x"},
      %{
        id: 4,
        type: :multiple_choice,
        category: :history,
        text: "h1",
        options: ["A"],
        answer: "A"
      },
      %{
        id: 5,
        type: :true_false,
        category: :history,
        text: "h2",
        options: ["V", "F"],
        answer: "F"
      }
    ]
  end
end
