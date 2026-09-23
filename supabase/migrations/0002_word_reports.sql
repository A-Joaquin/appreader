-- BlackReader · Fase 2 — reportes desde el lector
-- Depende de 0001_users_progress.sql (usa is_admin / is_active).
--
-- `word_reports` YA EXISTE y tiene datos: esta migración NO la recrea, solo le
-- añade lo que le faltaba para que el panel de admin pueda triar los reportes
-- (un mensaje del usuario y un estado abierto/resuelto) y le pone la RLS.
-- Lo que ya tenía se aprovecha tal cual: fragment_id, char_offset, direction,
-- tapped_word, counterpart_word y el snapshot del texto en los dos idiomas.
--
-- ⚠️ CORRER PASO A PASO, uno cada vez (selecciona el bloque y Run).
-- Van separados a propósito: un `create index` sobre una columna que se acaba
-- de añadir en la MISMA tanda falla con «column "status" does not exist».
-- Cada paso es idempotente: se puede repetir sin romper nada.

-- ═══════════════════════════════════════════════════════════════════════════
-- PASO 1 — columnas que faltaban
-- ═══════════════════════════════════════════════════════════════════════════
alter table public.word_reports
  -- Lo que escribe el usuario. Obligatorio en la app cuando elige "Otro
  -- problema", porque es lo único que explica el reporte.
  add column if not exists message     text,
  -- 'open' | 'resolved'. Texto con CHECK en vez de enum: un enum nuevo obliga
  -- a crear el tipo antes y a no usarlo en la misma transacción, y no aporta
  -- nada para dos valores.
  add column if not exists status      text not null default 'open',
  add column if not exists resolved_at timestamptz,
  add column if not exists resolved_by uuid references auth.users(id) on delete set null;

-- ═══════════════════════════════════════════════════════════════════════════
-- PASO 2 — el CHECK del estado y el índice de la lista
-- ═══════════════════════════════════════════════════════════════════════════
alter table public.word_reports
  drop constraint if exists word_reports_status_check;
alter table public.word_reports
  add constraint word_reports_status_check
  check (status in ('open', 'resolved'));

-- Para la lista del panel: pendientes primero, del más reciente al más viejo.
create index if not exists word_reports_status_idx
  on public.word_reports(status, created_at desc);

-- ═══════════════════════════════════════════════════════════════════════════
-- PASO 3 — valores de report_type que usa la app
-- ═══════════════════════════════════════════════════════════════════════════
-- `missing_translation` ya existía y se conserva: es el de los reportes que ya
-- están guardados. Estos tres van sueltos porque Postgres no deja USAR un
-- valor de enum en la misma transacción en que se añade.
alter type word_report_type add value if not exists 'bad_translation';
alter type word_report_type add value if not exists 'bad_format';
alter type word_report_type add value if not exists 'other';

-- ═══════════════════════════════════════════════════════════════════════════
-- PASO 4 — RLS
-- ═══════════════════════════════════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════════════════════════════════
-- PASO 5 — comprobación (no cambia nada)
-- ═══════════════════════════════════════════════════════════════════════════
-- Deben salir las 4 columnas nuevas...
select column_name, data_type, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'word_reports'
  and column_name in ('message', 'status', 'resolved_at', 'resolved_by')
order by column_name;

-- ...los 4 valores del enum...
select enumlabel from pg_enum e
  join pg_type t on t.oid = e.enumtypid
where t.typname = 'word_report_type'
order by e.enumsortorder;

-- ...y la RLS activa con sus 4 políticas.
select relrowsecurity as rls_activa from pg_class
where oid = 'public.word_reports'::regclass;
select policyname from pg_policies
where schemaname = 'public' and tablename = 'word_reports'
order by policyname;
