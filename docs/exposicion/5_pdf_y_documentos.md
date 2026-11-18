# 5 · PDF y documentos: cómo se generan y se archivan

## En una frase
Los PDF se **dibujan con código dentro del celular**, sin internet, con el paquete **`pdf`** de Dart. El paquete **`printing`** los manda a la impresora o los comparte por WhatsApp. Cada documento recibe un **número único** y queda **archivado**.

## Cómo se genera un PDF, paso a paso
1. **Se juntan los datos** de la base del celular: la venta y sus productos, o el cliente y sus fiados, o los totales del periodo.
2. **Se dibuja el documento con "widgets de PDF"**, igual que una pantalla de Flutter pero en papel: `pw.Text` para un texto, `pw.Image` para el logo, `pw.TableHelper` para las tablas, `pw.Row` y `pw.Column` para acomodar.
3. **Se elige el papel:**
   - **tirilla de 80 mm** para impresora térmica;
   - **carta** para compartir o archivar.

   El mismo código se acomoda solo al tamaño.
4. **Se convierte en bytes** (`doc.save()`): eso ya es el archivo PDF.
5. **Se guarda** en la carpeta `VERTEX_documentos` (en el PC: `Documentos\VERTEX_documentos`) y se anota la ruta en la tabla `documentos`.
6. **Se imprime o se comparte:**
   - `Printing.layoutPdf` abre la impresión del sistema: impresora Wi-Fi o Bluetooth, o "Guardar como PDF".
   - `Printing.sharePdf` abre "Compartir": WhatsApp, correo o Drive.

## El número único de cada documento
- Formato: **`TIPO-EQUIPO-000001`**. Ejemplo: `CC-A3F1-000002` es la cuenta de cobro número 2 del equipo A3F1.
- Tipos:

  | Prefijo | Documento |
  |---|---|
  | CV | Comprobante de venta |
  | CT | Cotización |
  | CC | Cuenta de cobro |
  | PD | Pedido al proveedor |
  | IN | Informe |
  | AU | Autorización de datos del cliente (Anexo 3, Ley 1581) |

- El consecutivo se suma **dentro de una transacción**, así que no se repite.
- El código del equipo evita que dos celulares den el mismo número.
- Reimprimir la misma venta **conserva su número**.

## Qué hace cada archivo

| Archivo | Qué hace |
|---|---|
| `pdf_factura.dart` | Dibuja el **comprobante, la cotización y el pedido**: logo, datos del negocio (NIT, dirección), cliente, tabla de productos, total, y la nota "No es factura electrónica DIAN". Se ajusta a tirilla de 80 mm o a carta |
| `pdf_reportes.dart` | Dibuja PDF **de varias páginas** por bloques: tarjetas con cifras, tablas, barras y párrafos, con encabezado y "Página x de y". Lo usan los informes y la cuenta de cobro |
| `reportes_contables.dart` | **Arma el contenido**: el informe semanal, quincenal o mensual (resultados, flujo de caja, gastos, cartera, inventario, libro de movimientos) y la cuenta de cobro |
| `legal_page.dart` (en pantallas) | Dibuja el **formato de autorización Anexo 3** prellenado con el cliente, el comercio, el teléfono y la fecha, con líneas para firmar |
| `promocion_page.dart` (en pantallas) | No es PDF: arma la **imagen de la promoción** (1080 × 1080, PNG) con el logo y los precios, para el estado de WhatsApp |
| `archivo.dart` | **Guarda** el PDF en la carpeta, lo vuelve a leer, lo **imprime** o lo **comparte** |

## Muestra este pedazo
Abre **`pdf_factura.dart`** y busca **Ctrl+F**: `pdfDocumento`. Señala:
- `pw.Image(logo` → *"aquí va el logo del negocio"*;
- `TableHelper.fromTextArray` → *"aquí va la tabla de productos"*;
- `No es factura electrónica` → *"siempre lo aclaramos"*;
- `return doc.save()` → *"y esto convierte el dibujo en el archivo PDF"*.

## Si el jurado pregunta…
- **"¿Usaste un servicio externo para los PDF?"** → **No.** Se generan en el propio celular con el paquete `pdf` (licencia Apache 2.0). Funciona en modo avión y no cuesta nada.
- **"¿Es factura electrónica?"** → **No**, y lo dice cada documento. La factura electrónica exige un proveedor tecnológico autorizado por la DIAN. La app ya guarda lo necesario (emisor, cliente, ítems, precios, totales, número) para conectarse con uno.
- **"¿Cómo imprimen en una impresora térmica?"** → Con el servicio de impresión del celular: `printing` usa el diálogo de Android o Windows. El formato de 80 mm ya está listo.
