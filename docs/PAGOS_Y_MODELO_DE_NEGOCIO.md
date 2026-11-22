# Pagos, pasarela y modelo de negocio

## Parte 1 · Medios de pago en la app (ya funciona)

### Qué hace
Cada venta, abono o gasto guarda **cómo se pagó**:

| Medio | Para qué |
|---|---|
| **Efectivo** | La plata de la caja |
| **Nequi** · **Daviplata** | Pagos desde el celular |
| **Bancolombia** | Transferencia a la cuenta del negocio |
| **Otra transferencia** | Bre-B u otros bancos |
| **Tarjeta débito** · **Tarjeta crédito** | Datáfono |

- **Pago dividido:** un cliente puede pagar **una parte por Nequi y otra en efectivo**, o con tres medios. La app avisa *"Faltan $X"* o *"Sobran $X"* hasta que la suma cuadre con el total, y el botón *"Poner lo que falta"* llena el último valor solo.
- La **venta fiada no lleva medio de pago**: queda por cobrar. Cuando el cliente abona, el abono sí dice cómo pagó.
- También se pregunta el medio al **vender una cotización** y al **pagarle un pedido al proveedor**.
- **Pago parcial al proveedor:** al llegar el pedido se elige si se pagó **todo**, **una parte** (30, 50 o 70 %) o **todo fiado**. El gasto es solo lo pagado, con su medio; el saldo queda en **Lo que debo** con fecha límite, y cada abono pregunta otra vez el medio (efectivo, Nequi…). Así el cierre de caja cuadra aunque se le pague al proveedor por partes.

### Dónde se ve
- **Caja:** cada movimiento muestra su medio ("Venta · Nequi + Efectivo").
- **Comprobante (PDF y WhatsApp):** "Forma de pago: Efectivo $5.000 + Nequi $20.000".
- **Cierre de caja** (Inicio → Herramientas → *Cierre de caja*):
  - cuánto entró hoy por cada medio;
  - **cuánto efectivo debería haber**: base + efectivo recibido − gastos pagados en efectivo;
  - la diferencia con lo que el tendero cuenta (*cuadra / sobran / faltan*);
  - envío del cierre por WhatsApp.
- **Informe para el contador:**
  - nueva sección *"Ingresos y pagos por medio de pago"*;
  - total digital, para conciliar con los extractos de Nequi y los bancos;
  - en el libro de movimientos, la forma de pago de cada uno.

### Datos para recibir pagos
En el menú ⋮ → **Datos para recibir pagos** el tendero escribe su Nequi, su Daviplata, su cuenta de Bancolombia y su **llave Bre-B**. Esos datos salen solos:
- en la **cuenta de cobro** ("Puede pagar por transferencia: Nequi 300 123 4567 · Bancolombia Ahorros…");
- en la **cotización**.

Así el cliente paga desde su propia app del banco, **sin comisiones para el tendero**.

### Cómo funciona por dentro
- `lib/domain/pagos.dart`: lista de medios, validación (`problemaPagos`), pago dividido, totales por medio (`PorMedio`) y cuadre de efectivo.
- La base del celular pasa a la **versión 6**. La columna `pagos` guarda `[{"medio":"nequi","monto":20000}, …]`. Los movimientos anteriores no tienen pagos y se leen como **efectivo**: nada se pierde al actualizar.
- **En la nube (Supabase)** hay una columna `pagos` (jsonb) y una regla `privado.pagos_validos`. La aplicamos y la probamos en el proyecto real. El servidor **rechaza**:
  - pagos que no suman el total;
  - medios inventados;
  - pagos en una venta fiada.

  Así, aunque alguien modifique la app, los números no se pueden falsear.
- Pruebas: `test/pagos_test.dart`.

---

## Parte 2 · Pasarela de pago: qué hay y qué sigue (dicho con honestidad)

**Hoy:** el cliente paga por transferencia con los datos del negocio (Nequi, Bancolombia, Bre-B) y el tendero lo registra con su medio. Funciona sin internet y **no cuesta nada**.

**Siguiente fase:** link de pago y QR con una pasarela. Recomendamos **Wompi** (Bancolombia): acepta Nequi, PSE, tarjetas y QR.

