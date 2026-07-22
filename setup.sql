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

-- 2) Tabla de subastas en línea (el evento)
create table if not exists public.subastas_web (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  fecha timestamptz not null,
  descripcion text,
  activa boolean default true,
  created_at timestamptz default now()
);

-- 3) Perfiles: un registro por cada usuario de Supabase Auth.
--    Distingue al administrador (usted) de los compradores que
--    se registran solos desde la página para pujar en vivo.
create table if not exists public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text,
  telefono text,
  es_admin boolean not null default false,
  bloqueado boolean not null default false,
  created_at timestamptz default now()
);

-- Crea el perfil automáticamente cuando alguien se registra
-- (comprador o admin). Nunca se marca es_admin=true aquí.
create or replace function public.manejar_nuevo_usuario()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.perfiles (id, nombre, telefono)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nombre', ''),
    coalesce(new.raw_user_meta_data->>'telefono', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.manejar_nuevo_usuario();

-- Función auxiliar: ¿el usuario actual es administrador?
create or replace function public.es_admin()
returns boolean
language sql stable
security definer set search_path = public
as $$
  select coalesce((select es_admin from public.perfiles where id = auth.uid()), false);
$$;

-- 4) Lotes de una subasta en vivo (los animales que se rematan
--    uno por uno durante la transmisión).
create table if not exists public.subasta_lotes (
  id uuid primary key default gen_random_uuid(),
  subasta_id uuid not null references public.subastas_web(id) on delete cascade,
  orden int not null default 0,
  lote text not null,
  categoria text not null,
  nombre text,
  peso_kg numeric,
  edad_meses int,
  foto_url text,
  precio_salida numeric not null default 0,
  incremento numeric not null default 500,
  precio_actual numeric,
  estado text not null default 'pendiente' check (estado in ('pendiente','en_vivo','vendido','cerrado')),
  ganador_id uuid references auth.users(id),
  ganador_nombre text,
  created_at timestamptz default now()
);

-- 5) Pujas: historial de ofertas de cada lote. Se insertan
--    exclusivamente a través de la función hacer_puja() de abajo,
--    nunca directo desde el navegador, para que nadie pueda
--    falsificar un monto.
create table if not exists public.pujas (
  id uuid primary key default gen_random_uuid(),
  lote_id uuid not null references public.subasta_lotes(id) on delete cascade,
  comprador_id uuid not null references auth.users(id),
  comprador_nombre text not null,
  monto numeric not null,
  created_at timestamptz default now()
);

-- Función que registra una puja de forma segura: valida el monto
-- contra el precio actual dentro de la misma transacción (evita
-- que dos compradores "ganen" el mismo instante) y actualiza el
-- lote. Es la ÚNICA forma de pujar.
create or replace function public.hacer_puja(p_lote_id uuid, p_monto numeric)
returns public.subasta_lotes
language plpgsql
security definer set search_path = public
as $$
declare
  v_lote public.subasta_lotes;
  v_perfil public.perfiles;
  v_minimo numeric;
begin
  if auth.uid() is null then
    raise exception 'Debe iniciar sesión para pujar.';
  end if;

  select * into v_perfil from public.perfiles where id = auth.uid();
  if v_perfil.bloqueado then
    raise exception 'Su cuenta no puede pujar. Contacte al rancho.';
  end if;

  select * into v_lote from public.subasta_lotes where id = p_lote_id for update;
  if not found then
    raise exception 'Lote no encontrado.';
  end if;
  if v_lote.estado <> 'en_vivo' then
    raise exception 'Este lote no está en vivo en este momento.';
  end if;

  v_minimo := coalesce(v_lote.precio_actual, v_lote.precio_salida - v_lote.incremento) + v_lote.incremento;
  if p_monto < v_minimo then
    raise exception 'La puja mínima ahora es L %', v_minimo;
  end if;

  insert into public.pujas (lote_id, comprador_id, comprador_nombre, monto)
  values (p_lote_id, auth.uid(), nullif(trim(v_perfil.nombre), ''), p_monto);

  update public.subasta_lotes
    set precio_actual = p_monto, ganador_id = auth.uid(), ganador_nombre = nullif(trim(v_perfil.nombre), '')
    where id = p_lote_id
    returning * into v_lote;

  return v_lote;
end;
$$;

grant execute on function public.hacer_puja(uuid, numeric) to authenticated;

-- 6) Seguridad (RLS)
alter table public.ganado_web enable row level security;
alter table public.subastas_web enable row level security;
alter table public.perfiles enable row level security;
alter table public.subasta_lotes enable row level security;
alter table public.pujas enable row level security;

-- Ganado
drop policy if exists "publico lee ganado publicado" on public.ganado_web;
create policy "publico lee ganado publicado"
  on public.ganado_web for select
  using (publicado = true);

