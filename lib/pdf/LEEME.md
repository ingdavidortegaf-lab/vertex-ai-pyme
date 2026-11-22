# 4 · PDF y documentos

Los PDF se dibujan en el celular, sin internet, con el paquete `pdf`, y se imprimen o comparten con `printing`.

- `pdf_factura.dart`: comprobante, cotización y pedido (con logo; tirilla de 80 mm o carta).
- `pdf_reportes.dart`: PDF de varias páginas (informes y cuenta de cobro).
- `reportes_contables.dart`: arma el contenido de los informes y del cobro.
- `archivo.dart`: guarda el PDF con su número único y lo vuelve a abrir.

El formato de autorización de datos (número `AU-`) se dibuja en `lib/ui/legal_page.dart` → `pdfAutorizacion` y se archiva con este mismo `archivo.dart`.

Explicación completa: `docs/COMO_ESTA_CONSTRUIDO.txt`
