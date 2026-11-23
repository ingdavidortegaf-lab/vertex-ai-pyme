-- Prueba de roles, invitaciones y RLS por rol. Corre contra una base LOCAL
-- creada con supabase/migrations/ (`supabase start`), nunca contra el
-- proyecto real:
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
--        -v ON_ERROR_STOP=1 -f supabase/tests/roles_y_permisos.sql
-- Todo va en una transacción que se deshace al final. Si algo falla, se
-- detiene con «FALLO: …».

\set ON_ERROR_STOP on
begin;

-- Usuarios: D dueño, P despachador, C contador, B bodeguero, A administrador
-- y E, que ya tiene su propio negocio con datos.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
select u.id::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       u.email, '', now(), now(), '{}', '{}'
from (values
  ('d0000000-0000-4000-8000-00000000000d', 'duena@prueba.local'),
  ('0f000000-0000-4000-8000-00000000000a', 'despachador@prueba.local'),
  ('c0000000-0000-4000-8000-00000000000c', 'contador@prueba.local'),
  ('b0000000-0000-4000-8000-00000000000b', 'bodeguero@prueba.local'),
  ('a0000000-0000-4000-8000-0000000000aa', 'admin@prueba.local'),
  ('e0000000-0000-4000-8000-00000000000e', 'otra@prueba.local')
) as u(id, email);

do $$
begin
  if (select count(*) from public.miembros where rol = 'dueno'
      and user_id::text in ('d0000000-0000-4000-8000-00000000000d','0f000000-0000-4000-8000-00000000000a',
        'c0000000-0000-4000-8000-00000000000c','b0000000-0000-4000-8000-00000000000b',
        'a0000000-0000-4000-8000-0000000000aa','e0000000-0000-4000-8000-00000000000e')) <> 6 then
    raise exception 'FALLO: cada usuario nuevo debe quedar como dueño de su propio negocio';
  end if;
end $$;

set local role authenticated;

-- ----------------------------------------------- E: su negocio ya tiene datos
select set_config('request.jwt.claim.sub', 'e0000000-0000-4000-8000-00000000000e', true),
       set_config('request.jwt.claims', '{"sub":"e0000000-0000-4000-8000-00000000000e","role":"authenticated"}', true);
insert into public.clientes (id, nombre, nombre_ts, telefono, telefono_ts, deleted, deleted_ts, updated_at)
values (gen_random_uuid(), 'Cliente de E', now(), '', now(), false, now(), now());

-- ------------------------------------------- D: datos e invitaciones
select set_config('request.jwt.claim.sub', 'd0000000-0000-4000-8000-00000000000d', true),
       set_config('request.jwt.claims', '{"sub":"d0000000-0000-4000-8000-00000000000d","role":"authenticated"}', true);
insert into public.productos (id, nombre, nombre_ts, precio, precio_ts, costo, costo_ts,
                              minimo, minimo_ts, deleted, deleted_ts, updated_at)
values ('11111111-0000-4000-8000-000000000001', 'Arroz', now(), 2500, now(), 2000, now(), 0, now(), false, now(), now());
insert into public.inventario (id, producto_id, cantidad, motivo, costo_unit, fecha)
values (gen_random_uuid(), '11111111-0000-4000-8000-000000000001', 50, 'entrada', 2000, now());
insert into public.ventas (id, concepto, monto, tipo, credito, fecha)
values (gen_random_uuid(), 'Venta', 5000, 'ingreso', false, now()),
       (gen_random_uuid(), 'Arriendo', 900000, 'egreso', false, now());
insert into public.clientes (id, nombre, nombre_ts, telefono, telefono_ts, deleted, deleted_ts, updated_at)
values ('22222222-0000-4000-8000-000000000002', 'Cliente de D', now(), '', now(), false, now(), now());

select set_config('prueba.cod_p', public.crear_invitacion('despachador'), true),
       set_config('prueba.cod_c', public.crear_invitacion('contador'), true),
       set_config('prueba.cod_b', public.crear_invitacion('bodeguero'), true),
       set_config('prueba.cod_a', public.crear_invitacion('administrador'), true),
       set_config('prueba.cod_e', public.crear_invitacion('despachador'), true),
       set_config('prueba.empresa_d', (public.mi_contexto()->>'empresa_id'), true);

do $$
begin
  if current_setting('prueba.cod_p') !~ '^[A-Z0-9]{8}$' then
    raise exception 'FALLO: el código de invitación no tiene 8 caracteres';
  end if;
  begin
    perform public.crear_invitacion('dueno');
    raise exception 'FALLO: se pudo invitar a alguien como dueño';
  exception when invalid_parameter_value then null;
  end;
