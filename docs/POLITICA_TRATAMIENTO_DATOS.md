# Política de Tratamiento de Datos Personales — VERTEX AI Pyme

> **Texto que la app muestra sin internet** (enlace «Política de Tratamiento de Datos Personales» de la casilla de autorización; código en `lib/domain/legal.dart`). Sigue la estructura del artículo 13 del Decreto 1377 de 2013 (compilado en el Decreto 1074 de 2015, Título 2, Capítulo 25). Los campos entre corchetes los completa cada MiPyme usuaria.

## 1. Roles
| Rol | Quién | Qué hace |
|---|---|---|
| Responsable del tratamiento | Cada MiPyme usuaria de la app: [razón social, NIT, dirección, correo y teléfono] | Decide qué datos de sus clientes registra y para qué; obtiene su autorización |
| Encargada del tratamiento | VERTEX TECH, desarrolladora y operadora de la plataforma | Aloja y procesa los datos por cuenta de la MiPyme, solo para prestar el servicio; no los usa para fines propios |

## 2. Datos que se tratan
- **De los clientes de la MiPyme:** nombre, celular y, si el cliente los da, tipo y número de documento (cédula o NIT), correo y municipio; sus compras, abonos, saldos y la fecha y el medio en que autorizó.
- **De los proveedores y terceros:** nombre, celular, documento y correo si se registran, pedidos, saldos por pagar, abonos y pagos fijos.
- **De la MiPyme:** ventas, gastos, abonos, saldos por cobrar, productos e inventario, cotizaciones y los datos que el negocio pone en sus comprobantes (nombre, NIT o cédula, dirección, WhatsApp).
- **Del usuario de la app:** correo electrónico para iniciar sesión. La contraseña nunca se guarda en texto plano (hash con sal en Supabase Auth).
- **No se tratan** datos sensibles ni datos de niños, niñas o adolescentes.

## 3. Finalidades
1. Registrar y consultar las ventas, gastos, cobros, inventario, clientes y proveedores del negocio.
2. Calcular reportes y responder preguntas del asistente sobre el negocio.
3. Preparar mensajes (cobro, comprobante, cotización, pedido, promoción con foto o video, seguimiento de clientes) que el usuario decide enviar por WhatsApp desde su propio celular. Los mensajes comerciales de seguimiento solo se sugieren para clientes que autorizaron la comunicación comercial.
4. Llevar lo que el negocio le debe a sus proveedores y sus pagos fijos.
5. Respaldar la información en la nube y compartirla entre los celulares de la misma empresa.
6. Atender solicitudes de los titulares y cumplir obligaciones legales.

## 4. Tratamiento y seguridad
- En el celular: base cifrada (SQLCipher, AES-256) con clave en el almacén seguro del sistema; sin copias de seguridad automáticas de Android.
- En la nube: solo por HTTPS; cada empresa ve únicamente sus datos (reglas RLS por empresa).
- Asistente de IA: solo recibe totales del negocio y la pregunta sin nombres, celulares, documentos ni correos; para redactar promociones, solo nombres de productos, precios, estilo y ocasión (minimización). Sin señal, la redacción se hace en el celular.
- Sesión: bloqueo tras 5 intentos fallidos y cierre por 30 minutos de inactividad.
- Transmisión a terceros: el proveedor de nube (Supabase) y el de IA actúan como subencargados de infraestructura; no se venden ni ceden datos.

## 5. Derechos de los titulares (art. 8, Ley 1581 de 2012)
Conocer, actualizar y rectificar sus datos; solicitar prueba de la autorización; ser informado del uso; presentar quejas ante la Superintendencia de Industria y Comercio; revocar la autorización o pedir la supresión cuando no se respeten los principios; acceder gratis a sus datos.

## 6. Cómo ejercerlos
- **Clientes de una MiPyme:** ante la MiPyme responsable, por el canal que ella publique. En la app, la MiPyme puede editar o eliminar al cliente.
- **Usuarios de la app:** menú «Privacidad y datos» (revocar la autorización y borrar los datos del celular) o por correo a contacto@vertextechco.online.
- **Plazos:** consultas, máximo 10 días hábiles; reclamos, máximo 15 días hábiles (arts. 14 y 15, Ley 1581 de 2012).

## 7. Vigencia
Rige desde su aceptación en la app (versión indicada en la pantalla de la política). Los cambios sustanciales se informarán en la app y se pedirá de nuevo la autorización.
