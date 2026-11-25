# La base de datos de VERTEX AI Pyme: cómo mostrarla y consultarla

## 1. Primero lo más importante: ¿qué bases de datos usa la app?

| Dónde | Motor | ¿Se puede abrir? | Para qué |
|---|---|---|---|
| **En el celular** | **SQLite cifrada con SQLCipher (AES-256)** | **No**, y eso es bueno: está cifrada para que nadie lea los datos si roban el celular | Trabajar sin internet |
| **En el PC (Windows)** | **SQLite** sin cifrar | **Sí**: `C:\Users\<tu usuario>\AppData\Roaming\co.vertextech\vertex_ai_pyme\vertex.db` | La misma app en el PC |
| **En la nube** | **PostgreSQL 17** (Supabase) | **Sí**: en el SQL Editor de supabase.com o con DBeaver | Respaldo y varios celulares |
| Para practicar | `vertex_demo.db` (esta carpeta) | **Sí** | Una base con datos de ejemplo para mostrar sin tocar datos reales |

### ¿Y MySQL?
**La app no usa MySQL**, y así lo debes decir si preguntan:
- **En el celular** se usa **SQLite** porque vive *dentro* de la app: no necesita un servidor, funciona sin internet y es la base que traen Android e iPhone. MySQL necesita un servidor encendido, que no cabe en un celular.
- **En la nube** se usa **PostgreSQL** porque Supabase lo trae con **seguridad por fila (RLS)**, **JSON (`jsonb`)** y **triggers**, que usamos para separar las tiendas y validar los pagos.
- **El lenguaje (SQL) es casi el mismo en los tres.** Por eso dejamos el archivo `3_practica_MySQL_Workbench.sql`, con las mismas consultas en MySQL, para mostrarlo en el programa que ya tienes.

**En una frase:** *"Usamos SQLite en el dispositivo porque es una base embebida, sin servidor, ideal para trabajar sin conexión; y PostgreSQL en la nube por la seguridad a nivel de fila y el soporte de JSON. No usamos MySQL, pero el SQL es estándar: aquí tienen las mismas consultas en MySQL."*

---

## 2. Cómo están organizadas las tablas (dibújalo así)

```
 BASE DEL CELULAR / PC (SQLite)                    NUBE (PostgreSQL · Supabase)
 ─────────────────────────────                     ────────────────────────────
 clientes ──< ventas          (fiados, abonos)      empresas ──< miembros >── usuarios (Auth)
 productos ──< inventario     (entradas, ventas)        │
 cola_sync   (lo que falta subir)                       ├──< clientes
 documentos  (CV, CT, CC, PD, IN, AU con su número)     ├──< ventas      (con pagos jsonb)
 proveedores ──< cuentas_pagar ──< pagos_proveedor      ├──< productos
 cotizaciones · ajustes (autorizaciones aut_cli_…)      │
 preguntas_ia                                           └──< inventario
                                                        Cada fila lleva empresa_id → RLS
```

| Tabla | Qué guarda | Columnas clave |
|---|---|---|
| `clientes` | Nombre y celular de cada cliente | `id` (UUID), `nombre`, `telefono` |
| `ventas` | Ventas, gastos y abonos | `tipo` (ingreso, egreso, abono), `monto`, `credito` (fiado), `pagos` (JSON con los medios de pago), `fecha` |
| `productos` | Productos y servicios | `precio`, `costo`, `minimo`, `unidad` (und, kg, lb, serv), `codigo` |
| `inventario` | Cada entrada y salida de mercancía | `cantidad` (+ entra, − sale), `motivo`, `precio_unit`, `costo_unit` |
| `cola_sync` | Lo que falta subir a la nube | `tabla`, `payload`, `estado`, `intentos` |
| `documentos` | Comprobantes, cotizaciones, cobros, pedidos e informes | `numero` (ej. CC-A3F1-000017), `archivo` (ruta del PDF) |
| `ajustes` | Datos del negocio, preferencias y **autorizaciones de clientes** (`aut_cli_<id>`, Ley 1581) | `clave`, `valor` |
| `proveedores` | Proveedores con su WhatsApp | `nombre`, `telefono` |
| `cuentas_pagar` | **Lo que se le debe a un proveedor** (pedido pagado en parte o fiado) | `proveedor_nombre`, `total`, `vence` |
| `pagos_proveedor` | Cada **abono** a una cuenta, unido al gasto que generó | `cuenta_id` (llave foránea), `monto`, `egreso_id` |

