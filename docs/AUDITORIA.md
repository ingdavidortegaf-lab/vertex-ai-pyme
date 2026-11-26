# Auditoría técnica – VERTEX AI Pyme (prototipo)

**Estado (16 nov. 2026), con Flutter 3.50.0 / Dart 3.14:**
- `flutter analyze`: **0 errores, 0 advertencias**. Quedan 13 avisos
  informativos: Flutter 3.47+ marca como obsoleto `package:flutter/material.dart`
  a favor del paquete `material_ui`. Funciona igual; la migración queda para
  después del evento.
- `flutter test`: **55 de 55 pruebas pasan**.
- `flutter build apk --release --obfuscate --split-debug-info=build\debug-info`:
  **compila** (64,1 MB), tanto en modo solo local como con la nube
  (`--dart-define-from-file=dart_defines.json`, archivo ignorado por git).
- Celular real (Xiaomi 14T, HyperOS): el APK se instala y **la app abre bien**
  (16 nov. 2026), así que la base cifrada con SQLCipher y la clave en el Keystore
  funcionan en el dispositivo. **Flujo en modo avión verificado** por el
  usuario: clientes, venta, gasto y venta fiada, tablero actualizado,
  asistente («¿cuánto vendí esta semana?», «¿quién me debe?»), mensaje de
  WhatsApp y datos que siguen ahí al reabrir la app.
- **Sincronización con Supabase verificada** en el celular real (16 nov.
  2026): el APK con nube se instaló encima del anterior sin perder datos; al
  quitar el modo avión e iniciar sesión subieron los 4 clientes y los 7
  movimientos (3 ventas de contado, 2 fiadas, 2 gastos) registrados sin
  señal. En el servidor: un envío por registro (11 POST con respuesta 201,
  ningún rechazo), 0 duplicados, todo en la empresa del usuario y ninguna
  venta apunta a un cliente inexistente. Los dos intentos con clave errada
  devolvieron 400 y la app los contó como fallidos.
- El emulador no arranca en este PC porque falta el controlador de
  virtualización; se prueba en el celular real.

