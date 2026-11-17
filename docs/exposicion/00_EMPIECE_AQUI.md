# VERTEX AI Pyme — Guía para exponer el código

> Abre cada archivo `EXPLICACION.md` en VS Code y presiona **Ctrl+Shift+V** para verlo con formato.
> Esta carpeta es para **mostrar y explicar** el código. Para **correr** la app se usa el proyecto real: `C:\dev\vertex_ai_pyme`.

## ¿Qué es la app, en una frase?
Un **cuaderno de fiados en el celular** para la tienda de barrio de Casanare: registra ventas, fiados, gastos e inventario, **funciona sin señal**, y cuando vuelve internet guarda todo en la nube sola.

## ¿Con qué está hecha?
| Parte | Programa / lenguaje | En palabras sencillas |
|---|---|---|
| La app | **Flutter** con lenguaje **Dart** | Un solo código que sirve para Android, iPhone y PC |
| Base de datos del celular | **SQLite** cifrado con **SQLCipher** | Un "archivo de Excel" escondido y con candado dentro del celular |
| La nube | **Supabase** (base de datos **PostgreSQL**) | Un respaldo en internet; cada tienda solo ve lo suyo |
| Inteligencia artificial | **Edge Function** en **TypeScript** + **Gemini** | Un pequeño programa en la nube que le pregunta a la IA |
| Editor | **VS Code** | Donde se escribe y se corre el código |
| Historial de cambios | **Git** | Guarda cada versión del código |

Todo es **gratis** y de código abierto (ver `09_documentos/LICENCIAS.md`).

## Las partes del código (en orden para exponer)
| Carpeta | Qué hay | Idea clave para decir |
|---|---|---|
| `01_arranque` | Cómo empieza la app | "Abre la base con candado y arranca la sincronización" |
| `02_pantallas` | Lo que ve el tendero | "Botones grandes, colores de pizarra, todo en español" |
| `03_reglas_del_negocio` | Las cuentas y las reglas | "Aquí está la inteligencia del negocio, sin pantallas" |
| `04_datos_sin_senal` | Guardar y sincronizar | "Nada se pierde, nada se duplica" |
| `05_nube` | Supabase e IA | "Cada tienda solo ve sus datos; la IA no ve nombres" |
| `06_pruebas` | 78 pruebas automáticas | "La computadora revisa que todo funcione" |
| `07_configuracion` | Android, Windows y paquetes | "Android 12+, sin copias de seguridad, ventana de PC" |
| `08_seguridad_y_privacidad` | Mapa de la seguridad | "Ley 1581 y OWASP: dónde está cada protección" |
| `09_documentos` | Manual, política de datos, auditoría | "Todo lo que pide la convocatoria" |

## Cómo está organizada la app (3 capas)
```
 PANTALLAS (02)   ← lo que se ve y se toca
      │  solo hablan con la base del celular
      ▼
 DATOS (04)       ← base con candado + cola de envío + sincronización
      │  usan las reglas
      ▼
 REGLAS (03)      ← cuentas, conflictos, códigos de barras, textos
      │
      ▼  (solo cuando hay internet)
 NUBE (05)        ← Supabase + IA
```
**Regla de oro:** las pantallas **nunca** hablan directo con internet. Todo pasa por la base del celular; por eso la app funciona en modo avión.

## Guion sugerido (10 minutos)
1. **(1 min)** Qué es y con qué está hecha → esta página.
2. **(1 min)** `01_arranque/main.dart` → "así arranca".
3. **(2 min)** `04_datos_sin_senal/local_db.dart` y `sync_service.dart` → "guardar sin señal y sincronizar".
4. **(2 min)** `03_reglas_del_negocio/conflictos.dart` y `codigos.dart` → "dos celulares sin señal no se pisan" y "la gramera".
5. **(1 min)** `05_nube/supabase_schema.sql` → "cada tienda ve solo lo suyo (RLS)".
6. **(1 min)** `02_pantallas/tablero_page.dart` → "la pizarra del día y los reportes".
7. **(1 min)** `06_pruebas` → correr las pruebas en vivo.
8. **(1 min)** `08_seguridad_y_privacidad` → Ley 1581.

## Buscar por tema
| Quiero mostrar… | Abre… |
|---|---|
| Funciona sin señal | `04_datos_sin_senal/local_db.dart` (transacción + cola) y `sync_service.dart` |
| No se duplica nada | `04_datos_sin_senal/remote_api.dart` (función `enviar`, upsert por id) |
| Conflictos entre celulares | `03_reglas_del_negocio/conflictos.dart` |
| Inventario | `03_reglas_del_negocio/resumen.dart` y `04_datos_sin_senal/local_db.dart` (`saveVentaProductos`) |
| Código de barras y gramera | `03_reglas_del_negocio/codigos.dart` y `02_pantallas/escaner.dart` |
| Factura en PDF con logo | `02_pantallas/pdf_factura.dart` |
| WhatsApp | `03_reglas_del_negocio/documentos.dart` y `02_pantallas/herramientas_page.dart` |
| Asistente | `03_reglas_del_negocio/asistente_local.dart` y `05_nube/asistente_index.ts` |
| Reportes y gráficas | `02_pantallas/tablero_page.dart` y `graficas.dart` |
| Seguridad | `08_seguridad_y_privacidad/EXPLICACION.md` |
