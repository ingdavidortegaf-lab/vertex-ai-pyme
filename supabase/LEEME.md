# Backend en la nube (Supabase)

- `migrations/` (SQL / PostgreSQL): **fuente de verdad del esquema**. Una migración por cambio, en orden de versión. Son las mismas que tiene registradas el proyecto real (mismo nombre, versión y contenido).
  - Local o CI: `supabase start` y `supabase db reset` aplican todas desde cero.
  - Proyecto real: `supabase link --project-ref <ref>` y `supabase db push` aplica solo las que falten.
  - Cambio nuevo: `supabase migration new <nombre>`, escribir el SQL, probarlo en local y luego subirlo.
- `supabase_schema.sql`: el esquema completo en un solo archivo, **solo de referencia** (se actualiza a mano después de cada migración).
- `config.toml`: configuración de la CLI para el entorno local (sin claves).
- `functions/asistente/index.ts` (TypeScript / Deno): la función de IA. Revisa la sesión y llama a Google Gemini con la clave guardada como secreto del servidor (`GEMINI_API_KEY`). Modos: `consejo`, `mensaje` y `promocion`.

Explicación completa: `docs/COMO_ESTA_CONSTRUIDO.txt`
