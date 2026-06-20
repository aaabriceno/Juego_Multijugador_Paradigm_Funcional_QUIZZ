# Guia del lenguaje: donde se hace cada cosa

Mapa rapido de conceptos de Elixir y donde aparecen en este proyecto. Pensado
para estudiar o explicar el codigo. Las rutas y lineas son reales; si el codigo
cambia, los numeros pueden moverse un poco, pero el modulo sigue igual.

## 1. Tipos de datos del lenguaje

Elixir es dinamico e inmutable. Estos son los tipos que usa el proyecto:

| Tipo | Que es | Donde se ve | Ejemplo |
|---|---|---|---|
| **Atom** | Constante con nombre (empieza con `:`) | Fases del juego | `:waiting`, `:playing`, `:round_results`, `:finished` |
| **Mapa (`Map`)** | Clave-valor, el "estado" del juego | `Game.new_state/1` en `engine.ex` | `%{phase: :waiting, players: %{}, round: 0, ...}` |
| **Lista** | Coleccion ordenada | Banco de preguntas, opciones | `["Venus", "Marte", "Jupiter"]` |
| **Tupla** | Grupo fijo de valores | Mensajes a procesos | `{:join, player_id, name}` |
| **String (binario)** | Texto entre comillas dobles | Nombres, respuestas | `"Ana"`, `"Marte"` |
| **Integer / Float** | Numeros | Puntaje, tiempos | `100`, `round + 1` |
| **Boolean** | `true` / `false` (son atoms) | Banderas | `connected?: true`, `correct?: false` |
| **`nil`** | Ausencia de valor | Sin ganador, sin pregunta | `winner: nil`, `current_question: nil` |
| **`MapSet`** | Conjunto sin repetidos | Preguntas ya usadas | `used_question_ids: MapSet.new()` |

Convencion: una funcion que termina en `?` devuelve booleano
(`all_players_answered?`, `tie?`, `connected?`).

El **estado completo de una partida** es un solo mapa, definido en
`lib/trivia_crack_quiz/game/engine.ex` -> funcion `new_state/1`.

## 2. Constructores (como se crea cada cosa)

En Elixir no hay clases ni `new` como en Java. Se "construye" llamando funciones
que devuelven datos nuevos.

| Que se construye | Como | Donde |
|---|---|---|
| Estado inicial de la partida | `new_state/1` devuelve el mapa base | `engine.ex` |
| Un jugador | mapa `%{name:, score: 0, connected?: true, ...}` | `add_player/3` en `engine.ex` |
| El proceso de una sala | `GenServer.start_link/3` | `GameServer.start_link/1` en `server.ex` |
| Una sala (a demanda) | `DynamicSupervisor.start_child/2` | `Rooms.create/1` en `rooms.ex` |
| `child_spec` del proceso | mapa con `:id`, `:start`, `:restart` | `GameServer.child_spec/1` en `server.ex` |

Modulos = `defmodule NombreModulo do ... end`. No son objetos; son espacios de
nombres con funciones. Ejemplo: `defmodule TriviaCrackQuiz.Game do`.

## 3. Funciones: definicion y formas

| Forma | Para que | Ejemplo en el proyecto |
|---|---|---|
| `def` | Funcion publica | `def add_player(state, player_id, name)` (`engine.ex`) |
| `defp` | Funcion privada (solo dentro del modulo) | `defp winner(state)`, `defp normalize(value)` |
| `do:` en una linea | Funcion corta | `def next_round(state), do: next_question(state)` |
| `@` modulo atributo | Constante del modulo | `@min_players 3`, `@round_time_ms 10_000` |

### Multiples clausulas (pattern matching en los argumentos)

En vez de `if` adentro, se definen varias versiones de la misma funcion y Elixir
elige segun el patron. Ejemplo real, `next_question/1` en `engine.ex`:

```elixir
# Si ya se llego al maximo de rondas -> termina
def next_question(%{round: round, max_rounds: max_rounds} = state)
    when round >= max_rounds do
  finish(state)
end

# Cualquier otro caso -> siguiente pregunta
def next_question(state) do
  # ...elige pregunta, sube round, etc.
end
```

