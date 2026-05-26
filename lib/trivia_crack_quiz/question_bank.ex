defmodule TriviaCrackQuiz.QuestionBank do
  @moduledoc """
  Banco inicial de preguntas para la trivia.
  """

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
      }
    ]
  end
end
