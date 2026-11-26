# Computador, caja rápida y comercio (supermercado y ferretería)

Este documento explica tres cosas: cómo se ve la app en el computador, cómo funciona la caja rápida y qué se agregó para supermercados, ferreterías, droguerías y tiendas. También dice qué está probado y qué falta.

## 1. La app en el computador

**Cuándo cambia:** desde 900 px de ancho (un portátil o un PC), la app deja de verse como un celular centrado.

- **Menú lateral:** queda a la izquierda, en verde pizarra, con estas secciones:
  - Inicio, Caja rápida, Movimientos, Inventario, Clientes, Herramientas y Asistente.
  - Desde 1200 px el menú muestra los nombres; entre 900 y 1200 px muestra solo los iconos.
  - Cada rol ve solo sus secciones, como en el celular.
- **Inicio en dos columnas:**
  - Izquierda: pagos fijos, meta y reportes.
  - Derecha: por vencer, por reponer, quién debe y los mejores clientes.
- **Inventario en tabla:**
  - Columnas: código, producto, precio, costo y margen (solo si el rol ve costos), stock, IVA y vencimiento.
  - Un clic abre las acciones del producto (entrada, ajuste o editar).
- **Ancho de las pantallas:**
  - Formularios, registro y «¿Quién atiende?»: se ven centrados.
  - Listas de Movimientos y Clientes: tienen un ancho máximo para que se lean bien.
- **Atajos de teclado:**

  | Tecla | Qué hace |
  |---|---|
  | F2 | Abrir la caja rápida (dentro de ella: ir al buscador) |
  | Ctrl+1 … Ctrl+7 | Ir a la sección 1 a 7 del menú |

**En el celular no cambia nada:** se ve como siempre, con la barra de abajo. La caja rápida está en **Caja**, con el botón **Caja rápida**.

Código: `lib/ui/escritorio.dart` (anchos y páginas centradas) y `lib/ui/home_page.dart` (menú lateral).

## 2. Caja rápida (punto de venta)

Archivo: `lib/ui/punto_venta_page.dart`. Funciona sin internet.

- **Lector de código de barras USB:**
  - Escribe el código y da Enter: el producto entra al carrito.
  - También reconoce las etiquetas de la gramera, con su peso.
- **Por nombre:** se escribe parte del nombre. Si hay un solo resultado, Enter lo agrega; si hay varios, se elige en la grilla.
- **Varias unidades:** `12*` antes del código o del nombre suma 12 de una vez.
- **Por metro, litro o kilo:** sin etiqueta de gramera, la app pregunta cuánto (por ejemplo, 12,5 m de cable).
- **Precio por mayor:**
  - Se aplica solo cuando la cantidad llega al mínimo, y la línea dice «por mayor».
  - Ejemplo: cemento a $34.000; desde 10 bultos, $32.500.
- **Cobro:**
  - Efectivo, Nequi, Daviplata, tarjeta débito o crédito, u otra transferencia.
  - Con efectivo:
    - escribes lo recibido y la app muestra el cambio;
    - hay botones de billetes ($2.000 a $100.000) y uno de «Exacto»;
    - si lo recibido no alcanza, no deja cobrar.
- **Descuento:** solo para quien tiene permiso, con el tope que fijó el dueño.
- **Fiar:** F6 o «Fiar a un cliente». Hay un buscador de clientes, y solo aparece para quien tiene permiso.
- **Al cobrar:**
  - queda una venta con sus productos;
  - el inventario baja;
  - se ve el cambio y el botón para enviar o imprimir el comprobante (tirilla de 80 mm).
- **Teclas:**

  | Tecla | Qué hace |
  |---|---|
  | F2 | Ir al buscador |
  | Enter | Agregar el producto; con el buscador vacío, cobrar |
  | F4 | Cobrar |
  | F6 | Fiar |
  | Supr | Quitar el último producto agregado |
  | Esc | Limpiar el buscador; si está vacío, vaciar el carrito (pregunta antes) |

## 3. Lo que necesita un supermercado o una ferretería

