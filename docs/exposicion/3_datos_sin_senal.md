# 3 · Datos sin señal: la memoria del celular y la sincronización

## En una frase
La app guarda todo **primero en el celular**, en una base de datos con candado, y un **motor de sincronización** lo sube a la nube cuando hay internet, **sin perder ni duplicar nada**.

## Cómo funciona, paso a paso (apréndetelo, es lo más importante)
1. **El tendero guarda una venta.** La venta se escribe en la tabla `ventas` **y**, en la misma operación (una **transacción**), se anota en la **cola de envío** (`cola_sync`). O se guardan las dos cosas o ninguna: nunca queda una venta sin anotar.
2. **Cada venta nace con un número único (UUID)** creado en el celular. Ese número no se repite en ningún otro celular del mundo.
3. **El motor de sincronización** (`sync_service.dart`) se despierta **cada 30 segundos**, **cuando vuelve la señal** y **cuando se guarda algo**.
4. Toma la cola **en orden** y envía cada registro a Supabase con **upsert por id**: si ya estaba allá, no se duplica. Esto se llama **envío idempotente**.
5. Si sale bien, lo marca como enviado. Si **no hay red**, no pasa nada: queda en la cola y se reintenta.
6. Si falla, **espera cada vez más** antes de reintentar: 15 s, 30 s, 1 min… hasta 30 min (**backoff exponencial**). Después de 5 intentos lo aparta como "error", **pero nunca lo borra**.
7. Después **descarga** lo que hicieron otros celulares de la misma tienda, en tandas de 500, solo lo nuevo desde la última vez.

## Qué hace cada archivo

| Archivo | Qué hace | Cómo decirlo |
|---|---|---|
| `local_db.dart` | **La base del celular**. Crea las tablas: clientes, ventas, productos, inventario, cola, cotizaciones, proveedores, documentos, ajustes. Va **cifrada con SQLCipher (AES-256)**; la clave se genera al azar y se guarda en el almacén seguro de Android. Las actualizaciones **conservan los datos** (vamos en la versión 5). También numera los documentos | "La memoria con candado" |
| `sync_service.dart` | **El motor de sincronización**: cola, reintentos, descarga | "El mensajero que sube los datos" |
| `remote_api.dart` | **La conexión con Supabase**: enviar, descargar y llamar a la IA. Traduce los errores (sin red, sesión vencida, dato rechazado) | "La ventanilla hacia la nube" |
| `asistente_service.dart` | Decide si responde el **asistente local** (sin internet) o la **IA de la nube**. Si no hay señal, deja la pregunta en cola | |
| `main.dart` | **Donde arranca la app**: abre la base cifrada, conecta Supabase si está configurado, arranca la sincronización y muestra la primera pantalla | "El botón de encendido" |
| `config.dart` | La configuración que entra **al compilar** (dirección de Supabase, clave pública, correo de privacidad). **Aquí no hay claves escritas.** Solo acepta direcciones `https://` | |

## Muestra estos pedazos
1. **`local_db.dart`**, busca **Ctrl+F**: `Future<String> saveMovimiento`. Señala `db.transaction` y `_enqueue`:
   *"Aquí se guarda la venta y, en la misma transacción, se anota en la cola. Por eso nada se pierde."*
2. **`remote_api.dart`**, busca: `upsert(`. Señala `onConflict: 'id'`:
   *"Se envía con upsert por id. Si la señal se cae justo después de enviar y se reintenta, el servidor no la duplica."*
3. **`sync_service.dart`**, busca: `Duration(seconds: 30)`:
   *"Cada 30 segundos y cada vez que vuelve la señal intenta subir lo pendiente."*

## Si el jurado pregunta…
- **"¿Qué pasa si se cae internet a mitad del envío?"** → La venta sigue en la cola porque solo se marca como enviada cuando el servidor responde. Al reintentar, el upsert por id evita el duplicado. **Hay una prueba automática que simula exactamente eso** (`sync_test.dart`).
- **"¿Por qué UUID y no un número consecutivo?"** → Porque dos celulares sin señal crearían el mismo número 1, 2, 3… El UUID se crea en el celular y nunca choca.
- **"¿La base del PC también va cifrada?"** → En Windows usamos SQLite normal en la carpeta del usuario. El cifrado en Windows está pendiente; en el celular sí va cifrada.
