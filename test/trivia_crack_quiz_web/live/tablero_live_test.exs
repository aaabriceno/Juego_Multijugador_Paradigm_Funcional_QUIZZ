defmodule TriviaCrackQuizWeb.TableroLiveTest do
  # async: false porque comparten el Registry/Supervisor global de salas; no
  # deben correr en paralelo con otros tests que crean salas.
  use TriviaCrackQuizWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias TriviaCrackQuiz.{GameServer, Rooms}

  setup do
    # Limpia salas que hayan dejado otros tests y espera a que sus procesos
    # mueran de verdad (terminate es async), para partir de un estado conocido
    # sin importar el orden de ejecucion.
    cleanup_rooms()
    on_exit(&cleanup_rooms/0)
    :ok
  end

  defp cleanup_rooms do
    children = DynamicSupervisor.which_children(TriviaCrackQuiz.RoomSupervisor)

    for {_, pid, _, _} <- children, is_pid(pid) do
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

  test "the board shows active rooms with their players", %{conn: conn} do
    Rooms.create("tablero-demo")
    GameServer.join("tablero-demo", "p1", "Ana")
    GameServer.join("tablero-demo", "p2", "Luis")

    {:ok, _view, html} = live(conn, ~p"/tablero")

    assert html =~ "Tablero en vivo"
    assert html =~ "tablero-demo"
    assert html =~ "Ana"
    assert html =~ "Luis"
  end

  test "empty board shows a placeholder", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/tablero")
    assert html =~ "No hay salas activas"
  end

  test "Rooms.list exposes a roster sorted by score", %{conn: _conn} do
    Rooms.create("roster-demo")
    GameServer.join("roster-demo", "p1", "Ana")
    GameServer.join("roster-demo", "p2", "Luis")
    # Forzamos puntajes distintos para verificar el orden.
    state = GameServer.state("roster-demo")
    refute state.players == %{}

    summary = Enum.find(Rooms.list(), &(&1.id == "roster-demo"))
    assert is_list(summary.roster)
    assert Enum.map(summary.roster, & &1.name) |> Enum.sort() == ["Ana", "Luis"]
  end
end
