# 06 · Pruebas automáticas (78 pruebas, todas pasan)

Son programas que **revisan solos** que la app funcione. Se corren con `flutter test` (en VS Code: ícono del matraz → ▶).

| Archivo | Qué comprueba |
|---|---|
| `sync_test.dart` | **Modo avión**, envío único, caída de red a la mitad, reintentos, sesión vencida, descargar lo de otro celular, preguntas a la IA en cola. |
| `conflictos_test.dart` | Unión campo por campo y cambios que llegan tarde. |
| `local_db_test.dart` | Tablero (ventas, gastos, fiados, abonos), validaciones y la cola. |
| `inventario_test.dart` | Stock, venta con productos, ganancia, ajuste por conteo y sincronización entre dos celulares. |
| `codigos_test.dart` | Códigos de barras, **etiquetas de gramera** y productos de versiones anteriores. |
| `documentos_test.dart` | Comprobante, cotización, pedido sugerido, promoción y recibir pedido. |
| `pdf_test.dart` | La factura en PDF (tirilla de 80 mm y carta). |
| `asistente_local_test.dart` / `asistente_inventario_test.dart` | Que el asistente entienda y responda bien. |
| `formato_test.dart` | Pesos colombianos, celulares y que se borren datos personales antes de la IA. |
| `soporte.dart` | **Herramientas para las pruebas**: una base de prueba y un "servidor falso" que se comporta como Supabase. |
| `capturas_test.dart` | Genera **fotos de las pantallas** para revisar el diseño en el PC. |

## Qué mostrar en vivo
En el proyecto real (`C:\dev\vertex_ai_pyme`, que sí se puede correr), abre `test\sync_test.dart`, busca **"se cae la red a mitad del envío"** y corre las pruebas: en segundos salen las 78 en verde.

## Frase para exponer
*"No solo decimos que funciona sin señal: tenemos pruebas que lo simulan, incluida una caída de internet a mitad del envío."*
