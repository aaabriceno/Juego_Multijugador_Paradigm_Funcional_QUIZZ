# Guía de presentación — Funciones clave del juego (10-15 min)

Estructura sugerida de slides + qué decir en cada una. Basado en el código real de `lib/trivia_crack_quiz/`.

---

## 1. Arquitectura general (1 slide)

**Mensaje:** separación entre lógica pura (funcional) y efectos (OTP).

- `TriviaCrackQuiz.Game` — `lib/trivia_crack_quiz/game/engine.ex` — **módulo puro**. Recibe estado, devuelve estado nuevo. Cero efectos secundarios, cero IO, cero procesos. Fácil de testear.
- `TriviaCrackQuiz.GameServer` — `lib/trivia_crack_quiz/game/server.ex` — **GenServer (actor)**. Una sala = un proceso. Mantiene el estado mutable (en términos de Erlang/OTP) y delega toda decisión de juego al motor puro.
- `TriviaCrackQuiz.Rooms` — `lib/trivia_crack_quiz/rooms.ex` — gestor: crea/lista/cierra salas vía `DynamicSupervisor` + `Registry`.

```
Jugador → LiveView → GameServer (actor, 1 por sala) → Game (funciones puras) → nuevo estado → PubSub → todos los LiveView de la sala
```

Punto fuerte pa la presentación: **cada sala es un proceso aislado**. Si una sala crashea, no afecta a las demás (tolerancia a fallos de OTP).

---

## 2. Flujo de vida de una sala (1-2 slides)

Mostrar como diagrama de estados (`phase`):

```
:waiting → :playing → :round_results → :playing → ... → :finished
```

Funciones que mueven la fase:
- `Game.start/1` → `:waiting` → `:playing` (exige `ready_to_start?/1`, mínimo 3 jugadores)
- `Game.next_question/1` → arma la siguiente pregunta y pasa a `:playing`
- `Game.evaluate_round/1` → `:playing` → `:round_results` (calcula puntos)
- `Game.finish/1` → `:finished` cuando `round >= max_rounds`

**Quién dispara cada transición:** el `GameServer` vía `handle_call`/`handle_info`, nunca el cliente directo — todo pasa por mensajes al actor.

---

## 3. Función estrella: `Game.next_question/1` (1 slide)

**Archivo:** `lib/trivia_crack_quiz/game/engine.ex`

```elixir
def next_question(state) do
  next_round_number = state.round + 1
  surprise? = next_round_number == Map.get(state, :surprise_round)
  question = select_question(state, surprise?) |> Map.put(:surprise, surprise?)
  now = System.monotonic_time(:millisecond)

  %{state | phase: :playing, round: next_round_number, round_started_at: now,
            round_time_ms: question_time_ms(question), current_question: question,
            used_question_ids: MapSet.put(state.used_question_ids, question.id),
            last_category: question.category, answers: %{}, round_results: nil}
end
```

Qué resaltar:
- **Inmutabilidad**: no modifica `state`, devuelve un mapa nuevo (`%{state | ...}`).
- Decide si esta ronda es la "sorpresa" (`surprise_round`, calculado una vez al crear la sala).
- Llama a `select_question/2` que tiene **dos caminos** (pattern matching por el booleano `surprise?`):
  - normal → banco filtrado por categoría/tipo de la sala, evita repetir categoría
  - sorpresa → banco completo (ignora filtro de categoría), solo respeta tipo

---

## 4. Función estrella: `Game.evaluate_round/1` — el scoring (1 slide)

**Archivo:** `lib/trivia_crack_quiz/game/engine.ex`

```elixir
def evaluate_round(%{phase: :playing, current_question: question} = state) when not is_nil(question) do
  surprise? = Map.get(question, :surprise, false)

  results = Map.new(state.answers, fn {player_id, answer} ->
    correct? = correct_answer?(question, answer.answer)
    points = if correct? do
      base = score_answer(state.round_started_at, answer.answered_at)
      if surprise?, do: round(base * @surprise_bonus), else: base
    else
      0
    end
    {player_id, %{answer: answer.answer, correct?: correct?, points: points}}
  end)
  ...
end
```

