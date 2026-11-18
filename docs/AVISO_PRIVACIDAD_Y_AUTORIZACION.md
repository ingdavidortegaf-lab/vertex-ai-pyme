# Aviso de privacidad, casilla y formato de autorización (Ley 1581 de 2012)

> Textos **oficiales** de la convocatoria CreaTIC Casanare 2026 («Formatos Modelo de Protección de Datos»), tal como los muestra la app. Código: `lib/domain/legal.dart` y `lib/ui/legal_page.dart`. Versión: **Aviso v2 · noviembre de 2026**. Como el texto cambió, la app vuelve a pedir la autorización una vez.

## Sección A: aviso en la pantalla de registro (primer uso)

> AVISO DE PRIVACIDAD: En cumplimiento de la Ley 1581 de 2012 y el Decreto 1074 de 2015, le informamos que los datos personales suministrados serán tratados para gestionar su registro, operación comercial, inventario, ventas, pedidos y contacto dentro de esta aplicación. Frente a los datos de clientes finales registrados por los comercios, la MiPyme usuaria actúa como Responsable del Tratamiento y la Gobernación de Casanare, como operadora de la plataforma, actúa como Encargada del Tratamiento. Usted puede ejercer sus derechos a conocer, actualizar, rectificar y suprimir sus datos, así como consultar nuestra Política de Tratamiento de Datos Personales directamente en esta aplicación.

**Casilla (sin premarcar; el botón «Aceptar y continuar» no se activa hasta marcarla):**

> ☐ He leído el Aviso de Privacidad y autorizo de manera previa, expresa e informada el tratamiento de mis datos personales conforme a la <u>Política de Tratamiento de Datos Personales</u>.

- El texto subrayado es un **enlace visible** que abre la política completa **dentro de la app, sin internet** (ver `POLITICA_TRATAMIENTO_DATOS.md`).
- Debajo del aviso hay enlaces a **www.casanare.gov.co** y al correo del canal de derechos.
- La aceptación se guarda en el celular con la fecha y la versión del aviso.
- El aviso y la política se pueden volver a ver en el menú ⋮ → **Privacidad y datos**, donde también se puede revocar la autorización y borrar los datos del celular.

## Sección B: Anexo 3, autorización de cada cliente del comercio

**Clientes nuevos:** al crear el cliente hay una casilla de autorización **sin marcar**, con enlace a la política. Sin marcarla no se puede guardar.

**Clientes que ya estaban:** en la ficha del cliente → **Formato de autorización de datos (Ley 1581)**. La app:
1. Llena el formato del Anexo 3 con el nombre del cliente, el comercio, el teléfono, el municipio y la fecha.
2. Le pone número (AU-…) y lo archiva en «Documentos».
3. Permite **imprimirlo** para firma o **enviarlo por WhatsApp** pidiendo que respondan **AUTORIZO**.
4. Cuando el cliente responde, se toca **Ya respondió «AUTORIZO»** y queda registrado con fecha y medio (guarde el pantallazo del chat como prueba).

Texto del formato (Anexo 3):

> **FORMATO DE AUTORIZACIÓN Y CONSENTIMIENTO INFORMADO PARA EL TRATAMIENTO DE DATOS PERSONALES**
>
> Yo, [cliente], identificado(a) con C.C. / NIT No. ________, actuando en nombre propio (o en representación del establecimiento ________), manifiesto de manera libre, previa, expresa e informada que AUTORIZO a [comercio] en calidad de Responsable del Tratamiento, y a la GOBERNACIÓN DE CASANARE – DIRECCIÓN DE LAS TIC en calidad de Encargada y operadora de la aplicación móvil VERTEX AI Pyme, para recolectar, almacenar, usar, circular y actualizar mis datos personales de contacto, ubicación y transacciones comerciales.
>
> Finalidades y Derechos: Declaro haber sido informado(a) de que mis datos serán utilizados exclusivamente para gestionar pedidos, ventas, entregas, control de cartera/fiados y comunicación comercial; que es facultativo responder preguntas sobre datos sensibles; y que puedo ejercer gratuitamente mis derechos a conocer, actualizar, rectificar y suprimir mis datos conforme a la Política de Tratamiento de Datos Personales disponible en la aplicación y en www.casanare.gov.co.
>
> Teléfono / Celular · Correo electrónico · Municipio / Dirección · Fecha (DD/MM/AAAA) · Firma del titular · C.C. / NIT

## Uso de la autorización dentro de la app
- **Seguimiento de clientes** (mensajes comerciales por WhatsApp): el botón «Escribirle» solo aparece para clientes que autorizaron; a los demás se les ofrece «Pedir autorización». Se sugiere no escribir más de una vez por semana.
- **IA:** nunca recibe nombres de personas, celulares ni correos.
