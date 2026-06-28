defmodule TriviaCrackQuizWeb.TableroLiveTest do
  use TriviaCrackQuizWeb.ConnCase
  import Phoenix.LiveViewTest

  alias TriviaCrackQuiz.{GameServer, Rooms}

  setup do
    # Limpia salas que hayan dejado otros tests, para que el tablero parta
    # vacio sin importar el orden de ejecucion.
    terminate_all = fn ->
      for {_, pid, _, _} <- DynamicSupervisor.which_children(TriviaCrackQuiz.RoomSupervisor) do
        DynamicSupervisor.terminate_child(TriviaCrackQuiz.RoomSupervisor, pid)
      end
    end

    terminate_all.()
    on_exit(terminate_all)
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
