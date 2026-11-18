# Arma la carpeta para EXPLICAR el codigo (no para correrlo).
# Copia cada archivo de codigo a su carpeta tematica con su EXPLICACION.md.
# Uso, desde la carpeta del proyecto:
#   powershell -ExecutionPolicy Bypass -File .\scripts\armar_exposicion.ps1
# Destino por defecto: D:\ESCRITORIO\VERTEX_AI_Pyme_EXPOSICION
param([string]$Destino = 'D:\ESCRITORIO\VERTEX_AI_Pyme_EXPOSICION')
$ErrorActionPreference = 'Stop'
$proy = Split-Path -Parent $PSScriptRoot
$guias = "$proy\docs\exposicion"

# Se vacia (no se borra) por si la carpeta esta abierta en VS Code o el Explorador.
if (Test-Path $Destino) { Get-ChildItem $Destino -Force | Remove-Item -Recurse -Force }
else { New-Item -ItemType Directory $Destino | Out-Null }

# Guias generales en la raiz
foreach ($f in @('00_LEAME_PRIMERO.md','GUIA_VISUAL.html','GUION_PARA_EXPONER.md','PREGUNTAS_DEL_JURADO.md','GLOSARIO.md')) {
  Copy-Item "$guias\$f" "$Destino\$f"
}

$carpetas = [ordered]@{
  '1_pantallas' = Get-ChildItem "$proy\lib\ui\*.dart" | ForEach-Object { $_.FullName }
  '2_reglas_del_negocio' = Get-ChildItem "$proy\lib\domain\*.dart" | ForEach-Object { $_.FullName }
  '3_datos_sin_senal' = (Get-ChildItem "$proy\lib\data\*.dart" | ForEach-Object { $_.FullName }) + @("$proy\lib\main.dart", "$proy\lib\config.dart")
  '4_nube_backend' = @("$proy\supabase\supabase_schema.sql")
  '5_pdf_y_documentos' = Get-ChildItem "$proy\lib\pdf\*.dart" | ForEach-Object { $_.FullName }
  '6_pruebas' = (Get-ChildItem "$proy\test\*.dart" | ForEach-Object { $_.FullName }) + @("$proy\tool\capturas_test.dart", "$proy\tool\muestra_pdf_test.dart")
  '7_configuracion' = @("$proy\pubspec.yaml", "$proy\android\app\build.gradle.kts", "$proy\android\app\src\main\AndroidManifest.xml",
                        "$proy\android\app\src\main\res\xml\data_extraction_rules.xml", "$proy\scripts\preparar_proyecto.ps1", "$proy\scripts\generar_licencias.ps1")
  '8_seguridad' = @()
  '10_base_de_datos' = Get-ChildItem "$proy\docs\base_de_datos\*" -File | Where-Object Name -ne 'LEEME_BASE_DE_DATOS.md' | ForEach-Object { $_.FullName }
  '9_documentos_convocatoria' = @('MANUAL_USUARIO.md','COMO_ESTA_CONSTRUIDO.txt','CONTABILIDAD_DOCUMENTOS_Y_ADAPTACION.md','AUDITORIA.md',
                                  'LICENCIAS.md','POLITICA_TRATAMIENTO_DATOS.md','AVISO_PRIVACIDAD_Y_AUTORIZACION.md','PAGOS_Y_MODELO_DE_NEGOCIO.md') | ForEach-Object { "$proy\docs\$_" }
}
foreach ($c in $carpetas.Keys) {
  $d = New-Item -ItemType Directory "$Destino\$c"
  $explicacion = if (Test-Path "$guias\$c.md") { "$guias\$c.md" } else { "$proy\docs\base_de_datos\LEEME_BASE_DE_DATOS.md" }
  Copy-Item $explicacion "$d\EXPLICACION.md"
  foreach ($f in $carpetas[$c]) { if (Test-Path $f) { Copy-Item $f $d } }
}
# Archivos con otro nombre para que se entienda de donde vienen
Copy-Item "$proy\supabase\functions\asistente\index.ts" "$Destino\4_nube_backend\asistente_index.ts"
Copy-Item "$proy\windows\runner\main.cpp" "$Destino\7_configuracion\windows_main.cpp"
Copy-Item "$proy\README.md" "$Destino\9_documentos_convocatoria\README.md"
if (Test-Path "$proy\.vscode\launch.json") { Copy-Item "$proy\.vscode\launch.json" "$Destino\7_configuracion\launch.json" }

# VS Code: abrir la guia al inicio y no marcar errores (los archivos estan separados del proyecto)
$vs = New-Item -ItemType Directory "$Destino\.vscode"
@'
{
  "workbench.startupEditor": "readme",
  "markdown.preview.breaks": true,
  "files.encoding": "utf8",
  "dart.analysisExcludedFolders": ["1_pantallas", "2_reglas_del_negocio", "3_datos_sin_senal", "5_pdf_y_documentos", "6_pruebas", "7_configuracion"],
  "problems.decorations.enabled": false
}
'@ | Set-Content "$vs\settings.json" -Encoding UTF8

Write-Host "Carpeta lista: $Destino"
Get-ChildItem $Destino | ForEach-Object { $n = if ($_.PSIsContainer) { (Get-ChildItem $_.FullName).Count } else { '' }; "{0,-32} {1}" -f $_.Name, $n }
