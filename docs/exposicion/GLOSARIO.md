# Glosario: las palabras técnicas, en sencillo

Si el jurado usa una de estas palabras, ya sabes qué significa y cómo responder.

| Palabra | Qué significa (sencillo) | En nuestra app |
|---|---|---|
| **Frontend** | La parte que se ve: pantallas y botones | Las pantallas en Flutter (`1_pantallas`) |
| **Backend** | La parte que no se ve, en un servidor: guarda datos, maneja usuarios | Supabase (`4_nube_backend`) |
| **Framework** | Una caja de herramientas para no empezar de cero | Flutter |
| **Lenguaje** | El idioma en que se escribe el programa | Dart (app), TypeScript (función de IA), SQL (base de datos) |
| **Multiplataforma** | Un mismo código sirve para varios sistemas | Android, Windows e iPhone con el mismo código |
| **Offline-first** | "Primero sin conexión": la app trabaja sin internet y sincroniza después | Todo se guarda en el celular primero |
| **Base de datos** | Donde se guardan los datos, en tablas (como hojas de Excel) | SQLite en el celular y PostgreSQL en la nube |
| **SQLite** | Base de datos pequeña que vive dentro de la app | La "memoria" del celular |
| **SQLCipher / AES-256** | Candado (cifrado) para la base del celular | Si roban el celular, no pueden leer los datos |
| **PostgreSQL** | Base de datos grande y profesional | La de Supabase, en la nube |
| **Supabase** | Servicio en la nube que da base de datos, usuarios y funciones (alternativa libre a Firebase) | Nuestro backend |
| **API** | Una "ventanilla" para que dos programas se hablen | La API de Supabase (guardar y leer datos) y la API de Gemini (IA) |
| **API REST** | Una API que funciona por internet con direcciones web y mensajes en JSON | Supabase y Gemini son REST |
| **JSON** | Formato de texto para enviar datos: `{"monto": 25000}` | Así viajan las ventas a la nube |
| **Edge Function** | Un programa pequeño que corre en el servidor de Supabase | `asistente`: llama a la IA con la clave escondida |
| **Endpoint** | La dirección web de una API | `.../functions/v1/asistente` |
| **Autenticación (Auth)** | Comprobar quién eres (correo y clave) | Supabase Auth |
| **Token / JWT** | Un "carné" digital que te da el servidor al iniciar sesión | La app lo manda en cada envío; la función de IA lo revisa |
| **RLS (Row Level Security)** | Seguridad por fila: la base solo entrega las filas de tu empresa | Una tienda nunca ve los datos de otra |
| **Trigger** | Una regla que la base ejecuta sola cuando pasa algo | Al crear un usuario se le crea su empresa; al actualizar un producto se mezcla campo por campo |
| **UUID** | Un número único gigante, que no se repite en ningún celular | Cada venta y cada cliente nace con su UUID |
| **Idempotente** | Hacer algo dos veces da el mismo resultado que una vez | Si una venta se envía dos veces, queda una sola |
| **Upsert** | "Inserta, o si ya existe, actualiza o ignora" | Así se envía todo a la nube |
| **Transacción** | Varias operaciones que se hacen todas o ninguna | Guardar la venta y anotarla en la cola, juntas |
| **Cola de sincronización** | Lista de pendientes por subir | La tabla `cola_sync` |
| **Backoff exponencial** | Si falla, esperar cada vez más antes de reintentar (15 s, 30 s, 1 min…) | Para no gastar batería ni datos |
| **Conflicto** | Dos celulares cambian lo mismo sin señal | Gana el cambio más reciente **de cada dato** |
| **Arquitectura en capas** | Separar pantallas, reglas y datos | Pantallas / Reglas / Datos / Nube |
| **Patrón Repositorio** | Una clase que esconde de dónde vienen los datos | `RemoteApi` (nube) y `LocalDb` (celular) |
| **Singleton** | Un objeto que existe una sola vez en la app | `LocalDb.instance`, `SyncService.instance` |
| **Widget** | Una pieza de pantalla en Flutter (botón, texto, tarjeta) | Todo lo que se ve es un widget |
| **Estado (state)** | Lo que la pantalla recuerda (lo escrito, lo elegido) | `StatefulWidget`, `ValueNotifier` |
| **Paquete / librería / dependencia** | Código hecho por otros que reutilizamos | Están en `pubspec.yaml` |
| **APK** | El instalador de Android | `VERTEX_AI_Pyme.apk` |
| **Compilar / build** | Convertir el código en el programa que se instala | `flutter build apk` |
| **Prueba automática (test)** | Un programa que revisa solo que otro funcione | 88 pruebas con `flutter test` |
| **Git / commit** | Historia de cambios del código; cada commit es una "foto" | Todo el proyecto está en Git |
| **Prompt** | Las instrucciones que se le dan a la IA | Se arman en la Edge Function solo con totales |
| **Notificación local** | Aviso que el celular se manda a sí mismo, sin servidor | "Se agotó el arroz" |
| **Ley 1581** | Ley colombiana de protección de datos personales (Habeas Data) | Autorización, aviso de privacidad y derechos |
| **OWASP** | Guía mundial de seguridad para apps | Cifrado, HTTPS, bloqueo de intentos, cierre por inactividad |
