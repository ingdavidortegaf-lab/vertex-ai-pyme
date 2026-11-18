# Preguntas del jurado (ingeniero de sistemas) y cómo responderlas

> **Consejo:** responde **corto** (2 o 3 frases), y si quiere más detalle, **muestra el archivo**. Si no sabes algo, di: *"Eso lo tenemos pendiente; hoy funciona así…"*. La honestidad suma puntos ("se califica lo que se demuestra").

---

## A. Lenguaje y tecnología

**1. ¿En qué lenguaje está hecha la app?**
En **Dart**, con el framework **Flutter** de Google. Además usamos **TypeScript** para la función de IA en el servidor y **SQL** para la base de datos en la nube.

**2. ¿Por qué Flutter?**
Porque con **un solo código** sale la app para Android, Windows e iPhone. Es gratis, lo mantiene Google, compila a código nativo (es rápida) y tiene muchas librerías.

**2b. ¿Funciona en iPhone?**
Sí, por la **versión web**: https://ingdavidortegaf-lab.github.io/vertex-ai-pyme/. Se abre en Safari y se agrega a la pantalla de inicio como una app. Es el mismo código Flutter compilado a web, y la base SQLite corre en WebAssembly. La app nativa de iPhone para la App Store requiere un Mac y la cuenta de Apple Developer (USD 99 al año); queda para después del piloto.

**3. ¿Es una app nativa, híbrida o web?**
Es **multiplataforma compilada**: Flutter convierte el código Dart en código de máquina del celular (ARM) y dibuja la pantalla con su propio motor. No es una página web dentro de una app.

**4. ¿Qué herramientas usaron para desarrollar?**
**VS Code** como editor, **Flutter SDK 3.50**, **Android SDK**, **Git** para versiones y **Supabase** para la nube. Todo gratuito.

**5. ¿Cuántas líneas de código tiene?**
Unas **13.000** entre Dart, TypeScript y SQL, más 93 pruebas automáticas.

---

## B. Arquitectura

**6. ¿Qué arquitectura usaron?**
**Arquitectura en capas, offline-first** (primero sin conexión):
1. **Pantallas** (Flutter).
2. **Reglas del negocio**: lógica pura, sin pantallas ni internet.
3. **Datos**: base SQLite cifrada en el celular, más una cola de sincronización.
4. **Nube**: Supabase.

Las pantallas **nunca** hablan directo con internet.
*(Muestra el dibujo de `GUIA_VISUAL.html`.)*

**7. ¿Qué significa "offline-first"?**
Que el celular es la fuente principal: todo se guarda ahí primero y la app funciona completa en modo avión. Internet solo sirve para respaldar y compartir entre celulares.

**8. ¿Usaron algún patrón de diseño?**
Sí:
- **Repositorio**: `RemoteApi` esconde de dónde vienen los datos; por eso en las pruebas lo cambiamos por un servidor falso.
- **Singleton**: una sola base y un solo motor de sincronización.
- **Cola transaccional (outbox)**: cada registro y su anotación en la cola se guardan juntos.
- **Observador**: `ValueNotifier`, las pantallas escuchan los cambios.

**9. ¿Cómo manejan el estado en Flutter?**
Con lo que trae Flutter: `StatefulWidget` y `ValueNotifier`. La base del celular avisa cuando cambia algo y las pantallas se redibujan. No necesitamos librerías extra.

---

## C. Backend y APIs

**10. ¿Qué backend tiene?**
**Supabase**:
- **PostgreSQL 17** con seguridad por fila (RLS);
- **Auth** para los usuarios;
- una **Edge Function** en TypeScript para la IA.

No hicimos un servidor propio: Supabase da todo eso con plan gratuito y es código abierto.

**11. ¿Qué APIs integraron y cómo?**
- **Supabase REST** (con el paquete `supabase_flutter`): guardar y leer tablas con `upsert` y `select`, por HTTPS y con el token del usuario.
- **Supabase Auth**: crear cuenta y entrar (`signUp`, `signInWithPassword`).
- **Edge Function** propia (`functions.invoke('asistente')`).
- **Google Gemini** (API REST `generateContent`), llamada **solo desde el servidor**.
- **WhatsApp**: enlaces `wa.me`, sin API de pago.

