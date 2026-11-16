// Supabase Edge Function: asistente de IA para MiPymes.
//
// Despliegue (CLI de Supabase, gratis):
//   supabase functions deploy asistente
//   supabase secrets set GEMINI_API_KEY=xxxx GEMINI_MODEL=<modelo gratuito vigente>
// (o en el panel: Edge Functions > Secrets > Add new secret).
//
// - La clave del modelo vive SOLO aquí (secreto del servidor), nunca en la app
//   ni en el repositorio.
// - Solo usuarios con sesión: verify_jwt activo y, además, la función valida
//   el token contra Supabase Auth antes de llamar al modelo.
// - Minimización (Ley 1581): la app solo envía totales y la pregunta sin
//   nombres, celulares ni correos. Aquí se vuelve a limpiar por si acaso.
// - No se registran (log) preguntas ni respuestas.

const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-flash-latest";
const KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const SB_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SB_ANON = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

/** El token debe ser de un usuario real con sesión vigente. */
async function usuarioValido(req: Request): Promise<boolean> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ") || !SB_URL) return false;
  try {
    const r = await fetch(`${SB_URL}/auth/v1/user`, {
      headers: { Authorization: auth, apikey: SB_ANON },
      signal: AbortSignal.timeout(5000),
    });
    return r.ok;
  } catch {
    return false;
  }
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const num = (v: unknown) =>
  typeof v === "number" && Number.isFinite(v) ? Math.max(0, v) : 0;

const limpiar = (s: string) =>
  s
    .replace(/[\w.+-]+@[\w-]+(\.[\w-]+)+/g, "[correo]")
    .replace(/\+?\d[\d\s-]{5,}\d/g, "[número]")
    .slice(0, 300);

const cop = (v: number) => "$" + Math.round(v).toLocaleString("es-CO");

function promptConsejo(b: Record<string, unknown>): string {
  const ingresos = num(b.ingresos);
  const egresos = num(b.egresos);
  const pregunta = limpiar(String(b.pregunta ?? "¿Cómo voy este mes?"));
  return (
    "Eres el asistente de un dueño de micro o pequeña empresa en Casanare, " +
    "Colombia. Responde en español sencillo, máximo 90 palabras, con 1 o 2 " +
    "consejos prácticos y concretos. No inventes cifras: usa solo estos datos.\n" +
    `Datos del mes: ventas ${cop(ingresos)} en ${Math.trunc(num(b.nIngresos))} ventas; ` +
    `gastos ${cop(egresos)} en ${Math.trunc(num(b.nEgresos))} movimientos; ` +
    `utilidad ${cop(ingresos - egresos)}; ventas de esta semana ${cop(num(b.ventasSemana))}; ` +
    `por cobrar ${cop(num(b.porCobrar))} entre ${Math.trunc(num(b.nDeudores))} clientes.\n` +
    `Pregunta: ${pregunta}`
  );
}

function promptMensaje(b: Record<string, unknown>): string {
  const saldo = num(b.saldo);
  const objetivo = saldo > 0
    ? `recordar con amabilidad un saldo pendiente de ${cop(saldo)} y pedir una fecha de pago`
    : "agradecer al cliente su compra y ofrecerle atención";
  return (
    "Redacta UN mensaje corto de WhatsApp (máximo 45 palabras) de un pequeño " +
    "negocio de Casanare, Colombia, para su cliente. Tono cordial y respetuoso " +
    `(usted). Objetivo: ${objetivo}. Escribe exactamente el marcador {nombre} ` +
    "donde va el nombre del cliente. Sin enlaces, sin emojis excesivos, sin " +
    "inventar datos. Devuelve solo el mensaje."
  );
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method" }, 405);
  if (!(await usuarioValido(req))) return json({ error: "auth" }, 401);
  if (!KEY) return json({ error: "no_key" }, 503);

  const largo = Number(req.headers.get("content-length") ?? "0");
  if (largo > 4000) return json({ error: "too_large" }, 413);

  let b: Record<string, unknown>;
  try {
    b = await req.json();
  } catch {
    return json({ error: "bad_json" }, 400);
  }

  const prompt = b.modo === "mensaje" ? promptMensaje(b) : promptConsejo(b);

  try {
    const r = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": KEY },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          // Margen amplio: los modelos que "piensan" gastan tokens antes de
          // responder; la longitud la controla el prompt.
          generationConfig: { maxOutputTokens: 1024, temperature: 0.4 },
        }),
        signal: AbortSignal.timeout(15000),
      },
    );
    if (!r.ok) return json({ error: "upstream" }, 502);
    const data = await r.json();
    const texto = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof texto !== "string" || !texto.trim()) {
      return json({ error: "empty" }, 502);
    }
    return json({ respuesta: texto.trim().slice(0, 1200) });
  } catch {
    return json({ error: "timeout" }, 504);
  }
});
