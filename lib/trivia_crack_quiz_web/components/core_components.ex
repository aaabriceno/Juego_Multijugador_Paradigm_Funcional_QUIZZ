defmodule TriviaCrackQuizWeb.CoreComponents do
  @moduledoc """
  Componentes base de interfaz para la aplicacion.

  Aunque este archivo es largo, su objetivo es juntar piezas reutilizables como
  formularios, inputs, tablas, iconos y mensajes. La idea es no repetir markup
  en todas las pantallas.

  Los estilos se apoyan en Tailwind CSS y daisyUI, que nos dan utilidades y
  componentes visuales para construir la interfaz del juego.

    * [daisyUI](https://daisyui.com/docs/intro/) - componentes y temas listos.

    * [Tailwind CSS](https://tailwindcss.com) - utilidades para layout,
      tamanos, flexbox, grid y espaciado.

    * [Heroicons](https://heroicons.com) - iconos usados por `icon/1`.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      sistema de componentes usado por Phoenix.

  """
  use Phoenix.Component
  use Gettext, backend: TriviaCrackQuizWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renderiza mensajes flash.

  ## Ejemplo

      <.flash kind={:info} flash={@flash} />
      <.flash
        id="welcome-back"
        kind={:info}
        phx-mounted={show("#welcome-back") |> JS.remove_attribute("hidden")}
        hidden
      >
        Bienvenido de nuevo!
      </.flash>
  """
  attr :id, :string, doc: "id opcional del contenedor flash"
  attr :flash, :map, default: %{}, doc: "mapa de mensajes flash a mostrar"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "tipo de mensaje flash"
  attr :rest, :global, doc: "atributos HTML extra para el contenedor flash"

  slot :inner_block, doc: "bloque opcional que renderiza el mensaje flash"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          
          <p>{msg}</p>
        </div>
         <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renderiza un boton con soporte de navegacion.

  ## Ejemplos

      <.button>Enviar!</.button>
      <.button phx-click="go" variant="primary">Enviar!</.button>
      <.button navigate={~p"/"}>Inicio</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "btn-primary", nil => "btn-primary btn-soft"}

    assigns =
      assign_new(assigns, :class, fn ->
        ["btn", Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>{render_slot(@inner_block)}</.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>{render_slot(@inner_block)}</button>
      """
    end
  end

  @doc """
  Renderiza un input con etiqueta y mensajes de error.

  Se puede pasar un `Phoenix.HTML.FormField` como argumento. Con eso Phoenix
  obtiene el nombre, id y valor del input. Si no se usa un campo de formulario,
  los atributos se pueden pasar manualmente.

  ## Tipos

  Esta funcion acepta los tipos de input HTML, considerando que:

    * Se puede usar `type="select"` para renderizar un `<select>`

    * `type="checkbox"` se usa para valores booleanos

    * Para subir archivos con LiveView se usa `Phoenix.Component.live_file_input/1`

  Los tipos no soportados, como radio, se pueden escribir directamente en las
  plantillas cuando haga falta.

  ## Ejemplos

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Tipo select

  Cuando se usa `type="select"`, se deben pasar las `options` y opcionalmente
  un `value` para marcar la opcion preseleccionada.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  Phoenix usa `options_for_select/2` internamente para construir las opciones.
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "campo obtenido desde el formulario, por ejemplo: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "indica si el checkbox esta marcado"
  attr :prompt, :string, default: nil, doc: "texto inicial para inputs select"
  attr :options, :list, doc: "opciones que se pasan al select"
  attr :multiple, :boolean, default: false, doc: "permite seleccion multiple"
  attr :class, :any, default: nil, doc: "clase CSS del input"
  attr :error_class, :any, default: nil, doc: "clase CSS para input con error"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset mb-2">
      <label for={@id}>
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label for={@id}>
        <span :if={@label} class="label mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "w-full select", @errors != [] && (@error_class || "select-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
           {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label for={@id}>
        <span :if={@label} class="label mb-1">{@label}</span> <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea",
            @errors != [] && (@error_class || "textarea-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label for={@id}>
        <span :if={@label} class="label mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "w-full input",
            @errors != [] && (@error_class || "input-error")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Funcion auxiliar usada por los inputs para mostrar errores del formulario.
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle" class="size-5" /> {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renderiza un encabezado con titulo.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">{render_slot(@inner_block)}</h1>
        
        <p :if={@subtitle != []} class="text-sm text-base-content/70">{render_slot(@subtitle)}</p>
      </div>
      
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renderiza una tabla con estilos generales.

  ## Ejemplo

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "funcion para generar el id de cada fila"
  attr :row_click, :any, default: nil, doc: "funcion para manejar phx-click en cada fila"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "funcion para transformar cada fila antes de llamar a los slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "slot para mostrar acciones en la ultima columna"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          
          <th :if={@action != []}><span class="sr-only">{gettext("Actions")}</span></th>
        </tr>
      </thead>
      
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renderiza una lista de datos.

  ## Ejemplo

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>
          
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renderiza un icono de [Heroicons](https://heroicons.com).

  Heroicons tiene tres estilos: outline, solid y mini. Por defecto se usa
  outline, pero se puede usar `-solid` o `-mini` como sufijo.

  El tamano y color se personalizan con clases CSS.

  Los iconos se toman desde `deps/heroicons` y se incluyen en el CSS compilado
  mediante el plugin de `assets/vendor/heroicons.js`.

  ## Ejemplos

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## Comandos JS

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Traduce un mensaje de error usando Gettext.
  """
  def translate_error({msg, opts}) do
    # Con Gettext normalmente pasamos los textos a traducir como argumentos
    # estaticos:
    #
    #     # Traduce cantidades usando reglas de plural
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # En formularios y APIs los errores se generan de forma dinamica,
    # por eso llamamos a Gettext usando nuestro backend. Las traducciones
    # estan en errors.po porque usamos el dominio "errors".
    if count = opts[:count] do
      Gettext.dngettext(TriviaCrackQuizWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(TriviaCrackQuizWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Traduce los errores de un campo a partir de una lista keyword.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