## 1. Segunda revisión: cambios hechos
| # | Problema | Riesgo | Solución |
|---|----------|--------|----------|
| 1 | No existían cobros pendientes; el anteproyecto promete «¿quién me debe?» | Promesa del pitch sin respaldo | Ventas **fiadas** + **abonos**; saldo por cliente; «Por cobrar» en el tablero y en el asistente |
| 2 | Conflictos por registro, no **por campo** como dice el anteproyecto | Se perdía un cambio cuando dos celulares editaban campos distintos | Marca de tiempo por campo (nombre, teléfono, borrado) en el celular y en el trigger `merge_cliente` del servidor |
| 3 | La cola borraba los registros tras 5 rechazos del servidor | Pérdida de datos | Estado `error`, **nunca se borra**; se reintenta al abrir la app y con el botón de la barra |
| 4 | Reintentos sin espera | Golpeaba al servidor y gastaba batería | Espera creciente: 15 s, 30 s, 1 min… tope 30 min |
| 5 | No había estado por registro | No se veía qué faltaba subir | Columna `sync` (pendiente / enviado / error) e icono en cada fila |
| 6 | Un cambio hecho durante el envío esperaba al siguiente ciclo (45 s) | Barra desactualizada en la demo | La sincronización se repite al terminar si llegó otro cambio |
| 7 | Solo se subían datos; no se bajaba lo de otros celulares | Multi-dispositivo incompleto | Descarga incremental por `recibido_at` y unión por campo |
| 8 | RLS por usuario, no **por empresa** | No cumplía «datos separados por empresa» | Tablas `empresas` y `miembros`, función `mi_empresa()`, `empresa_id` con RLS; la empresa se crea al crear el usuario |
| 9 | Las ventas se podían editar en el servidor | Rompía la regla de «solo se agregan» | Sin políticas UPDATE ni DELETE en `ventas` |
| 10 | El mensaje de error del servidor se guardaba en la cola | Podía guardar datos personales en texto plano dentro de logs | Solo se guarda el código técnico (máx. 40 caracteres) |
| 11 | Mensaje de WhatsApp fijo, sin IA | Promesa del anteproyecto | Mensaje sugerido por IA con marcador `{nombre}` (el nombre no sale del celular) y plantilla local sin señal |
| 12 | Asistente sin conexión: solo resumen del mes | No respondía «¿cuánto vendí esta semana?» ni «¿quién me debe?» | Motor de reglas local: ventas de hoy, semana y mes, quién debe, mejores clientes, gastos y mensaje de cobro |
| 13 | Preguntas a la IA sin señal se perdían | Incumplía «lo que necesita internet queda en cola» | Tabla `preguntas_ia`; se responden al volver la señal |
| 14 | La pregunta libre podía llevar nombres o teléfonos a la IA | Ley 1581 (minimización) | `anonimizarPregunta`: quita nombres de clientes, números largos y correos (en la app y otra vez en el servidor) |
| 15 | Sin cierre de sesión por inactividad ni bloqueo por intentos fallidos | OWASP M3 | Cierre tras 30 min sin uso; bloqueo de 5 min tras 5 claves erradas |
| 16 | Sin aviso de privacidad accesible ni manera de revocar o borrar | Ley 1581 | Menú «Privacidad y datos»: aviso, correo de derechos, revocar autorización, borrar datos del celular |
| 17 | El aviso decía «Responsable: VERTEX TECH» | Contradecía el anteproyecto (la MiPyme es la responsable) | Texto corregido: MiPyme responsable, plataforma encargada |
| 18 | Celular sin validar | wa.me fallaba con números mal escritos | Validación de celular con su país (selector con 28 países; Colombia: 10 dígitos que empiezan por 3) y número completo con indicativo |
| 19 | Fechas ISO con distinta precisión | Comparaciones de texto erróneas en el límite de un milisegundo | `isoUtc()` normaliza todo a milisegundos UTC |
| 20 | Faltaban índices | El tablero se hace lento con miles de movimientos | Índices por fecha, cliente y estado de la cola (local) y por empresa (servidor) |
| 21 | El tablero no se refrescaba solo | La demo exigía cambiar de pestaña | Las pantallas escuchan `LocalDb.cambios` |
| 22 | Fallo del almacén seguro = app cerrada sin explicación | Mala experiencia | Pantalla de error en español |
| 23 | http:// se aceptaba como URL de Supabase | Tráfico sin TLS | Solo se activa la nube con `https://` |
| 24 | Copias de seguridad de Android 12+ por `dataExtractionRules` | La base podía salir del equipo | `data_extraction_rules.xml` excluye todo |
| 25 | `mi_empresa()` (SECURITY DEFINER) se podía llamar por `/rest/v1/rpc` | Superficie de API innecesaria (linter de Supabase) | Movida al esquema `privado`, que la API no expone; 0 avisos de seguridad |
| 26 | Políticas RLS evaluaban `auth.uid()` por cada fila | Lentitud con muchos datos | `(select auth.uid())` y `(select privado.mi_empresa())`: una vez por consulta |
| 27 | La Edge Function confiaba solo en el gateway | Si se desactivaba `verify_jwt`, cualquiera gastaría la cuota de IA | La función valida el token contra Supabase Auth antes de llamar al modelo (probado: sin sesión responde 401) |
| 29 | No había inventario | El tendero no sabía qué se agotaba ni cuánto ganaba por producto | Productos (unión por campo) + movimientos de inventario que solo se agregan: el stock es su suma, así dos celulares sin señal no se pisan. Venta con productos en una transacción. Tablas `productos` e `inventario` en Supabase con RLS por empresa (verificado: RLS activo, anon sin acceso) |
| 30 | El tablero solo mostraba el mes | Sin comparación ni tendencia | Reportes por periodo (hoy, 7 días, mes, mes anterior) con variación frente al periodo anterior, barras de ventas y gastos por día o semana, contado frente a fiado y lo más vendido. Colores verificados para daltonismo; gastos con rayado además del color |
| 31 | El asistente no conocía el negocio | Respuestas genéricas | «Mi negocio» (nombre, tipo, meta del mes) y nuevas preguntas sin señal: qué se está agotando, producto más vendido, cómo voy con la meta, ganancia en productos |
| 32 | El aviso no dejaba claro quién es la encargada | La Ley 1581 distingue responsable y encargado | Aviso y política: la MiPyme es responsable y VERTEX TECH encargada; `docs/POLITICA_TRATAMIENTO_DATOS.md` y `docs/AVISO_PRIVACIDAD_Y_AUTORIZACION.md` (borradores para revisión jurídica) |
| 33 | Clave de 8 caracteres sin más reglas | Bases 4.4.3: política de contraseñas robustas | Mínimo 8 caracteres con letras y números, sin espacios al inicio o final |
| 34 | El tendero hacía a mano comprobantes, cotizaciones y pedidos | Pertinencia (procesos de la cadena de valor) | Comprobante de venta, cotizaciones que se vuelven venta, pedido sugerido al proveedor con ingreso de mercancía en bloque y promociones, todo por WhatsApp. Base local v3 (cotizaciones y proveedores, solo en el celular). El comprobante no es factura electrónica DIAN: trae los datos para conectarlo con un proveedor autorizado |
| 35 | Sin manual de usuario | Entregable 9.2 (4) | `docs/MANUAL_USUARIO.md` |
| 36 | Sin código de barras ni venta por peso | Tiendas que venden a granel (queso, carne, granos) y con lector | Código de barras y unidad (und/kg/lb) por producto, sincronizados por campo (base local v4 y columnas en Supabase); escáner con cámara (mobile_scanner, BSD-3) o lector USB/teclado; etiquetas de gramera EAN-13 (20–29 + PLU + gramos) con dígito de control. La gramera no se conecta por cable: se usa su etiqueta o se escribe el peso |
| 37 | Comprobantes solo como texto | El tendero necesita imprimir y entregar | PDF con logo del negocio en tirilla de 80 mm o carta (pdf y printing, Apache-2.0), impresión con el diálogo del sistema y compartir PDF. Sigue sin ser factura electrónica |
| 38 | Versión para PC | Pedida por el usuario | Hecha: Windows con SQLite (sqflite_common_ffi) en %APPDATA%; compila y abre. La base del PC no va cifrada (pendiente) |
| 39 | Documentos sin número consecutivo ni archivo | Trazabilidad para el contador y el cliente | Tabla `documentos` (base local v5): número único TIPO-EQUIPO-000001 asignado en transacción, reimpresión con el mismo número, PDF guardado en VERTEX_documentos y pantalla «Documentos» |
| 40 | Sin cuenta de cobro ni antigüedad de la deuda | Cobrar con soporte: qué, desde cuándo | Cuenta de cobro en PDF con extracto, abonos aplicados FIFO, días de mora y rangos 0-30/31-60/61-90/+90; pantalla «Cartera» |
| 41 | Reportes solo en pantalla | El contador necesita un soporte | Informes semanal, quincenal y mensual en PDF: resultados vs. periodo anterior, flujo de caja, gastos por concepto, cartera, inventario y libro de movimientos |
| 42 | Solo negocios de productos | MiPymes de servicios quedaban por fuera | Unidad `serv` sin inventario (local y Supabase, migración v5_unidad_servicio) |
| 43 | La app era igual para todos | Botones que no aplican confunden | Registro guiado en 5 pasos; la app esconde lo que el negocio no usa (fiado, gramera, códigos, pedidos) y renombra el catálogo |
| 45 | No se sabía cómo se pagó | El efectivo no cuadra y el contador no puede conciliar | Medio de pago por movimiento (efectivo, Nequi, Daviplata, Bancolombia, Bre-B, tarjetas) y pago dividido; base local v6 y columna `pagos` en Supabase con validación en el servidor (`privado.pagos_validos`); cierre de caja e informe por medio |
| 46 | Con muchas tiendas la nube recibía una consulta cada 30 s por celular aunque no hubiera cambios | Saturación y costo | Descarga adaptativa: 30 s a 5 min según haya o no cambios; lo guardado se sube de inmediato. Prueba `sync_adaptativo_test.dart` |
| 47 | Pasarela de pago | Cobro con link o QR | **No implementada (siguiente fase):** requiere cuenta de comercio por tienda (Wompi) y llaves reales; se dejó el diseño (Edge Function + webhook) y los costos en `docs/PAGOS_Y_MODELO_DE_NEGOCIO.md`. Hoy: datos de pago del negocio en los documentos |
| 44 | Sin avisos | El tendero se entera tarde de un agotado | Notificaciones locales (flutter_local_notifications, BSD-3) sin servidor: agotado, por acabarse, cartera vencida, meta y errores de envío; cada aviso una sola vez. Android compila con compileSdk 37 (el mínimo sigue en Android 12) |
| 28 | Las cuentas solo se creaban desde el panel | El negocio no podía empezar solo | Pantalla «Tu cuenta»: entrar, crear cuenta (clave ≥ 8), perfil, cerrar sesión avisando lo pendiente; errores en español; bloqueo tras 5 intentos |