**12. ¿Cómo se comunican la app y el servidor?**
Por **HTTPS** con mensajes **JSON**. Cada petición lleva el **token JWT** de la sesión. El servidor (con RLS) solo deja ver y crear filas de la empresa de ese usuario.

**13. ¿Qué tablas tiene la base en la nube?**
- **empresas** y **miembros**: quién pertenece a qué tienda;
- **clientes**;
- **ventas**: ventas, gastos y abonos;
- **productos**;
- **inventario**: entradas, ventas y ajustes.

Cada fila tiene `empresa_id`.

**14. ¿Qué es RLS y por qué lo usaron?**
**Row Level Security**: el mismo PostgreSQL filtra las filas según el usuario. Así, aunque alguien modifique la app, **una tienda no puede ver los datos de otra**: lo impide el servidor, no la app.

**15. ¿Dónde está la clave de la IA?**
En un **secreto de Supabase**, solo en el servidor. **Nunca** en la app ni en el código. La app llama a la Edge Function; la función revisa la sesión y llama a Gemini.

**16. ¿Qué le mandan a la IA?**
Solo **totales**: ventas, gastos, cuánto le deben. **Nunca** nombres, celulares ni correos. Se limpia dos veces: en la app (`privacidad.dart`) y en el servidor. Es la minimización de la Ley 1581.

---

## D. Funcionamiento sin internet y sincronización

**17. ¿Cómo funciona sin internet?**
Todo se guarda en una **base SQLite dentro del celular**. Cada registro se anota, en la misma transacción, en una **cola de envío**. Un motor revisa la cola cada 30 segundos y cada vez que vuelve la señal, y sube lo pendiente.

**18. ¿Qué pasa si se cae internet a mitad de un envío?**
El registro solo se marca como enviado cuando el servidor confirma. Si no confirma, se reintenta. Como cada registro tiene un **UUID** y se envía con **upsert por id**, el servidor **no lo duplica**. Hay una **prueba automática** que lo simula.

**19. ¿Y si falla muchas veces?**
Espera cada vez más (**backoff exponencial**: 15 s, 30 s, 1 min… hasta 30 min). Tras 5 intentos lo aparta como error, **sin borrarlo**, y avisa. Se puede reintentar desde el menú.

**20. ¿Qué pasa si dos celulares cambian lo mismo sin señal?**
- **Clientes y productos**: gana el cambio más reciente **de cada campo** (Last-Write-Wins por campo, con hora en UTC). Lo resuelve el celular y también un **trigger** en PostgreSQL.
- **Ventas e inventario**: **solo se agregan**, nunca se editan, así que no hay conflicto.

**21. ¿Por qué UUID y no 1, 2, 3?**
Porque dos celulares sin señal generarían el mismo número. El UUID se crea en el celular y no se repite.

---

## E. PDF, documentos e inventario

**22. ¿Cómo generan los PDF?**
**En el mismo celular**, sin internet, con el paquete **`pdf`** de Dart:
1. Se "dibuja" el documento con widgets (texto, logo, tablas).
2. Se convierte en bytes.
3. Se guarda en la carpeta `VERTEX_documentos`.
4. Con el paquete **`printing`** se imprime (diálogo del sistema, tirilla de 80 mm o carta) o se comparte (WhatsApp, correo).

**23. ¿Cómo numeran los documentos?**
`TIPO-EQUIPO-000001`. Ejemplo: `CV-A3F1-000012`. El consecutivo se suma dentro de una transacción y el código del equipo evita choques entre celulares. Todo queda en la tabla `documentos` con la ruta del PDF.

**24. ¿Es factura electrónica?**
**No**, y cada PDF lo dice. Para eso se necesita un proveedor tecnológico autorizado por la DIAN. La app ya tiene los datos estructurados para conectarse con uno: es el siguiente paso.

**25. ¿Cómo calculan la cuenta de cobro?**
Ordenamos fiados y abonos por fecha. Cada abono paga primero el fiado más antiguo (**FIFO**, como un contador). Lo que queda pendiente nos dice **desde cuándo debe**, los **días de mora** y la **antigüedad** (0-30, 31-60, 61-90, +90).

