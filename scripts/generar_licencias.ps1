# Genera docs/LICENCIAS.md con TODAS las dependencias (directas y
# transitivas) y su licencia, leyendo el archivo LICENSE de cada paquete.
# Requiere haber corrido `flutter pub get`.
#   powershell -ExecutionPolicy Bypass -File .\scripts\generar_licencias.ps1
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$cfg = Join-Path $raiz '.dart_tool\package_config.json'
if (-not (Test-Path $cfg)) { throw 'Primero ejecuta: flutter pub get' }

function Clasificar([string]$t) {
  if ($t -match 'Apache License') { return 'Apache-2.0' }
  if ($t -match 'Mozilla Public License') { return 'MPL-2.0' }
  if ($t -match 'GNU (Lesser|Library) General') { return 'LGPL (REVISAR)' }
  if ($t -match 'GNU General Public') { return 'GPL (REVISAR)' }
  if ($t -match 'Permission is hereby granted, free of charge') { return 'MIT' }
  if ($t -match 'Redistribution and use in source and binary forms') {
    if ($t -match 'Neither the name') { return 'BSD-3-Clause' }
    return 'BSD-2-Clause'
  }
  if ($t -match 'Permission to use, copy, modify, and/or distribute') { return 'ISC' }
  if ($t -match 'public domain') { return 'Dominio publico' }
  return 'REVISAR'
}

$json = Get-Content $cfg -Raw | ConvertFrom-Json
$baseCfg = New-Object Uri ((Resolve-Path $cfg).Path)
$filas = @()
foreach ($p in $json.packages) {
  if ($p.name -eq 'vertex_ai_pyme') { continue }
  $uri = New-Object Uri ($baseCfg, $p.rootUri)
  $dir = $uri.LocalPath
  $lic = Get-ChildItem $dir -File -ErrorAction SilentlyContinue |
         Where-Object { $_.Name -match '^(LICENSE|LICENCE|COPYING)' } | Select-Object -First 1
  $tipo = if ($lic) { Clasificar (Get-Content $lic.FullName -Raw) } else { 'Sin archivo LICENSE (REVISAR)' }
  $version = ''
  $pub = Join-Path $dir 'pubspec.yaml'
  if (Test-Path $pub) {
    $linea = Select-String -Path $pub -Pattern '^version:\s*(.+)$' | Select-Object -First 1
    if ($linea) { $version = $linea.Matches[0].Groups[1].Value.Trim() }
  }
  if ($dir -match '[\\/]flutter[\\/]packages[\\/]' -or $dir -match '[\\/]bin[\\/]cache[\\/]') {
    $version = 'SDK'
    # Los paquetes del SDK usan la licencia del repositorio de Flutter.
    if (-not $lic) { $tipo = 'BSD-3-Clause (Flutter SDK)' }
  }
  $filas += [pscustomobject]@{ Paquete = $p.name; Version = $version; Licencia = $tipo }
}
$filas = $filas | Sort-Object Paquete
$revisar = @($filas | Where-Object { $_.Licencia -match 'REVISAR' })

$md = @()
$md += '# Relacion de licencias - VERTEX AI Pyme'
$md += ''
$md += "Generado automaticamente el $(Get-Date -Format 'yyyy-MM-dd') con ``scripts/generar_licencias.ps1``"
$md += 'a partir del archivo LICENSE de cada paquete instalado (directo y transitivo).'
$md += ''
$md += '## Componentes principales'
$md += ''
$md += '| Componente | Licencia | Uso |'
$md += '|---|---|---|'
$md += '| Flutter SDK y Dart | BSD-3-Clause | Codigo de la app (Android e iOS) |'
$md += '| SQLite | Dominio publico | Base de datos local |'
$md += '| SQLCipher Community Edition | BSD-3-Clause (Zetetic) | Cifrado de la base local |'
$md += '| Supabase (plan gratuito) | Apache-2.0 (plataforma) / PostgreSQL License | Backend, autenticacion y RLS |'
$md += '| Deno (Edge Functions) | MIT | Funcion del asistente de IA |'
$md += '| Modelo de IA (capa gratuita via API) | Terminos del proveedor; sin costo en capa gratuita | Opcional; la app funciona sin el |'
$md += ''
$md += 'Sin imagenes, iconos ni marcas de terceros: los iconos son Material Icons (Apache-2.0, incluidos en Flutter).'
$md += ''
$md += "## Paquetes Dart/Flutter ($($filas.Count))"
$md += ''
$md += '| Paquete | Version | Licencia |'
$md += '|---|---|---|'
foreach ($f in $filas) { $md += "| $($f.Paquete) | $($f.Version) | $($f.Licencia) |" }
$md += ''
if ($revisar.Count -gt 0) {
  $md += "**Atencion:** $($revisar.Count) paquete(s) marcados REVISAR: confirmar su licencia en pub.dev antes de la entrega."
} else {
  $md += 'Todas las licencias son permisivas (BSD, MIT, Apache, ISC o dominio publico): no hay licencias de pago ni copyleft.'
}
$utf8 = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllText((Join-Path $raiz 'docs\LICENCIAS.md'), ($md -join "`n") + "`n", $utf8)
Write-Host "docs\LICENCIAS.md generado: $($filas.Count) paquetes, $($revisar.Count) por revisar."
