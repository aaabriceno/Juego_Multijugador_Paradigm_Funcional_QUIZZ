defmodule TriviaCrackQuizWeb do
  @moduledoc """
  Punto central para definir la capa web del proyecto.
  Desde aqui se configuran controladores, componentes, LiveViews y otros
  modulos relacionados con Phoenix.

  Se usa dentro de otros modulos asi:

      use TriviaCrackQuizWeb, :controller
      use TriviaCrackQuizWeb, :html

  Las definiciones de abajo se ejecutan en cada controlador, componente o
  LiveView que use este modulo. Por eso se mantienen cortas y enfocadas en
  imports, uses y aliases.

  No conviene definir logica de negocio dentro de los bloques `quote`.
  Si hace falta mas funcionalidad, se crea otro modulo y se importa aqui.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Funciones comunes para trabajar con conexiones y controladores.
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: TriviaCrackQuizWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Funciones utiles de los controladores para usar en vistas.
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Funciones auxiliares generales para renderizar HTML.
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Soporte para traducciones.
      use Gettext, backend: TriviaCrackQuizWeb.Gettext

      # Funciones para escapar y manejar HTML.
      import Phoenix.HTML
      # Componentes base de la interfaz.
      import TriviaCrackQuizWeb.CoreComponents

      # Modulos comunes usados en plantillas.
      alias Phoenix.LiveView.JS
      alias TriviaCrackQuizWeb.Layouts

      # Generacion segura de rutas con el sigil ~p.
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: TriviaCrackQuizWeb.Endpoint,
        router: TriviaCrackQuizWeb.Router,
        statics: TriviaCrackQuizWeb.static_paths()
    end
  end

  @doc """
  Cuando se usa este modulo, se envia al tipo correcto: controller, live_view,
  html, entre otros.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