| Tarifa de Wompi (referencia, 2026) | Valor |
|---|---|
| Plan avanzado: link de pago, tarjetas, PSE | **2,65 % + $700 + IVA** por transacción aprobada |
| Pagos con QR (Bancolombia y Nequi) | **1 % + IVA** (tarifa anunciada en septiembre de 2026) |
| Tarjeta presencial (datáfono) | 1,98 % + IVA |
| Plan básico (link de pago) | Gratis, pero solo entre cuentas Bancolombia |

Confirmar las tarifas vigentes con Wompi antes de firmar.

**Cómo se integraría:**
1. Cada tienda abre **su propia cuenta en Wompi**: cédula si es persona natural, o RUT y Cámara de Comercio si es empresa.
2. La app pide el link a una **Edge Function**. La llave privada de Wompi vive **solo en el servidor**, igual que la de la IA.
3. Wompi avisa a la Edge Function (webhook firmado) cuando el pago se aprueba, y el abono se registra solo con su medio.

**VERTEX nunca recibe ni guarda la plata ni los datos de las tarjetas:** el dinero va directo a la cuenta del tendero. Así no somos una entidad que maneja dinero de terceros y evitamos esa carga regulatoria.

**Por qué no está ya:**
- exige cuentas reales de comercio y llaves de producción;
- cobra comisión por transacción;
- no se puede probar sin ellas.

Preferimos no mostrar algo que no está probado.

---

## Parte 3 · Modelo de negocio: cuánto cobrar, cuánto cuesta y cuánto queda

### Precio recomendado
| Plan | Precio | Qué incluye |
|---|---|---|
| **Plan Tienda** | **$19.900/mes** o **$199.000/año** (2 meses gratis) | Nube y respaldo, 2 celulares, PDF, informes, cierre de caja, avisos |
| **Plan Red** (mayoristas) | Por tienda, con descuento por volumen | El mayorista lo paga para las tiendas que surte |

**Por qué $19.900 y no $14.900:**
- Con $14.900 se necesitan **104 tiendas** solo para cubrir los costos.
- Con $19.900 basta con **78**.
- Sigue siendo menos que un solo fiado recuperado al mes.

### Supuestos (cámbialos cuando tengas los datos del piloto)
| Concepto | Valor | Fuente |
|---|---|---|
| Dólar | $4.000 | Supuesto |
| Supabase plan Pro | USD 25/mes ≈ $100.000 | Supabase (precio público) |
| IA (Gemini) | Capa gratuita; reserva de USD 5 ≈ $20.000/mes | Supuesto |
| Dominio y correo | ≈ $15.000/mes | Supuesto |
| Salario mínimo 2026 | $1.750.905 + $249.095 de auxilio de transporte | Decretos 1469 y 1470 de 2025 |
| Costo empresa de un salario mínimo (con prestaciones y seguridad social) | ≈ $2.800.000/mes | Estimado |
| Soporte e instalación para 100 tiendas | Media persona | Supuesto |

### Costos de la tecnología
| | Mes | Año |
|---|---|---|
| Supabase Pro + IA + dominio | **$135.000** | **$1.620.000** |
| Una sola vez: cuenta de Google Play (USD 25) | | ≈ $100.000 |

La tecnología **casi no sube** con más tiendas: lo que sube es la gente que instala y da soporte.

### Con 100 tiendas en el plan Tienda ($19.900)
| | Mes | Año |
|---|---|---|
| **Ingresos** (100 × $19.900) | **$1.990.000** | **$23.880.000** |
| Tecnología | $135.000 | $1.620.000 |
| Soporte (media persona) | $1.400.000 | $16.800.000 |
| **Costos totales** | **$1.535.000** | **$18.420.000** |
| **Queda** | **$455.000** | **$5.460.000** |

Si la mensualidad se cobra con link de pago de Wompi, cada cobro de $19.900 paga unos $1.460 de comisión (cerca del 7 %), y quedan unos $310.000 al mes. Por eso conviene cobrar **anual** o por **transferencia directa** (Nequi, Bancolombia o Bre-B), sin comisión.

**Dicho con honestidad:** con 100 tiendas el negocio **se sostiene y deja un margen pequeño**, pero todavía no paga el sueldo de los tres fundadores. El negocio rinde al crecer, porque los costos casi no aumentan:

