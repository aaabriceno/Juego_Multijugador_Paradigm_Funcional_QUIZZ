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
