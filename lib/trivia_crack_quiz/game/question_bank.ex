defmodule TriviaCrackQuiz.QuestionBank do
  @moduledoc """
  Banco inicial de preguntas para la trivia.
  """

  @questions_dir "priv/data/questions"
  @questions_path "priv/data/question.json"

  def load_questions do
    cond do
      File.dir?(@questions_dir) ->
        load_questions_from_directory()

      File.exists?(@questions_path) ->
        load_questions_from_file(@questions_path)

      true ->
        sample_questions()
    end
  end

  defp load_questions_from_directory do
    @questions_dir
    |> Path.join("*.json")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.flat_map(&load_questions_from_file/1)
  end

  defp load_questions_from_file(path) do
    path
    |> File.read()
    |> case do
      {:ok, content} ->
        content
        |> Jason.decode!()
        |> Enum.map(&normalize_question/1)

      {:error, _reason} ->
        []
    end
  end

  def sample_questions do
    [
      %{
        id: 1,
        type: :multiple_choice,
        category: :science,
        text: "Que planeta es conocido como el planeta rojo?",
        options: ["Venus", "Marte", "Jupiter", "Saturno"],
        answer: "Marte"
      },
      %{
        id: 2,
        type: :true_false,
        category: :history,
        text: "La independencia del Peru se proclamo en 1821.",
        options: ["Verdadero", "Falso"],
        answer: "Verdadero"
      },
      %{
        id: 3,
        type: :quick_answer,
        category: :technology,
        text: "Que lenguaje funcional corre sobre la maquina virtual de Erlang?",
        options: [],
        answer: "Elixir"
      },
      %{
        id: 4,
        type: :multiple_choice,
        category: :culture,
        text: "Cual es la capital de Peru?",
        options: ["Cusco", "Lima", "Arequipa", "Trujillo"],
        answer: "Lima"
      },
      %{
        id: 5,
        type: :true_false,
        category: :sports,
        text: "Un partido de futbol profesional tiene dos tiempos principales.",
        options: ["Verdadero", "Falso"],
        answer: "Verdadero"
      }
    ]
  end

  defp normalize_question(question) do
    %{
      id: question["id"],
      type: atomize(question["type"]),
      category: atomize(question["category"]),
      text: question["text"] || question["question"],
      options: question["options"] || [],
      answer: question["answer"],
      # Respuestas alternativas aceptadas (ademas de "answer"), util en
      # preguntas de respuesta abierta. Opcional en el JSON.
      accept: question["accept"] || [],
      # Pista opcional que el jugador puede revelar con un boton.
      hint: question["hint"],
      difficulty: question["difficulty"],
      source: question["source"]
    }
  end

  defp atomize(value) when is_binary(value) do
    value
    |> String.replace(" ", "_")
    |> String.downcase()
    |> String.to_atom()
  end

  defp atomize(value), do: value
end