`when ...` es un **guard** (condicion extra para que la clausula aplique).

### Funciones de orden superior (reciben otra funcion)

Se usan para recorrer colecciones sin bucles mutables. En `evaluate_round/1`:

- `Map.new(state.answers, fn {id, ans} -> ... end)` — transforma cada respuesta.
- `Enum.reduce(results, state.players, fn ... end)` — acumula puntajes.
- `Enum.count(state.players, fn {_id, p} -> p.connected? end)` — cuenta conectados.

## 4. Inmutabilidad y el operador pipe `|>`

Nada se modifica "en el sitio". Cada funcion recibe un estado y devuelve uno
nuevo. El pipe encadena transformaciones: el resultado de la izquierda entra
como primer argumento de la derecha. Ejemplo (avance de ronda):

```elixir
state
|> Game.evaluate_round()
|> Game.next_question()
|> schedule_round_timeout()
```

Para "actualizar" un mapa se crea una copia con el cambio:
`%{state | phase: :playing}` (mapa nuevo con `phase` cambiado, el viejo intacto).

Helpers de actualizacion anidada (en `engine.ex`):
`put_in/3`, `update_in/3`, `get_in/2`.

## 5. Modelo de actores (concurrencia con OTP)

Cada sala es un proceso aislado que se comunica por mensajes, no por memoria
compartida. Esta en `lib/trivia_crack_quiz/game/server.ex`.

| Concepto OTP | Que hace | Donde |
|---|---|---|
| `use GenServer` | Convierte el modulo en un actor | arriba de `server.ex` |
| `GenServer.call/2` | Manda mensaje y **espera respuesta** | `join`, `answer`, `start_game` |
| `handle_call/3` | Recibe esos mensajes y responde | `def handle_call({:join, ...}, ...)` |
| `handle_info/2` | Recibe mensajes sueltos (timers, caidas) | `:round_timeout`, `{:DOWN, ...}` |
| `Process.send_after/3` | Programa un mensaje futuro (temporizador) | fin de ronda, sala vacia |
| `Process.monitor/1` | Avisa si un jugador se desconecta | `monitor_player/3` |

Flujo de un evento (ejemplo "responder"):

1. El navegador hace `phx-submit` -> `GameLive` recibe el evento.
2. `GameLive` llama `GameServer.answer(room_id, player_id, respuesta)`.
3. Eso es un `GenServer.call` -> llega a `handle_call({:answer, ...})`.
4. El actor aplica la funcion **pura** `Game.register_answer/3`.
5. Difunde el nuevo estado con `Phoenix.PubSub.broadcast`.
6. Todos los `GameLive` de esa sala reciben `{:game_state, estado}` y se
   redibujan.

## 6. Separacion clave: logica pura vs efectos

Esta es la decision de diseno mas importante del paradigma funcional aqui.

| Capa | Archivo | Responsabilidad | Tiene efectos? |
|---|---|---|---|
| **Logica pura** | `engine.ex` (`TriviaCrackQuiz.Game`) | Reglas: puntaje, rondas, ganador, empate | No. Solo `estado -> estado` |
| **Actor / efectos** | `server.ex` (`GameServer`) | Procesos, timers, red, monitoreo | Si |
| **Gestor de salas** | `rooms.ex` (`Rooms`) | Crear/listar/ubicar salas | Si (supervisores) |
| **Interfaz** | `live/*.ex` (`LobbyLive`, `GameLive`) | Mostrar y capturar eventos | Si (web) |

Regla: la interfaz **no** calcula reglas; el actor coordina pero **delega** las
reglas a funciones puras. Por eso los tests de logica
(`test/trivia_crack_quiz_test.exs`) se corren sin levantar procesos ni web.

## 7. Concurrencia (donde se ve)

La concurrencia es el corazon del proyecto y usa el **modelo de actores** de
Erlang/OTP: muchos procesos ligeros que corren en paralelo, no comparten
memoria y solo se comunican por mensajes. Asi se evitan condiciones de carrera
sin locks ni semaforos.

