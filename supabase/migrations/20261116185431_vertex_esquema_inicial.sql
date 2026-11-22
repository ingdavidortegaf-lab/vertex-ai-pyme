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

create or replace function public.mi_empresa() returns uuid
language sql stable security definer set search_path = public as $$
  select empresa_id from public.miembros where user_id = auth.uid() limit 1
$$;
revoke all on function public.mi_empresa() from public, anon;
grant execute on function public.mi_empresa() to authenticated;

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

do $$
declare u record; e uuid;
begin
  for u in select id from auth.users
           where id not in (select user_id from public.miembros) loop
    insert into public.empresas(nombre) values ('Mi empresa') returning id into e;
    insert into public.miembros(empresa_id, user_id, rol) values (e, u.id, 'admin');
  end loop;
end $$;

create table if not exists public.clientes(
  id uuid primary key,
  empresa_id uuid not null default public.mi_empresa() references public.empresas(id),
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
  new.empresa_id := old.empresa_id;
  new.creado_por := old.creado_por;
  new.recibido_at := now();
  return new;
end $$;
drop trigger if exists clientes_merge on public.clientes;
create trigger clientes_merge before update on public.clientes
  for each row execute function public.merge_cliente();

create table if not exists public.ventas(
  id uuid primary key,
  empresa_id uuid not null default public.mi_empresa() references public.empresas(id),
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

alter table public.empresas enable row level security;
alter table public.miembros enable row level security;
alter table public.clientes enable row level security;
alter table public.ventas   enable row level security;

drop policy if exists "ver mi empresa" on public.empresas;
create policy "ver mi empresa" on public.empresas for select to authenticated
  using (id = public.mi_empresa());

drop policy if exists "ver mi membresia" on public.miembros;
create policy "ver mi membresia" on public.miembros for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "clientes ver"     on public.clientes;
drop policy if exists "clientes crear"   on public.clientes;
drop policy if exists "clientes editar"  on public.clientes;
create policy "clientes ver" on public.clientes for select to authenticated
  using (empresa_id = public.mi_empresa());
create policy "clientes crear" on public.clientes for insert to authenticated
  with check (empresa_id = public.mi_empresa());
create policy "clientes editar" on public.clientes for update to authenticated
  using (empresa_id = public.mi_empresa())
  with check (empresa_id = public.mi_empresa());

drop policy if exists "ventas ver"   on public.ventas;
drop policy if exists "ventas crear" on public.ventas;
create policy "ventas ver" on public.ventas for select to authenticated
  using (empresa_id = public.mi_empresa());
create policy "ventas crear" on public.ventas for insert to authenticated
  with check (empresa_id = public.mi_empresa());

revoke all on public.empresas, public.miembros, public.clientes, public.ventas from anon;