## 2. Hallazgos de la primera revisión (se mantienen)
Inicialización de fechas en español, mes en hora local de Colombia, borrado
lógico, validación de montos colombianos, reintento por cambio de red,
`dispose` de controladores, consentimiento inicial, IA solo en el servidor,
`not null` en las columnas de dueño.

## 3. Cumplimiento frente a las bases
| Requisito | Estado |
|-----------|--------|
| Multiplataforma (Flutter), Android 12+ / iOS 16+ | Código único; minSdk 31 e iOS 16.0 los aplica el script |
| Modo sin conexión + cola | SQLCipher + cola transaccional, idempotente, con espera creciente y estados |
| Conflictos | Ventas solo se agregan (en la app y en el servidor); clientes por campo |
| Ciberseguridad | HTTPS, Supabase Auth, RLS por empresa, inactividad, bloqueo, claves por `--dart-define`, IA en el servidor, sin datos personales en logs |
| Ley 1581/2012 | Consentimiento obligatorio, aviso visible, canal de derechos, revocar y borrar, minimización hacia la IA |
| Cero licencias de pago | Ver `docs/LICENCIAS.md` (se genera con `scripts/generar_licencias.ps1`) |

## 4. OWASP Mobile Top 10 (2024)
| Riesgo | Mitigación |
|--------|------------|
| M1 Uso indebido de credenciales | Sin secretos en la app; anon key + RLS; clave de IA solo en el servidor |
| M2 Cadena de suministro | Paquetes populares y verificados; revisar `flutter pub outdated` antes de entregar |
| M3 Autenticación/autorización | Supabase Auth, RLS por empresa, cierre por inactividad, bloqueo por intentos |
| M4 Validación de entradas | Formularios + `check` en la base local y en el servidor; la Edge Function sanea y limita el tamaño |
| M5 Comunicación insegura | Solo HTTPS (TLS 1.2+ de Supabase); se rechaza http:// |
| M6 Privacidad | Minimización, consentimiento, IA sin datos personales |
| M7 Protección del binario | Release con `--obfuscate --split-debug-info` |
| M8 Mala configuración | `allowBackup=false`, `dataExtractionRules`, sin acceso anónimo a tablas |
| M9 Almacenamiento inseguro | SQLCipher con clave aleatoria de 256 bits en Keystore/Keychain |
| M10 Criptografía | `Random.secure`; cifrado de SQLCipher (AES-256) |

