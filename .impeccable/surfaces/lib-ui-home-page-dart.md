---
version: 1
slug: "lib-ui-home-page-dart"
primary_target: "lib/ui/home_page.dart"
related_targets: ["lib/ui/tablero_page.dart"]
---

# Surface: app shell + Inicio (tablero) — VERTEX AI Pyme (Android, Flutter)

Mode: operate. Audience: dueño de tienda en Casanare, a una mano, en el mostrador, con luz fuerte y a veces sin señal. Task: registrar en segundos y saber cómo va el día/mes y quién debe. Constraints: Material 3 components, offline (no fonts/assets from network), Spanish copy without jargon, 48 dp targets.

## Direction contract

THESIS: El tablero de tiza del mercado campesino: el día del negocio se lee como la pizarra del puesto, no como un dashboard de tarjetas iguales con métricas grises.

OWN-WORLD: Verde pizarra profundo (#16352B aprox.) en la barra superior y el bloque del día; contenido sobre fondo claro levemente verdoso. Tizas por trabajo: verde (ventas), ámbar (fiado/por cobrar), coral (gastos), azul cielo (asistente). Roboto con cifras tabulares; cifra principal enorme y etiquetas pequeñas (raise de specimen). Raises: largo de barra = monto exacto (labanotation); color fijo por cliente (character catalog); cada pestaña tiene su tiza (acetate tab board); registro recién sincronizado queda marcado hasta verse (gate board).

STORY: Al abrir ve cuánto vendió hoy y cuántas ventas fueron; toca Venta/Gasto/Abono sin buscar; abajo entiende la utilidad del mes y a quién cobrar.

FIRST VIEWPORT: AppBar pizarra con marca y píldora de sincronización; bloque pizarra a todo el ancho: «Hoy vendiste», cifra gigante en blanco, palotes de tiza agrupados de 5 (signature move), «esta semana» pequeño. Debajo, fila de 3 acciones rápidas (Venta primaria). Luego barras ventas/gastos del mes a escala exacta con utilidad, y «Te deben» con avatares de color fijo. NavigationBar M3: Inicio, Movimientos, Clientes, Asistente.

FORM: candidato 6 de 7 (pizarra del mercado campesino). seed:f36a03766ea34b7c

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
