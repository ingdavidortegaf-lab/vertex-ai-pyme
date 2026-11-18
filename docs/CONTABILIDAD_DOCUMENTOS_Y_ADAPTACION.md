# Contabilidad, documentos y app a la medida — cómo funciona

Esta guía explica lo que se agregó el 17 de noviembre de 2026: **documentos con número único y archivados**, **cuenta de cobro con trazabilidad**, **informes semanal, quincenal y mensual para el contador**, **pedido al proveedor en PDF**, **servicios**, **registro guiado del negocio** y **avisos en el celular**.
Para cada parte se explica qué hace, cómo funciona por dentro, por qué se hizo así, cómo usarla bien y qué no hace.

---

## 1. Documentos con número único y archivo en el equipo

### Qué hace
Cada documento que la app genera recibe un **número único** y su **PDF queda guardado** en el mismo equipo:

| Documento | Prefijo | Ejemplo |
|---|---|---|
| Comprobante de venta | CV | `CV-A3F1-000012` |
| Cotización | CT | `CT-A3F1-000004` |
| Cuenta de cobro | CC | `CC-A3F1-000002` |
| Pedido al proveedor | PD | `PD-A3F1-000007` |
| Informe (semanal, quincenal, mensual) | IN | `IN-A3F1-000001` |

El número tiene tres partes: **tipo**, **código del equipo** (4 letras al azar, distinto en cada celular o PC) y **consecutivo** de 6 cifras.

Todo queda en **Inicio → Herramientas → Documentos**, con un buscador por número o cliente y un filtro por tipo. Desde ahí se vuelve a compartir o imprimir el PDF sin rehacerlo.

### Dónde quedan los PDF
- **En el PC (Windows):** `Documentos\VERTEX_documentos`. El contador puede copiar la carpeta completa. En la app, el botón **Abrir la carpeta de documentos** la abre.
- **En el celular:** en la carpeta privada de la app. Se sacan con el botón **PDF** (WhatsApp, correo o Drive).

### Cómo funciona por dentro
- Tabla nueva `documentos` en la base del celular (versión 5 del esquema). Guarda id, tipo, número, registro de origen, cliente, total, fecha, ruta del PDF y un resumen. Archivo: `lib/data/local_db.dart`.
- **Consecutivo sin repetirse:** el contador de cada tipo vive en la tabla `ajustes` (`consec_venta`, `consec_cobro`…). Se lee, se suma 1 y se guarda **dentro de una transacción**: dos documentos no pueden quedar con el mismo número.
- **Sin choques entre equipos:** el código del equipo hace que dos celulares de la misma tienda nunca generen el mismo número, aun sin internet.
- **Reimpresión:** si vuelves a abrir el comprobante de la misma venta, se reutiliza el número que ya tenía (`reutilizar: true`). Lo mismo pasa con una cotización. Una cuenta de cobro, un pedido o un informe sí reciben número nuevo cada vez, porque son una "foto" de una fecha.
- **Actualización segura:** un celular con la versión anterior pasa solo a la versión 5. Se crea la tabla nueva y no se toca ningún dato. Se probó en el PC: la base pasó de la versión 4 a la 5 y conservó los datos.

### Buen uso
- Cuando un cliente o el contador pregunte por un documento, búscalo por su número en **Documentos**.
- Si borras un PDF de la carpeta, el registro sigue en la app; vuelve a generarlo desde su origen (la venta, la cotización o el cliente).

### Qué NO hace
- **No es factura electrónica DIAN** (lo dice cada PDF). La factura electrónica exige un proveedor tecnológico autorizado, con numeración autorizada por la DIAN y firma digital. La app ya guarda lo necesario (emisor, cliente, ítems, cantidades, precios y total) para conectarse después con ese proveedor.
- El archivo de documentos queda en cada equipo; **no se sube a la nube** en esta versión. Las ventas, clientes y productos sí se sincronizan.

---

## 2. Cuenta de cobro con trazabilidad (quién debe, cuánto y desde cuándo)