### Decisiones de diseño (lo que más le gusta a un ingeniero)
1. **Llaves primarias UUID**, creadas en el celular. Dos celulares sin señal nunca generan el mismo id, y el envío a la nube es **upsert por id**: así no se duplica nada.
2. **La existencia no se guarda: se calcula.** Se suman los movimientos de `inventario`. Funciona como un libro contable: no se "daña" si dos celulares venden a la vez.
3. **Las ventas no se editan ni se borran: solo se agregan.** Es una bitácora auditable. En la nube no hay permiso de UPDATE ni DELETE sobre ventas.
4. **Fechas en UTC** (hora universal). Se convierten a la hora de Colombia (UTC−5) para mostrar.
5. **Los pagos en JSON** (`[{"medio":"nequi","monto":20000}, …]`) permiten el pago dividido sin otra tabla. **El servidor valida que sumen el total** (regla `pagos_validos`).
6. **Integridad:**
   - Llaves primarias en todas las tablas y **CHECK** en los montos (> 0), los tipos y los pagos.
   - En la nube, **llave foránea a `empresas`** en cada tabla.
   - **Entre venta y cliente no hay llave foránea, y es a propósito:** como el sistema funciona sin conexión, una venta puede llegar a la nube antes que el cliente que se creó en otro celular. Con la llave foránea, esa venta se rechazaría. La integridad la cuidan la app y los triggers.
7. **Índices** por fecha y por empresa: las consultas de una tienda no recorren los datos de las demás.
8. **Transacciones:** cada venta y su entrada en `cola_sync` se guardan juntas: o las dos o ninguna.
9. **El saldo con el proveedor tampoco se guarda: se calcula** (total de la cuenta − suma de abonos), igual que la existencia. `pagos_proveedor.cuenta_id` sí tiene **llave foránea** a `cuentas_pagar`, porque las dos tablas viven solo en el celular (no hay problema de orden de llegada). Esquema local: **versión 12** (v8 terceros y pagos fijos; v9 perfiles con PIN y quién hizo cada venta; v10 anulaciones, descuentos, turnos y la vista `ventas_netas`; v11 IVA por producto y la cola `facturas_e`; v12 precio por mayor, vencimiento y unidades nuevas). Ver `docs/EQUIPO_CAJA_Y_FACTURACION.md`.

---

## 3. Cómo mostrar la base LOCAL (SQLite) con DBeaver

DBeaver Community es gratis y abre **SQLite, PostgreSQL y MySQL** en un solo programa.

1. Abre **DBeaver** (menú Inicio → DBeaver). Trae una base propia de ejemplo ("DBeaver Sample Database"): ignórala.
2. Arriba a la izquierda, toca el enchufe con el **+** (**Nueva conexión**) → elige **SQLite** → **Siguiente**.
3. En **Ruta**, toca **Abrir…** y elige `vertex_demo.db`, en esta carpeta.
4. Toca **Finalizar**. La primera vez DBeaver ofrece **descargar el controlador** (es gratis): acepta.
5. A la izquierda despliega la conexión → **Tablas**. Doble clic en **ventas** → pestaña **Datos**: ahí está cada venta.
6. Pestaña **Diagrama ER**: DBeaver **dibuja las tablas**, muy útil para explicar la estructura.
7. Para consultas: menú **Editor SQL → Abrir script SQL** (o **Archivo → Abrir archivo**), elige `1_consultas_base_local_SQLite.sql`, pon el cursor dentro de una consulta y presiona **Ctrl+Enter**.

**¿Y la base real del PC?** Cierra primero la app VERTEX y abre en DBeaver `C:\Users\<tu usuario>\AppData\Roaming\co.vertextech\vertex_ai_pyme\vertex.db`. Para no correr riesgos, solo **consulta** (SELECT): no edites nada a mano.

> Si prefieres algo más simple solo para SQLite: **DB Browser for SQLite** (gratis). Archivo → Abrir base de datos → pestaña "Ejecutar SQL".

---

## 4. Cómo mostrar la base de la NUBE (PostgreSQL)

### Opción fácil: en el navegador (sin instalar nada)
1. Entra a **supabase.com** → tu proyecto **VERTEX AI PYME**.
2. **Table Editor** (icono de tabla): ves cada tabla y sus filas, como una hoja de cálculo.
3. **SQL Editor** → **New query** → pega una consulta de `2_consultas_nube_PostgreSQL.sql` → **Run**.

