# Prepara el proyecto Flutter una sola vez (Windows PowerShell 5.1+):
#   1. Genera las carpetas android/ e ios/ con `flutter create` (en una carpeta
#      temporal, para no tocar lib/, test/ ni pubspec.yaml).
#   2. Aplica ANDROID_IOS.md: INTERNET, <queries>, minSdk 31, sin copias de
#      seguridad, nombre visible, iOS 16.
#   3. Descarga dependencias.
# Uso, desde la carpeta del proyecto:
#   powershell -ExecutionPolicy Bypass -File .\scripts\preparar_proyecto.ps1
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz
$utf8 = New-Object System.Text.UTF8Encoding $false

function Leer($ruta) { [IO.File]::ReadAllText($ruta) }
function Escribir($ruta, $texto) { [IO.File]::WriteAllText($ruta, $texto, $utf8) }

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter no esta en el PATH. Instalalo y abre una terminal nueva.'
}

# ---------------------------------------------------------- 1. plataformas
if (-not (Test-Path "$raiz\android") -or -not (Test-Path "$raiz\ios")) {
  $tmp = Join-Path $env:TEMP 'vertex_ai_pyme_plantilla'
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  flutter create --org co.vertextech --project-name vertex_ai_pyme --platforms android,ios "$tmp"
  if ($LASTEXITCODE -ne 0) { throw 'flutter create fallo' }
  foreach ($d in @('android', 'ios')) {
    if (-not (Test-Path "$raiz\$d")) { Copy-Item "$tmp\$d" "$raiz\$d" -Recurse }
  }
  if (-not (Test-Path "$raiz\.metadata")) { Copy-Item "$tmp\.metadata" "$raiz\.metadata" }
  Remove-Item $tmp -Recurse -Force
  Write-Host 'Carpetas android/ e ios/ generadas.'
}

# ------------------------------------------------------- 2. AndroidManifest
$m = "$raiz\android\app\src\main\AndroidManifest.xml"
$x = Leer $m
if ($x -notmatch 'android.permission.INTERNET') {
  $x = $x -replace '(<manifest[^>]*>)', "`$1`r`n    <uses-permission android:name=`"android.permission.INTERNET`"/>"
}
$intents = "`r`n        <intent><action android:name=`"android.intent.action.VIEW`"/><data android:scheme=`"https`"/></intent>" +
           "`r`n        <intent><action android:name=`"android.intent.action.SENDTO`"/><data android:scheme=`"mailto`"/></intent>"
if ($x -notmatch 'android:scheme="https"') {
  if ($x -match '<queries>') {
    $x = $x -replace '<queries>', "<queries>$intents"
  } else {
    $x = $x -replace '(\s*<application)', "`r`n    <queries>$intents`r`n    </queries>`$1"
  }
}
if ($x -notmatch 'android:allowBackup') {
  $x = $x -replace '<application', '<application android:allowBackup="false" android:fullBackupContent="false" android:dataExtractionRules="@xml/data_extraction_rules"'
}
$x = $x -replace 'android:label="vertex_ai_pyme"', 'android:label="VERTEX AI Pyme"'
Escribir $m $x

$xmlDir = "$raiz\android\app\src\main\res\xml"
New-Item -ItemType Directory -Force $xmlDir | Out-Null
$reglas = @'
<?xml version="1.0" encoding="utf-8"?>
<!-- Android 12+: ninguna copia en la nube ni transferencia entre equipos
     (la base cifrada y su clave no deben salir del celular). -->
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="root"/>
        <exclude domain="file"/>
        <exclude domain="database"/>
        <exclude domain="sharedpref"/>
        <exclude domain="external"/>
    </cloud-backup>
    <device-transfer>
        <exclude domain="root"/>
        <exclude domain="file"/>
        <exclude domain="database"/>
        <exclude domain="sharedpref"/>
        <exclude domain="external"/>
    </device-transfer>
</data-extraction-rules>
'@
Escribir "$xmlDir\data_extraction_rules.xml" $reglas

# --------------------------------------------------------- minSdk = 31
$kts = "$raiz\android\app\build.gradle.kts"
$groovy = "$raiz\android\app\build.gradle"
if (Test-Path $kts) {
  $g = Leer $kts
  $g = $g -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 31'
  $g = $g -replace 'minSdk\s*=\s*\d+', 'minSdk = 31'
  Escribir $kts $g
} elseif (Test-Path $groovy) {
  $g = Leer $groovy
  $g = $g -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 31'
  $g = $g -replace 'minSdkVersion\s+\d+', 'minSdkVersion 31'
  Escribir $groovy $g
}

# ------------------------------------------------------------------ iOS
$pbx = "$raiz\ios\Runner.xcodeproj\project.pbxproj"
if (Test-Path $pbx) {
  $p = Leer $pbx
  $p = $p -replace 'IPHONEOS_DEPLOYMENT_TARGET = \d+\.\d+;', 'IPHONEOS_DEPLOYMENT_TARGET = 16.0;'
  Escribir $pbx $p
}
$podfile = "$raiz\ios\Podfile"
if (Test-Path $podfile) {
  $pf = Leer $podfile
  $pf = $pf -replace "#?\s*platform :ios, '[\d.]+'", "platform :ios, '16.0'"
  Escribir $podfile $pf
}
$plist = "$raiz\ios\Runner\Info.plist"
if (Test-Path $plist) {
  $pl = Leer $plist
  if ($pl -notmatch 'LSApplicationQueriesSchemes') {
    $esquemas = "`t<key>LSApplicationQueriesSchemes</key>`n`t<array>`n`t`t<string>https</string>`n`t`t<string>whatsapp</string>`n`t`t<string>mailto</string>`n`t</array>`n"
    $i = $pl.LastIndexOf('</dict>')
    $pl = $pl.Substring(0, $i) + $esquemas + $pl.Substring($i)
  }
  $pl = $pl -replace '(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)', '${1}VERTEX AI Pyme${2}'
  Escribir $plist $pl
}

# --------------------------------------------------------- 3. dependencias
flutter pub get
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Ajustando versiones de paquetes...'
  flutter pub upgrade --major-versions
  if ($LASTEXITCODE -ne 0) { throw 'No se pudieron resolver las dependencias' }
}

Write-Host ''
Write-Host 'Listo. Siguiente:'
Write-Host '  flutter analyze'
Write-Host '  flutter test'
