-- Roles del equipo, invitaciones con código de un solo uso y políticas RLS
-- por rol. Misma matriz que lib/domain/roles.dart: la app oculta, el
-- servidor impide.
--
--   dueno          todo, incluido el equipo (uno solo por empresa)
--   administrador  todo menos el equipo
--   contador       solo consulta
--   despachador    ventas de contado y entradas de inventario; fiado y abonos
--                  solo si empresas.despachador_fia; sin costos ni gastos
--   bodeguero      entradas y ajustes de inventario; sin costos ni ventas
--
-- Los costos (productos.costo, inventario.costo_unit) no se pueden ocultar
-- por columna con RLS, así que despachador y bodeguero no leen esas tablas:
-- leen las vistas productos_operativos e inventario_operativo, sin costos.

create extension if not exists pgcrypto with schema extensions;

-- ------------------------------------------------------------------ roles
alter table public.miembros drop constraint if exists miembros_rol_check;
update public.miembros set rol = 'dueno' where rol = 'admin';
update public.miembros set rol = 'despachador' where rol = 'vendedor';
alter table public.miembros alter column rol set default 'dueno';
alter table public.miembros add constraint miembros_rol_check
  check (rol in ('dueno','administrador','contador','despachador','bodeguero'));
create unique index if not exists miembros_un_dueno on public.miembros(empresa_id) where rol = 'dueno';

create or replace function public.crear_empresa_para_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
declare e uuid;
begin
  insert into public.empresas(nombre) values ('Mi empresa') returning id into e;
  insert into public.miembros(empresa_id, user_id, rol) values (e, new.id, 'dueno');
  return new;
end $$;
revoke all on function public.crear_empresa_para_usuario() from public, anon, authenticated;

alter table public.empresas add column if not exists despachador_fia boolean not null default false;

create or replace function privado.mi_rol() returns text
language sql stable security definer set search_path = public as $$
  select rol from public.miembros where user_id = auth.uid() limit 1
$$;
revoke all on function privado.mi_rol() from public, anon;
grant execute on function privado.mi_rol() to authenticated;

create or replace function privado.despachador_fia() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select e.despachador_fia from public.empresas e
                   where e.id = (select privado.mi_empresa())), false)
$$;
revoke all on function privado.despachador_fia() from public, anon;
grant execute on function privado.despachador_fia() to authenticated;

-- --------------------------------------------------------------- miembros
-- Cada uno ve su membresía; dueño y administrador ven todo su equipo.
drop policy if exists "ver mi membresia" on public.miembros;
create policy "ver mi membresia" on public.miembros for select to authenticated
  using (user_id = (select auth.uid())
         or (empresa_id = (select privado.mi_empresa())
             and (select privado.mi_rol()) in ('dueno','administrador')));

-- --------------------------------------------------------------- clientes
drop policy if exists "clientes ver"    on public.clientes;
drop policy if exists "clientes crear"  on public.clientes;
drop policy if exists "clientes editar" on public.clientes;
create policy "clientes ver" on public.clientes for select to authenticated
  using (empresa_id = (select privado.mi_empresa())
         and ((select privado.mi_rol()) in ('dueno','administrador','contador')
              or ((select privado.mi_rol()) = 'despachador' and (select privado.despachador_fia()))));
create policy "clientes crear" on public.clientes for insert to authenticated
  with check (empresa_id = (select privado.mi_empresa())
              and ((select privado.mi_rol()) in ('dueno','administrador')
                   or ((select privado.mi_rol()) = 'despachador' and (select privado.despachador_fia()))));
create policy "clientes editar" on public.clientes for update to authenticated
  using (empresa_id = (select privado.mi_empresa())
         and (select privado.mi_rol()) in ('dueno','administrador'))
  with check (empresa_id = (select privado.mi_empresa())
              and (select privado.mi_rol()) in ('dueno','administrador'));

