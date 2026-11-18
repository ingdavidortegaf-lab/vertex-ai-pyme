# Guion para explicar el código (5 a 7 minutos)

> Ten abierta la **`GUIA_VISUAL.html`** en el navegador y **VS Code** con esta carpeta.
> No leas el código: **di qué hace** y **señala la línea**.

| Min. | Qué dices | Qué muestras |
|---|---|---|
| 0:00 | *"VERTEX AI Pyme es una app para la tienda de barrio que funciona sin internet: ventas, fiados, inventario y documentos para el contador."* | La guía visual, sección **"La app en una imagen"** |
| 0:30 | *"Está hecha en **Dart con Flutter**: un solo código para Android, Windows e iPhone. El backend es **Supabase** con PostgreSQL, y la IA es **Gemini** a través de una función del servidor."* | Sección **"Con qué está hecha"** |
| 1:15 | *"La arquitectura es en capas y offline-first: las pantallas nunca hablan con internet; todo se guarda primero en el celular."* | Sección **"Arquitectura"** (el dibujo de capas) |
| 2:00 | *"Cuando el tendero guarda una venta, se escribe en la base cifrada y en una cola, en la misma transacción. Un motor sube la cola cada 30 segundos o cuando vuelve la señal, con upsert por id: nada se pierde ni se duplica."* | Sección **"Una venta sin señal"**. Luego VS Code: `3_datos_sin_senal/local_db.dart` → Ctrl+F `saveMovimiento` |
| 3:15 | *"En la nube, cada tienda solo ve sus datos gracias a RLS en PostgreSQL. La clave de la IA está escondida en el servidor."* | Sección **"El backend"**. VS Code: `4_nube_backend/supabase_schema.sql` → Ctrl+F `create policy "ventas ver"` |
| 4:15 | *"Los PDF se dibujan en el mismo celular con el paquete pdf de Dart, llevan logo y número único, y quedan archivados para el contador."* | Sección **"Cómo nace un PDF"**. VS Code: `5_pdf_y_documentos/pdf_factura.dart` → Ctrl+F `pdfDocumento` |
| 5:15 | *"La cuenta de cobro aplica los abonos a la deuda más antigua, como un contador: así sabemos desde cuándo debe cada cliente."* | VS Code: `2_reglas_del_negocio/contabilidad.dart` → Ctrl+F `estadoDeCuenta` |
| 6:00 | *"Y para saber que todo funciona tenemos 93 pruebas automáticas, incluida una que corta internet a mitad del envío."* | Terminal en `C:\dev\vertex_ai_pyme`: `flutter test` → **All tests passed!** |

## Si piden ver la base de datos (2 minutos)
Abre **DBeaver → VERTEX demo** y sigue el guion de `10_base_de_datos/EXPLICACION.md`:
1. Diagrama ER.
2. Consulta 3: últimas ventas.
3. Consulta 5: por medio de pago.
4. Consulta 8: inventario calculado.
5. En Supabase, consulta 5: sin duplicados.

## Si te cortan el tiempo (versión de 1 minuto)
*"Es una app en **Flutter/Dart**, **offline-first**: guarda todo en una **SQLite cifrada** en el celular y una **cola transaccional** la sincroniza con **Supabase** (PostgreSQL con RLS por empresa) usando **upsert idempotente**. Los **PDF se generan en el dispositivo** con el paquete pdf, y la **IA (Gemini)** se llama desde una **Edge Function** para no exponer la clave. Tiene **93 pruebas automáticas**."*

## Antes de entrar (lista de chequeo)
- [ ] Celular cargado, con la app abierta y en **modo avión** para la demo.
- [ ] PC con VS Code abierto en esta carpeta y la `GUIA_VISUAL.html` abierta en el navegador.
- [ ] Terminal abierta en `C:\dev\vertex_ai_pyme`, con `flutter test` ya corrido una vez (así la segunda corre más rápido).
- [ ] Haber leído `PREGUNTAS_DEL_JURADO.md`.
