# VERTEX AI Pyme – prototipo que funciona sin señal (Flutter)

App móvil para MiPymes de Casanare (CreaTIC Casanare 2026). Cubre tres
procesos y **funciona sin señal**: todo se guarda primero en el celular,
cifrado, y se sincroniza solo cuando vuelve la conexión.

| Proceso | En el prototipo |
|---|---|
| Gestión de clientes | Registro, historial por cliente, saldo y mensaje sugerido (IA o plantilla) que se abre listo en WhatsApp |
| Ventas y cobros | Ventas de contado, ventas fiadas (quedan por cobrar), gastos y abonos |
| Gestión financiera | Tablero del mes (ventas, gastos, utilidad, por cobrar, clientes) y asistente que responde con tus datos |

Fuera del alcance del prototipo: inventario, marketing, pagos, Make, API de WhatsApp.

## 1. Requisitos (todo gratis)
- Git, Flutter (canal estable), Android Studio (incluye el SDK de Android y un JDK)
- Un celular Android 12+ con depuración USB, o un emulador

## 2. Preparar el proyecto (una sola vez)
```powershell
cd C:\dev\vertex_ai_pyme
powershell -ExecutionPolicy Bypass -File .\scripts\preparar_proyecto.ps1
flutter analyze
flutter test
```
El script genera `android/` e `ios/`, aplica `ANDROID_IOS.md` (INTERNET,
`<queries>`, minSdk 31, sin copias de seguridad, iOS 16) y descarga dependencias.

## 3. Ejecutar
Modo solo local (sin nube; ideal para ensayar la demo de modo avión):
```powershell
flutter run
```
Con nube (Supabase):
```powershell
flutter run --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co --dart-define=SUPABASE_ANON_KEY=TU_CLAVE_ANON
```
La clave *anon* es pública por diseño: la seguridad la dan las políticas RLS.
**Nunca** uses la clave *service_role* en la app.

## 4. Supabase (plan gratuito)
1. En supabase.com crea un proyecto (región São Paulo, la más cercana).
2. **SQL Editor → New query**: pega todo `supabase_schema.sql` y ejecuta **Run**.
3. **Authentication → Users → Add user → Create new user**: correo y clave de
   demo, con **Auto Confirm User** marcado. (Al crearlo se le crea su empresa
   automáticamente.)
4. **Project Settings → API**: copia *Project URL* y la clave *anon public*.

## 5. Asistente con IA en el servidor (opcional)
Sin esto el asistente igual responde con los datos del celular.
```powershell
npx supabase login
npx supabase link --project-ref TU_REF
npx supabase functions deploy asistente
npx supabase secrets set GEMINI_API_KEY=TU_CLAVE GEMINI_MODEL=<modelo gratuito vigente>
```
La clave del modelo vive solo como secreto de Supabase: nunca en la app ni en el repositorio.

## 6. APK de prueba
```powershell
flutter build apk --release --obfuscate --split-debug-info=build\debug-info --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```
Queda en `build\app\outputs\flutter-apk\app-release.apk`.

## 7. Guion de la demo (3 min)
1. Activa **modo avión**. La barra dice «Sin conexión · 0 pendientes».
2. Crea 2 clientes (con celular). Registra una venta, una venta fiada y un gasto.
   La barra muestra los pendientes; el **Tablero** se actualiza al instante.
3. **Asistente**: «¿Cuánto vendí esta semana?», «¿Quién me debe?» y
   «mensaje para cobrarle a …» → «Abrir en WhatsApp».
4. Quita el modo avión → la barra pasa a «Sincronizando…» y luego «Sincronizado».
5. Muestra los registros en Supabase (Table Editor) una sola vez cada uno.

## 8. Licencias
`scripts\generar_licencias.ps1` genera `docs\LICENCIAS.md` con todas las dependencias.

Estado técnico y cumplimiento de las bases: `docs/AUDITORIA.md`.