-- ----------------------------------------------------------------- ventas
-- Solo se agregan (no hay UPDATE ni DELETE). Quien la hizo no se puede falsear.
drop policy if exists "ventas ver"   on public.ventas;
drop policy if exists "ventas crear" on public.ventas;
create policy "ventas ver" on public.ventas for select to authenticated
  using (empresa_id = (select privado.mi_empresa())
         and ((select privado.mi_rol()) in ('dueno','administrador','contador')
              or ((select privado.mi_rol()) = 'despachador' and tipo <> 'egreso')));
create policy "ventas crear" on public.ventas for insert to authenticated
  with check (empresa_id = (select privado.mi_empresa())
              and creado_por = (select auth.uid())
              and ((select privado.mi_rol()) in ('dueno','administrador')
                   or ((select privado.mi_rol()) = 'despachador'
                       and ((tipo = 'ingreso' and (not credito or (select privado.despachador_fia())))
                            or (tipo = 'abono' and (select privado.despachador_fia()))))));

-- -------------------------------------------------------------- productos
drop policy if exists "productos ver"    on public.productos;
drop policy if exists "productos crear"  on public.productos;
drop policy if exists "productos editar" on public.productos;
create policy "productos ver" on public.productos for select to authenticated
  using (empresa_id = (select privado.mi_empresa())
         and (select privado.mi_rol()) in ('dueno','administrador','contador'));
create policy "productos crear" on public.productos for insert to authenticated
  with check (empresa_id = (select privado.mi_empresa())
              and (select privado.mi_rol()) in ('dueno','administrador'));
create policy "productos editar" on public.productos for update to authenticated
  using (empresa_id = (select privado.mi_empresa())
         and (select privado.mi_rol()) in ('dueno','administrador'))
  with check (empresa_id = (select privado.mi_empresa())
              and (select privado.mi_rol()) in ('dueno','administrador'));

-- ------------------------------------------------------------- inventario
-- Solo se agrega. Despachador y bodeguero registran sin costo.
drop policy if exists "inventario ver"   on public.inventario;
drop policy if exists "inventario crear" on public.inventario;
create policy "inventario ver" on public.inventario for select to authenticated
  using (empresa_id = (select privado.mi_empresa())
         and (select privado.mi_rol()) in ('dueno','administrador','contador'));
create policy "inventario crear" on public.inventario for insert to authenticated
  with check (empresa_id = (select privado.mi_empresa())
              and creado_por = (select auth.uid())
              and ((select privado.mi_rol()) in ('dueno','administrador')
                   or ((select privado.mi_rol()) = 'despachador'
                       and motivo in ('venta','entrada') and costo_unit is null)
                   or ((select privado.mi_rol()) = 'bodeguero'
                       and motivo in ('entrada','ajuste') and costo_unit is null)));

-- -------------------------------------------- vistas sin costos (operativas)
-- Corren con los permisos del dueño de la vista y filtran por la empresa de
-- quien consulta. Las usan despachador y bodeguero para tener precios y stock
-- sin ver costos.
create or replace view public.productos_operativos as
  select id, empresa_id, nombre, nombre_ts, precio, precio_ts, minimo, minimo_ts,
         codigo, codigo_ts, unidad, unidad_ts, deleted, deleted_ts, updated_at,
         creado_por, recibido_at
  from public.productos
  where empresa_id = (select privado.mi_empresa());
create or replace view public.inventario_operativo as
  select id, empresa_id, producto_id, cantidad, motivo, venta_id, precio_unit, fecha,
         creado_por, recibido_at
  from public.inventario
  where empresa_id = (select privado.mi_empresa());
revoke all on public.productos_operativos, public.inventario_operativo from public, anon;
grant select on public.productos_operativos, public.inventario_operativo to authenticated;

-- ------------------------------------------------------------ invitaciones
create table if not exists public.invitaciones(
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(id) on delete cascade,
  codigo text not null unique check (codigo ~ '^[A-Z0-9]{8}$'),
  rol text not null check (rol in ('administrador','contador','despachador','bodeguero')),
  creado_por uuid not null default auth.uid(),
  creado_at timestamptz not null default now(),
  expira_at timestamptz not null,
  usado_por uuid,
  usado_at timestamptz
);
create index if not exists invitaciones_empresa_idx on public.invitaciones(empresa_id);
alter table public.invitaciones enable row level security;
revoke all on public.invitaciones from anon;

