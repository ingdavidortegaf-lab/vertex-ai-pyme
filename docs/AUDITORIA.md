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
| 18 | Celular sin validar | wa.me fallaba con números mal escritos | Validación de celular colombiano (10 dígitos que empiezan por 3) y formato `57…` |
| 19 | Fechas ISO con distinta precisión | Comparaciones de texto erróneas en el límite de un milisegundo | `isoUtc()` normaliza todo a milisegundos UTC |
| 20 | Faltaban índices | El tablero se hace lento con miles de movimientos | Índices por fecha, cliente y estado de la cola (local) y por empresa (servidor) |
| 21 | El tablero no se refrescaba solo | La demo exigía cambiar de pestaña | Las pantallas escuchan `LocalDb.cambios` |
| 22 | Fallo del almacén seguro = app cerrada sin explicación | Mala experiencia | Pantalla de error en español |
| 23 | http:// se aceptaba como URL de Supabase | Tráfico sin TLS | Solo se activa la nube con `https://` |
| 24 | Copias de seguridad de Android 12+ por `dataExtractionRules` | La base podía salir del equipo | `data_extraction_rules.xml` excluye todo |
| 25 | `mi_empresa()` (SECURITY DEFINER) se podía llamar por `/rest/v1/rpc` | Superficie de API innecesaria (linter de Supabase) | Movida al esquema `privado`, que la API no expone; 0 avisos de seguridad |
| 26 | Políticas RLS evaluaban `auth.uid()` por cada fila | Lentitud con muchos datos | `(select auth.uid())` y `(select privado.mi_empresa())`: una vez por consulta |

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
  la sincronización entre dos celulares de la misma empresa, el asistente
  con IA en el servidor (Edge Function sin desplegar) e iOS. Las pruebas
  automáticas usan SQLite sin cifrar sobre Windows.
- Se cambió `anonKey` por `publishableKey` en `Supabase.initialize`
  (supabase_flutter 2.18 marcó `anonKey` como obsoleto); se le pasa la misma clave anon.
- Roles: existe la columna `rol` (admin/vendedor) pero el prototipo usa solo admin.
- La revocación y la supresión en la nube se atienden por correo (canal de derechos).
- Nombre del modelo gratuito de IA: confirmarlo al desplegar (`GEMINI_MODEL`).
- Si la red del evento es mala: demo en modo avión (es el punto fuerte) y video de respaldo.
