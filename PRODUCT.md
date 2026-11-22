# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users
Dueños de micro y pequeños negocios de Casanare, Colombia (tienda, ferretería,
droguería, agro). Registran ventas, gastos y fiados desde su celular durante
la jornada, muchas veces sin señal, con poco tiempo entre cliente y cliente y
sin formación contable.

## Product Purpose
Llevar clientes, ventas de contado y fiadas, gastos y abonos en el celular, y
saber al instante cuánto se vendió, cuánto queda de utilidad y quién debe.
Todo funciona sin conexión; cuando vuelve la señal se sincroniza con la nube
de la empresa. Un asistente responde preguntas del negocio con los datos
propios (sin señal) y, con señal, da consejos con IA.

Éxito: que el dueño registre una venta en segundos y que sepa, sin hacer
cuentas, cómo va el mes y a quién cobrarle.

## Positioning
Hecho para negocios de zonas con mala señal: el modo sin conexión es el
camino principal, no un respaldo. Cobro por WhatsApp con mensaje sugerido y
privacidad conforme a la Ley 1581 de 2012 (la IA nunca recibe nombres ni
celulares).

## Operating Context
- Producto comercial de VERTEX TECH. Probado en un Xiaomi 14T (Android 15,
  HyperOS), incluso en modo avión.
- Uso a una mano, en el mostrador o en la calle, con luz fuerte.
- Montos en pesos colombianos sin decimales; celulares colombianos de 10 dígitos.

## Capabilities and Constraints
- Flutter (Material 3), Android 12+; iOS 16+ después del evento.
- Base local cifrada (SQLCipher) + Supabase (Auth, RLS por empresa, Edge
  Function con IA). Las claves solo entran por `--dart-define`.
- Sin dependencias de pago ni servicios que pidan tarjeta. Sin fuentes ni
  recursos descargados en tiempo de ejecución (debe verse igual sin señal).
- Textos en español de Colombia, claros y sin jerga técnica.

## Brand Commitments
- Nombre: «VERTEX AI Pyme», de VERTEX TECH. No hay logo, colores ni
  tipografía previos: la identidad visual se define en el rediseño.
- La MiPyme es la responsable de los datos; la plataforma es encargada.

## Evidence on Hand
- No hay clientes reales, testimonios ni cifras de uso: no se inventan.
- Datos de demostración los crea el usuario en la app.

## Product Principles
1. Sin señal también funciona: nada importante depende de internet.
2. Registrar es más rápido que anotar en el cuaderno.
3. Las cifras se entienden de un vistazo, sin saber contabilidad.
4. Los datos del negocio y de sus clientes se cuidan siempre.

## Accessibility & Inclusion
Usuarios con poca familiaridad digital y algunos con vista cansada: textos
legibles con tamaño de letra del sistema aumentado, objetivos táctiles
amplios, contraste alto bajo el sol.