| Necesidad | Estado |
|---|---|
| Cobrar rápido con lector de código de barras | **Hecho:** caja rápida |
| Productos por peso con gramera | Ya existía; ahora también en la caja rápida |
| Vender por metro, litro, galón, caja o paquete | **Hecho:** unidades nuevas |
| Precio por mayor (contratistas, tenderos) | **Hecho:** desde una cantidad |
| Vencimientos (alimentos, droguería, agro) | **Hecho:** fecha por producto y aviso 30 días antes, en Inicio y en Inventario |
| Cargar miles de productos sin digitarlos | **Hecho:** pegar desde Excel |
| Cambio y billetes en efectivo | **Hecho** |
| Turnos de caja con diferencia, anulaciones y descuentos con tope | Ya existía |
| Fiado y cartera | Ya existía |
| Cotizaciones (ferretería) y pedidos a proveedores | Ya existía |
| Comprobante en tirilla de 80 mm o carta | Ya existía |
| Factura electrónica | La cola ya existe; falta conectar un proveedor autorizado |
| Roles: dueño, administrador, contador, vendedor (cajero) y bodeguero | Ya existía; el rol «despachador» ahora se muestra como **Vendedor (cajero)** |
| Varias cajas a la vez en el mismo negocio | Funciona: cada caja es un usuario o un perfil y todo se une en la nube. No está probado con varias cajas reales al tiempo |
| Lotes con varias fechas de vencimiento para el mismo producto | **No hecho:** hoy es una fecha por producto (la más próxima) |
| Cajón monedero e impresora térmica conectados directamente | **No hecho:** se imprime por el sistema (PDF de 80 mm) |
| Lista de precios por cliente o por categoría | **No hecho** |
| Devoluciones parciales (un producto de la venta) | **Hecho:** se anula y se registra la venta nueva con lo que queda |
| Exportar a Excel (movimientos, cartera, inventario, kárdex) | **Hecho** |
| Kárdex por producto | **Hecho** |
| Ventas por vendedor y ganancia por producto | **Hecho** |
| Buscador global en el computador | **Hecho:** Ctrl+K |
| Etiquetas de precio con código de barras | **Hecho:** hoja carta de 24 (3 × 8), EAN-13 o Code 128, con el precio por mayor si lo hay |
| Lista de precios para clientes | **Hecho:** PDF sin costos ni stock |

### Importar desde Excel

En **Inventario**, botón con el icono de subir archivo (o «Traerlos de Excel» si aún no hay productos).

1. En Excel se seleccionan las columnas con la fila de títulos y se copian (Ctrl+C).
2. Se pegan en la app (Ctrl+V).
3. Con «Revisar», la app dice cuántos productos entran y qué filas tienen errores, con su número para corregirlas.

**Títulos que reconoce, en cualquier orden:** Nombre, Precio, Costo, Stock (o Cantidad), Código, Unidad, Mínimo, IVA, Precio por mayor y Desde. Sin títulos, el orden es Nombre, Precio, Costo, Stock, Código.

**Unidades:** se escriben como sea («metros», «Galón», «kilo», «caja»). La app las convierte.

**Si el producto ya existe** (mismo código o, si no tiene código, mismo nombre): se actualizan su precio y sus datos, pero **no se toca el stock**. Los productos nuevos entran con su stock inicial.

Código: `lib/domain/importar.dart`.

## 4. Reportes, Excel, kárdex y devoluciones

- **Exportar a Excel:** los archivos se abren con doble clic en Excel en español, con columnas y tildes bien. Son CSV con punto y coma, coma decimal y UTF-8.
  - Dónde están:
    - en **Herramientas → Informes**: movimientos del periodo, quién debe (con la antigüedad de la deuda) e inventario;
    - en **Inventario**: el botón de tabla exporta el inventario;
    - en cada **kárdex**: el botón de arriba exporta ese producto.
  - Qué protegen:
    - los costos solo salen para quien puede verlos;
    - una celda que empieza con «=», «+», «-» o «@» se guarda como texto para que Excel no la ejecute como fórmula.
  - Dónde queda el archivo:
    - en el PC, en *Documentos › VERTEX_documentos*, con un botón para abrirlo;
    - en el celular, se comparte por WhatsApp, correo o Drive.
- **Kárdex por producto:** en **Inventario**, toca un producto y elige **Historial (kárdex)**.
  - Muestra cada entrada, venta, ajuste y devolución con su fecha, quién la registró y el saldo que deja.
  - El contador también lo ve, sin poder cambiar nada.
