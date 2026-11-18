# 03 · Reglas del negocio (la "inteligencia")

Estos archivos **no tienen pantallas ni base de datos**: son las cuentas y las reglas. Por eso es fácil probarlos.

| Archivo | Para qué sirve, en palabras sencillas |
|---|---|
| `formato.dart` | Escribe la plata como **$25.000**, entiende montos escritos ("25.000", "25000"), valida celulares colombianos (10 dígitos que empiezan por 3) y los muestra como "300 123 4567". |
| `resumen.dart` | Los **"moldes"** de los datos: resumen del mes, cliente con su deuda, producto con su stock, línea de una venta, reporte por periodo. También calcula **qué hay que reponer** y **cuánto vale el inventario**. |
| `conflictos.dart` | **La regla de los dos celulares**: si dos personas cambian el mismo cliente o producto sin señal, se queda **el cambio más reciente de cada dato** (nombre, teléfono, precio…). Así no se pierde ninguno. |
| `codigos.dart` | **Códigos de barras y gramera**: revisa que el código sea válido (dígito de control), lee las **etiquetas de la gramera** (traen el producto y el peso en gramos) y convierte gramos a kilos o libras. |
| `documentos.dart` | Arma los **mensajes de WhatsApp**: comprobante de venta, cotización, pedido al proveedor y promoción. Calcula el **pedido sugerido** (lo que falta para llegar al doble del mínimo). |
| `asistente_local.dart` | El **asistente sin señal**: entiende la pregunta por palabras clave ("vendí hoy", "me debe", "agotando", "meta") y responde con los datos del celular. También arma el **mensaje de cobro**. |
| `privacidad.dart` | Antes de preguntarle algo a la IA, **borra nombres de clientes, números y correos** de la pregunta (Ley 1581). |
| `contabilidad.dart` | **Como un contador**: la cuenta de cobro aplica cada abono a la deuda **más antigua** (FIFO), calcula **desde cuándo debe** y los **días de mora**, y separa la deuda en 0-30, 31-60, 61-90 y más de 90 días. También define la **semana, la quincena y el mes** de los informes. |
| `avisos.dart` | Decide **qué avisar** (agotado, por acabarse, cartera vencida, meta, errores) y **no repite** un aviso. |
| `modo_negocio.dart` | Guarda **cómo trabaja el negocio** (productos, servicios o ambos; si fía, gramera, códigos, pedidos) para que la app se adapte. |

## Qué mostrar en pantalla
- `conflictos.dart` → la función `merge` de `ClienteCampos`: compara campo por campo y se queda con el más nuevo.
- `codigos.dart` → `leerEtiquetaBalanza`: un código `20 00123 00750 X` significa "producto 00123, **750 gramos**".

## Frases para exponer
- *"Si dos vendedores cambian el mismo cliente sin señal, no se pisan: se queda el cambio más reciente de cada dato."*
- *"Si la gramera imprime la etiqueta, la app lee el producto y el peso de una vez."*