**26. ¿Cómo calculan el inventario?**
La existencia **no se guarda como un número**: es la **suma de todos los movimientos** (entradas, ventas, ajustes). Así es auditable y no se daña si dos celulares venden a la vez.

**27. ¿Cómo leen el código de barras y la gramera?**
- Con la cámara (paquete `mobile_scanner`) o con un lector USB, que escribe como un teclado.
- Validamos el dígito de control EAN.
- Las etiquetas de gramera (empiezan por 20 a 29) traen el código del producto y el **peso en gramos**, y la app lo convierte a kilos o libras.

---

## E1. Base de datos (para mostrarla, mira `10_base_de_datos/EXPLICACION.md`)

**E1.1 ¿Qué motor de base de datos usaron? ¿Por qué no MySQL?**
- En el celular, **SQLite**: es embebida, vive dentro de la app sin servidor y funciona sin internet. Va cifrada con SQLCipher.
- En la nube, **PostgreSQL** (Supabase), por la seguridad por fila (RLS), el JSON (`jsonb`) y los triggers.
- MySQL necesita un servidor encendido y no trae RLS. El SQL es estándar: tenemos las mismas consultas en MySQL para mostrarlo.

**E1.2 ¿Cómo está modelada?**
Tablas `clientes`, `ventas` (ventas, gastos y abonos), `productos`, `inventario`, `cola_sync` y `documentos`. En la nube, además, `empresas` y `miembros`; cada fila lleva `empresa_id`.
- Las llaves son **UUID** creados en el celular.
- La existencia del inventario **se calcula** sumando movimientos.
- Las ventas **solo se agregan**: es una bitácora auditable.

**E1.3 ¿Por qué la venta no tiene llave foránea al cliente?**
Porque el sistema funciona sin conexión: una venta puede llegar a la nube antes que el cliente creado en otro celular, y la llave foránea la rechazaría. La integridad la cuidan la app y los triggers. Sí hay llave foránea a `empresas` y reglas **CHECK** en montos, tipos y pagos.

**E1.4 Muéstreme una consulta.**
Abre DBeaver con `vertex_demo.db` y corre la consulta 8 (inventario calculado) o la 5 (ventas por medio de pago). En Supabase, la consulta 5 de la nube demuestra que **no hay duplicados**.

## E2. Pagos, escala y costos

**E2.1 ¿Cómo manejan los pagos por Nequi, Bancolombia o tarjeta?**
Cada venta guarda su **medio de pago**, y se puede **dividir**: una parte por Nequi y otra en efectivo. La app revisa que la suma dé el total, y el **servidor lo vuelve a validar** con una regla en PostgreSQL (`pagos_validos`). Con eso se hace el **cierre de caja**: cuánto efectivo debe haber y cuánto llegó a cada cuenta.

**E2.2 ¿Tienen pasarela de pago?**
Todavía no, y lo decimos claro. Hoy el cliente paga por transferencia a las cuentas del tendero, que salen en la cuenta de cobro, sin comisión. La siguiente fase es **Wompi** (Bancolombia): link y QR. Cada tienda tendría su propia cuenta, la llave privada estaría solo en una Edge Function y un webhook confirmaría el pago. **VERTEX nunca toca la plata.** Wompi cobra alrededor del 2,65 % + $700 + IVA por transacción, y el QR, 1 % + IVA.

**E2.3 ¿Qué pasa con 100 tiendas? ¿Se satura?**
No:
- Cada tienda trabaja en su celular, así que si la nube se demora, la tienda no se detiene.
- 100 tiendas generan unos 216 MB al mes; el plan Pro de Supabase (8 GB) alcanza para unos 3 años.
- Implementamos **descarga adaptativa**: si no hay cambios, la app consulta cada vez menos, hasta cada 5 minutos. Bajamos de unas 27 a unas 3 consultas por segundo en horas tranquilas.
- Para crecer más, se cambia el plan de la base, no el código.