Para mostrar la base, empieza por estas tres:
- **Consulta 5:** *"No hay duplicados"*. Sale vacía.
- **Consulta 7:** *"Las reglas de seguridad por fila"*.
- **Consulta 8:** *"RLS activado en las 6 tablas"*.

En el SQL Editor entras como **administrador** y ves todas las empresas. Explícalo así: *"Yo veo todo porque soy el administrador; la app de cada tienda solo puede ver lo suyo, por RLS."*

### Opción DBeaver (conectarse desde el PC)
1. En Supabase: **Connect** (arriba) → **Session pooler**. Copia el **Host**, el **puerto**, el **usuario** (`postgres.xxxxx`) y el **nombre de la base** (`postgres`).
2. En DBeaver: **Nueva conexión → PostgreSQL** → pega esos datos.
3. La **contraseña** es la de la base de datos que elegiste al crear el proyecto. Escríbela tú: **no la compartas ni la muestres en la pantalla del evento**. Si no la recuerdas, se cambia en *Project Settings → Database → Reset database password*.
4. **Probar conexión → Finalizar.** Abre `2_consultas_nube_PostgreSQL.sql` y corre las consultas con **Ctrl+Enter**.

---

## 5. Cómo mostrarlo en MySQL Workbench (el programa que ya tienes)

MySQL Workbench es solo la "pantalla": necesita un **servidor MySQL** encendido, que **no tienes instalado**.
1. Instala **MySQL Server 8 Community** (gratis). En la instalación eliges la contraseña de `root`: guárdala tú.
2. Abre Workbench → conexión **Local instance** → escribe tu contraseña.
3. **File → Open SQL Script** → `3_practica_MySQL_Workbench.sql` → el **rayo** (Execute).

Eso crea la base `vertex_practica` con las tablas y los datos de ejemplo. Al final del archivo están las mismas consultas en MySQL.

**Diferencias que puedes señalar** (el SQL es casi igual):

| Qué | SQLite (celular) | PostgreSQL (nube) | MySQL (práctica) |
|---|---|---|---|
| Leer la lista de pagos (JSON) | `json_each(pagos)` | `jsonb_array_elements(pagos)` | `JSON_TABLE(pagos, '$[*]' …)` |
| Hora de Colombia | `datetime(fecha, '-5 hours')` | `fecha AT TIME ZONE 'America/Bogota'` | `DATE_SUB(fecha, INTERVAL 5 HOUR)` |
| Tipo de los montos | `REAL` | `numeric(14,2)` | `DECIMAL(14,2)` |
| Seguridad por fila (RLS) | No aplica (un solo dueño) | **Sí** | No existe igual |

---

## 6. Guion de 2 minutos para mostrar la base

1. *"La app tiene dos bases: SQLite en el celular, que funciona sin internet y va cifrada, y PostgreSQL en la nube."* → Muestra el **diagrama ER** en DBeaver.
2. *"Cada venta queda en la tabla ventas, con su medio de pago en JSON."* → Corre la **consulta 3** (últimas ventas) y la **5** (por medio de pago).
3. *"La existencia no se guarda: se calcula sumando movimientos."* → **Consulta 8** (inventario).
4. *"Lo que falta subir a la nube está en la cola."* → **Consulta 12**.
5. *"El tendero paga la mitad al proveedor y el resto queda fiado: el saldo también se calcula."* → **Consulta 16** (lo que debo) y **17** (abonos unidos a su gasto con un JOIN).
6. *"Solo le escribimos a quien autorizó."* → **Consulta 18** (seguimiento con la columna `autorizo`).
7. *"En la nube, cada tienda solo ve lo suyo y no hay duplicados."* → En Supabase, **consultas 5 y 7**.

---

## 7. Archivos de esta carpeta

| Archivo | Para qué |
|---|---|
| `vertex_demo.db` | Base SQLite de ejemplo (Tienda Doña Marta): clientes, productos, unas 90 ventas con distintos medios de pago, fiados, abonos y documentos |
| `1_consultas_base_local_SQLite.sql` | 18 consultas para la base local (probadas), incluidas **lo que se debe a proveedores** (16 y 17) y el **seguimiento de clientes con su autorización** (18) |
| `2_consultas_nube_PostgreSQL.sql` | 13 consultas para Supabase (probadas en el proyecto real; solo leen) |
| `3_practica_MySQL_Workbench.sql` | Las tablas, los datos de ejemplo y las consultas en MySQL, para practicar |

Para rehacer la base de ejemplo con fechas de hoy: `flutter test tool/base_demo_test.dart` y luego `python tool/exportar_mysql.py`.
