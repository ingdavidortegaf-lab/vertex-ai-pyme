-- =====================================================================
--  VERTEX AI Pyme · Consultas a la BASE DE LA NUBE (PostgreSQL en Supabase)
--  Dónde correrlas: supabase.com → tu proyecto → SQL Editor → New query →
--  pega una consulta → Run.  (También desde DBeaver, conectado a Supabase.)
--
--  OJO: en el SQL Editor entras como ADMINISTRADOR y ves todas las empresas.
--  La app NO: cada usuario solo ve su empresa gracias a RLS (consulta 7).
--  Estas consultas solo LEEN; no cambian nada.
-- =====================================================================


-- 1. ¿Qué tablas tiene el backend?
SELECT table_name AS tabla
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;


-- 2. ¿Cuántos registros hay en cada tabla?
SELECT 'empresas' AS tabla, COUNT(*) FROM empresas
UNION ALL SELECT 'clientes',   COUNT(*) FROM clientes
UNION ALL SELECT 'ventas',     COUNT(*) FROM ventas
UNION ALL SELECT 'productos',  COUNT(*) FROM productos
UNION ALL SELECT 'inventario', COUNT(*) FROM inventario;


-- 3. Ventas por empresa (cada tienda es una "empresa")
SELECT e.nombre AS empresa,
       COUNT(v.id)   AS movimientos,
       COALESCE(SUM(v.monto) FILTER (WHERE v.tipo = 'ingreso'), 0) AS ventas
FROM empresas e
LEFT JOIN ventas v ON v.empresa_id = e.id
GROUP BY e.id, e.nombre
ORDER BY ventas DESC;


-- 4. Últimos movimientos que llegaron desde los celulares
SELECT recibido_at AT TIME ZONE 'America/Bogota' AS llego,
       fecha       AT TIME ZONE 'America/Bogota' AS fecha_en_la_tienda,
       tipo, concepto, monto, credito, pagos
FROM ventas
ORDER BY recibido_at DESC
LIMIT 10;


-- 5. PRUEBA: no hay duplicados (el id es la llave primaria y el envío es upsert)
SELECT id, COUNT(*) AS veces
FROM ventas
GROUP BY id
HAVING COUNT(*) > 1;          -- debe salir VACÍO


-- 6. ¿Cuánto entró por cada medio de pago? (columna pagos en formato jsonb)
SELECT p->>'medio'                 AS medio,
       SUM((p->>'monto')::numeric) AS total
FROM ventas, jsonb_array_elements(pagos) AS p
GROUP BY medio
ORDER BY total DESC;


-- 7. SEGURIDAD: las reglas RLS (cada tienda ve solo lo suyo)
SELECT tablename AS tabla, policyname AS regla, cmd AS operacion
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, cmd;


-- 8. ¿Está activada la seguridad por fila (RLS) en cada tabla?
SELECT relname AS tabla, relrowsecurity AS rls_activo
FROM pg_class
WHERE relnamespace = 'public'::regnamespace AND relkind = 'r'
ORDER BY relname;


-- 9. Reglas automáticas (triggers): crear la empresa, mezclar cambios por campo
SELECT event_object_schema AS esquema, event_object_table AS tabla, trigger_name AS trigger
FROM information_schema.triggers
WHERE trigger_schema IN ('public', 'auth')
ORDER BY tabla;


-- 10. Reglas de validación de la tabla ventas (CHECK)
SELECT conname AS regla, pg_get_constraintdef(oid) AS condicion
FROM pg_constraint
WHERE conrelid = 'public.ventas'::regclass AND contype = 'c';


-- 11. Probar la regla de los pagos (devuelve true o false; no guarda nada)
SELECT privado.pagos_validos('[{"medio":"nequi","monto":20000},{"medio":"efectivo","monto":5000}]', 25000, 'ingreso', false) AS pago_dividido_bien,
       privado.pagos_validos('[{"medio":"nequi","monto":20000}]', 25000, 'ingreso', false)                                AS faltan_5000,
       privado.pagos_validos('[{"medio":"efectivo","monto":5000}]', 5000, 'ingreso', true)                                AS fiado_con_pago;


-- 12. Fiados pendientes por cliente (en la nube)
SELECT c.nombre,
       SUM(CASE WHEN v.tipo = 'ingreso' AND v.credito THEN v.monto
                WHEN v.tipo = 'abono' THEN -v.monto ELSE 0 END) AS saldo
FROM clientes c
JOIN ventas v ON v.cliente_id = c.id
WHERE NOT c.deleted
GROUP BY c.id, c.nombre
HAVING SUM(CASE WHEN v.tipo = 'ingreso' AND v.credito THEN v.monto
                WHEN v.tipo = 'abono' THEN -v.monto ELSE 0 END) > 0
ORDER BY saldo DESC;


-- 13. Tamaño de la base (para saber cuánto espacio queda en el plan)
SELECT pg_size_pretty(pg_database_size(current_database())) AS tamano_total;
