-- Prueba de productos en el servidor: precio por mayor, vencimiento y
-- unidades nuevas; la unión por campo con su marca de tiempo; y que el
-- despachador los ve sin ver costos.
-- Corre contra una base LOCAL creada con supabase/migrations/ (`supabase
-- start`), nunca contra el proyecto real:
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
--        -v ON_ERROR_STOP=1 -f supabase/tests/productos.sql
-- Todo va en una transacción que se deshace al final.

\set ON_ERROR_STOP on
begin;

-- D dueña, P despachador.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
select u.id::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       u.email, '', now(), now(), '{}', '{}'
from (values
  ('d2000000-0000-4000-8000-00000000000d', 'duena-prod@prueba.local'),
  ('0f200000-0000-4000-8000-00000000000a', 'despachador-prod@prueba.local')
) as u(id, email);

set local role authenticated;

select set_config('request.jwt.claim.sub', 'd2000000-0000-4000-8000-00000000000d', true),
       set_config('request.jwt.claims', '{"sub":"d2000000-0000-4000-8000-00000000000d","role":"authenticated"}', true);

-- Cable por metro con precio por mayor desde 50 m y una galleta que vence.
insert into public.productos (id, nombre, nombre_ts, precio, precio_ts, costo, costo_ts,
                              minimo, minimo_ts, deleted, deleted_ts, updated_at,
                              unidad, unidad_ts, precio_mayor, precio_mayor_ts,
                              cantidad_mayor, cantidad_mayor_ts)
values ('62000000-0000-4000-8000-000000000001', 'Cable 12', '2026-11-01', 4200, '2026-11-01',
        3000, '2026-11-01', 0, '2026-11-01', false, '2026-11-01', '2026-11-01',
        'm', '2026-11-01', 3800, '2026-11-01', 50, '2026-11-01');
insert into public.productos (id, nombre, nombre_ts, precio, precio_ts, costo, costo_ts,
                              minimo, minimo_ts, deleted, deleted_ts, updated_at,
                              unidad, unidad_ts, vence, vence_ts)
values ('62000000-0000-4000-8000-000000000002', 'Galletas', '2026-11-01', 2000, '2026-11-01',
        1500, '2026-11-01', 0, '2026-11-01', false, '2026-11-01', '2026-11-01',
        'paq', '2026-11-01', '2026-12-15', '2026-11-01');

-- Un cambio viejo del precio por mayor no pisa al nuevo; uno nuevo sí.
update public.productos set precio_mayor = 3000, precio_mayor_ts = '2026-10-01'
 where id = '62000000-0000-4000-8000-000000000001';
do $$
begin
  if (select precio_mayor from public.productos where id = '62000000-0000-4000-8000-000000000001') <> 3800 then
    raise exception 'FALLO: un precio por mayor más viejo pisó al nuevo';
  end if;
end $$;
update public.productos set precio_mayor = 3700, precio_mayor_ts = '2026-11-20'
 where id = '62000000-0000-4000-8000-000000000001';
do $$
begin
  if (select precio_mayor from public.productos where id = '62000000-0000-4000-8000-000000000001') <> 3700 then
    raise exception 'FALLO: el precio por mayor nuevo no quedó';
  end if;
  if (select updated_at from public.productos where id = '62000000-0000-4000-8000-000000000001')
     <> '2026-11-20'::timestamptz then
    raise exception 'FALLO: updated_at no tomó la fecha del precio por mayor';
  end if;
end $$;

-- Unidad que no existe y fecha mal escrita: el servidor las rechaza.
do $$
begin
  begin
    update public.productos set unidad = 'bulto', unidad_ts = now()
     where id = '62000000-0000-4000-8000-000000000001';
    raise exception 'FALLO: aceptó una unidad que no existe';
  exception when check_violation then null;
  end;
  begin
    update public.productos set vence = '15/12/2026', vence_ts = now()
     where id = '62000000-0000-4000-8000-000000000002';
    raise exception 'FALLO: aceptó una fecha de vencimiento mal escrita';
  exception when check_violation then null;
  end;
  begin
    update public.productos set precio_mayor = -1, precio_mayor_ts = now()
     where id = '62000000-0000-4000-8000-000000000001';
    raise exception 'FALLO: aceptó un precio por mayor negativo';
  exception when check_violation then null;
  end;
end $$;

select set_config('prueba.cod_p', public.crear_invitacion('despachador'), true);

-- El despachador ve precio por mayor y vencimiento en la vista sin costos.
select set_config('request.jwt.claim.sub', '0f200000-0000-4000-8000-00000000000a', true),
       set_config('request.jwt.claims', '{"sub":"0f200000-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select public.unirse_con_codigo(current_setting('prueba.cod_p'));
do $$
begin
  if (select precio_mayor from public.productos_operativos
       where id = '62000000-0000-4000-8000-000000000001') <> 3700 then
    raise exception 'FALLO: el despachador no ve el precio por mayor';
  end if;
  if (select vence from public.productos_operativos
       where id = '62000000-0000-4000-8000-000000000002') <> '2026-12-15' then
    raise exception 'FALLO: el despachador no ve el vencimiento';
  end if;
  if (select count(*) from public.productos) <> 0 then
    raise exception 'FALLO: el despachador lee la tabla con costos';
  end if;
end $$;

rollback;
\echo 'OK: productos (por mayor, vencimiento y unidades)'
