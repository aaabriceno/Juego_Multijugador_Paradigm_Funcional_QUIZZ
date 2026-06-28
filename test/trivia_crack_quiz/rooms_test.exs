defmodule TriviaCrackQuiz.RoomsTest do
  use ExUnit.Case, async: false

  alias TriviaCrackQuiz.{Game, GameServer, Rooms}

  # Cada test usa ids unicos y limpia sus salas (de forma sincrona) para no
  # contaminar el Registry compartido entre tests.
  setup do
    cleanup_rooms()
    on_exit(&cleanup_rooms/0)
    :ok
  end

  defp cleanup_rooms do
    for {_, pid, _, _} <- DynamicSupervisor.which_children(TriviaCrackQuiz.RoomSupervisor),
        is_pid(pid) do
      ref = Process.monitor(pid)
      DynamicSupervisor.terminate_child(TriviaCrackQuiz.RoomSupervisor, pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _} -> :ok
      after
        500 -> :ok
      end
    end

    :ok
  end

  defp unique_id, do: "test-" <> Integer.to_string(System.unique_integer([:positive]))

  # Localiza el pid del proceso de una sala por su id.
  defp room_pid(room_id) do
    [{pid, _}] = Registry.lookup(TriviaCrackQuiz.RoomRegistry, room_id)
    pid
  end

  test "a freshly created empty room (random or named) auto-closes when nobody joins" do
    # Reproduce el bug reportado: el creador entra a una sala (aleatoria o con
    # nombre), nunca se registra y se va -> la sala quedaba viva para siempre.
    # Ahora el temporizador de sala vacia arranca desde init.
    id = unique_id()
    Rooms.create(id)

    pid = room_pid(id)
    ref = Process.monitor(pid)

    # Nadie hizo join: la sala esta vacia. Disparamos el timeout que init
    # ya dejo programado (en vez de esperar los 15s reales).
    send(pid, :empty_room_timeout)

    # El proceso se detiene solo. El Registry limpia su entrada de forma
    # asincrona, por eso esperamos la baja del proceso (no exists? de inmediato).
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
    refute Process.alive?(pid)
  end

  test "an empty room does NOT close while a connected player is present" do
    id = unique_id()
    Rooms.create(id)
    GameServer.join(id, "p1", "Ana")

    pid = room_pid(id)
    send(pid, :empty_room_timeout)

    # Sigue vivo: hay un jugador conectado.
    assert Process.alive?(pid)
    assert Rooms.exists?(id)
  end

  test "create starts a room process and exists?/list see it" do
    id = unique_id()

    assert {:ok, ^id} = Rooms.create(id)
    assert Rooms.exists?(id)
    assert Enum.any?(Rooms.list(), &(&1.id == id))
  end

  test "create is idempotent for the same id" do
    id = unique_id()

    assert {:ok, ^id} = Rooms.create(id)
    assert {:ok, ^id} = Rooms.create(id)
    assert Enum.count(Rooms.list(), &(&1.id == id)) == 1
  end

  test "rooms keep independent state (no cross-talk)" do
    a = unique_id()
    b = unique_id()
    Rooms.create(a)
    Rooms.create(b)

    GameServer.join(a, "p1", "Ana")
    GameServer.join(a, "p2", "Luis")

    GameServer.join(b, "p9", "Zoe")

    assert map_size(GameServer.state(a).players) == 2
    assert map_size(GameServer.state(b).players) == 1
    refute Map.has_key?(GameServer.state(b).players, "p1")
  end

  test "list summary reports players, capacity and phase" do
    id = unique_id()
    Rooms.create(id)
    GameServer.join(id, "p1", "Ana")

    summary = Enum.find(Rooms.list(), &(&1.id == id))

    assert summary.players == 1
    assert summary.max_players == Rooms.max_players()
    assert summary.phase == :waiting
  end

  test "random_open reuses a waiting room with room left" do
    id = unique_id()
    Rooms.create(id)
    GameServer.join(id, "p1", "Ana")

    # Con una sala en espera y con cupo, no debe crear otra.
    before = length(Rooms.list())
    chosen = Rooms.random_open()

    assert chosen == id
    assert length(Rooms.list()) == before
  end

  test "random_open creates a new room when none are open" do
    before = length(Rooms.list())
    chosen = Rooms.random_open()

    assert Rooms.exists?(chosen)
    assert length(Rooms.list()) == before + 1
  end

  test "GameServer.leave removes the player and the count drops" do
    id = unique_id()
    Rooms.create(id)
    GameServer.join(id, "p1", "Ana")
    GameServer.join(id, "p2", "Luis")
    GameServer.join(id, "p3", "Mia")

    GameServer.leave(id, "p2")

    state = GameServer.state(id)
    refute Map.has_key?(state.players, "p2")
    assert map_size(state.players) == 2

    summary = Enum.find(Rooms.list(), &(&1.id == id))
    assert summary.players == 2
  end

  test "create_named turns the name into a url-safe slug" do
    name = "Sala de Águilas!! 2026"
    id = Rooms.create_named(name)

    assert id == "sala-de-aguilas-2026"
    assert Rooms.exists?(id)
  end

  test "create_named falls back to random when name is blank" do
    id = Rooms.create_named("   ")
    assert String.starts_with?(id, "sala-")
    assert Rooms.exists?(id)
  end

  test "create_named avoids clobbering an existing room" do
    Rooms.create_named("duplicada")
    id2 = Rooms.create_named("duplicada")

    # El segundo no debe reusar el id ya tomado.
    refute id2 == "duplicada"
    assert Rooms.exists?("duplicada")
    assert Rooms.exists?(id2)
  end

  test "close removes the room from the registry and list" do
    id = unique_id()
    Rooms.create(id)
    assert Rooms.exists?(id)

    [{pid, _}] = Registry.lookup(TriviaCrackQuiz.RoomRegistry, id)
    ref = Process.monitor(pid)

    assert :ok = Rooms.close(id)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}
    refute Rooms.exists?(id)
    refute Enum.any?(Rooms.list(), &(&1.id == id))
  end

  test "empty room timeout stops the process when nobody is connected" do
    id = unique_id()
    Rooms.create(id)
    GameServer.join(id, "p1", "Ana")
    GameServer.leave(id, "p1")

    [{pid, _}] = Registry.lookup(TriviaCrackQuiz.RoomRegistry, id)
    ref = Process.monitor(pid)
    send(pid, :empty_room_timeout)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    # El Registry limpia su entrada de forma asincrona; basta confirmar que el
    # proceso se detuvo (exists? puede ir un instante por detras).
    refute Process.alive?(pid)
  end

  test "reopens room when only one player remains after round results" do
    id = unique_id()
    Rooms.create(id)
    GameServer.join(id, "p1", "Ana")
    GameServer.join(id, "p2", "Luis")
    GameServer.join(id, "p3", "Mia")
    {:ok, _} = GameServer.start_game(id)

    GameServer.answer(id, "p1", "Marte")
    GameServer.leave(id, "p2")
    GameServer.leave(id, "p3")

    assert GameServer.state(id).phase == :round_results
    assert Game.connected_count(GameServer.state(id)) == 1

    [{pid, _}] = Registry.lookup(TriviaCrackQuiz.RoomRegistry, id)
    send(pid, :results_timeout)
    _ = :sys.get_state(pid)

    state = GameServer.state(id)
    assert state.phase == :waiting
    assert state.players == %{}
    assert Rooms.exists?(id)
  end

  test "continues match when two players remain after round results" do
    id = unique_id()
    Rooms.create(id)
    GameServer.join(id, "p1", "Ana")
    GameServer.join(id, "p2", "Luis")
    GameServer.join(id, "p3", "Mia")
    {:ok, _} = GameServer.start_game(id)

    GameServer.leave(id, "p3")

    [{pid, _}] = Registry.lookup(TriviaCrackQuiz.RoomRegistry, id)
    send(pid, :round_timeout)
    _ = :sys.get_state(pid)

    assert GameServer.state(id).phase == :round_results
    assert Game.connected_count(GameServer.state(id)) == 2

    send(pid, :results_timeout)
    _ = :sys.get_state(pid)

    state = GameServer.state(id)
    assert state.phase == :playing
    assert state.round == 2
    assert map_size(state.players) == 2
  end

  test "a room created with filters reports them in the listing" do
    id = unique_id()
    Rooms.create(id, %{categories: [:ciencia], types: [:multiple_choice]})

    summary = Enum.find(Rooms.list(), &(&1.id == id))
    assert summary.filters == %{categories: [:ciencia], types: [:multiple_choice], surprise: false}
  end

  test "random_open with filters reuses a room with the same filters" do
    sci = unique_id()
    his = unique_id()
    Rooms.create(sci, %{categories: [:ciencia], types: []})
    Rooms.create(his, %{categories: [:historia], types: []})

    # Pide aleatorio de ciencia: debe reusar la sala de ciencia, no la de historia.
    assert Rooms.random_open(%{categories: [:ciencia], types: []}) == sci
  end

  test "random_open with filters creates a new room when none match" do
    Rooms.create(unique_id(), %{categories: [:historia], types: []})

    chosen = Rooms.random_open(%{categories: [:ciencia], types: []})
    summary = Enum.find(Rooms.list(), &(&1.id == chosen))

    assert summary.filters == %{categories: [:ciencia], types: [], surprise: false}
  end
end
