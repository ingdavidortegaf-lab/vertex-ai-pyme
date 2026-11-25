# Equipo, caja y factura electrónica

Este documento explica tres partes de la app: quién puede hacer qué, la caja (turnos, anulaciones y descuentos) y la factura electrónica. También dice qué está probado y qué falta.

Regla de fondo: **la app oculta y el servidor impide.** Lo que un rol no puede hacer no aparece en pantalla. Si alguien se lo salta, la base de datos de Supabase (RLS y triggers) lo rechaza.

## 1. Roles

Cada cuenta tiene un rol en su negocio (tabla `miembros`). El código está en `lib/domain/roles.dart`.

| Rol | Qué hace |
|---|---|
| Dueño | Todo, incluido invitar empleados, cambiar sus roles y fijar el tope de descuento. Uno por negocio. |
| Administrador | Todo el negocio, menos manejar el equipo. Puede anular. |
| Contador | Consulta ventas, gastos, costos, informes y turnos. No registra nada. |
| Despachador | Vende de contado y registra entradas de mercancía. Da descuentos hasta el tope. Fía y recibe abonos solo si el dueño lo activa. No ve costos, gastos ni informes. |
| Bodeguero | Entradas y ajustes de inventario. No ve costos ni ventas. |

- **Invitar:** el dueño crea un código de 8 letras y números, de un solo uso, que vence en 7 días (`crear_invitacion`). El empleado lo escribe en *Menú ⋮ › Equipo › «Tengo un código»* (`unirse_con_codigo`).
- **Unirse:** no se puede si el celular o la cuenta tienen datos de un negocio propio. Así nada se mezcla ni se pierde.
- **Quitar a alguien del equipo:** su cuenta queda con un negocio propio vacío. En su celular se borra lo del negocio anterior. Lo que tenía sin subir **no** se sube al negocio nuevo, porque el rol se revisa antes de enviar la cola.
- **Despachador y bodeguero** bajan productos e inventario desde vistas sin costos (`productos_operativos`, `inventario_operativo`). Cuando ellos registran una entrada, el costo lo pone el servidor.

## 2. Perfiles con PIN (celular compartido)

Sirven para cuando varias personas usan el mismo celular con la misma cuenta.

- **Cómo funciona:** cada persona tiene un perfil con nombre, rol y PIN de 4 a 6 números. El PIN no puede ser de números repetidos ni seguidos.
- **Cómo se guarda el PIN:** como hash PBKDF2-HMAC-SHA256 con sal de 16 bytes y 20 000 iteraciones. Las iteraciones se guardan junto al hash, para poder subirlas en el futuro sin invalidar los PIN existentes. El PIN nunca se guarda en claro.
- **Intentos fallidos:** tras 5 PIN equivocados hay que esperar 30 segundos.
- **Primer perfil:** es el de quien maneja el celular, con el rol de la cuenta. Si el dueño olvida su PIN, entra confirmando la clave de su cuenta (necesita internet).
- **Permiso efectivo:** es el de la cuenta **y** el del perfil. Un perfil nunca puede más que la cuenta.
- **Autoría:** cada venta, gasto o abono guarda el nombre de quien atendía (`ventas.perfil`).
- **Inactividad:** se termina el turno de quien atiende y el siguiente debe decir quién es.
- **Límite, dicho con claridad:** el PIN oculta pantallas y deja el nombre en cada venta, pero **no reemplaza la cuenta**. El servidor decide según el rol de la cuenta. Por ejemplo: con la cuenta del dueño, un despachador que atiende con su perfil podría, saltándose la app, hacer lo que el servidor le permite al dueño.

## 3. Caja

### Anulaciones

Las ventas e inventario **solo se agregan**. Anular es agregar un movimiento nuevo de tipo `anulacion` que apunta al original (`anula`):

- Va por el mismo valor, el mismo cliente y los mismos medios de pago.
- Lo vendido vuelve al inventario con un movimiento `anulacion`.
- Un movimiento se anula una sola vez, y una anulación no se anula.
- El servidor pone el tipo anulado (`anula_tipo`). No se le cree al celular.

Quién puede anular:

- Solo dueño o administrador. En el servidor, la política de inserción y el trigger `privado.validar_venta`.
- Si atiende un perfil sin permiso en una cuenta que sí lo tiene, un dueño o administrador del celular autoriza con su PIN. Queda escrito en `autoriza`.
- Una venta con factura electrónica no se anula así. Haría falta una nota crédito, que no está hecha.

Cómo cuenta en los informes:

- La anulación cuenta **en su fecha**: resta con el tipo del original. Los informes suman sobre la vista local `ventas_netas`.
- Ejemplo: una venta del jueves anulada el viernes deja el jueves igual y el viernes en negativo.
- La cartera (cuentas de cobro) no muestra ni lo anulado ni la anulación.

### Descuentos

