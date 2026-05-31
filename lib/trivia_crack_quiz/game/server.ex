defmodule TriviaCrackQuiz.GameServer do
  @moduledoc """
  Actor principal de la partida.

  Mantiene un unico estado coherente y recibe eventos de jugadores mediante
  paso de mensajes.
  """

  use GenServer

  alias TriviaCrackQuiz.Game

  @topic "game:lobby"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, Game.new_state(), name: __MODULE__)
  end

  def subscribe do
    Phoenix.PubSub.subscribe(TriviaCrackQuiz.PubSub, @topic)
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
    new_state = Game.add_player(state, player_id, name)
    broadcast_state(new_state)
    {:reply, Game.visible_state(new_state), new_state}
  end

  def handle_call(:start_game, _from, state) do
    case Game.start(state) do
      {:error, reason, unchanged_state} ->
        {:reply, {:error, reason, Game.visible_state(unchanged_state)}, unchanged_state}

      new_state ->
        schedule_round_timeout(new_state)
        broadcast_state(new_state)
        {:reply, {:ok, Game.visible_state(new_state)}, new_state}
    end
  end

  def handle_call({:answer, player_id, submitted_answer}, _from, state) do
    new_state = Game.register_answer(state, player_id, submitted_answer)

    new_state =
      if Game.all_players_answered?(new_state) do
        new_state
        |> Game.evaluate_round()
        |> Game.next_question()
        |> tap(&schedule_round_timeout/1)
      else
        new_state
      end

    broadcast_state(new_state)
    {:reply, Game.visible_state(new_state), new_state}
  end

  def handle_call(:next_round, _from, state) do
    new_state =
      state
      |> Game.evaluate_round()
      |> Game.next_question()

    schedule_round_timeout(new_state)
    broadcast_state(new_state)
    {:reply, Game.visible_state(new_state), new_state}
  end

  def handle_call(:state, _from, state) do
    {:reply, Game.visible_state(state), state}
  end

  @impl true
  def handle_info(:round_timeout, %{phase: :playing} = state) do
    new_state =
      state
      |> Game.evaluate_round()
      |> Game.next_question()

    schedule_round_timeout(new_state)
    broadcast_state(new_state)
    {:noreply, new_state}
  end

  def handle_info(:round_timeout, state), do: {:noreply, state}

  defp schedule_round_timeout(%{phase: :playing, round_time_ms: round_time_ms}) do
    Process.send_after(self(), :round_timeout, round_time_ms)
  end

  defp schedule_round_timeout(_state), do: :ok

  defp broadcast_state(state) do
    Phoenix.PubSub.broadcast(
      TriviaCrackQuiz.PubSub,
      @topic,
      {:game_state, Game.visible_state(state)}
    )
  end
end
