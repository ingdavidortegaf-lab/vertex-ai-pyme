-- VERTEX AI Pyme · esquema para Supabase (plan gratuito).
-- Ejecutar COMPLETO en Supabase > SQL Editor > New query > Run.
-- Es idempotente: se puede volver a ejecutar sin perder datos.
--
-- Si ejecutaste una versión ANTERIOR de este archivo (tablas sin empresa_id),
-- borra primero esas tablas de prueba:
--   drop table if exists public.ventas, public.clientes cascade;

-- ===================================================== empresas y miembros
-- Cada usuario pertenece a una empresa; todos los datos se separan por
-- empresa (RLS). Al crear un usuario se le crea su empresa automáticamente.
create table if not exists public.empresas(
  id uuid primary key default gen_random_uuid(),
  nombre text not null default 'Mi empresa',
  creado_at timestamptz not null default now()
);

create table if not exists public.miembros(
  empresa_id uuid not null references public.empresas(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rol text not null default 'admin' check (rol in ('admin','vendedor')),
  primary key (empresa_id, user_id)
);
create unique index if not exists miembros_un_usuario on public.miembros(user_id);

-- Empresa del usuario que hace la petición. Vive en un esquema privado que
-- la API REST no expone (no se puede llamar por /rest/v1/rpc).
create schema if not exists privado;
revoke all on schema privado from public, anon;
grant usage on schema privado to authenticated;

create or replace function privado.mi_empresa() returns uuid
language sql stable security definer set search_path = public as $$
  select empresa_id from public.miembros where user_id = auth.uid() limit 1
$$;
revoke all on function privado.mi_empresa() from public, anon;
grant execute on function privado.mi_empresa() to authenticated;

create or replace function public.crear_empresa_para_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
declare e uuid;
begin
  insert into public.empresas(nombre) values ('Mi empresa') returning id into e;
  insert into public.miembros(empresa_id, user_id, rol) values (e, new.id, 'admin');
  return new;
end $$;
revoke all on function public.crear_empresa_para_usuario() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.crear_empresa_para_usuario();

-- Usuarios creados ANTES de este script: también reciben su empresa.
do $$
declare u record; e uuid;
begin
  for u in select id from auth.users
           where id not in (select user_id from public.miembros) loop
    insert into public.empresas(nombre) values ('Mi empresa') returning id into e;
    insert into public.miembros(empresa_id, user_id, rol) values (e, u.id, 'admin');
  end loop;
end $$;

-- ================================================================ clientes
-- Conflictos: gana el cambio más reciente DE CADA CAMPO (marca por campo).
create table if not exists public.clientes(
  id uuid primary key,
  empresa_id uuid not null default privado.mi_empresa() references public.empresas(id),
  nombre text not null check (char_length(nombre) between 1 and 80),
  nombre_ts timestamptz not null,
  telefono text not null default '' check (telefono ~ '^(57[0-9]{10})?$'),
  telefono_ts timestamptz not null,
  deleted boolean not null default false,
  deleted_ts timestamptz not null,
  updated_at timestamptz not null,
  creado_por uuid default auth.uid(),
  recibido_at timestamptz not null default now()
);
create index if not exists clientes_empresa_idx on public.clientes(empresa_id, recibido_at);

create or replace function public.merge_cliente() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.nombre_ts < old.nombre_ts then
    new.nombre := old.nombre; new.nombre_ts := old.nombre_ts;
  end if;
  if new.telefono_ts < old.telefono_ts then
    new.telefono := old.telefono; new.telefono_ts := old.telefono_ts;
  end if;
  if new.deleted_ts < old.deleted_ts then
    new.deleted := old.deleted; new.deleted_ts := old.deleted_ts;
  end if;
  new.updated_at := greatest(new.nombre_ts, new.telefono_ts, new.deleted_ts);
  new.empresa_id := old.empresa_id;   -- un cliente no cambia de empresa
  new.creado_por := old.creado_por;
  new.recibido_at := now();           -- para que otros celulares lo descarguen
  return new;
end $$;
drop trigger if exists clientes_merge on public.clientes;
create trigger clientes_merge before update on public.clientes
  for each row execute function public.merge_cliente();

-- ================================================ ventas, gastos y abonos
-- Solo se agregan: no hay política de UPDATE ni DELETE (el servidor lo
-- impide aunque alguien lo intente).
create table if not exists public.ventas(
  id uuid primary key,
  empresa_id uuid not null default privado.mi_empresa() references public.empresas(id),
  cliente_id uuid,
  concepto text not null check (char_length(concepto) between 1 and 120),
  monto numeric(14,2) not null check (monto > 0),
  tipo text not null check (tipo in ('ingreso','egreso','abono')),
  credito boolean not null default false,
  fecha timestamptz not null,
  creado_por uuid default auth.uid(),
  recibido_at timestamptz not null default now(),
  check (not credito or tipo = 'ingreso'),
  check (tipo = 'egreso' or not (credito or tipo = 'abono') or cliente_id is not null)
);
create index if not exists ventas_empresa_idx on public.ventas(empresa_id, recibido_at);
create index if not exists ventas_empresa_fecha_idx on public.ventas(empresa_id, fecha desc);

-- ======================================================== seguridad (RLS)
alter table public.empresas enable row level security;
alter table public.miembros enable row level security;
alter table public.clientes enable row level security;
alter table public.ventas   enable row level security;

-- Las funciones van dentro de (select ...) para que se evalúen una vez por
-- consulta y no una vez por fila.
alter table public.clientes alter column empresa_id set default privado.mi_empresa();
alter table public.ventas   alter column empresa_id set default privado.mi_empresa();

drop policy if exists "ver mi empresa" on public.empresas;
create policy "ver mi empresa" on public.empresas for select to authenticated
  using (id = (select privado.mi_empresa()));

drop policy if exists "ver mi membresia" on public.miembros;
create policy "ver mi membresia" on public.miembros for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "clientes ver"     on public.clientes;
drop policy if exists "clientes crear"   on public.clientes;
drop policy if exists "clientes editar"  on public.clientes;
create policy "clientes ver" on public.clientes for select to authenticated
  using (empresa_id = (select privado.mi_empresa()));
create policy "clientes crear" on public.clientes for insert to authenticated
  with check (empresa_id = (select privado.mi_empresa()));
create policy "clientes editar" on public.clientes for update to authenticated
  using (empresa_id = (select privado.mi_empresa()))
  with check (empresa_id = (select privado.mi_empresa()));

drop policy if exists "ventas ver"   on public.ventas;
drop policy if exists "ventas crear" on public.ventas;
create policy "ventas ver" on public.ventas for select to authenticated
  using (empresa_id = (select privado.mi_empresa()));
create policy "ventas crear" on public.ventas for insert to authenticated
  with check (empresa_id = (select privado.mi_empresa()));

-- Nadie anónimo toca las tablas.
revoke all on public.empresas, public.miembros, public.clientes, public.ventas from anon;

-- Versión anterior de la función, que estaba expuesta en la API pública.
drop function if exists public.mi_empresa();

-- ============================================================ inventario
-- Productos: gana el cambio más reciente de cada campo (trigger
-- merge_producto). El stock NO se guarda: es la suma de los movimientos de
-- inventario, que solo se agregan (dos celulares sin señal nunca se pisan).
create table if not exists public.productos(
  id uuid primary key,
  empresa_id uuid not null default privado.mi_empresa() references public.empresas(id),
  nombre text not null check (char_length(nombre) between 1 and 80),
  nombre_ts timestamptz not null,
  precio numeric(14,2) not null default 0 check (precio >= 0),
  precio_ts timestamptz not null,
  costo numeric(14,2) not null default 0 check (costo >= 0),
  costo_ts timestamptz not null,
  minimo numeric(12,3) not null default 0 check (minimo >= 0),
  minimo_ts timestamptz not null,
  deleted boolean not null default false,
  deleted_ts timestamptz not null,
  updated_at timestamptz not null,
  creado_por uuid default auth.uid(),
  recibido_at timestamptz not null default now()
);
create index if not exists productos_empresa_idx on public.productos(empresa_id, recibido_at);

create or replace function public.merge_producto() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.nombre_ts < old.nombre_ts then new.nombre := old.nombre; new.nombre_ts := old.nombre_ts; end if;
  if new.precio_ts < old.precio_ts then new.precio := old.precio; new.precio_ts := old.precio_ts; end if;
  if new.costo_ts < old.costo_ts then new.costo := old.costo; new.costo_ts := old.costo_ts; end if;
  if new.minimo_ts < old.minimo_ts then new.minimo := old.minimo; new.minimo_ts := old.minimo_ts; end if;
  if new.deleted_ts < old.deleted_ts then new.deleted := old.deleted; new.deleted_ts := old.deleted_ts; end if;
  new.updated_at := greatest(new.nombre_ts, new.precio_ts, new.costo_ts, new.minimo_ts, new.deleted_ts);
  new.empresa_id := old.empresa_id;
  new.creado_por := old.creado_por;
  new.recibido_at := now();
  return new;
end $$;
drop trigger if exists productos_merge on public.productos;
create trigger productos_merge before update on public.productos
  for each row execute function public.merge_producto();

create table if not exists public.inventario(
  id uuid primary key,
  empresa_id uuid not null default privado.mi_empresa() references public.empresas(id),
  producto_id uuid not null,
  cantidad numeric(12,3) not null check (cantidad <> 0),
  motivo text not null check (motivo in ('venta','entrada','ajuste')),
  venta_id uuid,
  precio_unit numeric(14,2),
  costo_unit numeric(14,2),
  fecha timestamptz not null,
  creado_por uuid default auth.uid(),
  recibido_at timestamptz not null default now(),
  check (motivo <> 'entrada' or cantidad > 0),
  check (motivo <> 'venta' or cantidad < 0)
);
create index if not exists inventario_empresa_idx on public.inventario(empresa_id, recibido_at);
create index if not exists inventario_producto_idx on public.inventario(empresa_id, producto_id);

alter table public.productos enable row level security;
alter table public.inventario enable row level security;

drop policy if exists "productos ver" on public.productos;
drop policy if exists "productos crear" on public.productos;
drop policy if exists "productos editar" on public.productos;
create policy "productos ver" on public.productos for select to authenticated
  using (empresa_id = (select privado.mi_empresa()));
create policy "productos crear" on public.productos for insert to authenticated
  with check (empresa_id = (select privado.mi_empresa()));
create policy "productos editar" on public.productos for update to authenticated
  using (empresa_id = (select privado.mi_empresa()))
  with check (empresa_id = (select privado.mi_empresa()));

-- Inventario: solo se agrega (sin UPDATE ni DELETE).
drop policy if exists "inventario ver" on public.inventario;
drop policy if exists "inventario crear" on public.inventario;
create policy "inventario ver" on public.inventario for select to authenticated
  using (empresa_id = (select privado.mi_empresa()));
create policy "inventario crear" on public.inventario for insert to authenticated
  with check (empresa_id = (select privado.mi_empresa()));

revoke all on public.productos, public.inventario from anon;
-- v4: código de barras y unidad de venta (und, kg, lb) por producto, también
-- unidos campo por campo.
alter table public.productos add column if not exists codigo text not null default '' check (char_length(codigo) <= 40);
alter table public.productos add column if not exists codigo_ts timestamptz not null default 'epoch';
alter table public.productos add column if not exists unidad text not null default 'und' check (unidad in ('und','kg','lb'));
alter table public.productos add column if not exists unidad_ts timestamptz not null default 'epoch';

create or replace function public.merge_producto() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.nombre_ts < old.nombre_ts then new.nombre := old.nombre; new.nombre_ts := old.nombre_ts; end if;
  if new.precio_ts < old.precio_ts then new.precio := old.precio; new.precio_ts := old.precio_ts; end if;
  if new.costo_ts < old.costo_ts then new.costo := old.costo; new.costo_ts := old.costo_ts; end if;
  if new.minimo_ts < old.minimo_ts then new.minimo := old.minimo; new.minimo_ts := old.minimo_ts; end if;
  if new.deleted_ts < old.deleted_ts then new.deleted := old.deleted; new.deleted_ts := old.deleted_ts; end if;
  if new.codigo_ts < old.codigo_ts then new.codigo := old.codigo; new.codigo_ts := old.codigo_ts; end if;
  if new.unidad_ts < old.unidad_ts then new.unidad := old.unidad; new.unidad_ts := old.unidad_ts; end if;
  new.updated_at := greatest(new.nombre_ts, new.precio_ts, new.costo_ts, new.minimo_ts,
                             new.deleted_ts, new.codigo_ts, new.unidad_ts);
  new.empresa_id := old.empresa_id;
  new.creado_por := old.creado_por;
  new.recibido_at := now();
  return new;
end $$;
-- v5: servicios (unidad 'serv'): se venden sin llevar inventario
-- (peluquería, taller, domicilios, asesorías…).
alter table public.productos drop constraint if exists productos_unidad_check;
alter table public.productos add constraint productos_unidad_check
  check (unidad in ('und','kg','lb','serv'));

-- v6: medios de pago por movimiento (pago dividido).
-- pagos = [{"medio": "nequi", "monto": 20000}, {"medio": "efectivo", "monto": 5000}]
-- La suma debe ser igual al monto. La venta fiada no lleva pagos.
-- Los movimientos anteriores quedan con pagos = null (se leen como efectivo).
create or replace function privado.pagos_validos(p jsonb, monto numeric, tipo text, credito boolean)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case
    when p is null then true
    when tipo = 'ingreso' and credito then false
    when jsonb_typeof(p) <> 'array' or jsonb_array_length(p) = 0 or jsonb_array_length(p) > 7 then false
    else (
      select bool_and(
               jsonb_typeof(e) = 'object'
               and e->>'medio' in ('efectivo','nequi','daviplata','bancolombia','transferencia','tarjeta_debito','tarjeta_credito')
               and jsonb_typeof(e->'monto') = 'number'
               and (e->>'monto')::numeric > 0)
             and abs(sum((e->>'monto')::numeric) - monto) <= 1
      from jsonb_array_elements(p) e)
  end
$$;
revoke all on function privado.pagos_validos(jsonb, numeric, text, boolean) from public, anon;
grant execute on function privado.pagos_validos(jsonb, numeric, text, boolean) to authenticated;

alter table public.ventas add column if not exists pagos jsonb;
alter table public.ventas drop constraint if exists ventas_pagos_validos;
alter table public.ventas add constraint ventas_pagos_validos
  check (privado.pagos_validos(pagos, monto, tipo, credito));
