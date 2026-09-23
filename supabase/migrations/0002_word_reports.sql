-- BlackReader · Fase 2 — reportes desde el lector
-- Pegar completo en Supabase → SQL Editor → Run.
-- Depende de 0001_users_progress.sql (usa is_admin / is_active).
--
-- `word_reports` YA EXISTE y tiene datos: esta migración NO la recrea, solo le
-- añade lo que le faltaba para que el panel de admin pueda triar los reportes
-- (un mensaje del usuario y un estado abierto/resuelto) y le pone la RLS.
-- Todo es idempotente: se puede correr dos veces sin romper nada.
--
-- Lo que ya tenía y se aprovecha tal cual: fragment_id, char_offset, direction,
-- tapped_word, counterpart_word y el snapshot del texto en los dos idiomas.

-- ───────────────────────────────────────────────────────────────────────────
-- 1. Tipos
-- ───────────────────────────────────────────────────────────────────────────

-- Estado del reporte (nuevo).
do $$ begin
  create type report_status as enum ('open', 'resolved');
exception when duplicate_object then null; end $$;

-- Valores que usa la app en `report_type`. `missing_translation` ya existía y
-- se conserva: es el de los reportes que ya están guardados.
--
-- Nota: `add value` se puede correr dentro de una transacción (PG 12+), pero
-- el valor nuevo no se puede USAR hasta que esa transacción cierre. Aquí solo
-- se añaden, no se usan, así que el script entero va de una. Si el editor se
-- queja, ejecuta estas tres líneas sueltas y vuelve a lanzar el resto.
alter type word_report_type add value if not exists 'bad_translation';
alter type word_report_type add value if not exists 'bad_format';
alter type word_report_type add value if not exists 'other';

-- ───────────────────────────────────────────────────────────────────────────
-- 2. Columnas que faltaban
-- ───────────────────────────────────────────────────────────────────────────
alter table public.word_reports
  -- Lo que escribe el usuario. Obligatorio en la app cuando elige "Otro
  -- problema", porque es lo único que explica el reporte.
  add column if not exists message     text,
  add column if not exists status      report_status not null default 'open',
  add column if not exists resolved_at timestamptz,
  add column if not exists resolved_by uuid references auth.users(id) on delete set null;

-- Para la lista del panel: pendientes primero, del más reciente al más viejo.
create index if not exists word_reports_status_idx
  on public.word_reports(status, created_at desc);

-- ───────────────────────────────────────────────────────────────────────────
-- 3. RLS
-- ───────────────────────────────────────────────────────────────────────────
-- Sin esto la tabla es legible con la anon key: cualquiera con la clave
-- pública de la app puede listar quién reportó qué.
alter table public.word_reports enable row level security;

-- El usuario crea reportes a su nombre (y solo si no está baneado).
drop policy if exists wr_insert_own on public.word_reports;
create policy wr_insert_own on public.word_reports
  for insert
  with check ( user_id = auth.uid() and public.is_active(auth.uid()) );

-- Ve los suyos; el admin, todos.
drop policy if exists wr_select_own_or_admin on public.word_reports;
create policy wr_select_own_or_admin on public.word_reports
  for select using ( user_id = auth.uid() or public.is_admin(auth.uid()) );

-- Resolver / reabrir es cosa del admin.
drop policy if exists wr_admin_update on public.word_reports;
create policy wr_admin_update on public.word_reports
  for update using ( public.is_admin(auth.uid()) )
  with check ( public.is_admin(auth.uid()) );

drop policy if exists wr_admin_delete on public.word_reports;
create policy wr_admin_delete on public.word_reports
  for delete using ( public.is_admin(auth.uid()) );
