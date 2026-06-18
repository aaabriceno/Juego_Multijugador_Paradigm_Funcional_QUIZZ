# Arquitectura Phoenix LiveView + OTP

Este documento resume como se organiza el juego para mantener el codigo claro
y facil de ampliar.

## Capas del proyecto

- `lib/trivia_crack_quiz/game/`: logica del dominio del juego.
- `lib/trivia_crack_quiz/rooms.ex`: gestor de salas (crear, listar, unirse).
- `lib/trivia_crack_quiz_web/live/`: pantallas interactivas en Phoenix LiveView.
- `lib/trivia_crack_quiz_web/`: router, endpoint, componentes y capa web.
- `assets/`: estilos, JavaScript, sonidos y confeti.
- `docs/`: documentos de avance, diagramas y decisiones tecnicas.

## Arbol de supervision

`TriviaCrackQuiz.Application` inicia el arbol OTP con, entre otros:

- `Phoenix.PubSub`: canal de mensajes para difundir el estado a los clientes.
- `TriviaCrackQuiz.RoomRegistry` (`Registry`): asocia cada `room_id` con el
  proceso de su sala, para encontrarla por nombre sin pasar el pid a mano.
- `TriviaCrackQuiz.RoomSupervisor` (`DynamicSupervisor`): crea y supervisa un
  proceso `GameServer` por cada sala, bajo demanda. Si una sala falla, solo se
  reinicia esa sala; las demas siguen intactas.
- `TriviaCrackQuizWeb.Endpoint`: servidor web.

No existe un unico `GameServer` global: hay tantos como salas activas, y cada
uno mantiene su propio estado aislado.

## Flujo principal

1. `TriviaCrackQuiz.Application` inicia el arbol de supervision OTP.
2. Desde el lobby (`LobbyLive`), el jugador crea una sala o se une a una. El
   gestor `Rooms` arranca (si hace falta) un `GameServer` bajo el
   `RoomSupervisor` y lo registra en `RoomRegistry`.
3. `GameLive` recibe el `room_id` por la URL (`/sala/:room_id`) y se suscribe al
   topico de esa sala (`game:room:<room_id>`).
4. Los eventos de interfaz (`join`, `start`, `answer`, `leave`) se envian al
   `GameServer` de esa sala.
5. `GameServer` modifica su estado llamando funciones puras de
   `TriviaCrackQuiz.Game`.
6. El estado visible se publica con `Phoenix.PubSub` solo a esa sala.
7. LiveView recibe el nuevo estado y actualiza la interfaz en tiempo real.

## Modulos de juego

- `TriviaCrackQuiz.Game`: funciones puras para crear estado, agregar y quitar
  jugadores, iniciar partida, registrar respuestas, evaluar rondas, calcular
  ganador y detectar empates.
- `TriviaCrackQuiz.GameServer`: proceso `GenServer` de una sala. Centraliza el
  estado, procesa mensajes, monitorea a los jugadores conectados y programa
  temporizadores con `Process.send_after/3` (ronda, resultados y cierre de sala
  vacia).
- `TriviaCrackQuiz.Rooms`: unica puerta para crear, listar y localizar salas;
  habla con el `RoomSupervisor` y el `RoomRegistry`.
- `TriviaCrackQuiz.QuestionBank`: banco inicial de preguntas por tipo y
  categoria.

## Reglas de mantenimiento

- La interfaz no debe calcular puntajes ni decidir reglas de ronda.
- `GameServer` coordina procesos, temporizadores y broadcast, pero delega las
  reglas a funciones puras.
- Las funciones puras deben recibir un estado y devolver un nuevo estado.
- Las nuevas pantallas LiveView deben vivir dentro de
  `lib/trivia_crack_quiz_web/live/`.
- Las nuevas reglas del juego deben agregarse primero en
  `lib/trivia_crack_quiz/game/`.

## El paradigma funcional en el proyecto

El curso es de paradigma funcional; estas son las decisiones donde se ve:

- **Separacion estado puro / efectos**: toda la regla del juego vive en
  `TriviaCrackQuiz.Game` como funciones puras `estado -> estado nuevo`. No leen
  ni escriben nada externo: dado el mismo estado de entrada, siempre producen la
  misma salida. Los efectos (procesos, temporizadores, red) quedan aislados en
  `GameServer`.
- **Inmutabilidad**: el estado nunca se muta en sitio. Cada transicion
  (`add_player`, `register_answer`, `evaluate_round`, `next_question`) construye
  y devuelve un mapa nuevo; el anterior queda intacto. Esto hace el flujo del
  juego predecible y facil de testear.
- **Transformaciones encadenadas**: el avance de una ronda se expresa como una
  tuberia de transformaciones con el operador `|>`
  (`state |> evaluate_round() |> next_question() |> ...`), en vez de pasos
  imperativos con variables mutables.
- **Pattern matching y guards**: las distintas fases y casos se distinguen por
  coincidencia de patrones en los argumentos (por ejemplo `next_question/1`
  segun si se alcanzo el maximo de rondas), no con cadenas de `if`.
- **Modelo de actores (OTP)**: la concurrencia se basa en procesos que no
  comparten memoria y se comunican solo por mensajes; el estado se transforma
  aplicando funciones puras sobre el estado recibido. Es el paradigma funcional
  llevado a la concurrencia.
- **Funciones de orden superior**: el recorrido de jugadores y respuestas usa
  `Enum.map/2`, `Enum.filter/2`, `Enum.reduce/3`, etc., en lugar de bucles con
  estado mutable.

Como referencia rapida, las funciones puras del dominio estan en
`lib/trivia_crack_quiz/game/engine.ex` (modulo `TriviaCrackQuiz.Game`) y se
prueban de forma aislada en `test/trivia_crack_quiz_test.exs`, sin levantar
procesos ni la parte web.