-- El dueño ve y anula las de su empresa. Crear y usar: solo con las funciones.
drop policy if exists "invitaciones ver"    on public.invitaciones;
drop policy if exists "invitaciones anular" on public.invitaciones;
create policy "invitaciones ver" on public.invitaciones for select to authenticated
  using (empresa_id = (select privado.mi_empresa()) and (select privado.mi_rol()) = 'dueno');
create policy "invitaciones anular" on public.invitaciones for delete to authenticated
  using (empresa_id = (select privado.mi_empresa()) and (select privado.mi_rol()) = 'dueno'
         and usado_at is null);

-- ---------------------------------------------------- funciones del equipo
-- Código de 8 caracteres sin letras que se confunden (sin I, L, O, 0, 1).
create or replace function public.crear_invitacion(p_rol text, p_dias int default 7)
returns text
language plpgsql security definer set search_path = public, extensions as $$
declare
  alfabeto constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  c text;
  b bytea;
  i int;
begin
  if auth.uid() is null then
    raise exception 'Inicia sesión para invitar' using errcode = '42501';
  end if;
  if privado.mi_rol() is distinct from 'dueno' then
    raise exception 'Solo el dueño puede invitar empleados' using errcode = '42501';
  end if;
  if p_rol not in ('administrador','contador','despachador','bodeguero') then
    raise exception 'Rol no válido para una invitación' using errcode = '22023';
  end if;
  if p_dias is null or p_dias < 1 or p_dias > 30 then
    raise exception 'La invitación debe durar entre 1 y 30 días' using errcode = '22023';
  end if;
  loop
    b := gen_random_bytes(8);
    c := '';
    for i in 0..7 loop
      c := c || substr(alfabeto, (get_byte(b, i) % length(alfabeto)) + 1, 1);
    end loop;
    exit when not exists (select 1 from public.invitaciones where codigo = c);
  end loop;
  insert into public.invitaciones(empresa_id, codigo, rol, creado_por, expira_at)
  values (privado.mi_empresa(), c, p_rol, auth.uid(), now() + make_interval(days => p_dias));
  return c;
end $$;

