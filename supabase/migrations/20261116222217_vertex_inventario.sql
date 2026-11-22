-- Productos: gana el cambio más reciente de cada campo.
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

-- Movimientos de inventario: solo se agregan (stock = suma de cantidades).
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

drop policy if exists "inventario ver" on public.inventario;
drop policy if exists "inventario crear" on public.inventario;
create policy "inventario ver" on public.inventario for select to authenticated
  using (empresa_id = (select privado.mi_empresa()));
create policy "inventario crear" on public.inventario for insert to authenticated
  with check (empresa_id = (select privado.mi_empresa()));

revoke all on public.productos, public.inventario from anon;
