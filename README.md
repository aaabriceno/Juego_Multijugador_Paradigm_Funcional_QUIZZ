# Preguntados: Trivia Crack Quiz Multiplayer

Juego multijugador de preguntas inspirado en Trivia Crack: Brain Quiz Games,
desarrollado en Elixir con paradigma funcional y procesos ligeros de OTP.

## Objetivo

Implementar una trivia interactiva para minimo 3 jugadores simultaneos. Cada
jugador responde preguntas de distintas categorias y el servidor mantiene un
estado coherente de la partida usando estructuras inmutables, funciones puras y
paso de mensajes entre procesos.

## Avance 1

La definicion del juego, el lenguaje elegido y el borrador del diagrama de
estructura estan en:

- [docs/avance_1.md](docs/avance_1.md)

## Requisitos

- Elixir 1.17 o compatible
- Erlang/OTP 27 o compatible

## Ejecucion inicial

```bash
mix deps.get
mix test
iex -S mix
```

Desde `iex -S mix` se podran probar los modulos base mientras se implementa la
logica completa del servidor multijugador.
