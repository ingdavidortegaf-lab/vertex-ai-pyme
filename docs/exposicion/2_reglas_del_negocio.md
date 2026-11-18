# 2 · Reglas del negocio: el cerebro de la app

## En una frase
Aquí están **las cuentas y las reglas**: cuánto se vendió, quién debe y desde cuándo, qué pasa si dos celulares cambian lo mismo, cuándo avisar. **No hay pantallas ni internet**: es lógica pura.

## Por qué está separado (esto le gusta a un ingeniero)
- Se llama **capa de dominio**. Al no depender de pantallas ni de internet, **se prueba fácil**: hay pruebas automáticas para casi todo lo de esta carpeta.
- Si mañana cambia el diseño, **las reglas no se tocan**.

## Qué hace cada archivo

| Archivo | Qué hace | Cómo decirlo |
|---|---|---|
| `contabilidad.dart` | **Cuenta de cobro**: aplica los abonos a la deuda más antigua (FIFO), calcula **desde cuándo debe**, los **días de mora** y la antigüedad (0-30, 31-60, 61-90, +90). También define la semana, la quincena y el mes de los informes | "Pensado como un contador" |
| `conflictos.dart` | **Dos celulares sin señal cambian lo mismo**: gana el cambio más reciente **de cada dato** (nombre, teléfono, precio…), no de la ficha completa. También la espera entre reintentos | "Nadie pisa el trabajo del otro" |
| `codigos.dart` | Códigos de barras: valida el dígito de control EAN, lee etiquetas de **gramera** (producto + peso) y convierte gramos a kilos o libras. Unidad "servicio" | |
| `documentos.dart` | Los **mensajes de WhatsApp** (comprobante, cotización, pedido, promoción) y el **pedido sugerido** | |
| `pagos.dart` | **Medios de pago**: efectivo, Nequi, Daviplata, Bancolombia, Bre-B y tarjetas. Revisa que el **pago dividido** sume el total y calcula el **cuadre de caja** | "Cobra como pague el cliente" |
| `avisos.dart` | **Qué avisar y cuándo**, sin repetir el mismo aviso | |
| `modo_negocio.dart` | **Cómo trabaja el negocio** (productos o servicios, si fía, gramera…) para adaptar la app | |
| `resumen.dart` | Los "moldes" de los datos: producto con su existencia, cliente con su deuda, resumen del periodo | |
| `asistente_local.dart` | El **asistente sin internet**: entiende palabras clave ("vendí hoy", "me debe") y responde con los datos del celular | "Responde aunque no haya señal" |
| `formato.dart` | Pesos colombianos ($25.000), celulares (300 123 4567), quitar tildes | |
| `privacidad.dart` | **Borra nombres, números y correos** de una pregunta antes de mandarla a la IA | "Ley 1581: minimización" |

## Muestra este pedazo (el mejor para lucirse)
Abre **`contabilidad.dart`** y busca con **Ctrl+F**: `estadoDeCuenta`.
Explícalo así, sin leer el código:
1. *"Ordena los fiados y abonos del cliente por fecha."*
2. *"Cada fiado entra a una fila de pendientes."*
3. *"Cada abono paga primero el fiado más antiguo: es el método FIFO, primero en entrar, primero en salir."*
4. *"Lo que queda son las deudas abiertas: con eso sabemos desde cuándo debe y cuántos días lleva."*

**Ejemplo para decir en voz alta:** *"Si doña Ana fió $50.000 en agosto y $40.000 en octubre, y abonó $30.000, la app sabe que de agosto le quedan $20.000 con más de 90 días. Eso va en la cuenta de cobro en PDF."*

## Si el jurado pregunta…
- **"¿Cómo resuelves conflictos?"** → Last-Write-Wins **por campo** con marcas de tiempo en UTC. Si en un celular cambian el precio y en otro el teléfono, se conservan los dos cambios. Ventas e inventario **nunca se editan, solo se agregan**, así que no tienen conflicto.
- **"¿Cómo calculas el inventario?"** → No se guarda un número de existencias que se pueda dañar: **la existencia es la suma de todos los movimientos** (entradas, ventas, ajustes). Es como un libro contable.
