defmodule TriviaCrackQuizWeb.CrearSalaLive do
  @moduledoc """
  Pantalla de configuracion de una sala nueva: nombre (opcional) + eleccion de
  categorias y tipos de pregunta. Sin seleccion = todas / todos.

  La seleccion se hace con checkboxes nativos dentro de un unico formulario:
  el estado vive en el DOM del navegador, asi no depende de eventos en vivo ni
  se pierde por recargas. Al enviar, se crea la sala con los filtros marcados.
  """
  use TriviaCrackQuizWeb, :live_view

  alias TriviaCrackQuiz.Rooms

  @categories [
    {:arte, "🎨", "Arte"},
    {:ciencia, "🔬", "Ciencia"},
    {:deportes, "⚽", "Deportes"},
    {:historia, "🏛️", "Historia"},
    {:tecnologia, "💻", "Tecnología"},
    {:cultura_general, "🌎", "Cultura General"}
  ]

  @types [
    {:multiple_choice, "🔘", "Opción múltiple"},
    {:true_false, "✅", "Verdadero / Falso"},
    {:quick_answer, "⌨️", "Escribir respuesta"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:categories, @categories)
     |> assign(:types, @types)}
  end

  @impl true
  def handle_event("create", params, socket) do
    name = Map.get(params, "name", "")
    categories = parse_selected(params["categories"], @categories)
    types = parse_selected(params["types"], @types)
    surprise = params["surprise"] == "true"

    room_id =
      Rooms.create_named(name, %{categories: categories, types: types, surprise: surprise})

    {:noreply, push_navigate(socket, to: ~p"/sala/#{room_id}")}
  end

  # Convierte los valores marcados (mapa "valor" => "true") en atoms validos.
  defp parse_selected(nil, _options), do: []

  defp parse_selected(selected, options) when is_map(selected) do
    valid = Map.new(options, fn {atom, _e, _l} -> {Atom.to_string(atom), atom} end)

    selected
    |> Enum.filter(fn {_value, checked} -> checked == "true" end)
    |> Enum.map(fn {value, _} -> valid[value] end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_selected(_other, _options), do: []

  @impl true
  def render(assigns) do
    ~H"""
    <main class="game-shell min-h-screen text-slate-800">
      <Layouts.flash_group flash={@flash} />
      <form
        phx-submit="create"
        class="mx-auto flex min-h-screen w-full max-w-3xl flex-col gap-6 px-4 py-10 sm:px-6"
      >
        <header class="flex items-center gap-3">
          <.link
            navigate={~p"/"}
            class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-white/15 text-xl text-white backdrop-blur transition hover:scale-105"
            title="Volver al lobby"
          >
            ←
          </.link>
          <div>
            <h1 class="text-3xl font-black tracking-tight text-white drop-shadow">Crear sala</h1>
            <p class="text-sm font-semibold text-white/80">Elige nombre, categorías y tipos</p>
          </div>
        </header>

        <section class="game-card p-6">
          <label class="text-xs font-bold uppercase tracking-wide text-slate-400">
            Nombre de la sala (opcional)
          </label>
          <input
            name="name"
            type="text"
            maxlength="30"
            placeholder="Ej: Sala de prueba"
            class="mt-2 w-full rounded-xl border-2 border-slate-200 px-3 py-2.5 text-sm font-semibold text-slate-800 outline-none transition focus:border-indigo-400"
          />
        </section>

        <%!-- Categorias como tarjetas seleccionables (checkbox nativo oculto). El
              estilo de "seleccionada" se aplica con peer-checked del checkbox. --%>
        <section class="game-card p-6">
          <h2 class="flex items-center gap-2 text-lg font-black text-slate-800">
            <.icon name="hero-tag" class="h-5 w-5 text-indigo-500" /> Categorías
          </h2>
          <p class="mt-1 text-xs font-semibold text-slate-400">
            Marca las que quieras. Si no marcas ninguna, se juega con todas.
          </p>
          <div class="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-3">
            <label :for={{value, emoji, label} <- @categories} class="cursor-pointer">
              <input type="checkbox" name={"categories[#{value}]"} value="true" class="peer sr-only" />
              <span class={option_card_class()}>
                <span class="text-2xl">{emoji}</span>
                <span class="mt-1 text-sm font-bold">{label}</span>
                <span class="absolute right-2 top-2 hidden h-5 w-5 items-center justify-center rounded-full bg-indigo-600 text-xs font-black text-white peer-checked:flex">
                  ✓
                </span>
              </span>
            </label>
          </div>
        </section>

        <section class="game-card p-6">
          <h2 class="flex items-center gap-2 text-lg font-black text-slate-800">
            <.icon name="hero-list-bullet" class="h-5 w-5 text-indigo-500" /> Tipos de pregunta
          </h2>
          <p class="mt-1 text-xs font-semibold text-slate-400">
            Marca los que quieras. Si no marcas ninguno, se juega con todos.
          </p>
          <div class="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-3">
            <label :for={{value, emoji, label} <- @types} class="cursor-pointer">
              <input type="checkbox" name={"types[#{value}]"} value="true" class="peer sr-only" />
              <span class={option_card_class()}>
                <span class="text-2xl">{emoji}</span>
                <span class="mt-1 text-sm font-bold">{label}</span>
                <span class="absolute right-2 top-2 hidden h-5 w-5 items-center justify-center rounded-full bg-indigo-600 text-xs font-black text-white peer-checked:flex">
                  ✓
                </span>
              </span>
            </label>
          </div>
        </section>

        <%!-- Pregunta sorpresa: una sola ronda de categoria aleatoria con 20%
              extra de puntos. Es un toggle (no es un tipo mas). --%>
        <section class="game-card p-6">
          <h2 class="flex items-center gap-2 text-lg font-black text-slate-800">
            <.icon name="hero-gift" class="h-5 w-5 text-indigo-500" /> Pregunta sorpresa
          </h2>
          <label class="mt-4 block cursor-pointer">
            <input type="checkbox" name="surprise" value="true" class="peer sr-only" />
            <span class={[
              option_card_class(),
              "flex-row items-center justify-center gap-2 py-4"
            ]}>
              <span class="text-2xl">🎁</span>
              <span class="text-sm font-bold">
                Incluir una pregunta sorpresa (categoría al azar, +20% de puntos)
              </span>
              <span class="absolute right-2 top-2 hidden h-5 w-5 items-center justify-center rounded-full bg-indigo-600 text-xs font-black text-white peer-checked:flex">
                ✓
              </span>
            </span>
          </label>
        </section>

        <section class="game-card flex flex-col gap-3 p-6">
          <p class="rounded-xl bg-indigo-50 px-3 py-2 text-xs font-semibold text-indigo-700">
            Lo que no marques se incluye completo (todas las categorías / todos los tipos).
          </p>
          <button type="submit" class="game-btn-primary px-5 py-3 text-base">
            Crear y entrar
          </button>
        </section>
      </form>
    </main>
    """
  end

  # Estilo de la tarjeta de una opcion. El resalte de "seleccionada" se logra
  # con las variantes peer-checked, que reaccionan al checkbox hermano marcado.
  defp option_card_class do
    "relative flex flex-col items-center rounded-2xl border-2 border-slate-200 bg-white px-3 py-4 text-slate-600 transition " <>
      "hover:border-indigo-300 hover:bg-slate-50 " <>
      "peer-checked:border-indigo-500 peer-checked:bg-indigo-50 peer-checked:text-indigo-700 peer-checked:shadow-md"
  end
end
