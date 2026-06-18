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
      |> Game.answer("p3", "Dalo")
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
end
