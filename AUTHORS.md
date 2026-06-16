# Autores

Proyecto: **Trivia Crack Quiz Multiplayer** — juego multijugador de trivia
construido con Elixir, Phoenix LiveView y OTP (paradigma funcional).

> La autoría de cada línea de código es verificable con `git blame <archivo>`
> y `git log --author="<nombre>"`. La siguiente tabla resume el aporte de cada
> integrante por componente.

## Aportes por componente

| Componente | Responsable | Descripción |
|---|---|---|
| Backend OTP / Actores | **Anthony Briceño** | `GameServer` (un actor por sala), supervisión dinámica, `Registry`. |
| Sistema de salas (N salas) | **Anthony Briceño** | `Rooms` manager, `DynamicSupervisor`, lobby y enrutado por sala. |
| Lógica del juego (motor puro) | **Anthony Briceño** | Módulo `Game` (engine): estado, rondas, puntaje, evaluación. |
| Frontend / LiveView | **Anthony Briceño**, **Sixto Cáceres**, **Paolo Mostajo** | `GameLive`, `LobbyLive`, vistas, animaciones, sonido, confeti. |
| Pruebas (ExUnit) | **Anthony Briceño** | Suite de tests de la lógica y de las salas. |
| Base de la secuencia de estados | **Paolo Mostajo** | Diseño inicial de la máquina de fases del juego. |
| Diagrama de flujos | **Sixto Cáceres** | Diagrama de flujo del juego. |
| Apoyo en frontend | **Paolo Mostajo**, **Sixto Cáceres** | Ajustes y aportes puntuales en la interfaz. |

## Contacto

- Anthony Briceño — anthonyquiroz305@gmail.com