end $$;

-- ---------------------------------------------------------------- uniones
select set_config('request.jwt.claim.sub', '0f000000-0000-4000-8000-00000000000a', true),
       set_config('request.jwt.claims', '{"sub":"0f000000-0000-4000-8000-00000000000a","role":"authenticated"}', true);
do $$
declare r jsonb;
begin
  r := public.unirse_con_codigo(lower(current_setting('prueba.cod_p')));
  if r->>'rol' <> 'despachador' or r->>'empresa_id' <> current_setting('prueba.empresa_d') then
    raise exception 'FALLO: el despachador no quedó en el negocio de D: %', r;
  end if;
end $$;

select set_config('request.jwt.claim.sub', 'c0000000-0000-4000-8000-00000000000c', true),
       set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-00000000000c","role":"authenticated"}', true);
do $$
begin
  begin
    perform public.unirse_con_codigo(current_setting('prueba.cod_p'));
    raise exception 'FALLO: un código ya usado sirvió otra vez';
  exception when invalid_parameter_value then null;
  end;
  perform public.unirse_con_codigo(current_setting('prueba.cod_c'));
end $$;

select set_config('request.jwt.claim.sub', 'b0000000-0000-4000-8000-00000000000b', true),
       set_config('request.jwt.claims', '{"sub":"b0000000-0000-4000-8000-00000000000b","role":"authenticated"}', true);
select public.unirse_con_codigo(current_setting('prueba.cod_b'));

select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-0000000000aa', true),
       set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-0000000000aa","role":"authenticated"}', true);
select public.unirse_con_codigo(current_setting('prueba.cod_a'));

select set_config('request.jwt.claim.sub', 'e0000000-0000-4000-8000-00000000000e', true),
       set_config('request.jwt.claims', '{"sub":"e0000000-0000-4000-8000-00000000000e","role":"authenticated"}', true);
do $$
begin
  begin
    perform public.unirse_con_codigo(current_setting('prueba.cod_e'));
    raise exception 'FALLO: una cuenta con datos dejó su negocio para unirse a otro';
  exception when invalid_parameter_value then null;
  end;
  if (select count(*) from public.clientes) <> 1 then
    raise exception 'FALLO: E perdió sus datos';
  end if;
end $$;

-- ------------------------------------------- P: despachador (sin fiado)
select set_config('request.jwt.claim.sub', '0f000000-0000-4000-8000-00000000000a', true),
       set_config('request.jwt.claims', '{"sub":"0f000000-0000-4000-8000-00000000000a","role":"authenticated"}', true);
do $$
declare n int;
begin
  if (select count(*) from public.ventas where tipo = 'egreso') <> 0 then
    raise exception 'FALLO: el despachador ve gastos';
  end if;
  if (select count(*) from public.ventas where tipo = 'ingreso') <> 1 then
    raise exception 'FALLO: el despachador no ve las ventas';
  end if;
  if (select count(*) from public.productos) <> 0 or (select count(*) from public.inventario) <> 0 then
    raise exception 'FALLO: el despachador lee las tablas con costos';
  end if;
  if (select count(*) from public.productos_operativos) <> 1 or (select count(*) from public.inventario_operativo) <> 1 then
    raise exception 'FALLO: el despachador no ve precios ni stock en las vistas operativas';
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name in ('productos_operativos','inventario_operativo')
               and column_name in ('costo','costo_ts','costo_unit')) then
    raise exception 'FALLO: las vistas operativas muestran costos';
  end if;
  if (select count(*) from public.clientes) <> 0 then
    raise exception 'FALLO: el despachador ve clientes sin tener fiado';
  end if;

  insert into public.ventas (id, concepto, monto, tipo, credito, fecha)
  values (gen_random_uuid(), 'Venta de contado', 3000, 'ingreso', false, now());
  begin
    insert into public.ventas (id, concepto, monto, tipo, credito, fecha)
    values (gen_random_uuid(), 'Gasto', 1000, 'egreso', false, now());
    raise exception 'FALLO: el despachador registró un gasto';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.ventas (id, cliente_id, concepto, monto, tipo, credito, fecha)
    values (gen_random_uuid(), '22222222-0000-4000-8000-000000000002', 'Fiado', 1000, 'ingreso', true, now());
    raise exception 'FALLO: el despachador fió sin permiso del dueño';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.ventas (id, concepto, monto, tipo, credito, fecha, creado_por)
    values (gen_random_uuid(), 'Suplantada', 1000, 'ingreso', false, now(), 'd0000000-0000-4000-8000-00000000000d');
    raise exception 'FALLO: el despachador registró una venta a nombre de otra persona';
  exception when insufficient_privilege then null;
  end;

  insert into public.inventario (id, producto_id, cantidad, motivo, fecha)
  values (gen_random_uuid(), '11111111-0000-4000-8000-000000000001', 10, 'entrada', now());
  -- Aunque mande un costo, el servidor pone el del producto (2000).
  insert into public.inventario (id, producto_id, cantidad, motivo, costo_unit, fecha)
  values ('33333333-0000-4000-8000-000000000003', '11111111-0000-4000-8000-000000000001', 10, 'entrada', 1, now());
  begin
    insert into public.inventario (id, producto_id, cantidad, motivo, fecha)
    values (gen_random_uuid(), '11111111-0000-4000-8000-000000000001', -3, 'ajuste', now());
    raise exception 'FALLO: el despachador hizo un ajuste de inventario';
  exception when insufficient_privilege then null;
  end;

  update public.productos set precio = 1 where id = '11111111-0000-4000-8000-000000000001';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLO: el despachador cambió un precio'; end if;

  begin
    perform public.crear_invitacion('despachador');
    raise exception 'FALLO: el despachador creó una invitación';
  exception when insufficient_privilege then null;
  end;
  begin
    perform * from public.equipo();
    raise exception 'FALLO: el despachador vio el equipo';
  exception when insufficient_privilege then null;
  end;
  if (public.mi_contexto()->>'rol') <> 'despachador' then
    raise exception 'FALLO: mi_contexto no devuelve el rol';
  end if;
