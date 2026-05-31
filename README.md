# Trivia Crack Quiz Multiplayer

Juego multijugador de preguntas desarrollado en Elixir, Phoenix LiveView y OTP.
La partida usa un `GameServer` supervisado para coordinar jugadores, rondas,
temporizadores y puntajes mediante paso de mensajes.

## Estructura principal

- `lib/trivia_crack_quiz/game/`: dominio del juego, funciones puras, banco de
  preguntas y actor OTP.
- `lib/trivia_crack_quiz_web/live/`: interfaz grafica en Phoenix LiveView.
- `docs/`: avances, diagramas y documentos del proyecto.
- `assets/`: estilos y JavaScript de Phoenix.

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

## Verificacion

```bash
mix test
```
