# 4 · Nube y backend: Supabase + la función de IA

## En una frase
El **backend** es **Supabase**: una base de datos **PostgreSQL** en internet, con **usuarios (Auth)**, **seguridad por fila (RLS)** y una **Edge Function** escrita en **TypeScript** que llama a la **IA de Google (Gemini)**.

## Cómo está formado el backend (dibújalo así)

```
 App (celular o PC)
   │  HTTPS + token de sesión (JWT)
   ▼
 ┌─────────────────────────── SUPABASE ───────────────────────────┐
 │  Auth ........ usuarios con correo y clave (hash con sal)        │
 │  API REST .... la app guarda y lee tablas (PostgREST)            │
 │  PostgreSQL .. empresas, miembros, clientes, ventas,             │
 │                productos, inventario                             │
 │     · RLS: cada fila tiene empresa_id; solo ves tu empresa       │
 │     · Triggers: crea la empresa del usuario nuevo;               │
 │                 mezcla cambios campo por campo                   │
 │  Edge Function "asistente" (TypeScript / Deno)                   │
 │     · revisa el token  · arma la pregunta (totales o productos)          │
 │     · llama a Gemini con la clave secreta ───────────────────────┼──► API de Google Gemini
 └──────────────────────────────────────────────────────────────────┘
```

## Qué APIs integramos y cómo
| API | Para qué | Cómo se conecta |
|---|---|---|
| **Supabase REST (PostgREST)** | Subir y bajar ventas, clientes, productos e inventario | Con el paquete oficial `supabase_flutter`: `from('ventas').upsert(...)` y `select()`. Va por HTTPS con el token del usuario |
| **Supabase Auth** | Crear cuenta, entrar, cerrar sesión | `auth.signUp` y `auth.signInWithPassword`. La clave se guarda con **hash y sal**: ni nosotros la vemos |
| **Supabase Edge Functions** | El asistente de IA | `functions.invoke('asistente')` desde la app |
| **Google Gemini (REST)** | Consejos del mes, mensajes de cobro y **textos de promoción** | **Solo desde el servidor**: la función hace `POST .../models/gemini...:generateContent` con la clave en un **secreto de Supabase**. La clave **nunca** está en la app |
| **WhatsApp** | Enviar comprobantes, cobros, pedidos | **No usamos API de pago**: abrimos un enlace `wa.me` con el mensaje escrito y el tendero toca "enviar" |

## Qué hace cada archivo

| Archivo | Lenguaje | Qué hace |
|---|---|---|
| `supabase_schema.sql` | **SQL** | Crea todo el backend: tablas, **RLS**, triggers, permisos. Se pega en Supabase → SQL Editor → Run |
| `asistente_index.ts` | **TypeScript** (Deno) | La Edge Function de IA. En el proyecto real está en `supabase/functions/asistente/index.ts` |

## Muestra estos pedazos
1. **`supabase_schema.sql`**, busca **Ctrl+F**: `create policy "ventas ver"`.
   *"Esta regla hace que la base solo entregue las ventas de la empresa del usuario. Aunque alguien modifique la app, no puede ver datos de otra tienda: lo bloquea el servidor."*
2. **`supabase_schema.sql`**, busca: `crear_empresa_para_usuario`.
   *"Cuando alguien crea su cuenta, este trigger le crea su empresa automáticamente."*
3. **`asistente_index.ts`**, busca: `usuarioValido` y luego `generativelanguage`.
   *"Primero valida que el usuario tenga sesión; si no, responde 401. Después llama a Gemini con la clave que está escondida en el servidor."*

## Si el jurado pregunta…
- **"¿Por qué Supabase y no Firebase o un servidor propio?"** → Es **PostgreSQL de verdad** (SQL estándar, se puede migrar a cualquier servidor), tiene **RLS** para separar empresas, **plan gratuito** y es **código abierto**. Un servidor propio cuesta más mantenerlo.
- **"¿Dónde corre el backend?"** → En la nube de Supabase (región us-east-1). La base es PostgreSQL 17.
- **"¿Por qué la IA pasa por una Edge Function y no directo desde la app?"** → Para **no poner la clave de la IA en la app** (cualquiera podría sacarla del APK), para **validar la sesión** y para **limpiar la pregunta** de datos personales.
- **"¿Qué datos ve la IA?"** → Para consejos, solo totales: ventas, gastos, cuánto le deben. Para promociones, solo nombres de productos, precios, el estilo y la ocasión. **Nunca** nombres de personas, celulares ni correos (Ley 1581, minimización).
- **"¿Y si la IA no está disponible?"** → La app no depende de ella: el asistente responde con los datos del celular y las promociones las redacta el celular con plantillas de mercadeo. La función tiene tres modos (`consejo`, `mensaje`, `promocion`) y solo responde si está configurado el secreto `GEMINI_API_KEY`.
- **"¿Escala?"** → Cada registro es pequeño y se envía por lotes; PostgreSQL con índices por empresa y fecha soporta miles de tiendas. Para crecer se pasa a un plan pago de Supabase sin cambiar código.
