defmodule TriviaCrackQuizWeb.ErrorJSON do
  @moduledoc """
  Este modulo se usa cuando ocurre un error en una peticion JSON.

  La configuracion relacionada se encuentra en `config/config.exs`.
  """

  # Si queremos personalizar un codigo de estado especifico,
  # podemos agregar nuestras propias clausulas, por ejemplo:
  #
  # def render("500.json", _assigns) do
  #   %{errors: %{detail: "Internal Server Error"}}
  # end

  # Por defecto Phoenix devuelve el mensaje del estado segun el nombre
  # de la plantilla. Por ejemplo, "404.json" se convierte en "Not Found".
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
