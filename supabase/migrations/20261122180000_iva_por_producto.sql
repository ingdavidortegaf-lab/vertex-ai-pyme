-- IVA por producto (porcentaje que escribe el dueño; −1 = sin definir: la
-- app no trae tarifas precargadas). Se une por campo como los demás datos
-- del producto, con su marca de tiempo.

alter table public.productos add column if not exists iva numeric(5,2) not null default -1
  check (iva = -1 or (iva >= 0 and iva <= 100));
alter table public.productos add column if not exists iva_ts timestamptz not null default 'epoch';

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
  if new.iva_ts < old.iva_ts then new.iva := old.iva; new.iva_ts := old.iva_ts; end if;
  new.updated_at := greatest(new.nombre_ts, new.precio_ts, new.costo_ts, new.minimo_ts,
                             new.deleted_ts, new.codigo_ts, new.unidad_ts, new.iva_ts);
  new.empresa_id := old.empresa_id;
  new.creado_por := old.creado_por;
  new.recibido_at := now();
  return new;
end $$;

-- Despachador y bodeguero también ven el IVA (no es un costo). Las columnas
-- nuevas van al final para poder reemplazar la vista sin borrarla.
create or replace view public.productos_operativos as
  select id, empresa_id, nombre, nombre_ts, precio, precio_ts, minimo, minimo_ts,
         codigo, codigo_ts, unidad, unidad_ts, deleted, deleted_ts, updated_at,
         creado_por, recibido_at, iva, iva_ts
  from public.productos
  where empresa_id = (select privado.mi_empresa());