drop policy if exists "admin lee todo el ganado" on public.ganado_web;
create policy "admin lee todo el ganado"
  on public.ganado_web for select
  to authenticated using (public.es_admin());

drop policy if exists "admin escribe ganado" on public.ganado_web;
create policy "admin escribe ganado"
  on public.ganado_web for all
  to authenticated using (public.es_admin()) with check (public.es_admin());

-- Subastas (evento)
drop policy if exists "publico lee subastas activas" on public.subastas_web;
create policy "publico lee subastas activas"
  on public.subastas_web for select
  using (activa = true);

drop policy if exists "admin lee todas las subastas" on public.subastas_web;
create policy "admin lee todas las subastas"
  on public.subastas_web for select
  to authenticated using (public.es_admin());

drop policy if exists "admin escribe subastas" on public.subastas_web;
create policy "admin escribe subastas"
  on public.subastas_web for all
  to authenticated using (public.es_admin()) with check (public.es_admin());

-- Perfiles
drop policy if exists "usuario ve su perfil" on public.perfiles;
create policy "usuario ve su perfil"
  on public.perfiles for select
  to authenticated using (id = auth.uid() or public.es_admin());

-- Un usuario puede actualizar su propia fila (para corregir su
-- nombre/teléfono) y el admin puede actualizar cualquier fila
-- (para bloquear/desbloquear compradores). Nota: en Supabase el
-- admin y los compradores comparten el mismo rol de Postgres
-- ("authenticated"), así que la protección de las columnas
-- es_admin/bloqueado NO puede hacerse con GRANT por columna
-- (eso bloquearía también al admin) — se hace con el trigger
-- de abajo, que sí distingue fila por fila.
drop policy if exists "admin gestiona perfiles" on public.perfiles;
drop policy if exists "usuario edita su perfil" on public.perfiles;
create policy "usuario edita su perfil"
  on public.perfiles for update
  to authenticated
  using (id = auth.uid() or public.es_admin())
  with check (id = auth.uid() or public.es_admin());

-- Impide que un usuario normal se auto-asigne es_admin=true o se
-- desbloquee a sí mismo; solo el admin puede cambiar esas columnas.
create or replace function public.proteger_columnas_perfil()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.es_admin() then
    new.es_admin := old.es_admin;
    new.bloqueado := old.bloqueado;
  end if;
  return new;
end;
$$;

drop trigger if exists antes_actualizar_perfil on public.perfiles;
create trigger antes_actualizar_perfil
  before update on public.perfiles
  for each row execute function public.proteger_columnas_perfil();

-- Lotes de subasta: catálogo público de lo que se está rematando
drop policy if exists "publico lee lotes de subasta" on public.subasta_lotes;
create policy "publico lee lotes de subasta"
  on public.subasta_lotes for select
  using (true);

drop policy if exists "admin escribe lotes de subasta" on public.subasta_lotes;
create policy "admin escribe lotes de subasta"
  on public.subasta_lotes for all
  to authenticated using (public.es_admin()) with check (public.es_admin());

-- Pujas: historial visible para todos (transparencia de remate),
-- pero la única forma de INSERTAR es la función hacer_puja()
-- de arriba (nadie tiene permiso de insert directo).
drop policy if exists "publico lee pujas" on public.pujas;
create policy "publico lee pujas"
  on public.pujas for select
  using (true);

drop policy if exists "admin borra pujas" on public.pujas;
create policy "admin borra pujas"
  on public.pujas for delete
  to authenticated using (public.es_admin());

-- Tiempo real: para que el precio y las pujas se actualicen
-- solas en pantalla sin recargar la página (con chequeo para
-- poder correr este script más de una vez sin error).
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='subasta_lotes') then
    alter publication supabase_realtime add table public.subasta_lotes;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='pujas') then
    alter publication supabase_realtime add table public.pujas;
  end if;
end $$;

-- 7) Bucket de fotos (público para verlas, solo admin sube)
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
  to authenticated with check (bucket_id = 'ganado-fotos' and public.es_admin());

drop policy if exists "admin actualiza fotos ganado" on storage.objects;
create policy "admin actualiza fotos ganado"
  on storage.objects for update
  to authenticated using (bucket_id = 'ganado-fotos' and public.es_admin());

-- ============================================================
-- IMPORTANTE — DOS PASOS MANUALES DESPUÉS DE CORRER ESTE SCRIPT:
--
-- 1) Cree su usuario administrador en
--    Supabase → Authentication → Users → Add user
--    (su correo + una contraseña fuerte).
--
-- 2) Vuelva a este SQL Editor y ejecute (con SU correo):
--
--    update public.perfiles set es_admin = true
--    where id = (select id from auth.users where email = 'su-correo@ejemplo.com');
--
--    Sin este paso, ese usuario entra a admin.html pero no podrá
--    escribir nada (por seguridad, así protegemos también a los
--    compradores que se registren solos para pujar).
-- ============================================================
