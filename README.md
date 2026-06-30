# Trivia Crack Quiz Multiplayer

Juego multijugador de preguntas desarrollado en Elixir, Phoenix LiveView y OTP
como proyecto final del curso de Lenguajes de Programacion (paradigma funcional).

Cada sala es una partida independiente que corre como su propio proceso
`GameServer`, creado bajo demanda y supervisado dinamicamente. Los jugadores
se coordinan por paso de mensajes y el estado se publica en tiempo real con
`Phoenix.PubSub`, sin recargar la pagina.

## Integrantes

- Anthony Briceño Quiroz
- Sixto Caceres Terrones
- Paolo Mostajo Alor

## Caracteristicas

- **Multiples salas en paralelo**: crear sala (con nombre opcional y filtros) o
  unirse a una aleatoria desde el lobby. Cada sala admite hasta 10 jugadores.
- **Filtros al crear sala**: el creador elige categorias (arte, ciencia,
  deportes, historia, tecnologia, cultura general) y tipos de pregunta
  (opcion multiple, verdadero/falso, respuesta rapida). Ninguna seleccion = todas.
- **4 tipos de pregunta**:
  - `multiple_choice`: elegir entre 4 opciones.
  - `true_false`: verdadero o falso.
  - `quick_answer`: respuesta por teclado con tolerancia a errores de tipeo
    (distancia de Levenshtein ≤ 1) y 4 segundos extra de tiempo.
  - `sorpresa`: una pregunta por partida, categoria aleatoria (ignora el filtro
    de categorias), aparece en una ronda al azar, vale +20% de puntos.
- **Tiempo real**: rondas, temporizadores, respuestas y marcador se actualizan
  al instante via LiveView + PubSub.
- **Tablero espectador** (`/tablero`): vista publica con todas las salas activas
  y el ranking en vivo de cada una. Ideal para proyectar en pantalla.
- **Puntaje por rapidez**: respuesta correcta = 100 pts base + hasta 50 pts
  extra segun que tan rapido se respondio.
- **Reconexion**: cerrar la pestana solo marca al jugador como desconectado;
  al volver conserva su puntaje. Salir con el boton lo elimina definitivamente.
- **Auto-cierre de salas vacias**: una sala sin jugadores conectados se cierra
  sola despues de 15 segundos.
- **Final con podio**: detecta empates, muestra podio con los tres primeros,
  animaciones, sonidos y confeti. Boton para volver al lobby o jugar de nuevo.

## Pantallas

| Ruta | Descripcion |
|---|---|
| `/` | Lobby: lista de salas activas, union aleatoria, link a crear sala y tablero. |
| `/crear` | Crear sala: nombre opcional + filtros por categoria/tipo/sorpresa. |
| `/sala/:id` | Partida: sala de espera, pregunta en curso, resultados por ronda, podio final. |
| `/tablero` | Tablero espectador: ranking en vivo de todas las salas. |

## Estructura del proyecto

```
lib/
  trivia_crack_quiz/
    game/
      engine.ex        # Logica pura del juego (funciones puras, inmutable)
      server.ex        # Actor GenServer: un proceso por sala
      question_bank.ex # Carga el banco de preguntas desde priv/data/
    rooms.ex           # Gestor de salas (crear, listar, unirse, cerrar)
    application.ex     # Arbol de supervision OTP

  trivia_crack_quiz_web/
    live/
      lobby_live.ex       # Pantalla principal
      crear_sala_live.ex  # Pantalla de creacion con filtros
      game_live.ex        # Pantalla de partida
      tablero_live.ex     # Tablero espectador
    router.ex             # Rutas de la aplicacion

priv/data/questions/     # Banco de preguntas en JSON por categoria
docs/                    # Documentacion adicional
```

## Arquitectura

El arbol OTP arranca, ademas del endpoint web y `Phoenix.PubSub`:

- `RoomRegistry` (`Registry`): mapea cada `room_id` a su proceso `GameServer`.
- `RoomSupervisor` (`DynamicSupervisor`): crea y supervisa un `GameServer` por
  sala bajo demanda. Sin limite artificial de salas simultaneas.

Flujo de un evento (ejemplo: jugador responde):

```
Navegador → WebSocket → GameLive → GameServer.answer/3
  → Game.register_answer/3  (funcion pura)
  → Game.evaluate_round/1   (si todos respondieron)
  → PubSub.broadcast        (nuevo estado a todos los LiveView de la sala)
  → LiveView re-renderiza   (solo el diff HTML)
```

La logica del juego (`Game`) es un modulo de funciones puras: recibe estado,
devuelve estado nuevo. Nunca lanza procesos ni hace IO. Esto la hace 100%
testeable sin mocks ni efectos.

## Documentacion tecnica

La documentacion tecnica principal del proyecto ya esta disponible en LaTeX y
en PDF dentro de `docs/`.

- Ver o descargar el informe tecnico: [docs/documentacion_tecnica.pdf](docs/documentacion_tecnica.pdf)
- Revisar la fuente LaTeX: [docs/documentacion_tecnica.tex](docs/documentacion_tecnica.tex)
- Consultar la guia de instalacion completa: [docs/guia_instalacion_local.md](docs/guia_instalacion_local.md)

El informe incluye:

- diagrama de la estructura del juego
- explicacion de la estrategia de concurrencia con OTP
- definicion de los modulos y funciones principales
- decisiones funcionales de diseno y flujo operativo de una partida

## Instalacion y ejecucion

### Requisitos previos

Tener instalado en la maquina:

- **Erlang/OTP 26** o superior
- **Elixir 1.15** o superior

Verificar con:

```bash
elixir --version
mix --version
```

Si no estan instalados, seguir la guia por sistema operativo:
[docs/guia_instalacion_local.md](docs/guia_instalacion_local.md)

### Pasos para correr el juego

**1. Descomprimir o clonar el proyecto** (si viene como zip, extraerlo; si viene del repositorio):

```bash
git clone https://github.com/aaabriceno/Juego_Multijugador_Paradigm_Funcional_QUIZZ.git
cd Juego_Multijugador_Paradigm_Funcional_QUIZZ
```

**2. Instalar dependencias:**

```bash
mix deps.get
mix setup
```

**3. Iniciar el servidor:**

```bash
mix phx.server
```

**4. Abrir en el navegador:**

```
http://localhost:4000
```

**Para multijugador local:** abrir la misma URL en tres pestanas o navegadores distintos y registrar un jugador distinto en cada una. Al iniciar, la consola tambien imprime la IP de red local (`http://192.168.x.x:4000`) para que otros dispositivos de la misma red WiFi puedan unirse.

Si necesitas regenerar el PDF de la documentacion tecnica:

```powershell
.\scripts\build_technical_docs.ps1
```

## Pruebas

```bash
mix test
```

Resultado esperado: **72 tests, 0 failures**.

## Banco de preguntas

Las preguntas viven en `priv/data/questions/` (un archivo JSON por categoria).
Ver [docs/banco_preguntas.md](docs/banco_preguntas.md) para formato y scripts
de generacion/validacion.
