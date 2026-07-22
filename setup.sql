-- ============================================================
-- RANCHO MOROLICA — Configuración de la base de datos
-- Ejecutar en: Supabase → SQL Editor → New query → Run
-- Seguro de ejecutar más de una vez.
-- ============================================================

-- 1) Tabla de ganado publicado en la web
create table if not exists public.ganado_web (
  id uuid primary key default gen_random_uuid(),
  lote text not null,
  categoria text not null,
  nombre text,
  peso_kg numeric not null,
  edad_meses int,
  precio_lps numeric,
  estado text,
  foto_url text,
  publicado boolean default true,
  vendido boolean default false,
  created_at timestamptz default now()
);

-- 2) Tabla de subastas en línea
create table if not exists public.subastas_web (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  fecha timestamptz not null,
  descripcion text,
  activa boolean default true,
  created_at timestamptz default now()
);

-- 3) Seguridad (RLS): el público solo LEE lo publicado;
--    solo usuarios con sesión (usted) pueden escribir.
alter table public.ganado_web enable row level security;
alter table public.subastas_web enable row level security;

drop policy if exists "publico lee ganado publicado" on public.ganado_web;
create policy "publico lee ganado publicado"
  on public.ganado_web for select
  using (publicado = true);

drop policy if exists "admin lee todo el ganado" on public.ganado_web;
create policy "admin lee todo el ganado"
  on public.ganado_web for select
  to authenticated using (true);

drop policy if exists "admin escribe ganado" on public.ganado_web;
create policy "admin escribe ganado"
  on public.ganado_web for all
  to authenticated using (true) with check (true);

drop policy if exists "publico lee subastas activas" on public.subastas_web;
create policy "publico lee subastas activas"
  on public.subastas_web for select
  using (activa = true);

drop policy if exists "admin escribe subastas" on public.subastas_web;
create policy "admin escribe subastas"
  on public.subastas_web for all
  to authenticated using (true) with check (true);

-- 4) Bucket de fotos (público para verlas, solo admin sube)
insert into storage.buckets (id, name, public)
values ('ganado-fotos', 'ganado-fotos', true)
on conflict (id) do nothing;

drop policy if exists "publico ve fotos ganado" on storage.objects;
create policy "publico ve fotos ganado"
  on storage.objects for select
  using (bucket_id = 'ganado-fotos');

drop policy if exists "admin sube fotos ganado" on storage.objects;
create policy "admin sube fotos ganado"
  on storage.objects for insert
  to authenticated with check (bucket_id = 'ganado-fotos');

drop policy if exists "admin actualiza fotos ganado" on storage.objects;
create policy "admin actualiza fotos ganado"
  on storage.objects for update
  to authenticated using (bucket_id = 'ganado-fotos');

-- ============================================================
-- IMPORTANTE: Cree su usuario administrador en
-- Supabase → Authentication → Users → Add user
-- (su correo + una contraseña fuerte). Con ese correo
-- entrará a admin.html
-- ============================================================
