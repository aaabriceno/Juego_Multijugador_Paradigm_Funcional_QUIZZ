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
    assert started.current_question.id == 1
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
end
