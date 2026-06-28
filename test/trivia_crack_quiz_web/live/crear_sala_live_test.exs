defmodule TriviaCrackQuizWeb.CrearSalaLiveTest do
  # async: false: comparten el Registry/Supervisor global de salas.
  use TriviaCrackQuizWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias TriviaCrackQuiz.Rooms

  # Cierra (de forma sincrona) las salas creadas para no contaminar a otros
  # tests; el Registry/Supervisor de salas es global entre tests.
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

  test "the create screen renders categories and types", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/crear")

    assert html =~ "Crear sala"
    assert html =~ "Arte"
    assert html =~ "Verdadero"
    # Checkboxes por categoria y tipo.
    assert html =~ ~s(name="categories[arte]")
    assert html =~ ~s(name="types[multiple_choice]")
  end

  test "submitting with selected filters creates a room with those filters", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/crear")

    params = %{
      "name" => "Sala Test",
      "categories" => %{"arte" => "true"},
      "types" => %{"multiple_choice" => "true"}
    }

    assert {:error, {:live_redirect, %{to: "/sala/" <> room_id}}} =
             view |> form("form", params) |> render_submit()

    summary = Enum.find(Rooms.list(), &(&1.id == room_id))
    assert summary.filters == %{categories: [:arte], types: [:multiple_choice], surprise: false}
  end

  test "submitting with surprise enabled sets the surprise flag", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/crear")

    params = %{"name" => "Sorpresa", "surprise" => "true"}

    assert {:error, {:live_redirect, %{to: "/sala/" <> room_id}}} =
             view |> form("form", params) |> render_submit()

    summary = Enum.find(Rooms.list(), &(&1.id == room_id))
    assert summary.filters.surprise == true
  end

  test "submitting with no selection creates a room with all categories and types", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/crear")

    assert {:error, {:live_redirect, %{to: "/sala/" <> room_id}}} =
             view |> form("form", %{"name" => ""}) |> render_submit()

    summary = Enum.find(Rooms.list(), &(&1.id == room_id))
    assert summary.filters == %{categories: [], types: [], surprise: false}
  end
end