Puntos pa explicar:
- **Bonus de velocidad**: `score_answer/2` da 100 pts base + hasta 50 pts extra según qué tan rápido respondiste (`speed_bonus = max(50 - div(elapsed, 200), 0)`).
- **Bonus sorpresa**: `+20%` (`@surprise_bonus 1.2`) si la pregunta era la categoría sorpresa de la partida.
- Pattern matching en la cabecera de la función (`%{phase: :playing, current_question: question} = state`) — Elixir solo ejecuta esta cláusula si el estado calza esa forma; si no, cae a la cláusula de abajo (`evaluate_round(state), do: state`) — **guard clauses como control de flujo**, no `if/else` anidados.

---

## 5. Función estrella: `correct_answer?/2` — tolerancia a errores de tipeo (1 slide)

**Archivo:** `lib/trivia_crack_quiz/game/engine.ex` (también usa `levenshtein/2` y `normalize/1`, privadas en el mismo archivo)

```elixir
def correct_answer?(question, submitted) do
  submitted_norm = normalize(submitted)
  valid = accepted_answers(question)

  cond do
    Enum.any?(valid, &(&1 == submitted_norm)) -> true
    question.type == :quick_answer ->
      Enum.any?(valid, fn answer ->
        String.length(answer) >= 3 and levenshtein(answer, submitted_norm) <= 1
      end)
    true -> false
  end
end
```

- `normalize/1`: minúsculas, sin tildes (NFD + regex), sin espacios sobrantes.
- Solo preguntas de **respuesta por teclado** (`:quick_answer`) toleran 1 error de tipeo, calculado con **distancia de Levenshtein** (programación dinámica, implementada a mano con `Enum.reduce` sobre las filas de la matriz — buen ejemplo de recursión/acumulador funcional).
- Las de opción múltiple/verdadero-falso se comparan exactas (no necesitan tolerancia, no se tipean).

Mencionar la razón de negocio: el usuario pidió esto porque las preguntas de teclado eran "muy estrictas" y frustraban a los jugadores.

---

## 6. Filtros y categoría sorpresa (1 slide)

**Archivo:** `lib/trivia_crack_quiz/game/engine.ex`

- `normalize_filters/1` — acepta formatos viejos y nuevos (`:all`, atom, mapa) → siempre normaliza a `%{categories: [], types: [], surprise: false}`.
- `filter_questions/2` — filtra banco por categoría Y tipo; si el cruce queda vacío, no rompe: cae al banco completo (`if filtered == [], do: questions, else: filtered`).
- `surprise_round/2` — si la sala activó "sorpresa", reserva **una ronda al azar** (`Enum.random(1..max_rounds)`) para la pregunta especial.
- En esa ronda, `select_question(state, true)` ignora el filtro de categoría pero respeta el de tipo.

Este es el **4to tipo de pregunta requerido por el informe**: la categoría sorpresa.

---

## 7. El actor `GameServer` — concurrencia con OTP (1-2 slides)

**Archivo:** `lib/trivia_crack_quiz/game/server.ex`

Mostrar el ciclo de vida:
- `start_link/1` — una sala = un proceso, registrado por nombre vía `Registry` (`{:via, Registry, {RoomRegistry, room_id}}`).
- `handle_call({:answer, ...})` — recibe respuesta, delega a `Game.register_answer/3`, y si **todos los conectados ya respondieron** (`all_players_answered?/1`), cierra la ronda antes de que expire el timer.
- `handle_info(:round_timeout, ...)` — si nadie cerró antes, el timer cierra la ronda igual (`Process.send_after`).
- `handle_info(:empty_room_timeout, ...)` — si la sala lleva 15s sin nadie conectado, el proceso se detiene solo (`{:stop, :normal, state}`). **Bug corregido esta sesión**: este timer ahora arranca desde `init/1`, no solo al hacer join/leave.
- `handle_info({:DOWN, ...})` — si el proceso LiveView de un jugador muere (cierre de pestaña), se marca desconectado sin tumbar la partida.

Idea central pa la presentación: **el estado de cada sala vive solo en su proceso**. No hay base de datos ni estado global compartido — concurrencia segura por diseño (modelo de actores de Erlang/OTP), no por locks.

---

## 8. `Rooms` — coordinación entre salas (1 slide)

**Archivo:** `lib/trivia_crack_quiz/rooms.ex`

