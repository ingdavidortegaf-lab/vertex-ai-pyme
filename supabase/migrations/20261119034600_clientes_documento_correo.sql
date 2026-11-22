alter table public.clientes add column if not exists tipo_doc text not null default 'CC'
  check (tipo_doc in ('CC','NIT','CE','PPT','PA'));
alter table public.clientes add column if not exists documento text not null default ''
  check (documento ~ '^[0-9A-Z-]{0,20}$');
alter table public.clientes add column if not exists correo text not null default ''
  check (char_length(correo) <= 120 and (correo = '' or correo ~ '^[^@[:space:]]+@[^@[:space:]]+\.[A-Za-z]{2,}$'));
alter table public.clientes add column if not exists datos_ts timestamptz not null default '1970-01-01T00:00:00Z';

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
  if new.datos_ts < old.datos_ts then
    new.tipo_doc := old.tipo_doc; new.documento := old.documento;
    new.correo := old.correo; new.datos_ts := old.datos_ts;
  end if;
  new.updated_at := greatest(new.nombre_ts, new.telefono_ts, new.deleted_ts, new.datos_ts);
  new.empresa_id := old.empresa_id;
  new.creado_por := old.creado_por;
  new.recibido_at := now();
  return new;
end $$;
