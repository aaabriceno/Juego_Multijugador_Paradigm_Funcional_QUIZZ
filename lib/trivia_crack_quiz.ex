defmodule TriviaCrackQuiz do
  @moduledoc """
  API publica del juego Trivia Crack Quiz Multiplayer.
  """

  @doc """
  Devuelve el estado visible de la partida actual.
  """
  def state, do: TriviaCrackQuiz.GameServer.state()

  @doc """
  Registra un jugador en la partida.
  """
  def join(player_id, name), do: TriviaCrackQuiz.GameServer.join(player_id, name)

  @doc """
  Inicia la partida si existen al menos 3 jugadores.
  """
  def start_game, do: TriviaCrackQuiz.GameServer.start_game()

  @doc """
  Envia la respuesta de un jugador.
  """
  def answer(player_id, submitted_answer),
    do: TriviaCrackQuiz.GameServer.answer(player_id, submitted_answer)
end
