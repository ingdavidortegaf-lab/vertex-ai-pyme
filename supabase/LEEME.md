# 5 · Backend en la nube (Supabase)

- `supabase_schema.sql` (SQL / PostgreSQL): tablas, seguridad por fila (RLS: cada tienda ve solo lo suyo) y triggers. Se pega en Supabase → SQL Editor → Run.
- `functions/asistente/index.ts` (TypeScript / Deno): la función de IA. Revisa la sesión y llama a Google Gemini con la clave guardada como secreto del servidor.

Explicación completa: `docs/exposicion/4_nube_backend.md`
