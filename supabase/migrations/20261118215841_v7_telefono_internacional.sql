-- Celulares de cualquier país: número completo con indicativo, sin «+»,
-- entre 8 y 15 dígitos (E.164). Colombia sigue siendo 57 + 10 dígitos.
alter table public.clientes drop constraint clientes_telefono_check;
alter table public.clientes add constraint clientes_telefono_check
  check (telefono ~ '^([0-9]{8,15})?$');
