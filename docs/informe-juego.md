Trabajo Final: Desarrollo de un Juego Multijugador en
Paradigma Funcional

Integrantes:

●  Briceño Quiroz Anthony Angel
●  Cáceres Terrones Sixto Manuel
●  Mostajo Alor Paolo

Lenguaje de Programación: Elixir
Juego a desarrollar: Preguntados: Trivia Crack Quiz Multiplayer

Objetivo:
Implementar el juego Preguntados para un mínimo de 3
jugadores simultáneos. Cada jugador responde preguntas de
distintas categorías y el servidor mantiene un estado de la
partida usando estructuras inmutables, funciones puras y paso
de mensajes entre procesos.

Reglas Principales:

1. La partida iniciará cuando haya al menos 3 jugadores

registrados en la sala.

2. Cada jugador tiene nombre, puntaje, estado de conexión

y última acción.

3. En cada ronda se selecciona una pregunta.
4. Todos los jugadores reciben la misma pregunta.
5. Cada jugador envía una respuesta.
6. El servidor valida respuestas y actualiza puntajes.
7. Al terminar la ronda, se notifica el marcador a todos los

jugadores.

8. Gana quien tenga mayor puntaje al finalizar la cantidad

definida de rondas.

Tipos de preguntas

●  Opción múltiple: Una pregunta con varias alternativas y una

respuesta correcta.

●  Verdadero o falso: Afirmación que debe marcarse como

verdadera o falsa.

●  Respuesta rápida: Pregunta corta donde se compara una

respuesta textual normalizada.

●  Categoría sorpresa: Pregunta elegida aleatoriamente entre

ciencia, historia, deportes, arte, tecnología o cultura general.

Árbol de Supervisión OTP

TriviaCrackQuiz.Application

inicia

Supervisor OTP

supervisa

GameServer.start_link

Fase: Espera de Jugadores

Estado: phase: waiting,

players: %{}

Esperando mensajes en el
buzón...

Mensaje: join

handle_call{:join, ...}

Llama a función pura

Game.add_player/2

No

Retorna nuevo mapa

Actualiza Estado

¿Jugadores >= 3?

Sí

Esperando...

Mensaje: start_game

handle_cast{:start_game}

Fase: Bucle de Rondas

Cambia a phase: playing

Preparar Ronda

Llama a función pura

Game.next_question/2

Extrae pregunta del

QuestionBank

Broadcast: Envía pregunta

a los clientes

Process.send_after/3

Inicia Temporizador de

Ronda

Esperando respuestas

concurrentes...

Mensaje: answer

Mensaje interno:

round_timeout

handle_cast{:answer, ...}

handle_info{:round_timeout}

No

Llama a función pura

Game.register_answer/3

Evaluar Respuestas

Retorna estado modificado

Llama a función pura

Actualiza mapa de answers

Game.evaluate_round/1

Compara answers con

current_question

Asigna Puntos según

rapidez y acierto

Actualiza puntajes y limpia

answers

Broadcast: Envía Marcador

Actualizado

¿round == max_rounds?

Sí

Fase: Finalización

Cambia a phase: finished

Broadcast: Resultados y

Ganador

Fin del Proceso de Partida

Jugador 1

Jugador 2

Jugador 3

TriviaCrackQuiz.Application

Supervisor OTP

GameServer

Game
Funciones puras

QuestionBank

Process.send_after/3

start_link()

1

GameServer.start_link()

2

Inicializa estado
phase: waiting
players: %{}
3

4

join(player_1)

8

{:ok, joined}

join(player_2)

{:ok, joined}

join(player_3)

12

{:ok, joined}

add_player(state, player_1)

nuevo estado con player_1

add_player(state, player_2)

nuevo estado con player_2

add_player(state, player_3)

nuevo estado con player_3

5

7

9

11

13

15

6

10

14

21

23

obtener pregunta

pregunta seleccionada

22

alt

[jugadores >=
3]

Envía mensaje interno
start_game
16

[jugadores <
3]

Permanece en waiting
17

handle_cast(:start_game)
18

Cambia phase a playing
19

[Por cada ronda hasta max_rounds]

loop

par

29

broadcast pregunta

broadcast pregunta

broadcast pregunta

[Respuestas concurrentes]

answer(player_1, opción, timestamp)

32

answer(player_2, opción, timestamp)

35

answer(player_3, opción, timestamp)

broadcast marcador

broadcast marcador

broadcast marcador

next_question(state, round)

current_question

20

24

25

26

27

send_after(self, :round_timeout, tiempo)

temporizador activo

28

39

register_answer(state, player_1, answer)
30

estado con respuesta registrada

31

register_answer(state, player_2, answer)
33

estado con respuesta registrada

34

register_answer(state, player_3, answer)
36

estado con respuesta registrada

alt

cerrar ronda anticipadamente
38

37

[todos respondieron]

[se acaba el tiempo]

:round_timeout

evaluate_round(state)

puntajes actualizados
answers limpiadas

41

40

42

43

alt

44
[round ==
max_rounds]

phase: finished
45

[quedan rondas]

preparar siguiente ronda
46

broadcast resultados finales

broadcast resultados finales

broadcast resultados finales

calcular ganador final

ganador y resultados finales

48

47

49

50

51

Fin del proceso de partida
52

Jugador 1

Jugador 2

Jugador 3

TriviaCrackQuiz.Application

Supervisor OTP

GameServer

Game
Funciones puras

QuestionBank

Process.send_after/3

