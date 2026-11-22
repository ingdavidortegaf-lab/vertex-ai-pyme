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
