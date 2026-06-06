defmodule SplitQuestionsByCategory do
  @moduledoc false

  @input_path Path.expand("../priv/data/question.json", __DIR__)
  @output_dir Path.expand("../priv/data/questions", __DIR__)

  def run do
    questions =
      @input_path
      |> File.read!()
      |> Jason.decode!()

    File.mkdir_p!(@output_dir)

    questions
    |> Enum.group_by(& &1["category"])
    |> Enum.each(fn {category, category_questions} ->
      path = Path.join(@output_dir, "#{category}.json")
      File.write!(path, Jason.encode!(category_questions, pretty: true))
      IO.puts("#{path}: #{length(category_questions)} preguntas")
    end)
  end
end

SplitQuestionsByCategory.run()
