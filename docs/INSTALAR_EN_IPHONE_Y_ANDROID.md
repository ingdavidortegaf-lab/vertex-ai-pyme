# Cómo usar VERTEX AI Pyme en iPhone y en Android

## iPhone (y cualquier celular o computador): versión web
**Enlace:** https://ingdavidortegaf-lab.github.io/vertex-ai-pyme/

**Código QR:** `docs/QR_VERTEX_WEB.png`. También está en el escritorio del PC; se escanea con la cámara del iPhone.

### Instalarla como una app en el iPhone
1. Abre el enlace en **Safari**, el navegador del iPhone. Si lo abres desde WhatsApp, toca los tres puntos o la brújula y elige "Abrir en Safari".
2. Espera a que cargue. La primera vez descarga unos 8 MB; después abre rápido.
3. Toca **Compartir**, el cuadrado con la flecha hacia arriba.
4. Elige **"Agregar a pantalla de inicio"** → **Agregar**.
5. Aparece el ícono verde de **VERTEX** en la pantalla de inicio. Al abrirlo se ve a pantalla completa, como una app.

En **Android** también funciona: Chrome → menú ⋮ → **"Agregar a pantalla principal"**.

### Qué funciona en la versión web
- Todo lo principal:
  - registro del negocio;
  - ventas;
  - pago dividido (Nequi, efectivo, tarjeta…);
  - fiados y abonos;
  - inventario y servicios;
  - clientes y cuentas de cobro;
  - informes;
  - cierre de caja;
  - cotizaciones;
  - asistente.
- **Sin internet:** una vez abierta, sigue funcionando. Los datos se guardan **en el navegador de ese celular**.
- **Respaldo en la nube:** con la cuenta (muñequito de arriba) se sincroniza con Supabase, igual que en Android.
- **WhatsApp:** abre WhatsApp con el mensaje listo.
- **PDF:** se generan y se comparten o descargan.
- **Código de barras con la cámara:** Safari pide permiso para usar la cámara.

### Lo que NO tiene la versión web (dilo con honestidad si preguntan)
- **Avisos en el celular** (notificaciones): no aparecen en la versión web.
- **Base cifrada:** en el navegador la base no va cifrada con SQLCipher; la protege el aislamiento del navegador. **Para guardar datos reales de clientes, recomendamos iniciar sesión** y así quedan respaldados en la nube.
- **Logo del negocio:** se pone desde la app de Android o del PC.
- **Si se borran los datos de Safari, se borran los datos locales.** Con sesión iniciada, se recuperan desde la nube.

### ¿Y la app nativa de iPhone (App Store)?
El mismo código compila para iPhone, pero Apple exige **un Mac con Xcode** y una **cuenta de Apple Developer** (USD 99 al año). Queda en la ruta después del piloto. La versión web permite usarla **hoy**, sin Mac y sin pagar.

---

## Android: app nativa (APK)
**Archivo:** `VERTEX_AI_Pyme.apk`, en la carpeta de entrega del escritorio. Pesa unos 98 MB y requiere **Android 12** o más.

1. Pasa el archivo al celular: por WhatsApp a ti mismo, por cable o por Drive.
2. Ábrelo en el celular y toca **Instalar**.
3. Si dice que está bloqueado: **Ajustes → Permitir de esta fuente**, y vuelve a tocar **Instalar**.
4. Si ya tenías la app, se instala encima **sin perder los datos**.

La app Android es la más completa: base **cifrada**, **avisos** en el celular y funcionamiento sin internet.

---

## Después de actualizar (versión del 18 de noviembre)
- La app pide **aceptar otra vez la autorización de datos** una sola vez, porque el aviso cambió al texto oficial de la convocatoria. Los datos guardados no se pierden.
- **Ícono nuevo:** en Android aparece al instalar el APK nuevo. En iPhone, el ícono de la pantalla de inicio se queda con el anterior: bórrelo y vuelva a usar **Compartir → Agregar a pantalla de inicio** para ver el logo nuevo.
- **Compartir foto o video de una promoción:** funciona en Android, en iPhone con Safari y en navegadores que tienen la opción de compartir. En el computador solo se comparte el texto (queda copiado).

## Cómo se publicó la versión web (para el ingeniero)
- `flutter build web --release --base-href /vertex-ai-pyme/` genera la app en HTML, JavaScript y WebAssembly.
- La base del navegador es **SQLite compilada a WebAssembly** (`sqflite_common_ffi_web`), guardada en IndexedDB.
- El código elige solo qué base abrir: `lib/data/abrir_base.dart` usa importación condicional, con SQLCipher en el celular, SQLite en el PC y WebAssembly en la web.
- Se publica gratis en **GitHub Pages** (rama `gh-pages`) con HTTPS.
