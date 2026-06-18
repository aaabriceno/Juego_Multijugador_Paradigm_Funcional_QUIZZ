# Trivia Crack Quiz Multiplayer

Juego multijugador de preguntas desarrollado en Elixir, Phoenix LiveView y OTP.
Cada sala es una partida independiente: corre como su propio proceso
`GameServer`, creado bajo demanda y supervisado de forma dinamica. Los jugadores
se coordinan por paso de mensajes y el estado se publica en tiempo real con
`Phoenix.PubSub`, sin recargar la pagina.

## Caracteristicas

- **Multiples salas en paralelo**: crear sala (con nombre opcional) o unirse a
  una al azar desde el lobby. Cada sala tiene hasta 10 jugadores.
- **Tiempo real**: rondas, temporizadores, respuestas y marcador se actualizan
  al instante via LiveView + PubSub.
- **Preguntas por categoria**: arte, ciencia, deportes, historia, tecnologia y
  cultura general, con puntaje por acierto y bono por rapidez.
- **Salir y reconexion**: salir de la partida (con confirmacion) libera el
  lugar y la partida sigue con los que quedan; cerrar la pestana solo marca al
  jugador como desconectado y permite reconectar conservando el puntaje.
- **Final con podio**: detecta empates y muestra un podio con los tres
  primeros, animaciones, sonidos y confeti.

## Estructura principal

- `lib/trivia_crack_quiz/game/`: dominio del juego. Funciones puras (`Game`),
  el actor de cada sala (`GameServer`) y el banco de preguntas.
- `lib/trivia_crack_quiz/rooms.ex`: gestor de salas (crear, listar, unirse).
- `lib/trivia_crack_quiz_web/live/`: interfaz en Phoenix LiveView
  (`LobbyLive` y `GameLive`).
- `docs/`: avances, diagramas y documentos del proyecto.
- `assets/`: estilos, JavaScript, sonidos y confeti.

## Arquitectura (resumen)

El arbol OTP arranca, ademas del endpoint web y `Phoenix.PubSub`:

- `TriviaCrackQuiz.RoomRegistry` (`Registry`): mapea cada `room_id` a su proceso.
- `TriviaCrackQuiz.RoomSupervisor` (`DynamicSupervisor`): crea y supervisa un
  `GameServer` por sala bajo demanda.

Detalle completo en
[docs/arquitectura_phoenix_otp.md](docs/arquitectura_phoenix_otp.md).

## Instalacion

Guia detallada para los integrantes:

- [docs/guia_instalacion_local.md](docs/guia_instalacion_local.md)

```bash
mix deps.get
mix setup
```

## Ejecucion

```bash
mix phx.server
```

Luego abrir:

```text
http://localhost:4000
```

Al iniciar, la consola imprime tambien una URL con la IP de la red local
(`http://IP_DEL_HOST:4000`) para que otros dispositivos de la misma red (por
ejemplo un celular) entren a jugar.

## Verificacion

```bash
mix test
```
