# 1 · Pantallas: lo que ve y toca el tendero

## En una frase
Cada archivo de esta carpeta es **una pantalla o una pieza visual** de la app, hecha con **Flutter** (lenguaje **Dart**).

## Cómo funciona una pantalla en Flutter (para explicarlo)
- En Flutter **todo es un "widget"**: un botón, un texto, una tarjeta, una pantalla completa. Se arman como bloques de Lego, uno dentro de otro.
- Una pantalla tiene un método **`build`**, que dice cómo se dibuja. Cuando cambian los datos, Flutter la **vuelve a dibujar sola**.
- Las pantallas **no se conectan a internet**: le piden los datos a la base del celular (`LocalDb`) y escuchan sus cambios (`LocalDb.instance.cambios`). Cuando se guarda una venta, todas las pantallas se actualizan.

## Qué hace cada archivo

| Archivo | Qué es | Cómo decirlo |
|---|---|---|
| `home_page.dart` | La estructura: barra de arriba, menú ⋮ y las 5 pestañas de abajo | "La casa de la app" |
| `tablero_page.dart` | **Inicio**: lo vendido hoy, botones rápidos, meta y gráficas | "El tablero tipo Power BI" |
| `ventas_page.dart` | **Caja**: registrar venta, gasto o abono; con productos, escáner y peso | "La caja registradora" |
| `inventario_page.dart` | **Inventario o Servicios**: productos, existencias, por reponer | "El control de bodega" |
| `clientes_page.dart` | Lista de clientes con buscador | |
| `cliente_detalle_page.dart` | Ficha del cliente: cuánto debe, cobrar, cuenta de cobro | |
| `herramientas_page.dart` | Comprobantes, cotizaciones, pedidos al proveedor, promociones | "Todo lo que se manda por WhatsApp" |
| `oficina_page.dart` | **Informes**, **Cartera** y **Documentos emitidos** | "La oficina del contador" |
| `registro_negocio_page.dart` | Las **5 preguntas del inicio**; la app se adapta al negocio | "La app se moldea al negocio" |
| `notificaciones.dart` | Los **avisos** en el celular (se agotó, cobros vencidos) | |
| `asistente_page.dart` | Chat con el asistente | |
| `negocio_page.dart` | Mi negocio: nombre, NIT, dirección, logo | |
| `login_page.dart` | Cuenta: entrar, crear cuenta, clave fuerte, bloqueo | |
| `consent_gate.dart` | Pide la **autorización de datos** la primera vez (Ley 1581) | |
| `privacidad_page.dart` | Aviso de privacidad, derechos, borrar datos | |
| `escaner.dart` | La cámara para leer **códigos de barras** | |
| `inactividad.dart` | Cierra la sesión tras **30 minutos** sin uso | |
| `tema.dart` | Colores "pizarra del mercado", letras y botones | "El diseño" |
| `ilustraciones.dart` | Dibujos hechos con código (logo, pizarra) | "Sin imágenes descargadas" |
| `graficas.dart` | Gráficas dibujadas con código | |
| `comun.dart` | Ayudas comunes: mensajes abajo, abrir WhatsApp | |

## Muestra este pedazo
Abre **`home_page.dart`** y busca con **Ctrl+F**: `NavigationBar`.
Ahí están las 5 pestañas. Señala `label: 'Inicio'`, `'Caja'`, etc. y di:
*"Cada pestaña es un widget. Esta línea cambia el nombre de Inventario a Servicios si el negocio solo vende servicios: la app se adapta."* (`nombreCatalogo`)

## Si el jurado pregunta…
- **"¿Por qué Flutter y no Android nativo (Kotlin)?"** → Un solo código para Android, Windows e iPhone. Menos costo, y Google lo mantiene.
- **"¿Qué patrón de manejo de estado usaste?"** → El de Flutter: `StatefulWidget` + `ValueNotifier` (un "avisador" que redibuja cuando algo cambia). Es sencillo, no necesita librerías extra y alcanza para esta app.
- **"¿Es accesible?"** → Botones grandes, letra legible, todo en español sin jerga, modo oscuro automático.
