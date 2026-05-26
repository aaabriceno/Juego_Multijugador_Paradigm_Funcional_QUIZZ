defmodule TriviaCrackQuiz.GameServer do
  @moduledoc """
  Actor principal de la partida.

  Mantiene un unico estado coherente y recibe eventos de jugadores mediante
  paso de mensajes.
  """

  use GenServer

  alias TriviaCrackQuiz.Game

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, Game.new_state(), name: __MODULE__)
  end

  def join(player_id, name) do
    GenServer.call(__MODULE__, {:join, player_id, name})
  end

  def start_game do
    GenServer.call(__MODULE__, :start_game)
  end

  def answer(player_id, submitted_answer) do
    GenServer.call(__MODULE__, {:answer, player_id, submitted_answer})
  end

  def next_round do
    GenServer.call(__MODULE__, :next_round)
  end

  def state do
    GenServer.call(__MODULE__, :state)
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:join, player_id, name}, _from, state) do
    new_state = Game.join(state, player_id, name)
    {:reply, Game.visible_state(new_state), new_state}
  end

  def handle_call(:start_game, _from, state) do
    case Game.start(state) do
      {:error, reason, unchanged_state} ->
        {:reply, {:error, reason, Game.visible_state(unchanged_state)}, unchanged_state}

      new_state ->
        {:reply, {:ok, Game.visible_state(new_state)}, new_state}
    end
  end

  def handle_call({:answer, player_id, submitted_answer}, _from, state) do
    new_state = Game.answer(state, player_id, submitted_answer)
    {:reply, Game.visible_state(new_state), new_state}
  end

  def handle_call(:next_round, _from, state) do
    new_state = Game.next_round(state)
    {:reply, Game.visible_state(new_state), new_state}
  end

  def handle_call(:state, _from, state) do
    {:reply, Game.visible_state(state), state}
  end
end
