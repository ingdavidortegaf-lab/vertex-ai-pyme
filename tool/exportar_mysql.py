"""Exporta la base de demostración (SQLite) a un script de MySQL para practicar
en MySQL Workbench. Es solo para practicar: la app usa SQLite en el celular y
PostgreSQL en la nube, NO MySQL.
Uso:  python tool/exportar_mysql.py
"""
import sqlite3, json, os

AQUI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(AQUI, '..', 'docs', 'base_de_datos')
c = sqlite3.connect(os.path.join(BASE, 'vertex_demo.db'))


def q(v):
    if v is None:
        return 'NULL'
    if isinstance(v, (int, float)):
        return repr(v)
    return "'" + str(v).replace('\\', '\\\\').replace("'", "''") + "'"


def fecha(iso):  # 2026-11-18T15:30:00.000Z -> '2026-11-18 15:30:00.000'
    return q(iso.replace('T', ' ').replace('Z', '')[:23]) if iso else 'NULL'


out = ["""-- =====================================================================
--  VERTEX AI Pyme · PRÁCTICA EN MySQL (MySQL Workbench)
--  La app NO usa MySQL: en el celular usa SQLite y en la nube PostgreSQL.
--  Este archivo copia los datos de la base de demostración a MySQL para
--  mostrar que el SQL es casi el mismo en los tres motores.
--  Requiere MySQL Server 8 (gratis). En Workbench: File > Open SQL Script >
--  este archivo > el rayo (Execute). Crea la base `vertex_practica`.
--  Las fechas quedan en hora UTC, igual que en la app.
-- =====================================================================
DROP DATABASE IF EXISTS vertex_practica;
CREATE DATABASE vertex_practica CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE vertex_practica;

CREATE TABLE clientes (
  id        CHAR(36)    PRIMARY KEY,
  nombre    VARCHAR(80) NOT NULL,
  telefono  VARCHAR(15),
  deleted   TINYINT(1)  NOT NULL DEFAULT 0
);

CREATE TABLE productos (
  id      CHAR(36)      PRIMARY KEY,
  nombre  VARCHAR(80)   NOT NULL,
  precio  DECIMAL(14,2) NOT NULL,
  costo   DECIMAL(14,2) NOT NULL DEFAULT 0,
  minimo  DECIMAL(12,3) NOT NULL DEFAULT 0,
  unidad  VARCHAR(4)    NOT NULL DEFAULT 'und',
  codigo  VARCHAR(40),
  deleted TINYINT(1)    NOT NULL DEFAULT 0
);

CREATE TABLE ventas (
  id         CHAR(36)      PRIMARY KEY,
  cliente_id CHAR(36),
  concepto   VARCHAR(120)  NOT NULL,
  monto      DECIMAL(14,2) NOT NULL CHECK (monto > 0),
  tipo       ENUM('ingreso','egreso','abono') NOT NULL,
  credito    TINYINT(1)    NOT NULL DEFAULT 0,
  fecha      DATETIME(3)   NOT NULL,
  pagos      JSON,
  FOREIGN KEY (cliente_id) REFERENCES clientes(id),
  INDEX ventas_fecha_idx (fecha)
);

CREATE TABLE inventario (
  id          CHAR(36)      PRIMARY KEY,
  producto_id CHAR(36)      NOT NULL,
  cantidad    DECIMAL(12,3) NOT NULL,
  motivo      VARCHAR(20)   NOT NULL,
  venta_id    CHAR(36),
  precio_unit DECIMAL(14,2),
  costo_unit  DECIMAL(14,2),
  fecha       DATETIME(3)   NOT NULL,
  FOREIGN KEY (producto_id) REFERENCES productos(id)
);
"""]

for r in c.execute('SELECT id, nombre, telefono, deleted FROM clientes'):
    out.append(f"INSERT INTO clientes VALUES ({q(r[0])}, {q(r[1])}, {q(r[2])}, {r[3]});")
for r in c.execute('SELECT id, nombre, precio, costo, minimo, unidad, codigo, deleted FROM productos'):
    out.append('INSERT INTO productos VALUES (' + ', '.join(q(x) for x in r) + ');')
for r in c.execute('SELECT id, cliente_id, concepto, monto, tipo, credito, fecha, pagos FROM ventas ORDER BY fecha'):
    pagos = q(json.dumps(json.loads(r[7]), ensure_ascii=False)) if r[7] else 'NULL'
    out.append(f"INSERT INTO ventas VALUES ({q(r[0])}, {q(r[1])}, {q(r[2])}, {r[3]}, {q(r[4])}, {r[5]}, {fecha(r[6])}, {pagos});")
for r in c.execute('SELECT id, producto_id, cantidad, motivo, venta_id, precio_unit, costo_unit, fecha FROM inventario ORDER BY fecha'):
    out.append(f"INSERT INTO inventario VALUES ({q(r[0])}, {q(r[1])}, {r[2]}, {q(r[3])}, {q(r[4])}, {q(r[5])}, {q(r[6])}, {fecha(r[7])});")

out.append("""
-- =====================================================================
--  CONSULTAS (las mismas de la base local, en el idioma de MySQL)
-- =====================================================================

-- 1. Ventas por día (hora de Colombia = UTC - 5 horas)
SELECT DATE(DATE_SUB(fecha, INTERVAL 5 HOUR)) AS dia, COUNT(*) AS numero, SUM(monto) AS total
FROM ventas WHERE tipo = 'ingreso'
GROUP BY dia ORDER BY dia DESC LIMIT 7;

-- 2. Cuánto entró por cada medio de pago (JSON_TABLE lee la lista de pagos)
SELECT p.medio, SUM(p.monto) AS total
FROM ventas v,
     JSON_TABLE(v.pagos, '$[*]' COLUMNS (medio VARCHAR(20) PATH '$.medio',
                                         monto DECIMAL(14,2) PATH '$.monto')) AS p
WHERE v.tipo IN ('ingreso', 'abono')
GROUP BY p.medio ORDER BY total DESC;

-- 3. Quién debe y cuánto
SELECT c.nombre,
       SUM(CASE WHEN v.tipo = 'ingreso' AND v.credito = 1 THEN v.monto
                WHEN v.tipo = 'abono' THEN -v.monto ELSE 0 END) AS saldo
FROM clientes c JOIN ventas v ON v.cliente_id = c.id
GROUP BY c.id, c.nombre HAVING saldo > 0 ORDER BY saldo DESC;

-- 4. Inventario: existencia = suma de movimientos
SELECT p.nombre, p.unidad, COALESCE(SUM(i.cantidad), 0) AS existencia, p.minimo
FROM productos p LEFT JOIN inventario i ON i.producto_id = p.id
WHERE p.deleted = 0 AND p.unidad <> 'serv'
GROUP BY p.id, p.nombre, p.unidad, p.minimo ORDER BY existencia;

-- 5. Productos más vendidos y su ganancia
SELECT p.nombre, SUM(-i.cantidad) AS vendidos, SUM(-i.cantidad * (i.precio_unit - i.costo_unit)) AS ganancia
FROM inventario i JOIN productos p ON p.id = i.producto_id
WHERE i.motivo = 'venta'
GROUP BY p.id, p.nombre ORDER BY vendidos DESC;
""")

ruta = os.path.join(BASE, '3_practica_MySQL_Workbench.sql')
with open(ruta, 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(out))
print('listo:', ruta, len(out), 'líneas')