### Qué hace
Desde la **ficha del cliente** (botón **Cuenta de cobro en PDF**) o desde **Herramientas → Cartera**, la app arma un documento con:
- Saldo pendiente, **fecha desde la que debe** y **días de mora**.
- **Saldo por antigüedad:** 0 a 30, 31 a 60, 61 a 90 y más de 90 días.
- **Compras pendientes de pago,** una por una, con su fecha, valor original, lo que falta y los días.
- **Extracto completo:** cada fiado y cada abono con el saldo después de cada movimiento (trazabilidad).
- Un mensaje amable para WhatsApp con el mismo detalle.

### Cómo funciona por dentro (algoritmo FIFO)
Archivo: `lib/domain/contabilidad.dart`, función `estadoDeCuenta`.
1. Ordena los fiados y abonos del cliente por fecha.
2. Recorre la lista. Cada **fiado** entra a una fila de pendientes y sube el saldo. Cada **abono** baja el saldo y **paga primero los fiados más antiguos** (primero en entrar, primero en pagarse, como hacen los contadores).
3. Lo que queda en la fila son las compras pendientes. Para cada una calcula los días desde su fecha hasta hoy y la suma en su rango de antigüedad.

**Ejemplo (probado en `test/contabilidad_test.dart`):** fiados de $50.000 (1 de agosto), $40.000 (5 de octubre) y $20.000 (10 de noviembre), y un abono de $30.000.
El abono paga parte del fiado de agosto, que queda con $20.000 pendientes y 109 días. Resultado: saldo de $80.000, que debe desde el 1 de agosto, con $20.000 en más de 90 días, $40.000 en 31 a 60 días y $20.000 en 0 a 30 días.

### Buen uso
- Envía la cuenta de cobro antes de que el fiado pase de 30 días; la pantalla **Cartera** ordena a los clientes del que más debe en días al que menos.
- Si el cliente está al día, el PDF sale como **paz y salvo**.

---

## 3. Informes semanal, quincenal y mensual (para el dueño y el contador)

### Qué hace
**Herramientas → Informes**: eliges **Esta semana, Semana pasada, Esta quincena, Quincena anterior, Este mes o Mes anterior**, ves las cifras clave en pantalla y generas el PDF con logo y número. El PDF incluye:
1. **Indicadores:** ventas, gastos, utilidad, caja neta, número de ventas y ticket promedio, ganancia en productos, cartera y valor del inventario. Cada cifra trae su comparación con el periodo anterior.
2. **Estado de resultados simplificado:** contado, crédito, total de ventas, gastos y utilidad, frente al periodo anterior.
3. **Flujo de caja:** contado + abonos − gastos = lo que de verdad entró en efectivo.
4. **Ventas por día** (barras) y **productos más vendidos**.
5. **Gastos por concepto** con su porcentaje (los conceptos iguales se agrupan sin importar tildes ni mayúsculas).
6. **Cartera por antigüedad** y la lista de quién debe, desde cuándo y cuántos días.
7. **Inventario por reponer** y su valor al costo y a precio de venta.
8. **Libro de movimientos:** cada venta, gasto y abono con fecha, cliente, forma de pago y valor. Es lo que el contador necesita para registrar.

### Cómo funciona por dentro
- Periodos (`rangoPeriodo` en `contabilidad.dart`): la semana va de lunes a domingo; la quincena, del 1 al 15 o del 16 a fin de mes; el mes, del 1 al último día. Siempre se calcula también el periodo anterior del mismo tipo para comparar.
- Los datos salen de la base del celular (`cargarInforme` en `lib/pdf/reportes_contables.dart`). Por eso **funciona sin internet**.
- El PDF se arma por bloques: indicadores, tablas, barras y párrafos (`lib/pdf/pdf_reportes.dart`). Es de varias páginas, en tamaño carta, con encabezado, número del documento y "Página x de y".

### Buen uso
- **Cada lunes:** el informe de la semana pasada. **El día 16 y el día 1:** el de la quincena. **Cada inicio de mes:** el del mes anterior, para el contador.
- Envía el PDF al contador por WhatsApp o correo con el botón **PDF**.

