# Banco de preguntas

El juego carga preguntas principalmente desde archivos separados por categoria:

```text
priv/data/questions/
```

Estructura recomendada:

```text
priv/data/questions/arte.json
priv/data/questions/tecnologia.json
priv/data/questions/ciencia.json
priv/data/questions/historia.json
priv/data/questions/deportes.json
priv/data/questions/cultura_general.json
```

Tambien se mantiene este archivo como respaldo o punto de generacion inicial:

```text
priv/data/question.json
```

## Fuente recomendada

Para generar una base inicial se recomienda usar Open Trivia Database:

```text
https://opentdb.com/
```

Esta fuente es gratuita, no requiere API key y entrega preguntas en formato JSON.
Segun su documentacion, los datos estan publicados bajo licencia Creative
Commons Attribution-ShareAlike 4.0 International.

## Generar preguntas

Ejecutar:

```bash
mix run scripts/fetch_opentdb_questions.exs
```

El script descarga 360 preguntas:

- 60 de arte
- 60 de tecnologia
- 60 de ciencia
- 60 de historia
- 60 de deportes
- 60 de cultura general

El resultado inicial se guarda en:

```text
priv/data/question.json
```

Para separar ese archivo en 5 archivos por categoria, ejecutar:

```bash
mix run scripts/split_questions_by_category.exs
```

## Validar preguntas

Cada vez que se editen preguntas, ejecutar:

```bash
mix run scripts/validate_questions.exs
```

El validador revisa:

- que cada pregunta tenga `id`, `category`, `type`, `text`, `options` y `answer`
- que la categoria coincida con el archivo donde esta guardada
- que `multiple_choice` tenga 4 opciones y que `answer` exista dentro de
  `options`
- que `true_false` tenga exactamente `["Verdadero", "Falso"]`
- que `quick_answer` tenga `options` vacio
- que no haya ids repetidos

## Reglas de seleccion durante la partida

El motor del juego carga todas las preguntas en memoria al iniciar la partida.
Durante una sala:

- no se repiten preguntas ya usadas
- se evita repetir la misma categoria en rondas consecutivas mientras existan
  preguntas disponibles de otras categorias
- la partida usa `max_rounds` para limitar la cantidad de rondas
- si en un escenario pequeno se agotan las preguntas disponibles, el motor puede
  volver a usar el banco completo para evitar que la partida se rompa

## Formato esperado

```json
{
  "id": 1,
  "category": "tecnologia",
  "type": "multiple_choice",
  "difficulty": "medium",
  "text": "What does CPU stand for?",
  "options": [
    "Central Processing Unit",
    "Computer Personal Unit",
    "Central Program Utility",
    "Control Processing Unit"
  ],
  "answer": "Central Processing Unit",
  "source": "Open Trivia Database"
}
```

## Nota importante

Open Trivia Database devuelve muchas preguntas en ingles. Para una entrega mas
pulida, el equipo puede revisar y traducir manualmente las preguntas mas
importantes despues de generar el archivo JSON.
