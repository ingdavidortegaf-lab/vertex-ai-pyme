-- Supermercados y ferreterías:
--   * precio por mayor desde una cantidad (contratistas, tenderos que
--     compran por bulto);
--   * fecha de vencimiento por producto (alimentos, droguería, agro);
--   * unidades por medida y por empaque: metro, litro, galón, caja, paquete.
-- Todo se une por campo con su marca de tiempo, como los demás datos del
-- producto (merge_producto).

alter table public.productos drop constraint if exists productos_unidad_check;
alter table public.productos add constraint productos_unidad_check
  check (unidad in ('und','kg','lb','m','l','gal','caja','paq','serv'));

alter table public.productos
  add column if not exists precio_mayor numeric(14,2) not null default 0 check (precio_mayor >= 0),
  add column if not exists precio_mayor_ts timestamptz not null default 'epoch',
  add column if not exists cantidad_mayor numeric(14,3) not null default 0 check (cantidad_mayor >= 0),
  add column if not exists cantidad_mayor_ts timestamptz not null default 'epoch',
  add column if not exists vence text not null default ''
    check (vence = '' or vence ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'),
  add column if not exists vence_ts timestamptz not null default 'epoch';

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
  if new.precio_mayor_ts < old.precio_mayor_ts then
    new.precio_mayor := old.precio_mayor; new.precio_mayor_ts := old.precio_mayor_ts;
  end if;
  if new.cantidad_mayor_ts < old.cantidad_mayor_ts then
    new.cantidad_mayor := old.cantidad_mayor; new.cantidad_mayor_ts := old.cantidad_mayor_ts;
  end if;
  if new.vence_ts < old.vence_ts then new.vence := old.vence; new.vence_ts := old.vence_ts; end if;
  new.updated_at := greatest(new.nombre_ts, new.precio_ts, new.costo_ts, new.minimo_ts,
                             new.deleted_ts, new.codigo_ts, new.unidad_ts, new.iva_ts,
                             new.precio_mayor_ts, new.cantidad_mayor_ts, new.vence_ts);
  new.empresa_id := old.empresa_id;
  new.creado_por := old.creado_por;
  new.recibido_at := now();
  return new;
end $$;

-- Despachador y bodeguero también ven el precio por mayor y el vencimiento
-- (no son costos). Columnas nuevas al final para reemplazar la vista.
create or replace view public.productos_operativos as
  select id, empresa_id, nombre, nombre_ts, precio, precio_ts, minimo, minimo_ts,
         codigo, codigo_ts, unidad, unidad_ts, deleted, deleted_ts, updated_at,
         creado_por, recibido_at, iva, iva_ts,
         precio_mayor, precio_mayor_ts, cantidad_mayor, cantidad_mayor_ts, vence, vence_ts
  from public.productos
  where empresa_id = (select privado.mi_empresa());
