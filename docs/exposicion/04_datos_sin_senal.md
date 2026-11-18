# 04 · Datos y funcionamiento sin señal

Esta es **la parte más importante para el jurado de Tecnología**: aquí está por qué la app funciona en modo avión y no pierde ni duplica nada.

## `local_db.dart` — la base del celular (con candado)
**Para qué sirve:** guarda todo dentro del celular, **cifrado** (SQLCipher, AES-256). La clave del candado se crea al azar y vive en el almacén seguro del celular.

**Tablas:** clientes, ventas (ventas, gastos y abonos), productos, inventario (entradas y salidas), **cola_sync** (lo que falta subir), preguntas para la IA, cotizaciones, proveedores y ajustes.

**Lo más importante:** cada vez que se guarda algo, **en una sola operación** se guarda el dato **y** su entrada en la cola. Si el celular se apaga a la mitad, o se guarda todo o nada. Mira la función `saveVentaProductos`: guarda la venta, la salida de cada producto y su lugar en la cola, juntos.

**Inventario:** el stock **no se guarda como un número**; se calcula **sumando** entradas y salidas. Así dos celulares que venden el mismo producto sin señal llegan al número correcto.

## `sync_service.dart` — el motor de sincronización
**Para qué sirve:** cada 30 segundos, al cambiar la red o al guardar algo:
1. Revisa si hay internet y si hay sesión.
2. Envía la cola **en orden**.
   - Si el servidor acepta → sale de la cola.
   - Si rechaza → espera 15 s, 30 s, 1 min… y a los 5 intentos lo aparta **sin borrarlo**.
   - Si se cae la red → se detiene y la cola queda intacta.
3. Descarga lo que subieron otros celulares de la misma tienda.
4. Avisa a la barra de arriba: "Sincronizado", "Sin conexión · 3 pendientes", etc.

## `remote_api.dart` — la conexión con la nube
**Para qué sirve:** habla con Supabase. Envía cada registro con **"upsert por id"**: si el mismo registro llega dos veces, el servidor lo reconoce y **no lo duplica**.

## `asistente_service.dart` — ¿responde el celular o la IA?
**Para qué sirve:** si la pregunta es sobre datos ("¿cuánto vendí?"), responde el celular, exacto y sin señal. Si es abierta ("¿cómo vendo más?") y hay internet, pregunta a la IA solo con **totales**, nunca con nombres. Sin señal, la pregunta queda en cola.

## Frase para exponer
*"Cada registro nace con un número único en el celular y entra a una cola en la misma operación. Por eso, con o sin señal, nada se pierde y nada se duplica. Lo probamos en un celular real y con 88 pruebas automáticas."*
