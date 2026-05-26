defmodule TriviaCrackQuiz.Game do
  @moduledoc """
  Funciones puras para transformar el estado de una partida de trivia.
  """

  @min_players 3

  def new_state(questions \\ TriviaCrackQuiz.QuestionBank.sample_questions()) do
    %{
      phase: :waiting,
      players: %{},
      round: 0,
      max_rounds: 10,
      questions: questions,
      current_question: nil,
      answers: %{}
    }
  end

  def join(state, player_id, name) do
    player = %{name: name, score: 0, connected?: true, last_action: :joined}

    put_in(state, [:players, player_id], player)
  end

  def ready_to_start?(state) do
    map_size(state.players) >= @min_players
  end

  def start(state) do
    if ready_to_start?(state) do
      next_round(%{state | phase: :playing})
    else
      {:error, :not_enough_players, state}
    end
  end

  def next_round(%{round: round, max_rounds: max_rounds} = state) when round >= max_rounds do
    %{state | phase: :finished, current_question: nil, answers: %{}}
  end

  def next_round(state) do
    question = Enum.at(state.questions, rem(state.round, length(state.questions)))

    %{
      state
      | round: state.round + 1,
        current_question: question,
        answers: %{}
    }
  end

  def answer(%{phase: :playing, current_question: question} = state, player_id, submitted_answer)
      when not is_nil(question) do
    correct? = normalize(submitted_answer) == normalize(question.answer)
    points = if correct?, do: 100, else: 0

    state
    |> put_in([:answers, player_id], %{answer: submitted_answer, correct?: correct?})
    |> update_in([:players, player_id, :score], &((&1 || 0) + points))
    |> put_in([:players, player_id, :last_action], :answered)
  end

  def answer(state, _player_id, _submitted_answer), do: state

  def visible_state(state) do
    Map.drop(state, [:questions])
  end

  defp normalize(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.downcase()
  end
end
