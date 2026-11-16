# Ajustes de plataforma

`scripts\preparar_proyecto.ps1` aplica todo esto automáticamente. Este archivo
documenta qué hace, por si hay que revisarlo a mano.

## Android
`android/app/src/main/AndroidManifest.xml`
- `<uses-permission android:name="android.permission.INTERNET"/>`: sin él la app
  funciona en `flutter run` pero NO sincroniza en el APK release.
- Dentro de `<queries>`: intents `VIEW https` (WhatsApp por wa.me) y
  `SENDTO mailto` (canal de derechos). Sin ellos los botones fallan en Android 11+.
- En `<application>`: `android:allowBackup="false"`,
  `android:fullBackupContent="false"` y
  `android:dataExtractionRules="@xml/data_extraction_rules"` (archivo en
  `res/xml/`) para que la base cifrada no salga del celular por copias de
  seguridad ni transferencias entre equipos.
- `android:label="VERTEX AI Pyme"`.

`android/app/build.gradle.kts` → `defaultConfig { minSdk = 31 }` (Android 12+).

## iOS (se compila en Mac en la fase post-evento)
- `IPHONEOS_DEPLOYMENT_TARGET = 16.0` en `Runner.xcodeproj/project.pbxproj`.
- `ios/Podfile` (se crea en el primer `flutter build ios` en Mac):
  `platform :ios, '16.0'`. Si no existía al correr el script, cámbialo a mano
  después de ese primer build.
- `Info.plist`: `LSApplicationQueriesSchemes` con `https`, `whatsapp` y `mailto`.

## APK para el jurado
```
flutter build apk --release --obfuscate --split-debug-info=build\debug-info --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```
Sin los `--dart-define` el APK funciona en modo solo local (sin nube).
Resultado: `build\app\outputs\flutter-apk\app-release.apk`.

## Problemas del PC de desarrollo (Windows) y su solución
- **El SDK de Android no puede estar en una ruta con espacios** (por ejemplo
  `C:\Users\NOMBRE APELLIDO\...`). Se copió a `C:\Android\sdk` y se
  configuró con `flutter config --android-sdk C:\Android\sdk` y la variable
  `ANDROID_HOME`.
- **`flutter doctor --android-licenses`**: en las herramientas de línea de
  comandos recientes ya no hace falta; solo muestra un aviso.
- **Antivirus con revisión HTTPS (Avast)**: Gradle falla con
  `PKIX path building failed` porque el Java de Android Studio no confía en el
  certificado del antivirus. Sin desactivar el antivirus: se crea un almacén
  propio con la raíz pública de Avast y se compila con esa variable en la
  misma ventana:
  ```
  $env:JAVA_TOOL_OPTIONS="-Djavax.net.ssl.trustStore=C:\Android\java-truststore\cacerts-avast.jks -Djavax.net.ssl.trustStorePassword=changeit"
  ```
- **NDK**: si el build dice que no pudo instalar el NDK, se instala a mano
  (la herramienta nueva usa `/` en el nombre del paquete):
  ```
  C:\Android\sdk\cmdline-tools\latest\bin\android.exe --sdk=C:\Android\sdk sdk install ndk/28.2.13676358
  ```
- **Emulador**: necesita el controlador de virtualización (Android Emulator
  hypervisor driver), que se instala con permisos de administrador desde el
  SDK Manager de Android Studio. Para la demo se usa el celular real.
