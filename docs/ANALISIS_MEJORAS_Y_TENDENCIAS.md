# VERTEX AI Pyme: análisis de mejoras y tendencias (noviembre de 2026)

Este documento resume lo que se mejoró en esta ronda, por qué se hizo y qué sigue.

---

## 1. Lo que se mejoró en esta ronda

| Área | Antes | Ahora | Aporta a |
|---|---|---|---|
| **Jurídico (Ley 1581)** | Aviso propio y casilla simple | Aviso de privacidad, casilla **sin premarcar** con **enlace visible** a la Política, política completa sin internet, formato de autorización en PDF para cada cliente, registro de «AUTORIZO» por WhatsApp | Jurídica |
| **Proveedores** | Pedido pagado completo | Se paga **todo, una parte (30/50/70 %) o todo fiado**; el saldo queda en «Lo que debo» con fecha límite, abonos con medio de pago, WhatsApp al proveedor y aviso 3 días antes | Emprendimiento, Financiera |
| **Promociones** | Lista de precios en texto | **Foto o video** (cámara o galería), **imagen lista para el estado** (1080×1080 con logo y precios), **redactor con IA**: 5 estilos, temporada automática (quincena, fin de semana, viernes negro, Navidad), etiquetas del municipio | Marketing, Tecnología |
| **Clientes (CRM)** | Lista y cartera | **Seguimiento**: quién hace rato no viene, mejores clientes, nuevos y perdidos; mensaje sugerido por WhatsApp; solo a quien autorizó; no repetir antes de 7 días | Marketing, Jurídica |
| **Cualquier negocio** | 10 tipos | **22 tipos** con emoji (panadería, frutas, carnicería, ropa, celulares, transporte, hospedaje…) y la app se ajusta sola (inventario, servicios, gramera, códigos, fiado) | Emprendimiento |
| **Marca** | «V» de tiza | **Logo oficial de VERTEX TECH**: «V» blanca con facetas y el rombo del vértice, en los colores de la app, en el ícono del celular, la web y dentro de la app (el rombo brilla suave) | Marketing |
| **Experiencia** | Estática | Entrada animada de las herramientas, logo vivo, deuda con proveedores en el Inicio. Todo respeta «reducir movimiento» del celular | Tecnología |

Pruebas automáticas: **106**, todas pasan.

---

## 2. Tendencias de hoy y cómo responde VERTEX

### 2.1 Comercio conversacional (vender por WhatsApp)
En Colombia el cliente del barrio ya pide por WhatsApp. VERTEX no compite con WhatsApp: **lo alimenta**. Comprobantes, cuentas de cobro, cotizaciones, promociones con imagen y mensajes de seguimiento salen listos para enviar con un toque, sin pagar la API de WhatsApp Business.

### 2.2 IA generativa al servicio del tendero
La IA no es un adorno. Redacta promociones y consejos, y además:
- **Funciona sin internet** con plantillas de mercadeo, y con señal usa el modelo en la nube.
- **No envía datos personales**: a la nube solo viajan nombres de productos, precios, estilo y ocasión (minimización, Ley 1581).
- La clave del modelo vive solo como secreto de Supabase, nunca en la app ni en el repositorio.

### 2.3 Pagos digitales y llaves
La tienda recibe efectivo, Nequi, Daviplata, Bancolombia, transferencias y tarjeta, y puede **dividir el pago**. El cierre de caja separa el efectivo de lo digital. Con la llegada de los pagos inmediatos con **llaves** (Bre-B del Banco de la República), la app ya guarda la llave del negocio para mostrarla al cliente.

### 2.4 Crédito en la cadena: fiado de doble vía
La tienda **fía a sus clientes** y **le fían sus proveedores**. VERTEX lleva las dos cuentas: cartera por edades (lo que me deben) y cuentas por pagar con vencimientos (lo que debo). Con los dos lados se puede decir cómo queda la caja y negociar mejor con el proveedor.

### 2.5 Primero sin conexión (offline-first)
En veredas y municipios la señal va y viene. Todo se guarda cifrado en el celular (SQLCipher) y se sincroniza solo, con una espera que se adapta (de 30 s a 5 min) para no gastar datos.

### 2.6 Una app para cualquier dispositivo
Es la misma app en Android (APK), Windows y la web, que se instala en iPhone desde Safari como PWA, con su ícono y su base de datos local en el navegador.

### 2.7 Privacidad como ventaja
El cliente confía más en la tienda que le pide permiso. Por eso VERTEX pide la autorización, la guarda con fecha y medio, y solo sugiere escribirle a quien la dio.

---

## 3. Qué sigue (hoja de ruta)

| Prioridad | Mejora | Por qué |
|---|---|---|
| Alta | **Catálogo web** de la tienda (enlace para compartir) con pedido por WhatsApp | Vender 24/7 sin otra app |
| Alta | **Factura electrónica / documento equivalente POS** con un proveedor tecnológico autorizado por la DIAN | La obligación depende del régimen de cada negocio (verificar con el contador) |
| Media | **Puntos y fidelización** (cada 10 compras, un detalle) usando el seguimiento | Retener clientes |
| Media | **Pedido sugerido con IA** según la venta de las últimas semanas y la temporada | Comprar mejor al proveedor |
| Media | **Varios usuarios** (dueño y empleado) con permisos | Negocios con turnos |
| Baja | Lectura de **voz** para registrar ventas («vendí dos panelas a Ana») | Más rápido detrás del mostrador |

---

## 4. Lo que todavía no se probó (con honestidad)

- **iPhone real**: la versión web se probó en el navegador del computador, no en un iPhone físico.
- **APK nuevo en un celular**: compila bien, pero en esta sesión no había un celular conectado para instalarlo.
- **IA en la nube**: la función quedó publicada (versión 2, modo «promoción»). Solo responde si en Supabase está configurado el secreto `GEMINI_API_KEY`. Si no está, la app usa el redactor del celular y lo avisa.
- **Compartir foto o video**: el botón usa la hoja de compartir del sistema (Android, iPhone y navegadores que la soportan). En Windows solo se puede compartir el texto, que además queda copiado.
