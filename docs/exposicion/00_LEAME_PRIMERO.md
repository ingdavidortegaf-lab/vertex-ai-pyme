# VERTEX AI Pyme — Cómo está hecha la app (para exponer)

> **Cómo leer esta carpeta:** abre primero **`GUIA_VISUAL.html`** (doble clic: se abre en el navegador, con dibujos y sin internet).
> Después usa este archivo como mapa. En VS Code, los `.md` se ven bonitos con **Ctrl+Shift+V**.

---

## La app en 3 frases (apréndetelas)
1. **Qué es:** un cuaderno de ventas, fiados, inventario y documentos para la tienda de barrio, que **funciona sin internet**.
2. **Cómo está hecha:** una sola app escrita en **Dart con Flutter** (sirve para Android, Windows e iPhone). Guarda todo en una **base de datos dentro del celular**. Cuando hay internet, la copia a la nube (**Supabase**).
3. **Lo que la hace distinta:** nada se pierde ni se duplica sin señal, cada tienda solo ve lo suyo, y genera PDF de facturas, cobros e informes para el contador.

---

## Qué hay en esta carpeta

| Archivo o carpeta | Para qué sirve | Cuándo lo usas |
|---|---|---|
| **`GUIA_VISUAL.html`** | Diagramas de la arquitectura, del flujo sin señal, de los PDF y de la nube | Para estudiar y para mostrarle al jurado |
| **`GUION_PARA_EXPONER.md`** | Qué decir y qué mostrar, minuto a minuto | Para ensayar |
| **`PREGUNTAS_DEL_JURADO.md`** | Las preguntas que hace un ingeniero de sistemas, con la respuesta lista | Para estudiar la noche antes |
| **`GLOSARIO.md`** | Las palabras técnicas explicadas en sencillo | Cuando una palabra no se entiende |
| `1_pantallas/` | Lo que **ve y toca** el tendero | "¿Cómo hiciste las pantallas?" |
| `2_reglas_del_negocio/` | El **cerebro**: cuentas, cobros, conflictos, avisos | "¿Dónde está la lógica?" |
| `3_datos_sin_senal/` | La **memoria del celular** y la sincronización | "¿Cómo funciona sin internet?" |
| `4_nube_backend/` | **El backend**: la base en internet (Supabase) y la función de IA | "¿Qué backend usaste? ¿Qué API integraste?" |
| `5_pdf_y_documentos/` | Cómo se **generan los PDF** y cómo se archivan | "¿Cómo generas los PDF?" |
| `6_pruebas/` | **93 pruebas automáticas** | "¿Cómo sabes que funciona?" |
| `7_configuracion/` | Android, Windows y la lista de paquetes | "¿Qué librerías usaste? ¿Cómo compilas?" |
| `8_seguridad/` | Dónde está cada protección | "¿Es segura? ¿Cumple la Ley 1581?" |
| `9_documentos_convocatoria/` | Manual, política de datos, licencias, auditoría | Lo que pide la convocatoria |
| `10_base_de_datos/` | **La base de datos**: una base de ejemplo, consultas SQL probadas (SQLite, PostgreSQL y MySQL) y cómo mostrarla en DBeaver o Supabase | "¿Cómo es la base de datos? Muéstrela" |

En **cada carpeta** hay un archivo **`EXPLICACION.md`** que dice, en palabras sencillas:
- qué hace cada archivo de código;
- **la frase para decirle al jurado**;
- **qué pedazo de código mostrar** (y cómo buscarlo con **Ctrl+F**).

> No tienes que leer el código línea por línea. Basta con saber **qué hace cada archivo** y **mostrar el pedazo indicado**.

---

## El dibujo que tienes que saber hacer (arquitectura en capas)

```
   ┌──────────────────────────────────────────────┐
   │  1. PANTALLAS  (Flutter)                       │  ← lo que ve el tendero
   └───────────────┬──────────────────────────────┘
                   │ solo hablan con la base del celular
   ┌───────────────▼──────────────────────────────┐
   │  3. DATOS: base SQLite cifrada + cola de envío │  ← funciona sin internet
   └───────┬───────────────────────────┬──────────┘
           │ usa                       │ cuando hay internet
   ┌───────▼─────────┐        ┌────────▼───────────────────────┐
   │ 2. REGLAS        │        │ 4. NUBE (backend): Supabase     │
   │ (cuentas, cobros,│        │  · PostgreSQL con RLS           │
   │  conflictos)     │        │  · Auth (usuarios)              │
   └──────────────────┘        │  · Edge Function → Gemini (IA)  │
                               └────────────────────────────────┘
```

**Regla de oro (dila así):** *"Las pantallas nunca hablan directo con internet. Todo se guarda primero en el celular y un motor de sincronización lo sube después. Por eso la app funciona en modo avión."*

---

## Las herramientas, en una tabla

| Pieza | Qué usamos | En palabras sencillas |
|---|---|---|
| Lenguaje de la app | **Dart** | El idioma en que está escrita la app |
| Framework | **Flutter 3.50** (de Google) | Una "caja de herramientas" para hacer apps que sirven en Android, Windows e iPhone con un solo código |
| Base de datos del celular | **SQLite** cifrada con **SQLCipher** (AES-256) | Un archivo tipo Excel dentro del celular, con candado |
| Backend (la nube) | **Supabase**: **PostgreSQL** + Auth + Edge Functions | El servidor en internet: guarda la copia, maneja los usuarios y corre la función de IA |
| Inteligencia artificial | **Google Gemini** (API REST), llamada desde una **Edge Function en TypeScript** | La IA da consejos con los totales del mes; nunca ve nombres |
| PDF | Paquetes **`pdf`** y **`printing`** (Dart) | Dibujan la factura con código y la mandan a imprimir o a compartir |
| WhatsApp | Enlaces **`wa.me`** (con `url_launcher`) | Abre WhatsApp con el mensaje ya escrito; no usa una API de pago |
| Código de barras | **`mobile_scanner`** | Lee códigos con la cámara |
| Avisos | **`flutter_local_notifications`** | Notificaciones que el celular se manda a sí mismo, sin servidor |
| Editor y versiones | **VS Code** y **Git** | Donde se escribe el código y donde queda la historia de cambios |

Todo es **gratis** y de código abierto. El código es nuestro: unas **13.000 líneas** entre Dart, TypeScript y SQL.

---

## Pruébala en cualquier celular (también iPhone)
Enlace: https://ingdavidortegaf-lab.github.io/vertex-ai-pyme/. El código QR está en el escritorio (`QR_VERTEX_WEB.png`). Cómo instalarla: `9_documentos_convocatoria/INSTALAR_EN_IPHONE_Y_ANDROID.md`.

## Dónde está el proyecto real
- **Proyecto que sí corre:** `C:\dev\vertex_ai_pyme`. Ábrelo en VS Code y presiona **F5** para correr la app, o corre `flutter test` para las pruebas.
- **Esta carpeta** es una **copia ordenada para explicar**. Si la abres en VS Code puede marcar errores, porque los archivos están separados del proyecto; eso es normal.
