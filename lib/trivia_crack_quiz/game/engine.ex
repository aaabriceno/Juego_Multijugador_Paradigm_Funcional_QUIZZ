defmodule TriviaCrackQuiz.Game do
  @moduledoc """
  Funciones puras para transformar el estado de una partida de trivia.
  """

  @min_players 3
  @round_time_ms 20_000

  def new_state(questions \\ TriviaCrackQuiz.QuestionBank.load_questions()) do
    %{
      phase: :waiting,
      players: %{},
      round: 0,
      max_rounds: 10,
      round_started_at: nil,
      round_time_ms: @round_time_ms,
      questions: questions,
      current_question: nil,
      answers: %{},
      winner: nil
    }
  end

  def add_player(state, player_id, name) do
    player = %{name: name, score: 0, connected?: true, last_action: :joined}

    put_in(state, [:players, player_id], player)
  end

  def join(state, player_id, name), do: add_player(state, player_id, name)

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
    question = Enum.at(state.questions, rem(state.round, length(state.questions)))
    now = System.monotonic_time(:millisecond)

    %{
      state
      | round: state.round + 1,
        round_started_at: now,
        current_question: question,
        answers: %{}
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

  def all_players_answered?(state) do
    map_size(state.players) > 0 and map_size(state.answers) >= map_size(state.players)
  end

  def evaluate_round(%{phase: :playing, current_question: question} = state)
      when not is_nil(question) do
    players =
      Enum.reduce(state.answers, state.players, fn {player_id, answer}, acc ->
        correct? = normalize(answer.answer) == normalize(question.answer)

        points =
          if correct?, do: score_answer(state.round_started_at, answer.answered_at), else: 0

        acc
        |> update_in([player_id, :score], &((&1 || 0) + points))
        |> put_in([player_id, :last_action], if(correct?, do: :correct, else: :incorrect))
      end)

    %{state | players: players, answers: %{}}
  end

  def evaluate_round(state), do: state

  def finish(state) do
    %{state | phase: :finished, current_question: nil, answers: %{}, winner: winner(state)}
  end

  def visible_state(state) do
    Map.drop(state, [:questions])
  end

  defp score_answer(nil, _answered_at), do: 100

  defp score_answer(started_at, answered_at) do
    elapsed = max(answered_at - started_at, 0)
    speed_bonus = max(50 - div(elapsed, 400), 0)
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

  defp normalize(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.downcase()
  end
end
