# 3 · Datos sin señal (base del celular y sincronización)

- `local_db.dart` (núcleo: esquema, migraciones, ajustes y cola de envío) y `local_db_*.dart` (un módulo por tema: clientes, movimientos, inventario, proveedores, documentos, cotizaciones, negocio, nube y asistente): la base SQLite cifrada (esquema versión 8). Cada venta se guarda junto con su entrada en la cola, en una transacción. Aquí también viven las cuentas por pagar a proveedores, el resumen de clientes para el seguimiento y el registro de autorizaciones.
- `sync_service.dart`: el motor que sube la cola a la nube cada 30 s o al volver la señal.
- `abrir_base.dart`: abre la base según el equipo (celular cifrado, Windows o navegador).
- `asistente_service.dart`: qué se le pregunta a la IA (consejos, mensajes y promociones) y qué se hace sin señal.
- `remote_api.dart`: la conexión con Supabase (upsert por id, sin duplicar).

Explicación completa: `docs/COMO_ESTA_CONSTRUIDO.txt`
