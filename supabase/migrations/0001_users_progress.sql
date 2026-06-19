-- BlackReader · Fase 1 — usuarios, progreso y descargas
-- Pegar completo en Supabase → SQL Editor → Run.
-- NO toca books / content_blocks / block_fragments (para no romper la app actual).
-- El "ban por RLS" sobre el contenido se agrega en una migración posterior,
-- una vez que el login esté funcionando.

-- ───────────────────────────────────────────────────────────────────────────
-- Tipos
-- ───────────────────────────────────────────────────────────────────────────
do $$ begin
  create type user_status as enum ('active', 'banned', 'pending');
exception when duplicate_object then null; end $$;

do $$ begin
  create type user_role as enum ('user', 'admin');
exception when duplicate_object then null; end $$;

-- ───────────────────────────────────────────────────────────────────────────
-- profiles (1:1 con auth.users)
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role         user_role   not null default 'user',
  status       user_status not null default 'active',   -- futuro: nacer 'pending'
  created_at   timestamptz not null default now()
);

-- Crea el profile automáticamente cuando se registra un usuario.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ───────────────────────────────────────────────────────────────────────────
-- Helpers (SECURITY DEFINER para no recursar con las RLS de profiles)
-- ───────────────────────────────────────────────────────────────────────────
create or replace function public.is_admin(uid uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (select 1 from public.profiles p where p.id = uid and p.role = 'admin');
$$;

create or replace function public.is_active(uid uuid)
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (select 1 from public.profiles p where p.id = uid and p.status = 'active');
$$;

-- ───────────────────────────────────────────────────────────────────────────
-- reading_progress
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.reading_progress (
  user_id        uuid    not null references auth.users(id) on delete cascade,
  book_id        bigint  not null references public.books(id) on delete cascade,
  last_page      int     not null default 1,
  total_pages    int,
  last_active_at timestamptz not null default now(),  -- "última conexión leyendo"
  updated_at     timestamptz not null default now(),
  primary key (user_id, book_id)
);
create index if not exists reading_progress_book_idx on public.reading_progress(book_id);

-- ───────────────────────────────────────────────────────────────────────────
-- user_downloads
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.user_downloads (
  user_id       uuid   not null references auth.users(id) on delete cascade,
  book_id       bigint not null references public.books(id) on delete cascade,
  downloaded_at timestamptz not null default now(),
  primary key (user_id, book_id)
);

-- ───────────────────────────────────────────────────────────────────────────
-- RLS
-- ───────────────────────────────────────────────────────────────────────────
alter table public.profiles         enable row level security;
alter table public.reading_progress enable row level security;
alter table public.user_downloads   enable row level security;

-- profiles ------------------------------------------------------------------
drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin on public.profiles
  for select using ( id = auth.uid() or public.is_admin(auth.uid()) );

-- El usuario puede editar su propio profile PERO no escalar rol/estado:
-- esos dos los gestiona el admin (ver política aparte).
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update using ( id = auth.uid() )
  with check ( id = auth.uid() and role = 'user' );

drop policy if exists profiles_admin_update on public.profiles;
create policy profiles_admin_update on public.profiles
  for update using ( public.is_admin(auth.uid()) )
  with check ( public.is_admin(auth.uid()) );

-- reading_progress ----------------------------------------------------------
drop policy if exists rp_owner_all on public.reading_progress;
create policy rp_owner_all on public.reading_progress
  for all
  using ( user_id = auth.uid() and public.is_active(auth.uid()) )
  with check ( user_id = auth.uid() and public.is_active(auth.uid()) );

drop policy if exists rp_admin_read on public.reading_progress;
create policy rp_admin_read on public.reading_progress
  for select using ( public.is_admin(auth.uid()) );

-- user_downloads ------------------------------------------------------------
drop policy if exists ud_owner_all on public.user_downloads;
create policy ud_owner_all on public.user_downloads
  for all
  using ( user_id = auth.uid() and public.is_active(auth.uid()) )
  with check ( user_id = auth.uid() and public.is_active(auth.uid()) );

drop policy if exists ud_admin_read on public.user_downloads;
create policy ud_admin_read on public.user_downloads
  for select using ( public.is_admin(auth.uid()) );