### Qué NO hace
- No reemplaza la contabilidad formal: no lleva PUC, IVA ni retenciones. Es el **soporte organizado** para que el contador la haga más rápido. El PDF lo dice.
- La "utilidad" es ventas menos gastos registrados. La "ganancia en productos" (precio − costo) solo cuenta las ventas hechas con productos que tienen costo.

---

## 4. Pedido al proveedor en PDF
En **Pedir mercancía**, el botón de enviar arma el texto para WhatsApp **y** un PDF numerado (`PD-…`). El PDF trae el proveedor, los productos, las cantidades, el costo aproximado (el último costo registrado) y el total estimado. Queda archivado en **Documentos**.

---

## 5. Negocios de servicios (no solo productos)

### Qué hace
Además de **Unidad, Kilo y Libra**, un ítem del catálogo puede ser **Servicio**: corte de cabello, reparación, domicilio, asesoría, instalación…
- Se vende igual que un producto (en la caja, en cotizaciones y en comprobantes).
- **No lleva inventario:** no pide existencias ni mínimo, nunca sale como agotado ni en "por reponer", y no suma al valor del inventario.
- En los documentos sale con su precio, sin "c/u".

### Cómo funciona por dentro
- Unidad nueva `serv` (`lib/domain/codigos.dart`: `esServicio`, `precioConUnidad`). `ProductoStock.agotado` y `bajo` dan siempre falso para servicios.
- En la nube (Supabase) se amplió la regla de la columna `unidad` para aceptar `serv`. La migración `v5_unidad_servicio` ya está aplicada y también quedó en `supabase_schema.sql`.
- La venta de un servicio queda registrada igual que la de un producto, así sale en "más vendidos" y en la ganancia.

---

## 6. Registro guiado: la app se adapta al negocio

### Qué hace
La primera vez, después de aceptar el aviso de privacidad, la app **pregunta** en 5 pasos:
1. **Nombre y tipo de negocio** (tienda, droguería, agro, restaurante, peluquería, taller, servicios profesionales…).
2. **¿Qué vendes?** Productos, servicios o las dos cosas.
3. **¿Cómo trabajas?** ¿Fías? ¿Usas gramera? ¿Usas códigos de barras? ¿Le haces pedidos a proveedores? ¿Quieres avisos?
4. **Datos para los documentos:** NIT o cédula, dirección, WhatsApp, meta del mes y logo.
5. **Así quedó tu app:** un resumen de lo que se activó.

Según el tipo de negocio, la app **propone** respuestas (por ejemplo, una peluquería parte de "solo servicios"), y el dueño las cambia si quiere.

### Cómo se adapta
| Respuesta | Qué cambia |
|---|---|
| Solo servicios | La pestaña **Inventario** se llama **Servicios**; el botón dice **Servicio**; desaparecen gramera, códigos y pedidos |
| Productos y servicios | La pestaña se llama **Catálogo** y el formulario ofrece **Servicio** |
| No fía | Se esconden **Venta fiada** y **Cartera** |
| No usa gramera | El formulario no muestra **Kilo** ni **Libra** |
| No usa códigos | No aparece **Escanear código de barras** |
| No hace pedidos | No aparece **Pedir mercancía** |

Se cambia cuando quieras en el menú ⋮ → **Ajustar la app a mi negocio**.

### Cómo funciona por dentro
- `lib/domain/modo_negocio.dart`: el "modo del negocio" (qué vende y cómo trabaja), guardado en la tabla `ajustes` (`modo_oferta`, `modo_fia`…).
- `LocalDb.modo` es un `ValueNotifier`: cuando cambia, las pantallas se redibujan solas.
- **Compatibilidad:** si un celular viene de una versión anterior y no tiene estas respuestas, todo queda activado como antes. Nada se pierde; solo se muestra el registro una vez, con los datos que ya tenía cargados.
- `RegistroGate` (en `lib/ui/registro_negocio_page.dart`) se pone entre el aviso de privacidad y la app: si el negocio no está configurado, muestra el registro.