**E2.4 ¿Cuánto cuesta y cuánto ganan?**
- La tecnología cuesta unos **$135.000 al mes** (Supabase Pro, IA y dominio).
- Con **100 tiendas a $19.900** entran $1.990.000 al mes; menos tecnología y media persona de soporte, quedan unos **$455.000 al mes**.
- El punto de equilibrio son **78 tiendas**.
- Con 300 tiendas quedan unos $3 millones al mes. El detalle está en `docs/PAGOS_Y_MODELO_DE_NEGOCIO.md`.

## F. Seguridad, calidad y negocio

**28. ¿Cómo protegen los datos?**
- Base del celular **cifrada AES-256** (SQLCipher), con la clave en el almacén seguro de Android.
- Solo HTTPS.
- Claves con hash.
- Bloqueo tras 5 intentos y cierre a los 30 minutos sin uso.
- RLS en el servidor.
- Claves fuera del código.
- Sin copias de seguridad de Android.

**29. ¿Cómo probaron la app?**
- **93 pruebas automáticas** (`flutter test`): reglas, base de datos, sincronización con servidor simulado, caída de red, conflictos y PDF.
- Prueba real en un Xiaomi 14T: modo avión y sincronización con Supabase sin duplicados.
- Capturas de pantalla para revisar el diseño.

**30. ¿Cuánto cuesta mantenerla?**
**$0** en el plan gratuito de Supabase para el piloto. Con 100 tiendas, unos **$135.000 al mes** (Supabase Pro de USD 25, IA y dominio), sin cambiar código. Todas las librerías son gratuitas y de código abierto (149 paquetes con licencias libres).

**31. ¿Escala a muchas tiendas?**
Sí:
- cada tienda es una "empresa" separada por RLS;
- los envíos van por lotes;
- las consultas usan índices por empresa y fecha.

PostgreSQL maneja millones de filas.

**32. ¿Qué falta o qué harían después?**
- Factura electrónica DIAN con un proveedor autorizado.
- Cifrar la base en Windows.
- Roles de vendedor y administrador.
- Versión de iPhone (requiere Mac).
- Avisos con la app cerrada.

**33. ¿Quién es dueño del código?**
El equipo conserva la propiedad intelectual. La Gobernación recibe una **licencia gratuita e indefinida** de uso, como piden las bases.

---

## G. Lo nuevo: proveedores, promociones, seguimiento y la parte jurídica

**¿Cómo maneja lo que la tienda le debe al proveedor?**
Al recibir el pedido se elige si se pagó todo, una parte (por ejemplo la mitad) o todo fiado. Todo entra al inventario, el gasto se registra solo por lo pagado y el saldo queda en «Lo que debo» con su fecha límite. Los abonos se registran con el medio de pago y la app avisa 3 días antes del vencimiento.

**¿La IA hace la promoción?**
Sí. Con señal, la función de Supabase le pide el texto al modelo de IA. Solo viajan los nombres de los productos, los precios, el estilo y la ocasión, nunca datos de clientes. Sin señal, el celular redacta el texto con plantillas de mercadeo: gancho, ahorro, urgencia, llamado a la acción y etiquetas del municipio. Además arma una imagen cuadrada con el logo y los precios, lista para el estado de WhatsApp.

**¿No es ilegal escribirles a los clientes por WhatsApp?**
No, si autorizaron. La app pide la autorización con el formato oficial (Anexo 3), la guarda con fecha y medio, y solo muestra el botón «Escribirle» a quien autorizó. Además sugiere no escribir más de una vez por semana.

**¿Dónde está el enlace a la política?**
En la pantalla de bienvenida, en la casilla (sin premarcar): «…conforme a la Política de Tratamiento de Datos Personales», subrayado y tocable. La política completa se abre sin internet. También hay un enlace a www.casanare.gov.co y al correo del canal de derechos.

**¿Sirve para otros negocios?**
Sí. Hay 22 tipos (panadería, frutas, carnicería, ropa, celulares, peluquería, taller, transporte, hospedaje…). La app se ajusta sola: por ejemplo, si solo vende servicios, esconde el inventario y la gramera.

## Si te hace una pregunta que no sabes
Di con calma: *"Le muestro dónde está en el código"* y abre el archivo de la carpeta que corresponde, o la **`GUIA_VISUAL.html`** en la sección más cercana. O: *"No lo tenemos todavía; está en nuestra lista de pendientes en la auditoría."*
