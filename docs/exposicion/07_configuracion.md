# 07 · Configuración (Android, Windows y paquetes)

| Archivo | Para qué sirve |
|---|---|
| `pubspec.yaml` | La **lista de paquetes** (librerías) que usa la app y sus versiones. Todos gratuitos. |
| `AndroidManifest.xml` | Permisos de Android: internet, cámara (código de barras), abrir WhatsApp y correo. **Sin copias de seguridad** para que la base no salga del celular. Nombre visible "VERTEX AI Pyme". |
| `data_extraction_rules.xml` | Impide que Android copie la base a otro equipo o a la nube de Google. |
| `build.gradle.kts` | Versión mínima: **Android 12** (minSdk 31), como piden las bases. |
| `windows_main.cpp` | (En el proyecto real: `windows/runner/main.cpp`.) Crea la **ventana de Windows**, con el título "VERTEX AI Pyme" y su tamaño. |
| `launch.json` | Las configuraciones de **VS Code** para correr con F5: con nube, solo local y como el APK. |
| `preparar_proyecto.ps1` | Script que prepara el proyecto la primera vez. |
| `generar_licencias.ps1` | Script que genera la **lista de licencias** de todos los paquetes. |

## Cómo se compila
- **Celular (APK):** `flutter build apk --release --obfuscate --split-debug-info=build\debug-info --dart-define-from-file=dart_defines.json`
- **PC (Windows):** `flutter build windows --release --dart-define-from-file=dart_defines.json`

El archivo `dart_defines.json` (dirección y clave pública de Supabase) **no se comparte**: está fuera del código por seguridad.

## Frase para exponer
*"Es un solo código: con un comando sale el APK para Android y con otro el programa para Windows; iPhone queda listo para compilar en un Mac."*
