# 7 · Configuración: Android, Windows y paquetes

## En una frase
Aquí están los archivos que dicen **qué paquetes usa la app**, **qué permisos pide en Android** y **cómo se arma la ventana en Windows**.

## Qué hace cada archivo

| Archivo | Para qué sirve |
|---|---|
| `pubspec.yaml` | **La lista de paquetes** (librerías) con sus versiones. Todos gratis y de código abierto |
| `AndroidManifest.xml` | **Permisos de Android**: internet, cámara (código de barras), avisos (notificaciones). **Sin copias de seguridad**, para que la base no salga del celular |
| `data_extraction_rules.xml` | Impide que Android copie la base a otro equipo o a la nube de Google |
| `build.gradle.kts` | Cómo se compila para Android: **Android 12 o más** (minSdk 31), compilación con la SDK 37 |
| `windows_main.cpp` | Crea la **ventana de Windows** con el título y el tamaño (en el proyecto real: `windows/runner/main.cpp`, en C++) |
| `launch.json` | Configuraciones de **VS Code** para correr con F5 |
| `preparar_proyecto.ps1` | Prepara el proyecto la primera vez |
| `generar_licencias.ps1` | Genera la **lista de licencias** de todos los paquetes |

## Los paquetes principales (lo que hay en `pubspec.yaml`)

| Paquete | Para qué |
|---|---|
| `sqflite_sqlcipher` | Base de datos del celular **cifrada** |
| `sqflite_common_ffi` | Base de datos en **Windows** |
| `flutter_secure_storage` | Guardar la clave del cifrado en el almacén seguro del celular |
| `supabase_flutter` | Conexión con el backend (base, usuarios, funciones) |
| `connectivity_plus` | Saber cuándo vuelve el internet |
| `uuid` | Crear los números únicos de cada registro |
| `pdf` y `printing` | Crear, imprimir y compartir PDF |
| `mobile_scanner` | Leer códigos de barras con la cámara |
| `image_picker` | Elegir el logo de la galería |
| `url_launcher` | Abrir WhatsApp con el mensaje |
| `flutter_local_notifications` | Avisos en el celular |
| `intl` | Fechas y pesos en español de Colombia |

## Cómo se compila (un comando para cada sistema)
- **Celular (APK):** `flutter build apk --release --dart-define-from-file=dart_defines.json`
- **PC (Windows):** `flutter build windows --release --dart-define-from-file=dart_defines.json`

El archivo `dart_defines.json` tiene la dirección y la **clave pública** de Supabase. **No se comparte ni está en el código**: entra solo al compilar.

## Si el jurado pregunta…
- **"¿Dónde están las claves?"** → **En ninguna parte del código.** La dirección y la clave pública de Supabase entran al compilar con `--dart-define`. La clave de la IA es un **secreto del servidor**. La clave maestra de Supabase **nunca se usa en la app**.
- **"¿Cuál es el Android mínimo?"** → Android 12, como piden las bases.
- **"¿Y iPhone?"** → El mismo código compila para iPhone, pero hace falta un Mac para generarlo. Queda listo para cuando se tenga.
