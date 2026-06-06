defmodule ValidateQuestions do
  @moduledoc false

  @questions_dir Path.expand("../priv/data/questions", __DIR__)
  @valid_types ["multiple_choice", "true_false", "quick_answer"]
  @true_false_options ["Verdadero", "Falso"]

  def run do
    files =
      @questions_dir
      |> Path.join("*.json")
      |> Path.wildcard()
      |> Enum.sort()

    questions_by_file =
      Enum.map(files, fn file ->
        {file, Jason.decode!(File.read!(file))}
      end)

    errors =
      questions_by_file
      |> Enum.flat_map(fn {file, questions} -> validate_file(file, questions) end)
      |> Kernel.++(validate_duplicate_ids(questions_by_file))

    print_summary(questions_by_file, errors)

    if errors == [] do
      :ok
    else
      System.halt(1)
    end
  end

  defp validate_file(file, questions) do
    category = file |> Path.basename(".json")

    questions
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {question, index} ->
      validate_question(file, category, question, index)
    end)
  end

  defp validate_question(file, expected_category, question, index) do
    id = question["id"] || "sin_id"

    []
    |> add_error(missing?(question["id"]), file, id, index, "falta id")
    |> add_error(blank?(question["category"]), file, id, index, "falta category")
    |> add_error(
      question["category"] != expected_category,
      file,
      id,
      index,
      "category no coincide con el archivo #{expected_category}"
    )
    |> add_error(blank?(question["type"]), file, id, index, "falta type")
    |> add_error(
      question["type"] not in @valid_types,
      file,
      id,
      index,
      "type invalido: #{inspect(question["type"])}"
    )
    |> add_error(blank?(question["text"]), file, id, index, "falta text")
    |> add_error(blank?(question["answer"]), file, id, index, "falta answer")
    |> Kernel.++(validate_by_type(file, id, index, question))
  end

  defp validate_by_type(file, id, index, %{"type" => "multiple_choice"} = question) do
    options = question["options"]

    []
    |> add_error(not is_list(options), file, id, index, "options debe ser una lista")
    |> add_error(is_list(options) and length(options) != 4, file, id, index, "multiple_choice debe tener 4 opciones")
    |> add_error(
      is_list(options) and question["answer"] not in options,
      file,
      id,
      index,
      "answer no existe dentro de options"
    )
    |> add_error(
      is_list(options) and length(Enum.uniq(options)) != length(options),
      file,
      id,
      index,
      "options tiene opciones repetidas"
    )
  end

  defp validate_by_type(file, id, index, %{"type" => "true_false"} = question) do
    options = question["options"]

    []
    |> add_error(options != @true_false_options, file, id, index, "true_false debe tener options #{inspect(@true_false_options)}")
    |> add_error(question["answer"] not in @true_false_options, file, id, index, "answer debe ser Verdadero o Falso")
  end

  defp validate_by_type(file, id, index, %{"type" => "quick_answer"} = question) do
    options = question["options"]

    []
    |> add_error(options != [], file, id, index, "quick_answer debe tener options vacio")
  end

  defp validate_by_type(_file, _id, _index, _question), do: []

  defp validate_duplicate_ids(questions_by_file) do
    questions =
      Enum.flat_map(questions_by_file, fn {file, questions} ->
        Enum.map(questions, fn question -> {question["id"], file} end)
      end)

    questions
    |> Enum.group_by(fn {id, _file} -> id end, fn {_id, file} -> file end)
    |> Enum.flat_map(fn
      {nil, _files} ->
        []

      {id, files} ->
        unique_files = Enum.uniq(files)

        if length(files) > 1 do
          ["id repetido #{id} en #{Enum.join(unique_files, ", ")}"]
        else
          []
        end
    end)
  end

  defp add_error(errors, false, _file, _id, _index, _message), do: errors
  defp add_error(errors, nil, _file, _id, _index, _message), do: errors

  defp add_error(errors, true, file, id, index, message) do
    ["#{Path.basename(file)} ##{index} id=#{id}: #{message}" | errors]
  end

  defp missing?(value), do: is_nil(value)

  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(value), do: is_nil(value)

  defp print_summary(questions_by_file, errors) do
    IO.puts("Resumen de preguntas:")

    Enum.each(questions_by_file, fn {file, questions} ->
      by_type = Enum.frequencies_by(questions, & &1["type"])
      IO.puts("- #{Path.basename(file)}: #{length(questions)} preguntas #{inspect(by_type)}")
    end)

    if errors == [] do
      IO.puts("\nValidacion correcta: no se encontraron errores.")
    else
      IO.puts("\nErrores encontrados:")
      Enum.each(Enum.reverse(errors), &IO.puts("- #{&1}"))
    end
  end
end

ValidateQuestions.run()