-- Unirse a un negocio con el código. La cuenta deja su empresa propia solo si
-- está vacía (sin datos ni otros miembros): así nadie pierde información.
create or replace function public.unirse_con_codigo(p_codigo text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  yo uuid := auth.uid();
  inv public.invitaciones;
  vieja uuid;
  otros int;
  datos int;
begin
  if yo is null then
    raise exception 'Inicia sesión para unirte a un negocio' using errcode = '42501';
  end if;
  select * into inv from public.invitaciones
   where codigo = upper(trim(coalesce(p_codigo, ''))) for update;
  if not found or inv.usado_at is not null or inv.expira_at < now() then
    raise exception 'El código no es válido, ya se usó o se venció' using errcode = '22023';
  end if;
  select m.empresa_id into vieja from public.miembros m where m.user_id = yo;
  if vieja = inv.empresa_id then
    raise exception 'Ya perteneces a este negocio' using errcode = '22023';
  end if;
  if vieja is not null then
    select count(*) into otros from public.miembros m where m.empresa_id = vieja and m.user_id <> yo;
    select (select count(*) from public.clientes c where c.empresa_id = vieja)
         + (select count(*) from public.ventas v where v.empresa_id = vieja)
         + (select count(*) from public.productos p where p.empresa_id = vieja)
         + (select count(*) from public.inventario i where i.empresa_id = vieja)
      into datos;
    if otros > 0 or datos > 0 then
      raise exception 'Esta cuenta ya tiene un negocio con datos o empleados; usa otra cuenta para unirte'
        using errcode = '22023';
    end if;
    delete from public.miembros m where m.user_id = yo;
    delete from public.empresas e where e.id = vieja;
  end if;
  insert into public.miembros(empresa_id, user_id, rol) values (inv.empresa_id, yo, inv.rol);
  update public.invitaciones set usado_por = yo, usado_at = now() where id = inv.id;
  return jsonb_build_object('empresa_id', inv.empresa_id, 'rol', inv.rol);
end $$;

create or replace function public.cambiar_rol(p_usuario uuid, p_rol text)
returns void
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if privado.mi_rol() is distinct from 'dueno' then
    raise exception 'Solo el dueño puede cambiar roles' using errcode = '42501';
  end if;
  if p_usuario = auth.uid() then
    raise exception 'No puedes cambiar tu propio rol' using errcode = '22023';
  end if;
  if p_rol not in ('administrador','contador','despachador','bodeguero') then
    raise exception 'Rol no válido' using errcode = '22023';
  end if;
  update public.miembros set rol = p_rol
   where user_id = p_usuario and empresa_id = privado.mi_empresa() and rol <> 'dueno';
  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'Esa persona no es empleada de tu negocio' using errcode = '22023';
  end if;
end $$;

-- Quitar a alguien del equipo. Su cuenta queda con un negocio propio vacío,
-- para que pueda seguir usando la app sin ver los datos de este.
create or replace function public.quitar_miembro(p_usuario uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare e uuid; n int;
begin
  if privado.mi_rol() is distinct from 'dueno' then
    raise exception 'Solo el dueño puede quitar empleados' using errcode = '42501';
  end if;
  if p_usuario = auth.uid() then
    raise exception 'No puedes quitarte a ti mismo' using errcode = '22023';
  end if;
  delete from public.miembros
   where user_id = p_usuario and empresa_id = privado.mi_empresa() and rol <> 'dueno';
  get diagnostics n = row_count;
  if n = 0 then
    raise exception 'Esa persona no es empleada de tu negocio' using errcode = '22023';
  end if;
  insert into public.empresas(nombre) values ('Mi empresa') returning id into e;
  insert into public.miembros(empresa_id, user_id, rol) values (e, p_usuario, 'dueno');
end $$;

create or replace function public.definir_despachador_fia(p_valor boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if privado.mi_rol() is distinct from 'dueno' then
    raise exception 'Solo el dueño puede cambiar esta opción' using errcode = '42501';
  end if;
  update public.empresas set despachador_fia = coalesce(p_valor, false) where id = privado.mi_empresa();
end $$;

-- Lo que la app necesita saber al iniciar sesión.
create or replace function public.mi_contexto()
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'empresa_id', m.empresa_id,
    'rol', m.rol,
    'empresa', e.nombre,
    'despachador_fia', e.despachador_fia)
  from public.miembros m join public.empresas e on e.id = m.empresa_id
  where m.user_id = auth.uid()
$$;

-- El equipo con su correo (solo dueño y administrador).
create or replace function public.equipo()
returns table(user_id uuid, correo text, rol text)
language plpgsql stable security definer set search_path = public as $$
begin
  if privado.mi_rol() not in ('dueno','administrador') then
    raise exception 'Solo el dueño o el administrador ven el equipo' using errcode = '42501';
  end if;
  return query
    select m.user_id, u.email::text, m.rol
    from public.miembros m join auth.users u on u.id = m.user_id
    where m.empresa_id = privado.mi_empresa()
    order by case m.rol when 'dueno' then 0 else 1 end, u.email;
end $$;

revoke all on function public.crear_invitacion(text, int), public.unirse_con_codigo(text),
  public.cambiar_rol(uuid, text), public.quitar_miembro(uuid), public.definir_despachador_fia(boolean),
  public.mi_contexto(), public.equipo() from public, anon;
grant execute on function public.crear_invitacion(text, int), public.unirse_con_codigo(text),
  public.cambiar_rol(uuid, text), public.quitar_miembro(uuid), public.definir_despachador_fia(boolean),
  public.mi_contexto(), public.equipo() to authenticated;
