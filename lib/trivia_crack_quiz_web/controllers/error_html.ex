defmodule TriviaCrackQuizWeb.ErrorHTML do
  @moduledoc """
  Este modulo se usa cuando ocurre un error en una peticion HTML.

  La configuracion relacionada se encuentra en `config/config.exs`.
  """
  use TriviaCrackQuizWeb, :html

  # Si queremos personalizar paginas de error, se puede descomentar
  # embed_templates/1 y agregar plantillas en la carpeta de errores:
  #
  #   * lib/trivia_crack_quiz_web/controllers/error_html/404.html.heex
  #   * lib/trivia_crack_quiz_web/controllers/error_html/500.html.heex
  #
  # embed_templates "error_html/*"

  # Por defecto Phoenix devuelve un texto segun el nombre de la plantilla.
  # Por ejemplo, "404.html" se convierte en "Not Found".
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
