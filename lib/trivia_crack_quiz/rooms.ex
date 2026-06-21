defmodule TriviaCrackQuiz.Rooms do
  @moduledoc """
  Gestor de salas: crea, lista y localiza partidas.

  Cada sala es un proceso `GameServer` arrancado bajo el `RoomSupervisor` y
  registrado en `RoomRegistry`. Este modulo es la unica puerta para crear o
  consultar salas; el resto del sistema no habla con los supervisores
  directamente.

  Autor: Anthony Briceño
  """

  alias TriviaCrackQuiz.GameServer

  # Tope de jugadores por sala. Una sala llena no aparece como opcion para
  # union aleatoria, pero el minimo para iniciar lo decide el motor del juego.
  @max_players 10

  # Topic donde se anuncian altas/bajas de salas para que el lobby se refresque
  # en vivo sin recargar.
  @lobby_topic "rooms"

  def max_players, do: @max_players
  def lobby_topic, do: @lobby_topic

  @doc "Suscribe al canal del lobby para recibir avisos de cambios en las salas."
  def subscribe_lobby do
    Phoenix.PubSub.subscribe(TriviaCrackQuiz.PubSub, @lobby_topic)
  end

  @doc """
  Crea una sala con el id dado. Devuelve `{:ok, room_id}`. Si ya existe,
  devuelve `{:ok, room_id}` igual (idempotente) para no romper enlaces
  compartidos.
  """
  def create(room_id, category \\ :all) do
    spec = {GameServer, {room_id, category}}

    case DynamicSupervisor.start_child(TriviaCrackQuiz.RoomSupervisor, spec) do
      {:ok, _pid} ->
        broadcast_change()
        {:ok, room_id}

      {:error, {:already_started, _pid}} ->
        {:ok, room_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Crea una sala con un id aleatorio legible y devuelve su id."
  def create_random(category \\ :all) do
    {:ok, room_id} = create(generate_id(), category)
    room_id
  end

  @doc """
  Crea una sala a partir de un nombre escrito por el usuario. El nombre se
  convierte en un id apto para URL (slug). Si queda vacio o ya existe ese id,
  cae a un id aleatorio para no pisar otra sala. `category` limita las
  preguntas (`:all` = todas).
  """
  def create_named(name, category \\ :all) do
    slug = slugify(name)

    cond do
      slug == "" -> create_random(category)
      exists?(slug) -> create_random(category)
      true -> elem(create(slug, category), 1)
    end
  end

  @doc "Garantiza que la sala exista (la crea si hace falta) antes de entrar por URL."
  def ensure(room_id) do
    create(room_id)
    room_id
  end

  @doc "True si la sala con ese id tiene un proceso vivo."
  def exists?(room_id) do
    case Registry.lookup(TriviaCrackQuiz.RoomRegistry, room_id) do
      [] -> false
      _ -> true
    end
  end

  @doc """
  Lista todas las salas activas con un resumen: id, jugadores conectados,
  capacidad y fase. Ordenadas por id para una vista estable.
  """
  def list do
    DynamicSupervisor.which_children(TriviaCrackQuiz.RoomSupervisor)
    |> Enum.flat_map(fn {_, pid, _, _} -> summarize(pid) end)
    |> Enum.sort_by(& &1.id)
  end

  @doc """
  Devuelve el id de una sala abierta (en espera y con cupo) para union
  aleatoria. Con `category` distinta de `:all`, busca solo salas de esa
  categoria. Si no hay ninguna, crea una nueva con esa categoria.
  """
  def random_open(category \\ :all) do
    case Enum.find(list(), &open?(&1, category)) do
      nil -> create_random(category)
      room -> room.id
    end
  end

  # --- internos ---

  # Una sala admite union aleatoria si esta esperando, con cupo y (si se pide
  # una categoria) coincide con ella.
  defp open?(room, category) do
    room.phase == :waiting and room.players < @max_players and
      (category == :all or room.category == category)
  end

  defp summarize(pid) do
    case room_id_of(pid) do
      nil ->
        []

      room_id ->
        state = GameServer.state(room_id)

        [
          %{
            id: room_id,
            players: TriviaCrackQuiz.Game.connected_count(state),
            max_players: @max_players,
            phase: state.phase,
            category: Map.get(state, :category, :all)
          }
        ]
    end
  end

  # El Registry guarda la clave (room_id) por pid; lo recuperamos para no
  # depender de leer el estado solo para conocer el id.
  defp room_id_of(pid) do
    case Registry.keys(TriviaCrackQuiz.RoomRegistry, pid) do
      [room_id | _] -> room_id
      [] -> nil
    end
  end

  @doc "Avisa al lobby que la lista de salas cambio (alta, baja o reinicio)."
  def notify_changed do
    Phoenix.PubSub.broadcast(TriviaCrackQuiz.PubSub, @lobby_topic, :rooms_changed)
  end

  @doc """
  Termina el proceso de una sala. Devuelve `:ok` si existia o si ya estaba
  cerrada.
  """
  def close(room_id) do
    case Registry.lookup(TriviaCrackQuiz.RoomRegistry, room_id) do
      [{pid, _}] ->
        case DynamicSupervisor.terminate_child(TriviaCrackQuiz.RoomSupervisor, pid) do
          :ok ->
            notify_changed()
            :ok

          {:error, :not_found} ->
            GenServer.stop(pid, :normal)
            notify_changed()
            :ok
        end

      [] ->
        :ok
    end
  end

  defp broadcast_change, do: notify_changed()

  # Id corto, legible y unico para mostrar en URLs y en el lobby.
  defp generate_id do
    "sala-" <> (:crypto.strong_rand_bytes(4) |> Base.url_encode64() |> binary_part(0, 6))
  end

  # Convierte el nombre escrito en un id apto para URL: sin acentos, en
  # minusculas, espacios a guiones y solo letras/numeros/guiones. Limita el
  # largo para no generar URLs enormes.
  defp slugify(name) do
    name
    |> to_string()
    |> String.normalize(:nfd)
    |> String.replace(~r/[\x{0300}-\x{036f}]/u, "")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/u, "")
    |> String.trim()
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.slice(0, 30)
    |> String.trim("-")
  end
end
