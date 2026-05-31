defmodule TriviaCrackQuizWeb.Gettext do
  @moduledoc """
  Modulo encargado de las traducciones de la aplicacion usando Gettext.

  Este backend permite centralizar textos traducibles. Para usarlo en otro
  modulo se llama a `use Gettext` indicando este backend:

      use Gettext, backend: TriviaCrackQuizWeb.Gettext

      # Traduccion simple
      gettext("Here is the string to translate")

      # Traduccion con plural
      ngettext("Here is the string to translate",
               "Here are the strings to translate",
               3)

      # Traduccion por dominio
      dgettext("errors", "Here is the error message to translate")
  """
  use Gettext.Backend, otp_app: :trivia_crack_quiz
end