end $$;

-- ------------------------------------------- D activa el fiado del despachador
select set_config('request.jwt.claim.sub', 'd0000000-0000-4000-8000-00000000000d', true),
       set_config('request.jwt.claims', '{"sub":"d0000000-0000-4000-8000-00000000000d","role":"authenticated"}', true);
select public.definir_despachador_fia(true);

select set_config('request.jwt.claim.sub', '0f000000-0000-4000-8000-00000000000a', true),
       set_config('request.jwt.claims', '{"sub":"0f000000-0000-4000-8000-00000000000a","role":"authenticated"}', true);
do $$
begin
  if (select count(*) from public.clientes) <> 1 then
    raise exception 'FALLO: con fiado, el despachador debe ver los clientes';
  end if;
  insert into public.ventas (id, cliente_id, concepto, monto, tipo, credito, fecha)
  values (gen_random_uuid(), '22222222-0000-4000-8000-000000000002', 'Fiado', 1000, 'ingreso', true, now());
  insert into public.ventas (id, cliente_id, concepto, monto, tipo, credito, fecha)
  values (gen_random_uuid(), '22222222-0000-4000-8000-000000000002', 'Abono', 500, 'abono', false, now());
  if (select count(*) from public.ventas where tipo = 'egreso') <> 0 then
    raise exception 'FALLO: con fiado, el despachador ve gastos';
  end if;
end $$;

-- ------------------------------------------- quién atendió (perfil del celular)
do $$
begin
  insert into public.ventas (id, concepto, monto, tipo, credito, fecha, perfil)
  values (gen_random_uuid(), 'Venta de Luis', 2000, 'ingreso', false, now(), 'Luis');
  begin
    insert into public.ventas (id, concepto, monto, tipo, credito, fecha, perfil)
    values (gen_random_uuid(), 'Nombre larguísimo', 2000, 'ingreso', false, now(), repeat('x', 41));
    raise exception 'FALLO: se aceptó un nombre de perfil de más de 40 caracteres';
  exception when check_violation then null;
  end;
end $$;

-- ------------------------------------- el costo lo puso el servidor (lo ve D)
select set_config('request.jwt.claim.sub', 'd0000000-0000-4000-8000-00000000000d', true),
       set_config('request.jwt.claims', '{"sub":"d0000000-0000-4000-8000-00000000000d","role":"authenticated"}', true);
do $$
begin
  if (select costo_unit from public.inventario where id = '33333333-0000-4000-8000-000000000003') is distinct from 2000 then
    raise exception 'FALLO: el costo del inventario del despachador no es el del producto';
  end if;
end $$;

-- ------------------------------------------------------- C: contador
select set_config('request.jwt.claim.sub', 'c0000000-0000-4000-8000-00000000000c', true),
       set_config('request.jwt.claims', '{"sub":"c0000000-0000-4000-8000-00000000000c","role":"authenticated"}', true);
