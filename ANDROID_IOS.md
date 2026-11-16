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
