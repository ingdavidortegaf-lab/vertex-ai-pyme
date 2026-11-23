-- Nombre de quien registró el movimiento cuando varias personas atienden en
-- el mismo celular (perfil con PIN). Es informativo: quién lo envió de verdad
-- lo dice creado_por, que la política no deja falsear.
alter table public.ventas add column if not exists perfil text not null default ''
  check (char_length(perfil) <= 40);