## 5. Pruebas automáticas escritas
- `formato_test`: montos, celulares, texto, anonimización.
- `asistente_local_test`: detección de intención y respuestas sin señal.
- `conflictos_test`: unión por campo, cambios tardíos, borrado, espera de reintento.
- `local_db_test`: tablero (ventas, gastos, fiados, abonos, semana, hoy), validaciones y cola.
- `sync_test`: modo avión, envío único, caída de red a mitad, reenvío idempotente,
  rechazo con espera y apartado sin pérdida, sesión vencida, descarga desde otro
  celular, preguntas a la IA en cola.

## 6. Pendiente / riesgos conocidos
- Probado en un solo celular (Xiaomi 14T, Android). Sin probar todavía:
  la sincronización entre dos celulares de la misma empresa, la respuesta
  real del modelo de IA (la Edge Function está desplegada pero falta el
  secreto `GEMINI_API_KEY`), la creación de cuenta desde la app (depende de
  la confirmación por correo de Supabase) e iOS. Las pruebas automáticas
  usan SQLite sin cifrar sobre Windows.
- Rediseño visual (16 nov.): revisado con capturas generadas en Windows
  (`tool/capturas_test.dart`) en claro y oscuro; falta verlo en el celular.
- Se cambió `anonKey` por `publishableKey` en `Supabase.initialize`
  (supabase_flutter 2.18 marcó `anonKey` como obsoleto); se le pasa la misma clave anon.
