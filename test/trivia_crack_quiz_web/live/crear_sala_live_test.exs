defmodule TriviaCrackQuizWeb.CrearSalaLiveTest do
  use TriviaCrackQuizWeb.ConnCase
  import Phoenix.LiveViewTest

  alias TriviaCrackQuiz.Rooms

  # Cierra cualquier sala creada en estos tests para no contaminar a otros
  # (el Registry/Supervisor de salas es global entre tests).
  setup do
    on_exit(fn ->
      for {_, pid, _, _} <- DynamicSupervisor.which_children(TriviaCrackQuiz.RoomSupervisor) do
        DynamicSupervisor.terminate_child(TriviaCrackQuiz.RoomSupervisor, pid)
      end
    end)

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
