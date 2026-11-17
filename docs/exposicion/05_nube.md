# 05 · La nube (Supabase) y la IA

## `supabase_schema.sql` — la base de datos en internet
**Lenguaje:** SQL (PostgreSQL). Se pega en Supabase → SQL Editor → Run.

**Qué crea:**
- **Tablas:** empresas, miembros, clientes, ventas, productos e inventario.
- **RLS (seguridad por fila):** cada consulta se filtra por la **empresa** del usuario. Una tienda **no puede ver** los datos de otra, aunque alguien manipule la app. Busca `create policy`.
- **Triggers:**
  - Al crear un usuario se le crea su empresa (`crear_empresa_para_usuario`).
  - La unión por campo, igual que en el celular (`merge_cliente`, `merge_producto`).
- **Ventas e inventario solo se agregan:** no hay permiso para editarlos ni borrarlos.
- **Nadie sin sesión** puede leer nada (`revoke all … from anon`).

## `asistente_index.ts` — la función de IA
(En el proyecto real está en `supabase/functions/asistente/index.ts`.)
**Lenguaje:** TypeScript (motor Deno), corre en Supabase.

**Qué hace, paso a paso:**
1. Verifica que quien pregunta tenga **sesión válida**. Si no, responde 401.
2. **Limpia la pregunta otra vez** (quita correos y números).
3. Arma el mensaje para la IA **solo con totales del mes**.
4. Llama a **Gemini** y devuelve la respuesta.

**La clave de la IA** es un secreto del servidor (`GEMINI_API_KEY`). **Nunca** está en la app ni en el código.

## Frase para exponer
*"En la nube cada tienda solo ve lo suyo gracias a RLS, y la IA trabaja con totales, nunca con nombres ni celulares."*
