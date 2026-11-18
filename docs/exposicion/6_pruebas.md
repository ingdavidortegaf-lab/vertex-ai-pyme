# 6 · Pruebas automáticas: 88 pruebas, todas pasan

## En una frase
Son **programas que revisan solos que la app funcione**. Se corren con `flutter test` y en unos 15 segundos salen las 88 en verde.

## Por qué importan
- Cada vez que cambiamos algo, las corremos: si algo se dañó, **una prueba se pone en rojo** y lo sabemos antes de entregar.
- Las más importantes **simulan lo difícil**: modo avión, caída de internet a mitad del envío, dos celulares cambiando lo mismo.

## Qué comprueba cada archivo

| Archivo | Qué comprueba |
|---|---|
| `sync_test.dart` | **Modo avión**, envío único, **caída de red a mitad del envío**, reintentos, sesión vencida, bajar lo de otro celular |
| `conflictos_test.dart` | Unión campo por campo y cambios que llegan tarde |
| `local_db_test.dart` | Ventas, gastos, fiados, abonos y la cola |
| `inventario_test.dart` | Existencias, venta con productos, ganancia, conteo, dos celulares |
| `contabilidad_test.dart` | **Cuenta de cobro**: abonos a lo más antiguo, días de mora, antigüedad; semanas, quincenas y meses; **número único de documentos** |
| `informes_test.dart` | El **informe del mes y la cuenta de cobro en PDF** con datos reales |
| `avisos_test.dart` | Avisos sin repetirse, meta, cartera, **servicios sin inventario**, adaptación al negocio |
| `codigos_test.dart` | Códigos de barras y **etiquetas de gramera** |
| `documentos_test.dart` | Comprobante, cotización, pedido sugerido, promoción |
| `pdf_test.dart` | La factura en PDF (tirilla y carta) |
| `asistente_*_test.dart` | Que el asistente entienda y responda bien |
| `formato_test.dart` | Pesos, celulares y que se borren datos personales antes de la IA |
| `soporte.dart` | Herramientas para las pruebas: una base de prueba y un **"servidor falso"** que se comporta como Supabase |
| `capturas_test.dart` | Toma **fotos de las pantallas** para revisar el diseño en el PC |
| `muestra_pdf_test.dart` | Genera PDF de muestra para revisarlos a ojo |

## Qué mostrar en vivo (impresiona mucho)
1. Abre el proyecto real `C:\dev\vertex_ai_pyme` en VS Code.
2. Abre una terminal (**Ctrl+ñ**) y escribe: `flutter test`
3. Mientras corre, abre `sync_test.dart` y busca **Ctrl+F**: `se cae la red`.
   *"Esta prueba corta internet a mitad del envío y comprueba que no se pierda ni se duplique nada."*
4. Al final sale **"All tests passed!"**.

## Si el jurado pregunta…
- **"¿Qué tipo de pruebas son?"** → **Unitarias** (reglas sueltas, como la cuenta de cobro) y de **integración** (la base de datos real y la sincronización con un servidor simulado). Además, capturas de pantalla para revisar el diseño.
- **"¿Probaron en un celular real?"** → Sí, en un Xiaomi 14T: modo avión y sincronización real con Supabase sin duplicados. Las funciones del 17 de noviembre (PDF de cobro, informes y avisos) están probadas con pruebas automáticas y en el PC; en el celular, en curso.
