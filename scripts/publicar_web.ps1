# Publica la versión web en GitHub Pages (rama gh-pages).
#
# ANTES de correrlo: las migraciones de supabase/migrations deben estar
# aplicadas en producción (ver supabase/produccion/). Si no, la página nueva
# manda datos que el servidor todavía no conoce y quedan en cola.
#
# Uso (desde la carpeta del proyecto, en PowerShell):
#   .\scripts\publicar_web.ps1
#
# - La app y su motor de dibujo (CanvasKit) van completos en la página:
#   no se descarga nada de servidores externos al abrirla.
# - Las claves públicas de Supabase salen de dart_defines.json (no se sube a
#   git); nunca van escritas en el código.

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz

if (-not (Test-Path 'dart_defines.json')) {
  throw 'Falta dart_defines.json (URL y clave pública de Supabase).'
}

flutter build web --release --no-web-resources-cdn --base-href /vertex-ai-pyme/ `
  --dart-define-from-file=dart_defines.json
if ($LASTEXITCODE -ne 0) { throw 'La compilación web falló.' }

$commit = (git rev-parse --short HEAD).Trim()
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("vertex_gh_pages_" + [guid]::NewGuid().ToString('N'))
git worktree add --detach $tmp
try {
  Push-Location $tmp
  git checkout --orphan gh-pages-nueva
  git rm -rf --quiet . 2>$null
  Copy-Item -Recurse -Force (Join-Path $raiz 'build\web\*') $tmp
  # GitHub Pages no debe procesar los archivos con Jekyll.
  New-Item -ItemType File -Force (Join-Path $tmp '.nojekyll') | Out-Null
  git add -A
  git commit -q -m "Web: versión $commit"
  git push -f origin gh-pages-nueva:gh-pages
  Pop-Location
} finally {
  git worktree remove --force $tmp
  git branch -D gh-pages-nueva 2>$null
}
Write-Host "Publicada la versión $commit en https://ingdavidortegaf-lab.github.io/vertex-ai-pyme/"
