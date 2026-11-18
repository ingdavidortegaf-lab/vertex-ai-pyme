# 3 · Datos sin señal (base del celular y sincronización)

- `local_db.dart`: la base SQLite cifrada. Cada venta se guarda junto con su entrada en la cola, en una transacción.
- `sync_service.dart`: el motor que sube la cola a la nube cada 30 s o al volver la señal.
- `remote_api.dart`: la conexión con Supabase (upsert por id, sin duplicar).

Explicación completa: `docs/exposicion/3_datos_sin_senal.md`
