-- Prueba de caja en el servidor: anulaciones, tope de descuento y turnos.
-- Corre contra una base LOCAL creada con supabase/migrations/ (`supabase
-- start`), nunca contra el proyecto real:
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
--        -v ON_ERROR_STOP=1 -f supabase/tests/caja.sql
-- Todo va en una transacción que se deshace al final.

\set ON_ERROR_STOP on
begin;

-- D dueña, P despachador, A administrador.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
select u.id::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       u.email, '', now(), now(), '{}', '{}'
from (values
  ('d1000000-0000-4000-8000-00000000000d', 'duena-caja@prueba.local'),
  ('0f100000-0000-4000-8000-00000000000a', 'despachador-caja@prueba.local'),
  ('a1000000-0000-4000-8000-0000000000aa', 'admin-caja@prueba.local')
) as u(id, email);

set local role authenticated;

-- --------------------------------------------- D: venta, gasto e invitaciones
select set_config('request.jwt.claim.sub', 'd1000000-0000-4000-8000-00000000000d', true),
       set_config('request.jwt.claims', '{"sub":"d1000000-0000-4000-8000-00000000000d","role":"authenticated"}', true);
insert into public.ventas (id, concepto, monto, tipo, credito, fecha)
values ('51000000-0000-4000-8000-000000000001', 'Venta', 10000, 'ingreso', false, now()),
       ('51000000-0000-4000-8000-000000000002', 'Arriendo', 900000, 'egreso', false, now()),
       ('51000000-0000-4000-8000-000000000003', 'Venta 2', 4000, 'ingreso', false, now());
insert into public.productos (id, nombre, nombre_ts, precio, precio_ts, costo, costo_ts,
                              minimo, minimo_ts, deleted, deleted_ts, updated_at)
values ('61000000-0000-4000-8000-000000000001', 'Arroz', now(), 2500, now(), 2000, now(), 0, now(), false, now(), now());
select set_config('prueba.cod_p', public.crear_invitacion('despachador'), true),
       set_config('prueba.cod_a', public.crear_invitacion('administrador'), true);

