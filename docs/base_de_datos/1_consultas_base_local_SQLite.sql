-- =====================================================================
--  VERTEX AI Pyme · Consultas a la BASE LOCAL (SQLite)
--  Abre vertex_demo.db (o la base del PC) en DBeaver o DB Browser for
--  SQLite, pega una consulta y ejecútala (en DBeaver: Ctrl+Enter).
--
--  Las fechas se guardan en hora UTC (ej. 2026-11-18T15:30:00.000Z).
--  Colombia es UTC-5; por eso varias consultas usan  date(fecha, '-5 hours').
-- =====================================================================


-- 1. ¿Qué tablas tiene la base?
SELECT name AS tabla
FROM sqlite_master
WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
ORDER BY name;


-- 2. ¿Qué columnas tiene la tabla de ventas? (estructura)
PRAGMA table_info(ventas);


-- 3. Las últimas 10 ventas, gastos y abonos
SELECT datetime(fecha, '-5 hours') AS fecha_colombia,
       tipo,                 -- ingreso = venta, egreso = gasto, abono = pago de una deuda
       concepto,
       monto,
       credito,              -- 1 = venta fiada
       pagos                 -- medios de pago en JSON
FROM ventas
ORDER BY fecha DESC
LIMIT 10;


-- 4. Ventas por día (últimos 7 días con ventas)
SELECT date(fecha, '-5 hours') AS dia,
       COUNT(*)               AS numero_de_ventas,
       SUM(monto)             AS total_vendido
FROM ventas
WHERE tipo = 'ingreso'
GROUP BY dia
ORDER BY dia DESC
LIMIT 7;


-- 5. ¿Cuánto entró por cada medio de pago? (lee el JSON de la columna pagos)
SELECT json_extract(p.value, '$.medio')      AS medio,
       SUM(json_extract(p.value, '$.monto')) AS total
FROM ventas v, json_each(v.pagos) p
WHERE v.tipo IN ('ingreso', 'abono')
GROUP BY medio
ORDER BY total DESC;


-- 6. Ventas pagadas con DOS o más medios (pago dividido)
SELECT datetime(fecha, '-5 hours') AS fecha_colombia, concepto, monto, pagos
FROM ventas
WHERE json_array_length(pagos) > 1
ORDER BY fecha DESC;


-- 7. ¿Quién me debe y cuánto? (fiados menos abonos)
SELECT c.nombre,
       SUM(CASE WHEN v.tipo = 'ingreso' AND v.credito = 1 THEN v.monto
                WHEN v.tipo = 'abono' THEN -v.monto
                ELSE 0 END) AS saldo
FROM clientes c
JOIN ventas v ON v.cliente_id = c.id
GROUP BY c.id
HAVING saldo > 0
ORDER BY saldo DESC;


-- 8. Inventario: la existencia NO se guarda, se calcula sumando movimientos
SELECT p.nombre,
       p.unidad,
       COALESCE(SUM(i.cantidad), 0) AS existencia,
       p.minimo,
       CASE WHEN COALESCE(SUM(i.cantidad), 0) <= 0 THEN 'AGOTADO'
            WHEN COALESCE(SUM(i.cantidad), 0) <= p.minimo THEN 'Por reponer'
            ELSE 'Bien' END AS estado
FROM productos p
LEFT JOIN inventario i ON i.producto_id = p.id
WHERE p.deleted = 0 AND p.unidad <> 'serv'
GROUP BY p.id
ORDER BY existencia;


-- 9. Historial de un producto (cada entrada y cada venta)
SELECT datetime(i.fecha, '-5 hours') AS fecha_colombia, i.motivo, i.cantidad
FROM inventario i
JOIN productos p ON p.id = i.producto_id
WHERE p.nombre = 'Arroz 500 g'
ORDER BY i.fecha;


-- 10. Productos más vendidos y su ganancia (precio - costo)
SELECT p.nombre,
       SUM(-i.cantidad)                                   AS cantidad_vendida,
       SUM(-i.cantidad * i.precio_unit)                   AS total_vendido,
       SUM(-i.cantidad * (i.precio_unit - i.costo_unit))  AS ganancia
FROM inventario i
JOIN productos p ON p.id = i.producto_id
WHERE i.motivo = 'venta'
GROUP BY p.id
ORDER BY total_vendido DESC;


-- 11. Resumen del mes: ventas, gastos y utilidad
SELECT SUM(CASE WHEN tipo = 'ingreso' THEN monto ELSE 0 END)                      AS ventas,
       SUM(CASE WHEN tipo = 'egreso'  THEN monto ELSE 0 END)                      AS gastos,
       SUM(CASE WHEN tipo = 'ingreso' THEN monto WHEN tipo = 'egreso' THEN -monto
                ELSE 0 END)                                                        AS utilidad
FROM ventas
WHERE strftime('%Y-%m', fecha, '-5 hours') = strftime('%Y-%m', 'now', '-5 hours');


-- 12. Cola de sincronización: ¿qué falta por subir a la nube?
SELECT tabla, estado, COUNT(*) AS registros
FROM cola_sync
GROUP BY tabla, estado;


-- 13. Estado de envío de cada venta (pendiente = aún no está en la nube)
SELECT sync, COUNT(*) AS registros
FROM ventas
GROUP BY sync;


-- 14. Documentos emitidos (con su número único)
SELECT numero, tipo, cliente_nombre, total, datetime(fecha, '-5 hours') AS fecha_colombia
FROM documentos
ORDER BY fecha DESC;


-- 15. Ajustes del negocio (nombre, datos de pago, cómo trabaja)
SELECT clave, valor
FROM ajustes
WHERE clave LIKE 'negocio_%' OR clave LIKE 'pago_%' OR clave LIKE 'modo_%'
ORDER BY clave;