do $$
begin
  if (select count(*) from public.ventas where tipo = 'egreso') <> 1 or (select count(*) from public.productos) <> 1 then
    raise exception 'FALLO: el contador no ve gastos o productos con costo';
  end if;
  begin
    insert into public.ventas (id, concepto, monto, tipo, credito, fecha)
    values (gen_random_uuid(), 'Venta', 1000, 'ingreso', false, now());
    raise exception 'FALLO: el contador registró una venta';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.inventario (id, producto_id, cantidad, motivo, fecha)
    values (gen_random_uuid(), '11111111-0000-4000-8000-000000000001', 1, 'entrada', now());
    raise exception 'FALLO: el contador registró inventario';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.clientes (id, nombre, nombre_ts, telefono, telefono_ts, deleted, deleted_ts, updated_at)
    values (gen_random_uuid(), 'X', now(), '', now(), false, now(), now());
    raise exception 'FALLO: el contador creó un cliente';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ------------------------------------------------------ B: bodeguero
select set_config('request.jwt.claim.sub', 'b0000000-0000-4000-8000-00000000000b', true),
       set_config('request.jwt.claims', '{"sub":"b0000000-0000-4000-8000-00000000000b","role":"authenticated"}', true);
do $$
begin
  if (select count(*) from public.ventas) <> 0 or (select count(*) from public.productos) <> 0 then
    raise exception 'FALLO: el bodeguero ve ventas o costos';
  end if;
  if (select count(*) from public.productos_operativos) <> 1 then
    raise exception 'FALLO: el bodeguero no ve los productos';
  end if;
  insert into public.inventario (id, producto_id, cantidad, motivo, fecha)
  values (gen_random_uuid(), '11111111-0000-4000-8000-000000000001', -2, 'ajuste', now());
  begin
    insert into public.ventas (id, concepto, monto, tipo, credito, fecha)
    values (gen_random_uuid(), 'Venta', 1000, 'ingreso', false, now());
    raise exception 'FALLO: el bodeguero registró una venta';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ------------------------------------------------- A: administrador
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-0000000000aa', true),
       set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-0000000000aa","role":"authenticated"}', true);
do $$
declare n int;
begin
  update public.productos set precio = 2600, precio_ts = now() where id = '11111111-0000-4000-8000-000000000001';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLO: el administrador no pudo cambiar un precio'; end if;
  if (select count(*) from public.equipo()) <> 5 then
    raise exception 'FALLO: el administrador debe ver a los 5 del equipo';
  end if;
  begin
    perform public.crear_invitacion('contador');
    raise exception 'FALLO: el administrador creó una invitación';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.cambiar_rol('0f000000-0000-4000-8000-00000000000a', 'contador');
    raise exception 'FALLO: el administrador cambió un rol';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ------------------------------------------ D: cambia roles y quita a B
select set_config('request.jwt.claim.sub', 'd0000000-0000-4000-8000-00000000000d', true),
       set_config('request.jwt.claims', '{"sub":"d0000000-0000-4000-8000-00000000000d","role":"authenticated"}', true);
do $$
begin
  perform public.cambiar_rol('0f000000-0000-4000-8000-00000000000a', 'bodeguero');
  if (select rol from public.miembros where user_id = '0f000000-0000-4000-8000-00000000000a') <> 'bodeguero' then
    raise exception 'FALLO: el dueño no pudo cambiar el rol';
  end if;
  begin
    perform public.cambiar_rol('d0000000-0000-4000-8000-00000000000d', 'contador');
    raise exception 'FALLO: el dueño se cambió su propio rol';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.cambiar_rol('a0000000-0000-4000-8000-0000000000aa', 'dueno');
    raise exception 'FALLO: se nombró un segundo dueño';
  exception when invalid_parameter_value then null;
  end;
  perform public.quitar_miembro('b0000000-0000-4000-8000-00000000000b');
end $$;

select set_config('request.jwt.claim.sub', 'b0000000-0000-4000-8000-00000000000b', true),
       set_config('request.jwt.claims', '{"sub":"b0000000-0000-4000-8000-00000000000b","role":"authenticated"}', true);
do $$
begin
  if (public.mi_contexto()->>'rol') <> 'dueno'
     or (public.mi_contexto()->>'empresa_id') = current_setting('prueba.empresa_d') then
    raise exception 'FALLO: quien sale del equipo debe quedar con un negocio propio';
  end if;
  if (select count(*) from public.productos_operativos) <> 0 then
    raise exception 'FALLO: quien salió del equipo sigue viendo los productos del negocio';
  end if;
end $$;

reset role;
rollback;

\echo 'OK: roles, invitaciones y permisos por rol funcionan en el servidor.'
