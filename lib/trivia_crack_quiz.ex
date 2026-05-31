defmodule TriviaCrackQuiz do
  @moduledoc """
  API publica del juego Trivia Crack Quiz Multiplayer.
  """

  def state, do: TriviaCrackQuiz.GameServer.state()

  def join(player_id, name), do: TriviaCrackQuiz.GameServer.join(player_id, name)

  def start_game, do: TriviaCrackQuiz.GameServer.start_game()

  def answer(player_id, submitted_answer),
    do: TriviaCrackQuiz.GameServer.answer(player_id, submitted_answer)
end
