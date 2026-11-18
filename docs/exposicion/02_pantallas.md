# 02 · Pantallas (lo que ve el tendero)

Cada archivo es una pantalla o una pieza visual. Ninguna habla con internet: todas leen y guardan en la base del celular.

## Pantallas principales
| Archivo | Para qué sirve |
|---|---|
| `home_page.dart` | La estructura: barra verde de arriba con el estado de sincronización, menú y las 5 pestañas de abajo (Inicio, Caja, Inventario, Clientes, Asistente). |
| `tablero_page.dart` | **Inicio**: la "pizarra" con lo vendido hoy (una raya de tiza por venta), botones Venta/Gasto/Abono, herramientas, meta del mes y **reportes con gráficas** por periodo. |
| `ventas_page.dart` | **Caja**: movimientos por día y el formulario para registrar una venta (con productos, escáner y peso de gramera), un gasto o un abono. |
| `inventario_page.dart` | **Inventario**: productos, cuántos hay, qué reponer, "llegó mercancía", corregir por conteo; formulario con código de barras y unidad (unidad, kilo, libra). |
| `clientes_page.dart` | **Clientes**: lista con buscador y formulario para crear o editar. |
| `cliente_detalle_page.dart` | Ficha del cliente: cuánto debe, **cobrar por WhatsApp**, historial. |
| `asistente_page.dart` | **Asistente**: chat con preguntas sugeridas ("¿Quién me debe?", "¿Qué se me está agotando?"). |
| `herramientas_page.dart` | **Comprobantes, cotizaciones, pedir mercancía y promociones**, todo para enviar por WhatsApp, imprimir o en PDF. |
| `negocio_page.dart` | **Mi negocio**: nombre, tipo, meta del mes, NIT, dirección, WhatsApp y **logo**. |
| `login_page.dart` | **Cuenta**: entrar, crear cuenta (clave fuerte), bloqueo tras 5 intentos, cerrar sesión. |
| `consent_gate.dart` | Pide la **autorización de datos** la primera vez (Ley 1581). |
| `privacidad_page.dart` | Aviso de privacidad, derechos, revocar y borrar datos. |
| `escaner.dart` | Lee el **código de barras** con la cámara (en el PC, con lector USB o escribiéndolo). |
| `pdf_factura.dart` | Arma la **factura en PDF con logo**: tirilla de 80 mm o tamaño carta; imprimir o compartir. |
| `pdf_reportes.dart` | PDF de **varias páginas** para el contador: tarjetas con cifras, tablas, barras y número de página. |
| `reportes_contables.dart` | Arma el **informe semanal, quincenal o mensual** y la **cuenta de cobro** con los datos del celular. |
| `archivo.dart` | **Archiva** el PDF de cada documento en la carpeta VERTEX_documentos y lo vuelve a abrir. |
| `oficina_page.dart` | Pantallas **Informes**, **Cartera** (quién debe y desde cuándo) y **Documentos emitidos**. |
| `registro_negocio_page.dart` | **Registro guiado** en 5 pasos: la app pregunta y se adapta al negocio. |
| `notificaciones.dart` | **Avisos en el celular**: se agotó, se está acabando, cobros vencidos, meta cumplida. |

## Piezas visuales
| Archivo | Para qué sirve |
|---|---|
| `tema.dart` | Los colores "pizarra del mercado", letras, botones y avatares de clientes (cada cliente con su color). |
| `ilustraciones.dart` | Dibujos hechos con código (logo, palotes de tiza, pizarra, nube, escudo). **Sin imágenes descargadas.** |
| `graficas.dart` | Gráficas dibujadas con código: barras de ventas y gastos, contado vs fiado, lo más vendido. |
| `comun.dart` | Ayudas que usan todas las pantallas: avisos abajo, abrir WhatsApp, preguntar "¿seguro?". |
| `inactividad.dart` | Cierra la sesión de la nube tras **30 minutos** sin usar la app. |

**Qué mostrar en pantalla:** en `tablero_page.dart`, la clase `_PizarraDelDia` (la pizarra) y `ReportesNegocio` (los reportes).
**Frase para exponer:** *"Diseñamos para el tendero: letras grandes, todo en español, colores que se leen al sol y gráficas dibujadas por la app, sin descargar nada."*