### Sobre "iniciar sesión"
La app es **primero sin internet**: se usa sin cuenta y el registro del negocio queda en el equipo. La **cuenta en la nube** (para respaldo y varios celulares) se crea después en el muñequito de arriba, con la clave robusta de siempre. Así el tendero empieza a vender en un minuto, aunque no tenga señal.

---

## 7. Avisos en el celular (notificaciones)

### Qué avisa
| Aviso | Cuándo |
|---|---|
| **Se agotó X** (o "Se agotaron N productos") | Cuando un producto llega a 0, después de una venta, un ajuste o algo que llegó de otro celular |
| **Se está acabando X** | Cuando baja al mínimo que pusiste |
| **N clientes deben hace más de 30 días** | Una vez al día (desde las 8 a. m.), con el total vencido |
| **¡Cumpliste la meta del mes!** | Una vez por mes, al pasar la meta |
| **Hay datos que no se pudieron subir** | Si aparece un error de sincronización nuevo |

### Cómo funciona por dentro
- Paquete `flutter_local_notifications` (licencia BSD-3, gratis). Son **notificaciones locales**: el celular se las manda a sí mismo, **sin servidor y sin internet**.
- `lib/ui/notificaciones.dart` escucha los cambios de la base. Después de 2 segundos sin cambios (para agrupar), revisa la situación.
- Las reglas están en `lib/domain/avisos.dart` (`revisarAvisos`), sin pantallas, para poder probarlas. **Cada aviso sale una sola vez por situación:** la app recuerda qué productos ya avisó. Si el producto se vuelve a surtir y se agota otra vez, avisa de nuevo.
- En Android 13 o más, el celular pide permiso la primera vez. Se activan o desactivan en **Ajustar la app a mi negocio**.

### Qué NO hace
- No avisa con la app cerrada del todo: revisa cuando la app está abierta o en segundo plano. Para eso harían falta tareas en segundo plano o un servidor de notificaciones, que se dejaron por fuera para no gastar batería ni datos.

---

## 8. Pruebas que lo respaldan
`flutter test` corre **88 pruebas**, todas en verde. Las nuevas son:
- `test/contabilidad_test.dart`: FIFO de abonos, días de mora, rangos de antigüedad, periodos (semana, quincena y mes) y numeración única con reimpresión.
- `test/informes_test.dart`: gastos por concepto, variación frente al periodo anterior, y el informe y la cuenta de cobro generados en PDF con datos reales.
- `test/avisos_test.dart`: avisos que no se repiten, meta del mes, cartera una vez al día, servicios sin inventario y el modo del negocio.

**Probado en este PC:** el análisis de código sin errores, las 88 pruebas, el PDF del informe y de la cuenta de cobro revisados a ojo, las capturas de las pantallas nuevas, el APK compilado, y la app de Windows abierta con su base actualizada a la versión 5.
**Falta probar en el celular real:** los avisos (permiso y sonido), los PDF compartidos por WhatsApp y el registro guiado tocado con el dedo.

## 9. Archivos nuevos
| Archivo | Qué hace |
|---|---|
| `lib/domain/contabilidad.dart` | Cuenta de cobro (FIFO y antigüedad), periodos, gastos por concepto, variación |
| `lib/domain/avisos.dart` | Reglas de los avisos (qué avisar y cuándo) |
| `lib/domain/modo_negocio.dart` | Cómo trabaja el negocio y las sugerencias por tipo |
| `lib/pdf/archivo.dart` | Guardar, leer, imprimir y compartir los PDF archivados |
| `lib/pdf/pdf_reportes.dart` | PDF de varias páginas por bloques (informes y cuenta de cobro) |
| `lib/pdf/reportes_contables.dart` | Arma el informe y la cuenta de cobro con los datos de la base |
| `lib/ui/oficina_page.dart` | Pantallas de Informes, Cartera y Documentos emitidos |
| `lib/ui/registro_negocio_page.dart` | Registro guiado en 5 pasos |
| `lib/ui/notificaciones.dart` | Avisos en el celular |