- **Ventas por vendedor:** en **Informes**, cuánto vendió cada persona en el periodo, cuántas ventas hizo y su promedio. Sale del perfil (PIN) con que se registró cada venta. Si alguien entró con la cuenta sin perfil, aparece como «Cuenta principal».
- **Ganancia por producto:** en **Informes**, qué productos dejan más ganancia en el periodo: la venta menos el costo de cada unidad vendida. Las anulaciones restan. Solo la ve quien puede ver la utilidad.
- **Buscador global (Ctrl+K)** en el computador: busca productos por nombre o código, clientes y secciones.
  - Se maneja con las flechas y Enter.
  - Un producto abre sus acciones y un cliente abre su detalle.
  - También está el botón **Buscar** arriba.
- **Devolver productos:** en **Movimientos**, mantén presionada una venta con productos y elige **Devolver productos**.
  - **Cómo se elige:** se indica cuánto devuelve de cada producto y la app muestra el valor a devolver.
  - **Cómo se registra:** como las ventas solo se agregan, la venta original se anula (todo vuelve al inventario) y se registra una venta nueva con lo que el cliente se queda, al mismo precio, del mismo cliente y con el mismo medio de pago.
  - **Si era fiada:** la deuda baja en el valor devuelto.
  - **Quién puede:** pide el mismo permiso que anular (dueño o administrador, o su PIN como autorización).
  - **Con factura electrónica:** no se puede; haría falta una nota crédito, que no está hecha.

- **Etiquetas y lista de precios:** en **Inventario**, el botón de etiqueta (🏷).
  - **Qué productos salen:** los que se ven en ese momento; el buscador y los filtros sirven para elegirlos.
  - **Etiquetas:**
    - hoja carta de 24, con el nombre, el precio y el precio por mayor si lo hay;
    - código de barras EAN-13 si el producto tiene uno de supermercado, o Code 128 si tiene un código interno;
    - se puede elegir cuántas copias de cada una.
  - **Lista de precios:** PDF para enviar a los clientes, con el nombre del negocio y su teléfono, sin costos ni stock.
  - **Al terminar:** se abre la impresión, o se comparte si el equipo no imprime.

## 5. Base de datos

- **Esquema local v12** (`agregarMayoreoYVencimiento`). Columnas nuevas en `productos`:
  - `precio_mayor`, `cantidad_mayor` y `vence`, cada una con su marca de tiempo (`*_ts`);
  - se unen por campo, como los demás datos del producto.
- **Servidor:** migración `supabase/migrations/20261125150000_mayoreo_vencimiento_unidades.sql`. Hace cuatro cosas:
  - agrega las mismas columnas con sus reglas: sin negativos y fecha en formato «AAAA-MM-DD»;
  - acepta las unidades nuevas;
  - une los campos en `merge_producto`;
  - agrega las columnas a la vista sin costos que usan el vendedor y el bodeguero.
- **Prueba SQL:** `supabase/tests/productos.sql`, en GitHub Actions.

**No está aplicada en producción**, igual que las cuatro migraciones anteriores. Hay que aplicarlas, en orden, antes de publicar esta versión. Mientras tanto, el servidor rechaza los productos con los datos nuevos, que quedan en la cola del celular o del PC sin perderse.

## 6. Pruebas

- **`test/comercio_test.dart`:**
  - unidades;
  - precio por mayor;
  - vencimiento;
  - importar desde Excel: títulos, orden, errores, existentes y nuevos;
  - migración v11→v12;
  - unión del precio por mayor.
- **`test/pantallas_escritorio_test.dart`:**
  - menú lateral y atajos;
  - celular sin cambios;
  - caja rápida: lector, `12*`, precio por mayor, cambio, F4, efectivo que no alcanza, código desconocido, por metro y F6 para fiar;
  - inventario en tabla e importar.
- **`test/reportes_y_devoluciones_test.dart`:**
  - CSV para Excel (separadores, comillas y fórmulas);
  - libro de movimientos;
  - inventario sin costos;
  - kárdex;
  - ventas por vendedor;
  - ganancia por producto;
  - devoluciones de contado, fiadas y totales;
  - permiso para devolver.
- **En `test/pantallas_escritorio_test.dart`, además:** Ctrl+K, devolver desde Movimientos, y los informes por vendedor y por producto.
- **Capturas de diseño:** `flutter test tool/capturas_escritorio_test.dart --update-goldens` (en 1440×900, 1024×768 y celular).

**No probado todavía:**
- con un lector de código de barras físico (en las pruebas el código se escribe con el teclado, que es lo mismo que hace el lector USB);
- en un PC real con la versión de Windows;
- con varias cajas a la vez.
