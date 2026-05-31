# Guia de instalacion local

Esta guia explica que debe instalar cada integrante para ejecutar el proyecto
Trivia Crack Quiz Multiplayer en su computadora.

## Recomendacion por sistema operativo

- **Ubuntu o Debian:** ruta recomendada si ya trabajan en Linux.
- **Windows:** se recomienda usar **WSL con Ubuntu** para evitar problemas con
  rutas, dependencias y comandos de desarrollo.
- **macOS:** se recomienda usar Homebrew.
- **Windows sin WSL:** tambien funciona, pero puede requerir mas cuidado con la
  instalacion de Erlang, Elixir y Git.

## Requisitos generales

Todos deben tener:

- Git
- Erlang/OTP 26 o superior
- Elixir 1.15 o superior
- Acceso a internet la primera vez para descargar dependencias

El proyecto usa:

- Phoenix Framework
- Phoenix LiveView
- OTP/GenServer
- Tailwind CSS
- esbuild

Para verificar el entorno base:

```bash
git --version
elixir --version
mix --version
```

Si los tres comandos muestran una version, el entorno base esta listo.

## Ubuntu o Debian

Instalar dependencias del sistema:

```bash
sudo apt update
sudo apt install -y git curl build-essential inotify-tools
```

`inotify-tools` es recomendado en Linux porque Phoenix lo usa para recargar la
pagina automaticamente durante desarrollo.

### Instalar Erlang y Elixir con asdf

Esta opcion permite manejar versiones de Erlang y Elixir por proyecto.

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

Verificar:

```bash
elixir --version
mix --version
```

## Windows recomendado: WSL con Ubuntu

Esta es la opcion mas recomendable para el equipo si alguien usa Windows.
Permite trabajar casi igual que en Ubuntu.

1. Instalar WSL desde PowerShell como administrador:

```powershell
wsl --install
```

2. Reiniciar la computadora si Windows lo solicita.
3. Abrir Ubuntu desde el menu de inicio.
4. Dentro de Ubuntu/WSL, seguir la seccion **Ubuntu o Debian** de esta guia.
5. Clonar y ejecutar el proyecto dentro del sistema de archivos de WSL.

Recomendado:

```bash
cd ~
git clone <URL_DEL_REPOSITORIO>
cd Juego_Multijugador_Paradigm_Funcional_QUIZZ
```

Evitar trabajar desde rutas tipo `/mnt/c/...` porque pueden ser mas lentas o
generar problemas con watchers de archivos.

## Windows sin WSL

Esta opcion es valida, pero puede ser menos uniforme que WSL.

Instalar:

1. Git desde `https://git-scm.com/download/win`
2. Erlang/OTP desde `https://www.erlang.org/downloads`
3. Elixir desde `https://elixir-lang.org/install.html#windows`

Luego cerrar y volver a abrir PowerShell o Git Bash.

Verificar:

```powershell
git --version
elixir --version
mix --version
```

Para ejecutar comandos del proyecto en Windows, usar PowerShell o Git Bash:

```powershell
mix deps.get
mix setup
mix phx.server
```

Si aparece algun error con rutas o permisos, usar WSL suele resolverlo de forma
mas simple.

## macOS

Instalar Homebrew si aun no esta instalado:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Instalar Git y Elixir:

```bash
brew install git elixir
```

Homebrew normalmente instala Erlang/OTP como dependencia de Elixir.

Verificar:

```bash
git --version
elixir --version
mix --version
```

## Preparar el proyecto

Estos pasos son iguales para Ubuntu, WSL, Windows y macOS una vez que Git,
Erlang y Elixir ya estan instalados.

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

Resultado esperado actualmente:

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

Si falla la descarga o construccion de Tailwind o esbuild:

```bash
mix assets.setup
mix assets.build
```

### Advertencia de inotify-tools en Linux

Si en Ubuntu o WSL aparece una advertencia similar a:

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

En Windows PowerShell el comando equivalente es:

```powershell
$env:PORT=4001; mix phx.server
```

## Resumen rapido

Para alguien que ya tiene Git, Erlang y Elixir instalados:

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
