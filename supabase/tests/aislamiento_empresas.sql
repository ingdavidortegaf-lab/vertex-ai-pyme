-- Prueba de aislamiento entre empresas (RLS) y de «solo se agregan».
--
-- Corre contra una base LOCAL creada con las migraciones de
-- supabase/migrations/ (`supabase start`), nunca contra el proyecto real:
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
--        -v ON_ERROR_STOP=1 -f supabase/tests/aislamiento_empresas.sql
--
-- Crea dos usuarios (el trigger les crea la empresa A y la B), actúa como
-- cada uno con el rol `authenticated` y comprueba que:
--   1. B no ve nada de A (empresas, miembros, clientes, ventas, productos,
--      inventario);
--   2. B no puede insertar filas a nombre de A ni editar las de A;
--   3. ventas e inventario no se pueden editar ni borrar, ni siquiera por su
--      propia empresa.
-- Si algo falla, el script se detiene con «FALLO: …».

\set ON_ERROR_STOP on
begin;

-- ---------------------------------------------------------------- usuarios
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'a@prueba.local', '', now(), now(), '{}', '{}'),
  ('bbbbbbbb-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'b@prueba.local', '', now(), now(), '{}', '{}');

do $$
begin
  if (select count(*) from public.miembros
      where user_id in ('aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002')) <> 2
     or (select count(distinct empresa_id) from public.miembros
         where user_id in ('aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002')) <> 2 then
    raise exception 'FALLO: el trigger no creó una empresa distinta para cada usuario';
  end if;
end $$;

-- La empresa de A se guarda en una variable de la sesión para compararla
-- después, cuando B ya no la puede ver.
select set_config('prueba.empresa_a',
  (select empresa_id::text from public.miembros
   where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'), true);

-- ---------------------------------------------------- A crea sus datos
set local role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);

insert into public.clientes (id, nombre, nombre_ts, telefono, telefono_ts, deleted, deleted_ts, updated_at)
values ('c0000000-0000-0000-0000-00000000000a', 'Cliente de A', now(), '', now(), false, now(), now());
insert into public.ventas (id, concepto, monto, tipo, credito, fecha)
values ('d0000000-0000-0000-0000-00000000000a', 'Venta de A', 10000, 'ingreso', false, now());
insert into public.productos (id, nombre, nombre_ts, precio, precio_ts, costo, costo_ts,
                              minimo, minimo_ts, deleted, deleted_ts, updated_at)
values ('e0000000-0000-0000-0000-00000000000a', 'Producto de A', now(), 2500, now(), 2000, now(),
        0, now(), false, now(), now());
insert into public.inventario (id, producto_id, cantidad, motivo, fecha)
values ('f0000000-0000-0000-0000-00000000000a', 'e0000000-0000-0000-0000-00000000000a', 10, 'entrada', now());

do $$
begin
  if (select count(*) from public.clientes) <> 1 or (select count(*) from public.ventas) <> 1
     or (select count(*) from public.productos) <> 1 or (select count(*) from public.inventario) <> 1 then
    raise exception 'FALLO: A no ve sus propios datos';
  end if;
  if (select empresa_id from public.clientes) <> current_setting('prueba.empresa_a')::uuid then
    raise exception 'FALLO: el cliente de A no quedó en la empresa de A';
  end if;
end $$;

-- Ventas e inventario solo se agregan: ni la misma empresa puede editarlos.
do $$
declare n int;
begin
  update public.ventas set monto = 1 where id = 'd0000000-0000-0000-0000-00000000000a';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLO: se pudo editar una venta'; end if;
  delete from public.ventas where id = 'd0000000-0000-0000-0000-00000000000a';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLO: se pudo borrar una venta'; end if;
  update public.inventario set cantidad = 99 where id = 'f0000000-0000-0000-0000-00000000000a';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLO: se pudo editar un movimiento de inventario'; end if;
  delete from public.inventario where id = 'f0000000-0000-0000-0000-00000000000a';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLO: se pudo borrar un movimiento de inventario'; end if;
end $$;

-- ------------------------------------------------------- B intenta leer
select set_config('request.jwt.claim.sub', 'bbbbbbbb-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);

do $$
declare a uuid := current_setting('prueba.empresa_a')::uuid;
begin
  if exists (select 1 from public.empresas where id = a) then
    raise exception 'FALLO: B ve la empresa de A';
  end if;
  if exists (select 1 from public.miembros where empresa_id = a) then
    raise exception 'FALLO: B ve los miembros de A';
  end if;
  if (select count(*) from public.clientes) + (select count(*) from public.ventas)
     + (select count(*) from public.productos) + (select count(*) from public.inventario) <> 0 then
    raise exception 'FALLO: B ve clientes, ventas, productos o inventario de A';
  end if;
end $$;

-- ---------------------------------------------- B intenta escribir en A
do $$
declare a uuid := current_setting('prueba.empresa_a')::uuid;
        n int;
begin
  -- Insertar a nombre de A: la política lo rechaza (42501).
  begin
    insert into public.clientes (id, empresa_id, nombre, nombre_ts, telefono, telefono_ts,
                                 deleted, deleted_ts, updated_at)
    values (gen_random_uuid(), a, 'Intruso', now(), '', now(), false, now(), now());
    raise exception 'FALLO: B insertó un cliente en la empresa de A';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.ventas (id, empresa_id, concepto, monto, tipo, credito, fecha)
    values (gen_random_uuid(), a, 'Intruso', 1, 'ingreso', false, now());
    raise exception 'FALLO: B insertó una venta en la empresa de A';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.productos (id, empresa_id, nombre, nombre_ts, precio, precio_ts, costo, costo_ts,
                                  minimo, minimo_ts, deleted, deleted_ts, updated_at)
    values (gen_random_uuid(), a, 'Intruso', now(), 1, now(), 1, now(), 0, now(), false, now(), now());
    raise exception 'FALLO: B insertó un producto en la empresa de A';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.inventario (id, empresa_id, producto_id, cantidad, motivo, fecha)
    values (gen_random_uuid(), a, 'e0000000-0000-0000-0000-00000000000a', 5, 'entrada', now());
    raise exception 'FALLO: B insertó inventario en la empresa de A';
  exception when insufficient_privilege then null;
  end;

  -- Editar las filas de A: la política no las deja ver, así que no cambia nada.
  update public.clientes set nombre = 'Cambiado por B' where id = 'c0000000-0000-0000-0000-00000000000a';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLO: B editó un cliente de A'; end if;
  update public.productos set precio = 1 where id = 'e0000000-0000-0000-0000-00000000000a';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALLO: B editó un producto de A'; end if;
end $$;

-- B sí puede trabajar en su propia empresa.
insert into public.clientes (id, nombre, nombre_ts, telefono, telefono_ts, deleted, deleted_ts, updated_at)
values ('c0000000-0000-0000-0000-00000000000b', 'Cliente de B', now(), '', now(), false, now(), now());

-- ------------------------------------- A sigue sin ver lo de B, y su dato intacto
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
do $$
begin
  if exists (select 1 from public.clientes where id = 'c0000000-0000-0000-0000-00000000000b') then
    raise exception 'FALLO: A ve el cliente de B';
  end if;
  if (select nombre from public.clientes where id = 'c0000000-0000-0000-0000-00000000000a') <> 'Cliente de A' then
    raise exception 'FALLO: el cliente de A fue modificado por B';
  end if;
end $$;

reset role;
rollback;

\echo 'OK: la empresa A y la B están aisladas, y ventas e inventario solo se agregan.'
