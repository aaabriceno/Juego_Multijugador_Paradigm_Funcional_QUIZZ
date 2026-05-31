defmodule TriviaCrackQuizWeb.PageHTML do
  @moduledoc """
  Este modulo contiene paginas renderizadas por `PageController`.

  Las plantillas disponibles estan dentro de la carpeta `page_html`.
  """
  use TriviaCrackQuizWeb, :html

  embed_templates "page_html/*"
end