- Roles: existe la columna `rol` (admin/vendedor) pero el prototipo usa solo admin.
- La revocación y la supresión en la nube se atienden por correo (canal de derechos).
- Nombre del modelo gratuito de IA: confirmarlo al desplegar (`GEMINI_MODEL`).
- Si la red del evento es mala: demo en modo avión (es el punto fuerte) y video de respaldo.
- Bloque del 18 nov. (medios de pago, cierre de caja, descarga adaptativa): 93 pruebas en verde, migración v6 aplicada y probada en Supabase con casos válidos e inválidos, capturas revisadas. Falta probarlo en el celular real.
- Bloque del 17 nov. (documentos, cobro, informes, servicios, registro guiado, avisos): 88 pruebas en verde, PDF revisados a ojo, capturas en PC, APK y Windows compilados, base del PC migrada a v5. Falta en el celular: permiso y sonido de los avisos, compartir PDF por WhatsApp, registro guiado al tacto. Los avisos no salen con la app cerrada del todo. El archivo de documentos no se sincroniza a la nube.
- Bloque del 18 nov. (tarde): proveedores con pago parcial y cuentas por pagar (esquema local v7), promociones con foto, video, imagen para el estado y redactor con IA (local y en la nube; Edge Function `asistente` versión 2 con modo `promocion`), seguimiento de clientes por WhatsApp con autorización, 22 tipos de negocio, logo nuevo. 106 pruebas en verde. La IA en la nube solo responde si está el secreto `GEMINI_API_KEY`. Compartir archivos depende de la hoja de compartir del sistema (en Windows solo el texto). Falta probarlo todo en el celular real y en un iPhone.
- Bloque del 18 nov. (noche, 2): clientes con cédula o NIT (dígito de verificación DIAN) y correo, sincronizados por bloque con su marca de tiempo (columnas y trigger aplicados en Supabase); proveedores y terceros (servicios, arrendador, empleado); gasto a nombre de un tercero; pagos fijos con aviso; ejemplos según el tipo de negocio; nuevo cliente desde la venta y montos rápidos. El tipo de negocio se carga al abrir la app para los ejemplos de las casillas (el modo ya se cargaba en la pantalla de inicio; una nota anterior que decía lo contrario era un error de revisión). Esquema local v8; 128 pruebas.
- Auditoría del 18 nov. (noche): (1) **en la web no se podía subir el logo**: se guardaba como archivo y el navegador no lo permite; ahora el logo se guarda dentro de la base (texto base64) y funciona en web, celular y PC; probado en el navegador. (2) **Celulares de otros países**: selector de país (bandera e indicativo; en Windows, código del país) en clientes, proveedores y el negocio; la nube solo aceptaba `57` + 10 dígitos y se amplió con una migración a 8-15 dígitos (0 filas afectadas). (3) **Logo nuevo de VERTEX TECH** en ícono y app. 112 pruebas en verde. Pendiente: probar en un iPhone real.
- Bloque del 22 al 24 nov. (producto comercial de VERTEX TECH): se quitaron las referencias a la presentación de noviembre; textos legales con VERTEX TECH como encargada y marca de borrador para revisión de un abogado; GitHub Actions (analyze, test y pruebas SQL); migraciones versionadas; `local_db.dart` y `herramientas_page.dart` divididos por módulo; roles con invitación por código y RLS por rol; perfiles con PIN; turnos, anulaciones y descuentos con tope; factura electrónica con cola sin internet, CUFE y QR, sin proveedor real. Esquema local v11; 226 pruebas en verde. El 25 nov. GitHub Actions pasó completo: analyze, 226 pruebas y las pruebas SQL (aislamiento, roles y caja) sobre Supabase local con todas las migraciones. **No probado aún:** las cuatro migraciones nuevas en producción (no aplicadas) y todo esto en un celular real. Detalle en `docs/EQUIPO_CAJA_Y_FACTURACION.md`.
- 25 nov. (computador y comercio): menú lateral y pantallas anchas en el computador; caja rápida con lector de código de barras, cambio, precio por mayor y atajos (F2, F4, F6); unidades por metro, litro, galón, caja y paquete; precio por mayor; vencimientos con aviso; importar productos pegados desde Excel; el rol «despachador» se muestra como «Vendedor (cajero)». Esquema local v12 y migración `20261125150000_mayoreo_vencimiento_unidades` con su prueba SQL. 247 pruebas en verde. **No probado aún:** las cinco migraciones nuevas en producción (no aplicadas), un lector de código de barras físico, la versión de Windows con estos cambios en un PC real y varias cajas a la vez. Detalle en `docs/COMPUTADOR_Y_COMERCIO.md`.
- 25 nov. (reportes y devoluciones): exportar a Excel (movimientos, cartera, inventario y kárdex, con protección contra fórmulas); kárdex por producto; ventas por vendedor; ganancia por producto; buscador global Ctrl+K; devolver productos de una venta (anulación más venta nueva con lo que queda, sin cambiar el servidor). Pruebas en verde. Sin probar en un PC real: abrir el CSV en Excel.
- 25 nov. (precios y Windows): etiquetas de precio con código de barras (EAN-13 o Code 128) y lista de precios en PDF sin costos. La versión de Windows compila (`flutter build windows --release`); no se ha abierto en un PC real.
