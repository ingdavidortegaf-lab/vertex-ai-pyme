-- Caja: anulaciones, descuentos con tope y turnos con diferencia de caja.
--
-- Las ventas siguen sin UPDATE ni DELETE: anular es agregar un movimiento
-- nuevo (tipo 'anulacion') que apunta al original. Solo el dueño y el
-- administrador pueden anular (la política de inserción ya no deja a nadie
-- más). El descuento tiene un tope que fija el dueño, y lo hace cumplir el
-- servidor para todos los roles menos el dueño.

-- ----------------------------------------------------------------- ventas
alter table public.ventas drop constraint if exists ventas_tipo_check;
alter table public.ventas add constraint ventas_tipo_check
  check (tipo in ('ingreso','egreso','abono','anulacion'));

alter table public.ventas
  add column if not exists anula uuid,
  add column if not exists anula_tipo text check (anula_tipo in ('ingreso','egreso','abono')),
  add column if not exists descuento numeric(14,2) not null default 0 check (descuento >= 0),
  add column if not exists turno uuid,
  add column if not exists autoriza text not null default '' check (char_length(autoriza) <= 40);

alter table public.ventas drop constraint if exists ventas_anula_coherente;
alter table public.ventas add constraint ventas_anula_coherente
  check ((tipo = 'anulacion') = (anula is not null));
alter table public.ventas drop constraint if exists ventas_descuento_solo_en_ventas;
alter table public.ventas add constraint ventas_descuento_solo_en_ventas
  check (descuento = 0 or tipo = 'ingreso');

-- Un movimiento se anula una sola vez (si dos celulares lo anulan sin
-- conexión, el segundo queda rechazado y se ve como error en la cola).
create unique index if not exists ventas_una_anulacion on public.ventas(anula) where anula is not null;

alter table public.empresas add column if not exists descuento_max_pct numeric(5,2) not null default 0
  check (descuento_max_pct between 0 and 100);

-- La anulación tiene que corresponder a un movimiento de la misma empresa,
-- por el mismo valor y del mismo cliente. El descuento no pasa del tope.
create or replace function privado.validar_venta() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  o public.ventas;
  tope numeric;
begin
  if new.tipo = 'anulacion' then
    select * into o from public.ventas v where v.id = new.anula and v.empresa_id = new.empresa_id;
    if not found then
      raise exception 'El movimiento que se anula no existe en este negocio' using errcode = '23503';
    end if;
    if o.tipo = 'anulacion' then
      raise exception 'Una anulación no se anula' using errcode = '23514';
    end if;
    if new.monto <> o.monto or new.cliente_id is distinct from o.cliente_id then
      raise exception 'La anulación debe ser por el mismo valor y del mismo cliente' using errcode = '23514';
    end if;
    -- Qué se anuló lo dice el servidor, no el celular.
    new.anula_tipo := o.tipo;
  else
    new.anula_tipo := null;
  end if;
  if new.descuento > 0 and privado.mi_rol() is distinct from 'dueno' then
    select e.descuento_max_pct into tope from public.empresas e where e.id = new.empresa_id;
    -- Un peso de tolerancia por redondeo.
    if new.descuento > round((new.monto + new.descuento) * coalesce(tope, 0) / 100, 2) + 1 then
      raise exception 'El descuento supera el tope que definió el dueño' using errcode = '23514';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists validar_venta on public.ventas;
create trigger validar_venta before insert on public.ventas
  for each row execute function privado.validar_venta();

-- El despachador no ve gastos: tampoco la anulación de un gasto.
drop policy if exists "ventas ver" on public.ventas;
create policy "ventas ver" on public.ventas for select to authenticated
  using (empresa_id = (select privado.mi_empresa())
         and ((select privado.mi_rol()) in ('dueno','administrador','contador')
              or ((select privado.mi_rol()) = 'despachador'
                  and (tipo in ('ingreso','abono')
                       or (tipo = 'anulacion' and anula_tipo is distinct from 'egreso')))));

-- ------------------------------------------------------------- inventario
-- Lo vendido que se anula vuelve al inventario con un movimiento nuevo.
alter table public.inventario drop constraint if exists inventario_motivo_check;
alter table public.inventario add constraint inventario_motivo_check
  check (motivo in ('venta','entrada','ajuste','anulacion'));
alter table public.inventario drop constraint if exists inventario_anulacion_devuelve;
alter table public.inventario add constraint inventario_anulacion_devuelve
  check (motivo <> 'anulacion' or (cantidad > 0 and venta_id is not null));

-- ---------------------------------------------------------------- turnos
-- Un turno se sube al cerrarlo, completo: no hay que editarlo después.
create table if not exists public.turnos(
  id uuid primary key,
  empresa_id uuid not null default privado.mi_empresa() references public.empresas(id) on delete cascade,
  creado_por uuid not null default auth.uid(),
  perfil text not null default '' check (char_length(perfil) <= 40),
  abre timestamptz not null,
  cierra timestamptz not null,
  base numeric(14,2) not null default 0 check (base >= 0),
  esperado numeric(14,2) not null,
  contado numeric(14,2) not null check (contado >= 0),
  nota text not null default '' check (char_length(nota) <= 200),
  recibido_at timestamptz not null default now(),
  check (cierra >= abre)
);
create index if not exists turnos_empresa_idx on public.turnos(empresa_id, recibido_at);
alter table public.turnos enable row level security;

drop policy if exists "turnos ver" on public.turnos;
drop policy if exists "turnos crear" on public.turnos;
create policy "turnos ver" on public.turnos for select to authenticated
  using (empresa_id = (select privado.mi_empresa())
         and ((select privado.mi_rol()) in ('dueno','administrador','contador')
              or creado_por = (select auth.uid())));
create policy "turnos crear" on public.turnos for insert to authenticated
  with check (empresa_id = (select privado.mi_empresa())
              and creado_por = (select auth.uid())
              and (select privado.mi_rol()) in ('dueno','administrador','despachador'));

-- ------------------------------------------------------ tope de descuento
create or replace function public.definir_descuento_maximo(p_pct numeric)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if privado.mi_rol() is distinct from 'dueno' then
    raise exception 'Solo el dueño puede cambiar el tope de descuento' using errcode = '42501';
  end if;
  if p_pct is null or p_pct < 0 or p_pct > 100 then
    raise exception 'El tope va de 0 a 100 %%' using errcode = '22023';
  end if;
  update public.empresas set descuento_max_pct = p_pct where id = privado.mi_empresa();
end $$;

-- mi_contexto ahora también dice el tope de descuento.
create or replace function public.mi_contexto()
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'empresa_id', m.empresa_id,
    'rol', m.rol,
    'empresa', e.nombre,
    'despachador_fia', e.despachador_fia,
    'descuento_max_pct', e.descuento_max_pct)
  from public.miembros m join public.empresas e on e.id = m.empresa_id
  where m.user_id = auth.uid()
$$;

revoke all on function public.definir_descuento_maximo(numeric) from public, anon;
grant execute on function public.definir_descuento_maximo(numeric) to authenticated;
