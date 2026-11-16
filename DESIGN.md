# Design — VERTEX AI Pyme

Identidad «pizarra del mercado». Fuente de verdad en código:
`lib/ui/tema.dart` (tokens y tema), `lib/ui/ilustraciones.dart` (logo,
palotes e ilustraciones). Este archivo describe lo construido; si cambian, se
actualiza aquí.

## Idea
El día del negocio se lee como la pizarra del puesto de mercado: la barra
superior y el bloque «Hoy vendiste» van en verde pizarra con cifras en tiza
blanca; el resto de la app es claro para leer al sol. Cada trabajo tiene su
tiza.

## Color (ThemeExtension `Paleta`)
| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| pizarra | #17362C | #14302A | AppBar, bloque del día, cabeceras, burbuja del usuario, FAB |
| tizaBlanca | #F5F2E9 | #F5F2E9 | Texto sobre pizarra |
| tizaSuave | #B3C9BE | #A9C2B6 | Texto secundario sobre pizarra |
| ventas | #1B7F45 | #8FE0AE | Ventas, «Venta», utilidad positiva |
| gastos | #C2412D | #F59B83 | Gastos, utilidad negativa |
| fiado | #A35F00 | #F4C55A | Fiado, abonos, «Te deben», Clientes |
| asistente | #1F6FB2 | #9ACFF5 | Asistente, nube |
| *Tiza (ventasTiza…) | #8FE0AE · #F59B83 · #F4C55A · #9ACFF5 | igual | La misma tiza sobre la pizarra |
| *Fondo (ventasFondo…) | #DDF3E5 · #FBE3DD · #FCEBCB · #DCEBF8 | #173826 · #3D1E17 · #3A2C0E · #142B40 | Contenedores suaves, iconos de tipo, indicador de pestaña |

Superficies (claro): fondo #F4F7F3, tarjetas #FFFFFF con borde #D3DDD6,
texto #14201A / #46564D. Oscuro: fondo #0D1411, contenedores #121C17→#22312A.
Todos los textos de color cumplen 4,5:1 sobre su fondo.

Color fijo por cliente: `colorCliente(nombre)` elige uno de 8 pares
(fondo/tinta) por hash del nombre; el mismo cliente tiene el mismo color en
todas las pantallas.

## Tipografía
Roboto (del sistema, sin descargas). Cifras siempre tabulares (`cifras()`).
Escala Material 3 con pesos: display/headline 700–800 con tracking negativo,
títulos 700, etiquetas 600. La cifra principal de la pizarra va a 46 sp; las
etiquetas son pequeñas (jerarquía por contraste de tamaño).

## Forma y espacio
Tarjetas radio 18 con borde de 1 px, sin sombra. Botones alto 52, radio 16.
Campos rellenos radio 14. Hojas inferiores radio 28. Bloques de pizarra con
esquinas inferiores de 28. Secciones: 24 arriba del título, 8 abajo. Objetivos
táctiles ≥ 48 dp.

## Componentes
- Barra: logo «V» de tiza con chispa + «VERTEX AI Pyme»; avatar de cuenta;
  menú. Debajo, píldora de sincronización (icono de color por estado).
- Navegación Material 3: Inicio, Movimientos, Clientes, Asistente; el
  indicador toma la tiza de la sección.
- Formularios en hoja inferior (registrar, cliente, elegir cliente).
- Listas dentro de una tarjeta con separadores con sangría de 72.
- Estados vacíos con ilustración vectorial, título, texto y acción.

## Movimiento característico
**Palotes de tiza**: cada venta del día es una raya; se agrupan de cinco
(cuatro y la diagonal). Al aparecer una venta nueva se dibuja el trazo
(ease-out, ≤ 900 ms); con «quitar animaciones» del sistema se muestra sin
animar. Otros movimientos: cambio de pestaña por fundido (220 ms) y barras del
mes que crecen hasta su monto exacto (500 ms).

## Gráficas (`lib/ui/graficas.dart`)
Colores de serie validados con el verificador de paletas (daltonismo y
contraste), distintos de los colores de texto:
| Serie | Claro | Oscuro | Ayuda extra |
|---|---|---|---|
| Ventas | #1B7F45 | #3FA56C | barra llena |
| Gastos | #C2412D | #E0614B | barra rayada (textura), leyenda |
| Contado | #1F6FB2 | #4C93D6 | etiqueta directa con monto y % |
| Fiado | #A35F00 | #BF8420 | etiqueta directa con monto y % |

Rejilla recesiva (0, mitad, máximo) con montos cortos ($420 mil, $1,2 M).
Barras con 2 px de aire y puntas redondeadas de 4 px; al tocar un grupo se
resalta y su detalle sale arriba. Los indicadores muestran la variación con
flecha y texto, nunca solo color. Navegación: Inicio, Caja, Inventario,
Clientes, Asistente.

## Reglas
- Largo de barra = monto exacto (sin escalas engañosas).
- Lo recién sincronizado queda resaltado en la píldora hasta que se toca.
- Nada de degradados, vidrio ni sombras de adorno; el color hace trabajo.
- Ilustraciones solo en código (CustomPainter), nunca imágenes descargadas.
