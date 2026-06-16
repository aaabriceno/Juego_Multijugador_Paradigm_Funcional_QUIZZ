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
end
