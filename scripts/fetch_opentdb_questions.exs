defmodule FetchOpenTDBQuestions do
  @moduledoc false

  @output_path Path.expand("../priv/data/question.json", __DIR__)

  @categories [
    %{local: "tecnologia", opentdb_id: 18},
    %{local: "ciencia", opentdb_id: 17},
    %{local: "historia", opentdb_id: 23},
    %{local: "deportes", opentdb_id: 21},
    %{local: "cultura_general", opentdb_id: 9}
  ]

  def run do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    questions =
      @categories
      |> Enum.flat_map(&fetch_category/1)
      |> Enum.with_index(1)
      |> Enum.map(fn {question, id} -> Map.put(question, "id", id) end)

    File.mkdir_p!(Path.dirname(@output_path))
    File.write!(@output_path, Jason.encode!(questions, pretty: true))

    IO.puts("Se guardaron #{length(questions)} preguntas en #{@output_path}")
  end

  defp fetch_category(%{local: local_category, opentdb_id: opentdb_id}) do
    IO.puts("Descargando preguntas para #{local_category}...")

    1..2
    |> Enum.flat_map(fn _batch ->
      url =
        "https://opentdb.com/api.php?amount=30&category=#{opentdb_id}&type=multiple&encode=url3986"
        |> String.to_charlist()

      response = request(url)

      # OpenTDB recomienda no hacer llamadas demasiado seguidas.
      Process.sleep(5_500)

      response
      |> Map.fetch!("results")
      |> Enum.map(&normalize_question(&1, local_category))
    end)
  end

  defp request(url) do
    case :httpc.request(:get, {url, []}, [{:timeout, 15_000}], body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        Jason.decode!(body)

      {:ok, {{_, status, _}, _headers, body}} ->
        raise "OpenTDB respondio con estado #{status}: #{body}"

      {:error, reason} ->
        raise "No se pudo consultar OpenTDB: #{inspect(reason)}"
    end
  end

  defp normalize_question(raw, local_category) do
    answer = decode(raw["correct_answer"])

    incorrect_answers =
      raw["incorrect_answers"]
      |> Enum.map(&decode/1)

    %{
      "id" => nil,
      "category" => local_category,
      "type" => type(raw["type"]),
      "difficulty" => raw["difficulty"],
      "text" => decode(raw["question"]),
      "options" => Enum.shuffle([answer | incorrect_answers]),
      "answer" => answer,
      "source" => "Open Trivia Database"
    }
  end

  defp type("multiple"), do: "multiple_choice"
  defp type("boolean"), do: "true_false"
  defp type(type), do: type

  defp decode(value) do
    value
    |> URI.decode()
    |> String.replace("&quot;", "\"")
    |> String.replace("&#039;", "'")
    |> String.replace("&amp;", "&")
    |> String.replace("&eacute;", "e")
    |> String.replace("&uuml;", "u")
  end
end

FetchOpenTDBQuestions.run()