- **Monto:** el descuento va en pesos por venta. `monto` es lo cobrado y `descuento` lo descontado.
- **Ganancia:** el descuento se reparte en el precio de cada producto, para que la ganancia por producto lo refleje.
- **Tope:** lo fija el dueño, en porcentaje del total. Aplica a todos menos al dueño; con 0, nadie más descuenta.
- **Quién lo hace cumplir:** el servidor (`validar_venta`), con un peso de tolerancia por redondeo.

### Turnos

- **Abrir:** se abre con la base de efectivo del cajón.
- **Efectivo esperado:** base + efectivo que entró − efectivo que salió, con las anulaciones restando. Lo que se pagó por Nequi, tarjeta u otros se muestra aparte, porque no va al cajón.
- **Cerrar:** se cierra contando, y la app muestra «Sobran», «Faltan» o «Cuadra exacto».
- **En la nube:** el turno se sube completo al cerrarlo (tabla `turnos`, sin UPDATE ni DELETE). Cada empleado ve los suyos; dueño, administrador y contador ven todos en *Herramientas › Turnos de caja*.

## 4. Factura electrónica

**No hay proveedor tecnológico real conectado ni se inventan reglas de la DIAN.**

- **Interfaz:** `ProveedorFacturacion` (`lib/domain/facturacion.dart`), con `emitir` y `consultar`. La app usa `SinProveedor`. Para conectar un proveedor autorizado se implementa la interfaz y se asigna a `SyncService.instance.facturador`. Sus claves irían por `--dart-define` o en el servidor, nunca en el código.
- **Datos del emisor:** razón social, NIT, DV, dirección, municipio, correo y la resolución (número, prefijo, desde, hasta y vigencia). Los escribe el dueño tal como están en su RUT y su resolución. Ver *Herramientas › Factura electrónica*.
- **IVA:** es un porcentaje por producto que escribe el dueño; −1 significa «sin definir», no hay tarifas precargadas. Si una venta no tiene productos del inventario, la app pregunta su IVA. El precio registrado se toma como precio con IVA incluido; la base y el IVA se separan de él.
- **Estados:** `pendiente` (en la cola del celular), `enviado` (esperando a la DIAN), `aceptado` (con CUFE y QR) y `rechazado` (con el motivo, se puede reintentar con el mismo número).
- **Cola sin internet:** sin internet o sin proveedor, la factura espera. La sincronización la envía y luego consulta hasta que llega el CUFE. Si llega «aceptada» sin CUFE, no cuenta y se sigue consultando.
- **Numeración:** consecutiva dentro del rango de la resolución. No pasa de «hasta» ni de la fecha de vigencia. Solo se puede quitar de la cola la **última** pendiente, para no dejar huecos.
- **PDF y WhatsApp:** solo una factura **aceptada con CUFE** sale como «Factura electrónica de venta», con su CUFE y el QR que entregó el proveedor. Todo lo demás conserva «No es factura electrónica DIAN».

**Preguntas abiertas.** Las debe resolver el dueño con su contador o con el proveedor; no se supusieron:

- Cómo facturar a un consumidor final sin documento. Hoy se exige un cliente con documento.
- Qué hacer con un número de una factura rechazada.
- La nota crédito para anular una venta facturada.
- El formato exacto que pida el proveedor que se contrate.

## 5. Servidor (supabase/migrations)

| Migración | Qué hace |
|---|---|
| `20261122150000_roles_e_invitaciones` | Roles, invitaciones de un solo uso, RLS por rol, vistas sin costos, `mi_contexto`, `equipo`, `cambiar_rol`, `quitar_miembro`, `definir_despachador_fia` |
| `20261122160000_perfil_en_ventas` | Columna `ventas.perfil` (hasta 40 caracteres) |
| `20261122170000_caja_anulaciones_descuentos_turnos` | Anulaciones, descuentos con tope, tabla `turnos`, `definir_descuento_maximo`; el despachador no ve anulaciones de gastos |
| `20261122180000_iva_por_producto` | `productos.iva`, unido por campo (`merge_producto`), y la vista operativa con IVA |

**Estas cuatro migraciones no se han aplicado en producción.** Deben aplicarse antes de publicar una versión de la app que use estas funciones: si no, el servidor rechaza las columnas nuevas y esos registros quedan en la cola como error, sin perderse.

## 6. Pruebas

- **App (`flutter test`):** roles, perfiles y PIN (con el vector del RFC 7914), equipo con un servidor falso que sigue las mismas reglas, caja, facturación con un proveedor de prueba que solo existe en `test/`, pantallas, PDF y migraciones locales v8→v9→v10→v11.
- **Servidor (`supabase/tests/*.sql`):** aislamiento entre empresas (incluye turnos y anular desde otra empresa), roles y permisos, y caja. Corren en GitHub Actions contra una base local creada con las migraciones. **Aún no han corrido:** el envío a GitHub está detenido hasta que la cuenta tenga el permiso `workflow`. En este PC solo se revisó su sintaxis con `pglast`.