- `create/2`, `create_random/1`, `create_named/2` — todas pasan por `DynamicSupervisor.start_child/2`.
- `random_open/1` — busca una sala en espera con los **mismos filtros** pedidos; si no hay, crea una nueva.
- `list/0` — recorre todos los procesos hijos vivos y arma el resumen (usado por lobby y tablero espectador).
- `summarize/1` y `roster/1` — exponen solo lo necesario para la UI: jugadores conectados, fase, ronda, filtros, ranking ordenado por puntaje.

---

## 9. Demo en vivo (recomendado, 3-5 min)

Sugerencia de guion para mostrar mientras se explica:
1. Abrir `/` (lobby) → crear sala con `/crear`, elegir 2 categorías + tipo + sorpresa.
2. Abrir `/tablero` en otra pestaña/pantalla (espectador).
3. Unir 3 jugadores, jugar una ronda, mostrar el badge 🎁 cuando salga la pregunta sorpresa.
4. Cerrar pestaña de un jugador → mostrar que se marca desconectado sin romper la partida.
5. Terminar partida → mostrar botón "Volver al lobby".

---

## 10. Cierre — por qué es "funcional" (1 slide)

- Estado **inmutable**: cada transición devuelve un mapa nuevo, nunca se muta in-place.
- Lógica de juego = **funciones puras** (`Game` module) totalmente separadas de los efectos (`GameServer`), lo que las hace triviales de testear sin mocks (72 tests, todos sobre funciones puras o el actor real, sin red ni DB).
- **Pattern matching** y **guard clauses** como mecanismo de control de flujo en vez de condicionales anidados (ver `next_question/1`, `evaluate_round/1`, `handle_call`/`handle_info`).
- **Pipes** (`|>`) para encadenar transformaciones de estado de forma legible.
- **Actores (OTP)** para concurrencia seguro sin estado compartido ni locks explícitos.

---

## 11. Estructura de carpetas dentro de `lib/`

Todo el código vive en `lib/`, dividido en **dos carpetas principales** (patrón estándar de Phoenix: dominio vs web):

### `lib/trivia_crack_quiz/` — el dominio (lógica de negocio, sin HTTP/UI)

| Archivo | Qué contiene |
|---|---|
| `application.ex` | Árbol de supervisión OTP: arranca `RoomRegistry`, `RoomSupervisor` (DynamicSupervisor), PubSub, Endpoint. |
| `game/engine.ex` | Módulo `TriviaCrackQuiz.Game` — **toda la lógica pura** del juego (rondas, puntaje, filtros, validación de respuestas). |
| `game/server.ex` | Módulo `TriviaCrackQuiz.GameServer` — el **actor GenServer**, un proceso por sala. |
| `game/question_bank.ex` | Carga el banco de preguntas (categorías, tipos, respuestas válidas). |
| `rooms.ex` | Módulo `TriviaCrackQuiz.Rooms` — crear/listar/cerrar salas, búsqueda de sala aleatoria por filtros. |

### `lib/trivia_crack_quiz_web/` — la capa web (Phoenix LiveView, UI, rutas)

| Archivo | Qué contiene |
|---|---|
| `router.ex` | Define las rutas: `/` (lobby), `/crear`, `/tablero`, `/sala/:room_id`. |
| `live/lobby_live.ex` | Pantalla principal: lista de salas, botón unirse aleatorio, link a crear sala y tablero. |
| `live/crear_sala_live.ex` | Pantalla `/crear`: formulario con checkboxes de categorías/tipos/sorpresa. |
| `live/game_live.ex` | Pantalla de juego (`/sala/:room_id`): sala de espera, pregunta en curso, resultados, podio final. |
| `live/tablero_live.ex` | Pantalla `/tablero`: vista espectador con todas las salas y su ranking en vivo. |
| `components/core_components.ex` | Componentes UI reutilizables (botones, inputs, etc. — boilerplate de Phoenix). |
| `components/layouts.ex` | Layout HTML compartido por todas las vistas. |
| `endpoint.ex` | Punto de entrada HTTP/WebSocket de Phoenix. |
| `controllers/`, `telemetry.ex`, `gettext.ex` | Boilerplate estándar de Phoenix (no específico de este juego). |
