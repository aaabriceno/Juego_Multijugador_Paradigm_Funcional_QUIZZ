defmodule TriviaCrackQuiz.GameServer do
  @moduledoc """
  Actor de una partida (una sala).

  Cada sala corre como un proceso `GameServer` independiente, identificado por
  su `room_id` y registrado en `TriviaCrackQuiz.RoomRegistry`. Mantiene un
  unico estado coherente y recibe eventos de jugadores mediante paso de
  mensajes. Varias salas conviven en paralelo sin compartir estado.
  """

  use GenServer

  alias TriviaCrackQuiz.Game

  # El topic de PubSub depende de la sala: cada sala difunde su estado solo a
  # los LiveView suscritos a ella, sin filtrarse a otras salas.
  defp topic(room_id), do: "game:room:#{room_id}"

  # Localiza el proceso de la sala por su room_id usando el Registry.
  defp via(room_id), do: {:via, Registry, {TriviaCrackQuiz.RoomRegistry, room_id}}

  def start_link(room_id) do
    state = Game.new_state() |> Map.put(:room_id, room_id)
    GenServer.start_link(__MODULE__, state, name: via(room_id))
  end

  def subscribe(room_id) do
    Phoenix.PubSub.subscribe(TriviaCrackQuiz.PubSub, topic(room_id))
  end

  def join(room_id, player_id, name) do
    GenServer.call(via(room_id), {:join, player_id, name})
  end

  def reconnect(room_id, player_id) do
    GenServer.call(via(room_id), {:reconnect, player_id})
  end

  def start_game(room_id) do
    GenServer.call(via(room_id), :start_game)
  end

  def answer(room_id, player_id, submitted_answer) do
    GenServer.call(via(room_id), {:answer, player_id, submitted_answer})
  end

  def next_round(room_id) do
    GenServer.call(via(room_id), :next_round)
  end

  def reset(room_id) do
    GenServer.call(via(room_id), :reset)
  end

  def state(room_id) do
    GenServer.call(via(room_id), :state)
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:join, player_id, name}, {caller_pid, _tag}, state) do
    new_state =
      state
      |> Game.add_player(player_id, name)
      |> monitor_player(caller_pid, player_id)

    broadcast_state(new_state)
    {:reply, Game.visible_state(new_state), new_state}
  end

  # Reengancha a un jugador existente (refresco de pagina): vuelve a monitorear
  # su proceso LiveView y lo marca como conectado.
  def handle_call({:reconnect, player_id}, {caller_pid, _tag}, state) do
    if Map.has_key?(state.players, player_id) do
      new_state =
        state
        |> Game.set_connected(player_id, true)
        |> monitor_player(caller_pid, player_id)

      broadcast_state(new_state)
      {:reply, Game.visible_state(new_state), new_state}
    else
      {:reply, Game.visible_state(state), state}
    end
  end

  def handle_call(:start_game, _from, state) do
    case Game.start(state) do
      {:error, reason, unchanged_state} ->
        {:reply, {:error, reason, Game.visible_state(unchanged_state)}, unchanged_state}

      new_state ->
        new_state = schedule_round_timeout(new_state)
        broadcast_state(new_state)
        {:reply, {:ok, Game.visible_state(new_state)}, new_state}
    end
  end

  def handle_call({:answer, player_id, submitted_answer}, _from, state) do
    new_state = Game.register_answer(state, player_id, submitted_answer)

    new_state =
      if Game.all_players_answered?(new_state) do
        close_round(new_state)
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
      |> schedule_round_timeout()

    broadcast_state(new_state)
    {:reply, Game.visible_state(new_state), new_state}
  end

  def handle_call(:reset, _from, state) do
    # El estado nuevo ya no carga la referencia del temporizador anterior,
    # asi que hay que cancelarlo antes de descartar el estado viejo. Los
    # monitores de procesos siguen vigentes y deben sobrevivir al reinicio.
    cancel_round_timeout(state)

    new_state =
      state
      |> Game.reset()
      |> Map.put(:monitors, Map.get(state, :monitors, %{}))
      |> Map.put(:room_id, state.room_id)

    broadcast_state(new_state)
    {:reply, Game.visible_state(new_state), new_state}
  end

  def handle_call(:state, _from, state) do
    {:reply, Game.visible_state(state), state}
  end

  @impl true
  def handle_info(:round_timeout, %{phase: :playing} = state) do
    new_state = close_round(state)
    broadcast_state(new_state)
    {:noreply, new_state}
  end

  def handle_info(:round_timeout, state), do: {:noreply, state}

  def handle_info(:results_timeout, %{phase: :round_results} = state) do
    new_state =
      state
      |> Game.next_question()
      |> schedule_round_timeout()

    broadcast_state(new_state)
    {:noreply, new_state}
  end

  def handle_info(:results_timeout, state), do: {:noreply, state}

  # Un proceso LiveView monitoreado murio (pestana cerrada, refresco, caida).
  # Si el jugador no tiene otra pestana abierta, se marca como desconectado.
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {player_id, monitors} = Map.pop(Map.get(state, :monitors, %{}), ref)
    state = Map.put(state, :monitors, monitors)

    if player_id != nil and player_id not in Map.values(monitors) do
      new_state = Game.set_connected(state, player_id, false)
      broadcast_state(new_state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  defp monitor_player(state, caller_pid, player_id) do
    ref = Process.monitor(caller_pid)

    Map.update(
      state,
      :monitors,
      %{ref => player_id},
      &Map.put(&1, ref, player_id)
    )
  end

  # Cierra la ronda actual: evalua respuestas, pasa a la fase de resultados y
  # deja corriendo el temporizador que avanzara a la siguiente pregunta.
  defp close_round(state) do
    state
    |> Game.evaluate_round()
    |> schedule_results_timeout()
  end

  # Cancela el temporizador pendiente antes de programar uno nuevo; sin esto,
  # al cerrar una ronda anticipadamente el temporizador viejo seguiria vivo y
  # cortaria la ronda siguiente antes de tiempo.
  defp schedule_round_timeout(%{phase: :playing, round_time_ms: round_time_ms} = state) do
    cancel_round_timeout(state)
    timer_ref = Process.send_after(self(), :round_timeout, round_time_ms)
    Map.put(state, :round_timer_ref, timer_ref)
  end

  defp schedule_round_timeout(state) do
    cancel_round_timeout(state)
    Map.put(state, :round_timer_ref, nil)
  end

  defp schedule_results_timeout(%{phase: :round_results, results_time_ms: results_time_ms} = state) do
    cancel_round_timeout(state)
    timer_ref = Process.send_after(self(), :results_timeout, results_time_ms)
    Map.put(state, :round_timer_ref, timer_ref)
  end

  defp schedule_results_timeout(state) do
    cancel_round_timeout(state)
    Map.put(state, :round_timer_ref, nil)
  end

  defp cancel_round_timeout(%{round_timer_ref: timer_ref}) when is_reference(timer_ref) do
    Process.cancel_timer(timer_ref)
  end

  defp cancel_round_timeout(_state), do: :ok

  defp broadcast_state(state) do
    Phoenix.PubSub.broadcast(
      TriviaCrackQuiz.PubSub,
      topic(state.room_id),
      {:game_state, Game.visible_state(state)}
    )
  end
end