| Donde | Que aporta a la concurrencia |
|---|---|
| **Un `GameServer` por sala** (`server.ex`) | Cada sala es un proceso aparte. 5 salas = 5 procesos en paralelo; ninguno bloquea a otro. |
| **Mensajes, no memoria compartida** | Nadie toca el estado de otra sala directo. Todo entra por `GenServer.call`. |
| **`handle_call/3` procesa de a un mensaje** | El actor atiende su cola **secuencialmente**. Si 3 jugadores responden "a la vez", llegan 3 mensajes y se procesan en orden -> imposible que se pisen los puntajes. |
| **Cada navegador es un proceso LiveView** | Cada cliente conectado corre aislado y recibe el estado por PubSub. |
| **`DynamicSupervisor`** (`application.ex`) | Maneja N procesos sala a la vez. Si una sala crashea, las demas siguen (aislamiento de fallos). |
| **`Process.monitor/1`** (`server.ex`) | Detecta caidas de jugadores de forma concurrente: la caida llega como mensaje `{:DOWN, ...}`. |
| **`Process.send_after/3`** (`server.ex`) | Cada sala tiene sus propios temporizadores (ronda, resultados, sala vacia) corriendo en paralelo a las demas. |

Idea clave: el estado mutable "global" no existe. Cada proceso guarda su propio
estado y lo transforma aplicando funciones puras sobre el mensaje que recibe.
Eso es el paradigma funcional llevado a la concurrencia.

### Ejemplo concreto: 3 jugadores responden casi a la vez

1. Cada `GameLive` envia `GameServer.answer(room_id, id, respuesta)`.
2. Los 3 `GenServer.call` se encolan en el **mismo** proceso de esa sala.
3. El actor los procesa uno por uno con `handle_call({:answer, ...})`.
4. No hay dos escrituras simultaneas al estado: el orden de la cola las serializa.

## 8. Persistencia (que se guarda y que no)

| Que | Persiste? | Donde |
|---|---|---|
| **Banco de preguntas** | Si, **solo lectura** desde disco al arrancar | `question_bank.ex` -> `File.read` + `Jason.decode!` sobre los `.json` de `priv/data/` |
| **Salas activas** | No. Viven en memoria | proceso `GameServer` |
| **Jugadores, puntajes, ronda** | No. En el estado del proceso (RAM) | mapa de `new_state/1` |
| **Historial de partidas** | No se guarda nada | — |

No hay base de datos: el proyecto **no** usa Ecto, Postgres, SQLite, `:ets` ni
`:mnesia`. El unico acceso a disco es leer las preguntas (efecto de entrada),
nunca escribir estado de juego.

**Donde vive el estado:** en la memoria del proceso `GameServer`. Cuando el
proceso termina (servidor reiniciado, sala cerrada), su estado desaparece. Es
intencional: el juego es en tiempo real y efimero; al terminar una partida no
queda nada que guardar.

**Como defenderlo:** "El estado de cada partida vive en su proceso OTP en
memoria; la concurrencia se resuelve con el modelo de actores, sin estado
compartido. No hay persistencia de partidas porque el juego es efimero." Si se
necesitara persistir, las opciones serian (de menos a mas trabajo): `:dets`/
`:ets`, guardar a un archivo JSON, o Ecto con SQLite/Postgres.

## 9. Donde mirar primero, segun la pregunta

- "Como se calcula el puntaje" -> `score_answer/2` y `evaluate_round/1` en `engine.ex`.
- "Como se decide el ganador / empate" -> `winner/1` y `tie?/1` en `engine.ex`.
- "Como entra/sale un jugador" -> `add_player/3`, `remove_player/2` (`engine.ex`)
  y `handle_call({:join/:leave, ...})` (`server.ex`).
- "Como se crean las salas" -> `rooms.ex`.
- "De donde salen las preguntas" -> `question_bank.ex` (lee JSON de
  `priv/data/`), con `Jason.decode!` para parsear.
- "Como se ve en pantalla" -> `lib/trivia_crack_quiz_web/live/game_live.ex`
  (funcion `render/1` y los `*_panel`).
- "Como arranca todo" -> `lib/trivia_crack_quiz/application.ex` (arbol OTP).
