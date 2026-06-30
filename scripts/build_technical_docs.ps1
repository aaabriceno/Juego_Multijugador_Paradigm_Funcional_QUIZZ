$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$docsDir = Join-Path $repoRoot "docs"
$figuresDir = Join-Path $docsDir "figures"
$tectonic = Join-Path $repoRoot "tmp\tools\tectonic\tectonic.exe"
$mmdc = Join-Path $repoRoot "tmp\mermaid\node_modules\.bin\mmdc.cmd"
$mermaidConfig = Join-Path $figuresDir "mermaid-config.json"

if (-not (Test-Path $tectonic)) {
  throw "No se encontro tectonic en $tectonic."
}

if (-not (Test-Path $mmdc)) {
  throw "No se encontro Mermaid CLI en $mmdc."
}

$diagrams = @(
  @{ Input = "estructura_juego.mmd"; Output = "estructura_juego.png"; Width = 1800; Height = 1200 },
  @{ Input = "concurrencia_sala.mmd"; Output = "concurrencia_sala.png"; Width = 1800; Height = 1200 }
)

foreach ($diagram in $diagrams) {
  & $mmdc `
    -i (Join-Path $figuresDir $diagram.Input) `
    -o (Join-Path $figuresDir $diagram.Output) `
    -c $mermaidConfig `
    -b white `
    -w $diagram.Width `
    -H $diagram.Height `
    -s 2
}

Push-Location $docsDir
try {
  & $tectonic --outdir $docsDir (Join-Path $docsDir "documentacion_tecnica.tex")
}
finally {
  Pop-Location
}
