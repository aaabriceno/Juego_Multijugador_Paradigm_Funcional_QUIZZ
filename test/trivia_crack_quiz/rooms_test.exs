defmodule TriviaCrackQuiz.RoomsTest do
  use ExUnit.Case, async: false

  alias TriviaCrackQuiz.{GameServer, Rooms}

  # Cada test usa ids unicos y limpia sus salas al terminar para no contaminar
  # el Registry compartido entre tests.
  setup do
    on_exit(fn ->
      for {_, pid, _, _} <- DynamicSupervisor.which_children(TriviaCrackQuiz.RoomSupervisor) do
        DynamicSupervisor.terminate_child(TriviaCrackQuiz.RoomSupervisor, pid)
      end
    end)

    :ok
  end

  defp unique_id, do: "test-" <> Integer.to_string(System.unique_integer([:positive]))

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
end
