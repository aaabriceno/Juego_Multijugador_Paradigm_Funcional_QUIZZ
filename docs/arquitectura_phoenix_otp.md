# Arquitectura Phoenix LiveView + OTP

Este documento resume como se organizara el juego para mantener el codigo claro
y facil de ampliar.

## Capas del proyecto

- `lib/trivia_crack_quiz/game/`: logica del dominio del juego.
- `lib/trivia_crack_quiz_web/live/`: pantallas interactivas en Phoenix LiveView.
- `lib/trivia_crack_quiz_web/`: router, endpoint, componentes y capa web.
- `assets/`: estilos y JavaScript generados por Phoenix.
- `docs/`: documentos de avance, diagramas y decisiones tecnicas.

## Flujo principal

1. `TriviaCrackQuiz.Application` inicia el arbol de supervision OTP.
2. El supervisor inicia `Phoenix.PubSub`, `TriviaCrackQuiz.GameServer` y el
   endpoint web.
3. `GameLive` se suscribe al topico de la partida.
4. Los eventos de interfaz (`join`, `start`, `answer`) se envian al
   `GameServer`.
5. `GameServer` modifica el estado llamando funciones puras de
   `TriviaCrackQuiz.Game`.
6. El estado visible se publica con `Phoenix.PubSub`.
7. LiveView recibe el nuevo estado y actualiza la interfaz en tiempo real.

## Modulos de juego

- `TriviaCrackQuiz.Game`: funciones puras para crear estado, agregar jugadores,
  iniciar partida, registrar respuestas, evaluar rondas y calcular ganador.
- `TriviaCrackQuiz.GameServer`: proceso `GenServer` que centraliza el estado,
  procesa mensajes y programa temporizadores con `Process.send_after/3`.
- `TriviaCrackQuiz.QuestionBank`: banco inicial de preguntas por tipo y
  categoria.

## Reglas de mantenimiento

- La interfaz no debe calcular puntajes ni decidir reglas de ronda.
- `GameServer` coordina procesos, temporizadores y broadcast, pero delega reglas
  a funciones puras.
- Las funciones puras deben recibir un estado y devolver un nuevo estado.
- Las nuevas pantallas LiveView deben vivir dentro de
  `lib/trivia_crack_quiz_web/live/`.
- Las nuevas reglas del juego deben agregarse primero en
  `lib/trivia_crack_quiz/game/`.