select set_config('request.jwt.claim.sub', '0f100000-0000-4000-8000-00000000000a', true),
       set_config('request.jwt.claims', '{"sub":"0f100000-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select public.unirse_con_codigo(current_setting('prueba.cod_p'));
select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-0000000000aa', true),
       set_config('request.jwt.claims', '{"sub":"a1000000-0000-4000-8000-0000000000aa","role":"authenticated"}', true);
select public.unirse_con_codigo(current_setting('prueba.cod_a'));

-- ------------------------------------------------------------- anulaciones
-- P (despachador) no anula.
select set_config('request.jwt.claim.sub', '0f100000-0000-4000-8000-00000000000a', true),
       set_config('request.jwt.claims', '{"sub":"0f100000-0000-4000-8000-00000000000a","role":"authenticated"}', true);
do $$
begin
  begin
    insert into public.ventas (id, concepto, monto, tipo, credito, fecha, anula)
    values (gen_random_uuid(), 'Anulación: Venta', 10000, 'anulacion', false, now(),
            '51000000-0000-4000-8000-000000000001');
    raise exception 'FALLO: el despachador pudo anular';
  exception when insufficient_privilege then null;
  end;
end $$;

-- A (administrador) sí; por el mismo valor y una sola vez. El tipo anulado lo pone el servidor.
select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-0000000000aa', true),
       set_config('request.jwt.claims', '{"sub":"a1000000-0000-4000-8000-0000000000aa","role":"authenticated"}', true);
do $$
begin
  begin
    insert into public.ventas (id, concepto, monto, tipo, credito, fecha, anula)
    values (gen_random_uuid(), 'Anulación mal', 9999, 'anulacion', false, now(), '51000000-0000-4000-8000-000000000001');
    raise exception 'FALLO: se aceptó una anulación por otro valor';
  exception when check_violation then null;
  end;
  begin
    insert into public.ventas (id, concepto, monto, tipo, credito, fecha, anula)
    values (gen_random_uuid(), 'Anulación de nada', 10000, 'anulacion', false, now(), gen_random_uuid());
    raise exception 'FALLO: se aceptó la anulación de algo que no existe';
  exception when foreign_key_violation then null;
  end;
  begin
    insert into public.ventas (id, concepto, monto, tipo, credito, fecha)
    values (gen_random_uuid(), 'Anulación sin original', 10000, 'anulacion', false, now());
    raise exception 'FALLO: se aceptó una anulación sin decir qué anula';
  exception when check_violation or foreign_key_violation then null;
  end;
  insert into public.ventas (id, concepto, monto, tipo, credito, fecha, anula, anula_tipo)
  values ('51000000-0000-4000-8000-0000000000a1', 'Anulación: Venta', 10000, 'anulacion', false, now(),
          '51000000-0000-4000-8000-000000000001', 'egreso');
  if (select anula_tipo from public.ventas where id = '51000000-0000-4000-8000-0000000000a1') <> 'ingreso' then
    raise exception 'FALLO: el tipo anulado debe ponerlo el servidor, no el celular';
  end if;
  begin
    insert into public.ventas (id, concepto, monto, tipo, credito, fecha, anula)
    values (gen_random_uuid(), 'Otra vez', 10000, 'anulacion', false, now(), '51000000-0000-4000-8000-000000000001');
    raise exception 'FALLO: se anuló dos veces el mismo movimiento';
  exception when unique_violation then null;
  end;
  begin
    insert into public.ventas (id, concepto, monto, tipo, credito, fecha, anula)
    values (gen_random_uuid(), 'Anular la anulación', 10000, 'anulacion', false, now(),
            '51000000-0000-4000-8000-0000000000a1');
    raise exception 'FALLO: se anuló una anulación';
  exception when check_violation then null;
  end;
  -- La anulación del gasto.
  insert into public.ventas (id, concepto, monto, tipo, credito, fecha, anula)
  values ('51000000-0000-4000-8000-0000000000a2', 'Anulación: Arriendo', 900000, 'anulacion', false, now(),
          '51000000-0000-4000-8000-000000000002');
  -- Lo vendido vuelve al inventario solo con cantidad positiva y la venta.
  insert into public.inventario (id, producto_id, cantidad, motivo, venta_id, fecha)
  values (gen_random_uuid(), '61000000-0000-4000-8000-000000000001', 2, 'anulacion',
          '51000000-0000-4000-8000-000000000001', now());
  begin
    insert into public.inventario (id, producto_id, cantidad, motivo, fecha)
    values (gen_random_uuid(), '61000000-0000-4000-8000-000000000001', 2, 'anulacion', now());
    raise exception 'FALLO: devolución por anulación sin la venta';
  exception when check_violation then null;
  end;
end $$;

-- P ve la anulación de la venta pero no la del gasto.
select set_config('request.jwt.claim.sub', '0f100000-0000-4000-8000-00000000000a', true),
       set_config('request.jwt.claims', '{"sub":"0f100000-0000-4000-8000-00000000000a","role":"authenticated"}', true);
do $$
begin
  if not exists (select 1 from public.ventas where id = '51000000-0000-4000-8000-0000000000a1') then
    raise exception 'FALLO: el despachador debe ver la anulación de una venta';
  end if;
  if exists (select 1 from public.ventas where id = '51000000-0000-4000-8000-0000000000a2') then
    raise exception 'FALLO: el despachador vio la anulación de un gasto';
  end if;
end $$;

-- ---------------------------------------------------------- tope de descuento
do $$
begin
  begin
    insert into public.ventas (id, concepto, monto, tipo, credito, fecha, descuento)
    values (gen_random_uuid(), 'Con descuento', 9500, 'ingreso', false, now(), 500);
    raise exception 'FALLO: el despachador dio descuento sin que el dueño lo permitiera';
  exception when check_violation then null;
  end;
  begin
    perform public.definir_descuento_maximo(50);
    raise exception 'FALLO: el despachador cambió el tope de descuento';
  exception when insufficient_privilege then null;
  end;
end $$;

select set_config('request.jwt.claim.sub', 'd1000000-0000-4000-8000-00000000000d', true),
       set_config('request.jwt.claims', '{"sub":"d1000000-0000-4000-8000-00000000000d","role":"authenticated"}', true);
select public.definir_descuento_maximo(10);
do $$
begin
  if (public.mi_contexto()->>'descuento_max_pct')::numeric <> 10 then
    raise exception 'FALLO: mi_contexto no informa el tope de descuento';
  end if;
  -- La dueña no tiene tope.
  insert into public.ventas (id, concepto, monto, tipo, credito, fecha, descuento)
  values (gen_random_uuid(), 'Precio de amigo', 5000, 'ingreso', false, now(), 5000);
  begin
    insert into public.ventas (id, concepto, monto, tipo, credito, fecha, descuento)
    values (gen_random_uuid(), 'Gasto con descuento', 5000, 'egreso', false, now(), 100);
    raise exception 'FALLO: se aceptó descuento en algo que no es una venta';
  exception when check_violation then null;
  end;
end $$;

select set_config('request.jwt.claim.sub', '0f100000-0000-4000-8000-00000000000a', true),
       set_config('request.jwt.claims', '{"sub":"0f100000-0000-4000-8000-00000000000a","role":"authenticated"}', true);
do $$
begin
  insert into public.ventas (id, concepto, monto, tipo, credito, fecha, descuento)
  values (gen_random_uuid(), 'Dentro del tope', 9000, 'ingreso', false, now(), 1000);
  begin
    insert into public.ventas (id, concepto, monto, tipo, credito, fecha, descuento)
    values (gen_random_uuid(), 'Pasado del tope', 8500, 'ingreso', false, now(), 1500);
    raise exception 'FALLO: el despachador pasó el tope de descuento';
  exception when check_violation then null;
  end;
end $$;

-- ------------------------------------------------------------------ turnos
-- P sube su turno y solo ve los suyos; no puede subir uno a nombre de otro.
insert into public.turnos (id, perfil, abre, cierra, base, esperado, contado)
values ('71000000-0000-4000-8000-000000000001', 'Pedro', now() - interval '8 hours', now(), 50000, 180000, 179000);
do $$
begin
  begin
    insert into public.turnos (id, creado_por, abre, cierra, base, esperado, contado)
    values (gen_random_uuid(), 'd1000000-0000-4000-8000-00000000000d', now() - interval '1 hour', now(), 0, 0, 0);
    raise exception 'FALLO: el despachador subió un turno a nombre de otra persona';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.turnos (id, abre, cierra, base, esperado, contado)
    values (gen_random_uuid(), now(), now() - interval '1 hour', 0, 0, 0);
    raise exception 'FALLO: se aceptó un turno que cierra antes de abrir';
  exception when check_violation then null;
  end;
  update public.turnos set contado = 180000 where id = '71000000-0000-4000-8000-000000000001';
  if (select contado from public.turnos where id = '71000000-0000-4000-8000-000000000001') <> 179000 then
    raise exception 'FALLO: se pudo cambiar un turno ya cerrado';
  end if;
end $$;

-- D (dueña) ve el turno de P.
select set_config('request.jwt.claim.sub', 'd1000000-0000-4000-8000-00000000000d', true),
       set_config('request.jwt.claims', '{"sub":"d1000000-0000-4000-8000-00000000000d","role":"authenticated"}', true);
do $$
begin
  if not exists (select 1 from public.turnos where id = '71000000-0000-4000-8000-000000000001') then
    raise exception 'FALLO: la dueña no ve los turnos de su equipo';
  end if;
end $$;

-- Ventas sigue sin UPDATE ni DELETE.
do $$
declare n int;
begin
  update public.ventas set monto = 1 where id = '51000000-0000-4000-8000-000000000003';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLO: se pudo modificar una venta'; end if;
  delete from public.ventas where id = '51000000-0000-4000-8000-000000000003';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLO: se pudo borrar una venta'; end if;
end $$;

reset role;
rollback;
\echo 'OK: caja (anulaciones, descuentos y turnos) cumple las reglas'
