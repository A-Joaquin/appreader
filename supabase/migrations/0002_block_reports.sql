-- BlackReader · Fase 2 — reportes de bloques
-- Pegar completo en Supabase → SQL Editor → Run.
-- Depende de 0001_users_progress.sql (usa is_admin / is_active).
--
-- Un reporte lo crea el lector desde la barra de traducción (icono de bandera)
-- y siempre apunta al bloque que estaba leyendo; guarda además la página, el
-- fragmento y la palabra seleccionada para poder localizar el problema exacto.

-- ───────────────────────────────────────────────────────────────────────────
-- Tipos
-- ───────────────────────────────────────────────────────────────────────────
do $$ begin
  create type report_kind as enum (
    'bad_translation',      -- la traducción está mal
    'bad_format',           -- saltos de línea / espaciado / texto partido
    'translation_not_shown', -- la traducción no se ve o se ve mal
    'other'                 -- lo describe el usuario en `message`
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type report_status as enum ('open', 'resolved');
exception when duplicate_object then null; end $$;

-- ───────────────────────────────────────────────────────────────────────────
-- block_reports
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.block_reports (
  id             bigserial primary key,
  user_id        uuid   not null references auth.users(id) on delete cascade,
  book_id        bigint not null references public.books(id) on delete cascade,
  -- Si el bloque desaparece en una recarga del libro, el reporte sobrevive
  -- (queda la página y el texto copiado).
  block_id       bigint references public.content_blocks(id) on delete set null,
  page_number    int,
  fragment_order int,
  word           text,          -- palabra seleccionada al reportar, si había
  excerpt        text,          -- copia del texto reportado, para no perderlo
  kind           report_kind   not null,
  message        text,
  status         report_status not null default 'open',
  created_at     timestamptz   not null default now(),
  resolved_at    timestamptz,
  resolved_by    uuid references auth.users(id) on delete set null
);

create index if not exists block_reports_status_idx
  on public.block_reports(status, created_at desc);
create index if not exists block_reports_book_idx
  on public.block_reports(book_id);
create index if not exists block_reports_block_idx
  on public.block_reports(block_id);

-- ───────────────────────────────────────────────────────────────────────────
-- RLS
-- ───────────────────────────────────────────────────────────────────────────
alter table public.block_reports enable row level security;

-- El usuario crea reportes a su nombre (y solo si no está baneado).
drop policy if exists br_insert_own on public.block_reports;
create policy br_insert_own on public.block_reports
  for insert
  with check ( user_id = auth.uid() and public.is_active(auth.uid()) );

-- Ve los suyos; el admin, todos.
drop policy if exists br_select_own_or_admin on public.block_reports;
create policy br_select_own_or_admin on public.block_reports
  for select using ( user_id = auth.uid() or public.is_admin(auth.uid()) );

-- Resolver / reabrir es cosa del admin.
drop policy if exists br_admin_update on public.block_reports;
create policy br_admin_update on public.block_reports
  for update using ( public.is_admin(auth.uid()) )
  with check ( public.is_admin(auth.uid()) );

drop policy if exists br_admin_delete on public.block_reports;
create policy br_admin_delete on public.block_reports
  for delete using ( public.is_admin(auth.uid()) );
