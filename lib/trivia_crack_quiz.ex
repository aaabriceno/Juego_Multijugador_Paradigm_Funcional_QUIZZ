defmodule TriviaCrackQuiz do
  @moduledoc """
  API publica del juego Trivia Crack Quiz Multiplayer.

  Todas las operaciones reciben el `room_id` de la sala sobre la que actuan,
  ya que pueden coexistir varias partidas a la vez.
  """

  def state(room_id), do: TriviaCrackQuiz.GameServer.state(room_id)

  def join(room_id, player_id, name),
    do: TriviaCrackQuiz.GameServer.join(room_id, player_id, name)

  def start_game(room_id), do: TriviaCrackQuiz.GameServer.start_game(room_id)

  def answer(room_id, player_id, submitted_answer),
    do: TriviaCrackQuiz.GameServer.answer(room_id, player_id, submitted_answer)
end
