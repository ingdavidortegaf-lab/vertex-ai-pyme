create schema if not exists privado;
revoke all on schema privado from public, anon;
grant usage on schema privado to authenticated;

create or replace function privado.mi_empresa() returns uuid
language sql stable security definer set search_path = public as $$
  select empresa_id from public.miembros where user_id = auth.uid() limit 1
$$;
revoke all on function privado.mi_empresa() from public, anon;
grant execute on function privado.mi_empresa() to authenticated;

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

drop function if exists public.mi_empresa();
