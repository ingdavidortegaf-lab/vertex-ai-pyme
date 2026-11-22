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