| Tiendas | Ingresos/mes | Costos/mes | Queda/mes | Queda/año |
|---|---|---|---|---|
| 100 | $1.990.000 | $1.535.000 (½ persona de soporte) | $455.000 | $5.460.000 |
| 300 | $5.970.000 | $2.935.000 (1 persona) | $3.035.000 | $36.420.000 |
| 1.000 | $19.900.000 | $8.595.000 (3 personas + nube más grande) | $11.305.000 | $135.660.000 |

**Más ingresos posibles:**
- implementación y capacitación para gremios o grupos de negocios;
- el plan Red con mayoristas;
- la comisión por referir tiendas a la pasarela de pago, cuando exista.

---

## Parte 4 · ¿Se satura con 100 tiendas? Cómo lo evitamos

### Cuánta carga es
- **Datos:** una tienda activa genera unas 180 filas al día (ventas, gastos, abonos e inventario), unos **2 MB al mes**. 100 tiendas suman unos **216 MB al mes**.
  - El plan gratis de Supabase (500 MB) alcanza para unos **2 meses**.
  - El plan Pro (8 GB incluidos) alcanza para **unos 3 años** con 100 tiendas.
- **Consultas:** cada celular sube lo que guarda **una sola vez** (upsert por id) y descarga solo lo nuevo, en lotes de 500.

### Lo que ya está hecho para que no se sature
1. **Primero en el celular.** La tienda trabaja contra su propia base. Si la nube se demora o se cae, **la tienda no se detiene**: la cola espera y reintenta sola.
2. **Descarga adaptativa** (nueva). Antes cada celular preguntaba cada 30 segundos aunque no hubiera nada nuevo: con 100 tiendas y 2 celulares eran unas **27 consultas por segundo** todo el día. Ahora, si no llega nada, espera cada vez más (30 s, 1, 2, 4 y hasta 5 min), y vuelve a 30 s apenas hay movimiento. En horas tranquilas bajan a unas **3 consultas por segundo**, 10 veces menos. Prueba: `test/sync_adaptativo_test.dart`.
3. **Reintentos que esperan cada vez más** (15 s, 30 s, 1 min… hasta 30 min) si el servidor falla. Así miles de celulares no lo bombardean al mismo tiempo.
4. **Cada tienda separada por RLS** e **índices por empresa y fecha**: las consultas de una tienda no recorren los datos de las demás.
5. **Sin conexiones abiertas:** la app habla por HTTPS (API REST), no con conexiones directas a la base. Supabase reparte la carga con su pool de conexiones.
6. **La IA en cola:** las preguntas a la IA se hacen solo con totales y, sin señal, esperan en el celular.

### Lo que haríamos al crecer (más de 300 tiendas)
- Pasar a una máquina de base de datos más grande en Supabase: es un cambio de plan, **sin cambiar el código**.
- Subir los registros en lotes (varias ventas en una sola petición).
- Archivar los movimientos de más de 2 años.
- Un límite diario de preguntas a la IA por tienda.
- Monitorear en el panel de Supabase (uso, lentitud y errores) con alertas.

---

## Fuentes
- Wompi:
  - [tarifa QR al 1 %, Cambio Colombia (2026)](https://cambiocolombia.com/peso-a-peso-paso-a-paso/articulo/2026/9/wompi-amplia-los-pagos-sin-contacto-y-baja-al-uno-por-ciento-la-tarifa-de-los-pagos-con-qr);
  - [Enter.co](https://www.enter.co/fintech/wompi-baja-la-tarifa-del-qr-al-1-y-amplia-los-pagos-desde-el-celular/);
  - [reglamento para comercios](https://wompi.co/assets/downloadble/reglamento-Comercios-Colombia.pdf).
- Supabase:
  - [guía de precios 2026](https://www.jetadmin.io/blog/supabase-pricing-2026-guide-to-plans-limits-and-real-world-costs/);
  - verificar en supabase.com/pricing.
- Salario mínimo 2026:
  - [ConsultorSalud: decretos 1469 y 1470 de 2025](https://consultorsalud.com/aumento-del-salario-minimo-en-colombia-2026/);
  - [La República: decreto transitorio](https://www.larepublica.co/economia/mintrabajo-publico-decreto-transitorio-que-mantiene-minimo-de-1-75-millones-en-2026-4331878).
