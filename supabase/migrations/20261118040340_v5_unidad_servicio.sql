alter table public.productos drop constraint if exists productos_unidad_check;
alter table public.productos add constraint productos_unidad_check check (unidad in ('und','kg','lb','serv'));
