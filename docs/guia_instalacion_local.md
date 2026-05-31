# Guia de instalacion local

Esta guia explica que debe instalar cada integrante para ejecutar el proyecto
Trivia Crack Quiz Multiplayer en su computadora.

## Requisitos principales

- Git
- Elixir 1.15 o superior
- Erlang/OTP 26 o superior
- Acceso a internet para descargar dependencias la primera vez

El proyecto usa:

- Phoenix Framework
- Phoenix LiveView
- OTP/GenServer
- Tailwind CSS
- esbuild

## Verificar instalacion

Cada integrante debe abrir una terminal y ejecutar:

```bash
git --version
elixir --version
mix --version
```

Si los tres comandos responden con una version, el entorno base esta listo.

## Instalacion en Ubuntu o Debian

Instalar dependencias del sistema:

```bash
sudo apt update
sudo apt install -y git curl build-essential inotify-tools
```

Instalar Erlang y Elixir. Una opcion recomendada es usar `asdf`, porque permite
tener versiones controladas por proyecto:

```bash
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
source ~/.bashrc
asdf plugin add erlang
asdf plugin add elixir
asdf install erlang 27.3.4
asdf install elixir 1.17.3-otp-27
asdf global erlang 27.3.4
asdf global elixir 1.17.3-otp-27
```

`inotify-tools` es opcional para ejecutar el juego, pero recomendado para que
Phoenix recargue la pagina automaticamente durante el desarrollo.

## Instalacion en Windows

Opcion recomendada:

1. Instalar Git desde `https://git-scm.com/download/win`.
2. Instalar Erlang/OTP desde `https://www.erlang.org/downloads`.
3. Instalar Elixir desde `https://elixir-lang.org/install.html#windows`.
4. Reiniciar la terminal.
5. Verificar:

```bash
elixir --version
mix --version
```

Tambien se puede trabajar con WSL usando Ubuntu, siguiendo los pasos de la
seccion anterior.

## Instalacion en macOS

Con Homebrew:

```bash
brew install git elixir
```

Verificar:

```bash
elixir --version
mix --version
```

## Preparar el proyecto

Clonar el repositorio:

```bash
git clone <URL_DEL_REPOSITORIO>
cd Juego_Multijugador_Paradigm_Funcional_QUIZZ
```

Instalar dependencias de Elixir y assets:

```bash
mix deps.get
mix setup
```

`mix setup` ejecuta internamente:

- `mix deps.get`
- instalacion local de Tailwind si falta
- instalacion local de esbuild si falta
- compilacion de assets

## Ejecutar el juego

Iniciar Phoenix:

```bash
mix phx.server
```

Luego abrir en el navegador:

```text
http://localhost:4000
```

Para probar el modo multijugador local, abrir la misma URL en tres ventanas o
tres navegadores distintos. Cada ventana puede registrar un jugador diferente.

## Ejecutar pruebas

```bash
mix test
```

Resultado esperado:

```text
8 tests, 0 failures
```

El numero de tests puede aumentar cuando el proyecto avance.

## Comandos utiles

Formatear codigo:

```bash
mix format
```

Compilar:

```bash
mix compile
```

Construir assets:

```bash
mix assets.build
```

Ejecutar servidor con consola interactiva:

```bash
iex -S mix phx.server
```

## Problemas comunes

### Error al descargar dependencias

Si `mix deps.get` falla, revisar que haya conexion a internet. El proyecto
descarga paquetes desde Hex y GitHub.

Volver a intentar:

```bash
mix deps.get
```

### Error con Tailwind o esbuild

Si falla la descarga de Tailwind o esbuild:

```bash
mix assets.setup
mix assets.build
```

### Advertencia de inotify-tools en Linux

Si aparece una advertencia similar a:

```text
inotify-tools is needed to run file_system
```

Instalar:

```bash
sudo apt install -y inotify-tools
```

Esta advertencia no impide ejecutar el juego; solo afecta la recarga automatica
del navegador durante desarrollo.

### Puerto 4000 ocupado

Si Phoenix indica que el puerto 4000 esta ocupado, cerrar el otro proceso o usar
otro puerto:

```bash
PORT=4001 mix phx.server
```

Luego abrir:

```text
http://localhost:4001
```

## Resumen rapido

Para alguien que ya tiene Elixir instalado:

```bash
git clone <URL_DEL_REPOSITORIO>
cd Juego_Multijugador_Paradigm_Funcional_QUIZZ
mix setup
mix test
mix phx.server
```

Abrir:

```text
http://localhost:4000
```
