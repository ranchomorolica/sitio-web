-- ============================================================
-- RANCHO MOROLICA — Configuración de la base de datos
-- Ejecutar en: Supabase → SQL Editor → New query → Run
-- Seguro de ejecutar más de una vez (incluso en un proyecto que
-- ya tenía una versión anterior de este script).
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
alter table public.subastas_web add column if not exists video_url text;

-- 3) Configuración general del sitio (una sola fila): tipo de
--    cambio para mostrar precios en dólares, monto del depósito
--    de garantía y los datos bancarios donde el comprador
--    deposita ese dinero.
create table if not exists public.config_sitio (
  id boolean primary key default true check (id),
  tipo_cambio_lps_por_usd numeric not null default 26.5,
  deposito_garantia_lps numeric not null default 10000,
  datos_bancarios text not null default 'Pregunte al rancho por los datos de la cuenta bancaria.',
  updated_at timestamptz default now()
);
insert into public.config_sitio (id) values (true) on conflict (id) do nothing;

-- 4) Perfiles: un registro por cada usuario de Supabase Auth.
--    Distingue al administrador (usted) de los compradores que
--    se registran solos desde la página para pujar en vivo, y
--    guarda los datos de verificación de identidad (KYC) que
--    usted revisa antes de admitir a un comprador.
create table if not exists public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text,
  telefono text,
  es_admin boolean not null default false,
  bloqueado boolean not null default false,
  created_at timestamptz default now()
);
alter table public.perfiles add column if not exists identidad text;
alter table public.perfiles add column if not exists direccion text;
alter table public.perfiles add column if not exists estado_civil text;
alter table public.perfiles add column if not exists foto_id_frente_url text;
alter table public.perfiles add column if not exists foto_id_dorso_url text;
alter table public.perfiles add column if not exists estado_verificacion text not null default 'pendiente';
alter table public.perfiles add column if not exists motivo_rechazo text;
alter table public.perfiles add column if not exists deposito_pagado boolean not null default false;
alter table public.perfiles add column if not exists correo text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'perfiles_estado_verificacion_check') then
    alter table public.perfiles add constraint perfiles_estado_verificacion_check
      check (estado_verificacion in ('pendiente','aprobado','rechazado'));
  end if;
end $$;

-- Rellena el correo de compradores que ya se habían registrado
-- antes de agregar esta columna (para nuevos registros lo llena
-- el trigger de abajo). Seguro de correr varias veces.
update public.perfiles p set correo = u.email
from auth.users u
where u.id = p.id and p.correo is null;

-- Crea el perfil automáticamente cuando alguien se registra
-- (comprador o admin). Nunca se marca es_admin=true ni
-- estado_verificacion='aprobado' aquí — eso lo hace solo el admin.
create or replace function public.manejar_nuevo_usuario()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.perfiles (id, nombre, telefono, correo)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nombre', ''),
    coalesce(new.raw_user_meta_data->>'telefono', ''),
    new.email
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

-- 5) Vendedores externos (consignatarios): rancheros ajenos a
--    Rancho Morolica que registran su ganado para venderlo aquí.
create table if not exists public.vendedores (
  id uuid primary key default gen_random_uuid(),
  nombre_contacto text not null,
  telefono text,
  nombre_finca text not null,
  ubicacion_finca text,
  descripcion text,
  comision_pct numeric not null default 4,
  estado text not null default 'pendiente' check (estado in ('pendiente','aprobado','rechazado')),
  created_at timestamptz default now()
);
alter table public.vendedores add column if not exists correo text;

-- Reseñas y ranking de esos vendedores, dejadas por compradores
-- ya verificados.
create table if not exists public.resenas_vendedor (
  id uuid primary key default gen_random_uuid(),
  vendedor_id uuid not null references public.vendedores(id) on delete cascade,
  comprador_id uuid not null references auth.users(id) on delete cascade,
  calificacion int not null check (calificacion between 1 and 5),
  comentario text,
  created_at timestamptz default now(),
  unique (vendedor_id, comprador_id)
);

-- 6) Lotes de una subasta en vivo (los animales que se rematan
--    uno por uno durante la transmisión). vendedor_id queda vacío
--    si el animal es del propio Rancho Morolica.
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
alter table public.subasta_lotes add column if not exists vendedor_id uuid references public.vendedores(id);
alter table public.ganado_web add column if not exists vendedor_id uuid references public.vendedores(id);

-- 7) Pujas: historial de ofertas de cada lote. Se insertan
--    exclusivamente a través de las funciones hacer_puja() /
--    hacer_puja_fisica() de abajo, nunca directo desde el
--    navegador, para que nadie pueda falsificar un monto.
--    comprador_id queda vacío cuando la puja es física (del
--    ruedo), porque ese comprador presencial no tiene cuenta.
create table if not exists public.pujas (
  id uuid primary key default gen_random_uuid(),
  lote_id uuid not null references public.subasta_lotes(id) on delete cascade,
  comprador_id uuid references auth.users(id),
  comprador_nombre text not null,
  monto numeric not null,
  es_presencial boolean not null default false,
  registrada_por uuid references auth.users(id),
  created_at timestamptz default now()
);
alter table public.pujas alter column comprador_id drop not null;
alter table public.pujas add column if not exists es_presencial boolean not null default false;
alter table public.pujas add column if not exists registrada_por uuid references auth.users(id);

-- Función que registra una puja EN LÍNEA de forma segura: valida
-- el monto contra el precio actual dentro de la misma transacción
-- (evita que dos compradores "ganen" el mismo instante), exige que
-- el comprador ya esté verificado y con su depósito pagado, y
-- actualiza el lote. Es la ÚNICA forma de pujar desde la página.
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
  if v_perfil.estado_verificacion <> 'aprobado' then
    raise exception 'Su registro todavía no ha sido aprobado por el rancho.';
  end if;
  if not v_perfil.deposito_pagado then
    raise exception 'Debe pagar el depósito de garantía antes de poder pujar.';
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

-- Función que registra una puja FÍSICA (del ruedo): solo el
-- administrador/rematador la puede llamar, para que el precio de
-- la página y el precio físico del ruedo sean siempre el mismo.
create or replace function public.hacer_puja_fisica(p_lote_id uuid, p_monto numeric, p_nombre text)
returns public.subasta_lotes
language plpgsql
security definer set search_path = public
as $$
declare
  v_lote public.subasta_lotes;
  v_minimo numeric;
  v_nombre text;
begin
  if not public.es_admin() then
    raise exception 'Solo el rematador/administrador puede registrar pujas físicas.';
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

  v_nombre := coalesce(nullif(trim(p_nombre), ''), 'Comprador presencial');

  insert into public.pujas (lote_id, comprador_id, comprador_nombre, monto, es_presencial, registrada_por)
  values (p_lote_id, null, v_nombre, p_monto, true, auth.uid());

  update public.subasta_lotes
    set precio_actual = p_monto, ganador_id = null, ganador_nombre = v_nombre
    where id = p_lote_id
    returning * into v_lote;

  return v_lote;
end;
$$;

grant execute on function public.hacer_puja_fisica(uuid, numeric, text) to authenticated;

-- 8) Depósitos de garantía (L10,000 por defecto — ver
--    config_sitio). El comprador sube su comprobante de
--    transferencia/depósito bancario y el admin lo aprueba o
--    rechaza con la función revisar_deposito().
create table if not exists public.depositos (
  id uuid primary key default gen_random_uuid(),
  comprador_id uuid not null references auth.users(id) on delete cascade,
  monto numeric not null,
  comprobante_url text not null,
  estado text not null default 'pendiente' check (estado in ('pendiente','aprobado','rechazado')),
  motivo_rechazo text,
  revisado_por uuid references auth.users(id),
  created_at timestamptz default now()
);

create or replace function public.revisar_deposito(p_deposito_id uuid, p_aprobado boolean, p_motivo text default null)
returns void
language plpgsql
security definer set search_path = public
as $$
declare v_dep public.depositos;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede revisar depósitos.';
  end if;
  update public.depositos
    set estado = case when p_aprobado then 'aprobado' else 'rechazado' end,
        motivo_rechazo = p_motivo,
        revisado_por = auth.uid()
    where id = p_deposito_id
    returning * into v_dep;
  if not found then
    raise exception 'Depósito no encontrado.';
  end if;
  if p_aprobado then
    update public.perfiles set deposito_pagado = true where id = v_dep.comprador_id;
  end if;
end;
$$;

grant execute on function public.revisar_deposito(uuid, boolean, text) to authenticated;

-- Función para que el admin apruebe/rechace la verificación KYC.
create or replace function public.revisar_verificacion(p_comprador_id uuid, p_aprobado boolean, p_motivo text default null)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede revisar verificaciones.';
  end if;
  update public.perfiles
    set estado_verificacion = case when p_aprobado then 'aprobado' else 'rechazado' end,
        motivo_rechazo = p_motivo
    where id = p_comprador_id;
end;
$$;

grant execute on function public.revisar_verificacion(uuid, boolean, text) to authenticated;

-- 9) Facturas: comprobante automático de cada venta (catálogo o
--    subasta en vivo), con número consecutivo.
create sequence if not exists public.facturas_numero_seq start 1;

create table if not exists public.facturas (
  id uuid primary key default gen_random_uuid(),
  numero bigint not null default nextval('public.facturas_numero_seq'),
  origen text not null check (origen in ('catalogo','subasta')),
  ganado_id uuid references public.ganado_web(id),
  lote_id uuid references public.subasta_lotes(id),
  comprador_id uuid references auth.users(id),
  comprador_nombre text not null,
  comprador_telefono text,
  vendedor_id uuid references public.vendedores(id),
  monto_lps numeric not null,
  comision_pct numeric not null default 0,
  comision_lps numeric not null default 0,
  created_at timestamptz default now()
);

-- 10) Seguridad (RLS)
alter table public.ganado_web enable row level security;
alter table public.subastas_web enable row level security;
alter table public.perfiles enable row level security;
alter table public.subasta_lotes enable row level security;
alter table public.pujas enable row level security;
alter table public.config_sitio enable row level security;
alter table public.vendedores enable row level security;
alter table public.resenas_vendedor enable row level security;
alter table public.depositos enable row level security;
alter table public.facturas enable row level security;

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

-- Config del sitio: pública para leer (tipo de cambio, datos
-- bancarios del depósito), solo el admin la edita.
drop policy if exists "publico lee config" on public.config_sitio;
create policy "publico lee config"
  on public.config_sitio for select
  using (true);

drop policy if exists "admin edita config" on public.config_sitio;
create policy "admin edita config"
  on public.config_sitio for update
  to authenticated using (public.es_admin()) with check (public.es_admin());

-- Perfiles
drop policy if exists "usuario ve su perfil" on public.perfiles;
create policy "usuario ve su perfil"
  on public.perfiles for select
  to authenticated using (id = auth.uid() or public.es_admin());

-- Un usuario puede actualizar su propia fila (para corregir su
-- nombre/teléfono/datos KYC) y el admin puede actualizar cualquier
-- fila (para bloquear compradores). Nota: en Supabase el admin y
-- los compradores comparten el mismo rol de Postgres
-- ("authenticated"), así que la protección de las columnas
-- sensibles NO puede hacerse con GRANT por columna (eso
-- bloquearía también al admin) — se hace con el trigger de abajo,
-- que sí distingue fila por fila.
drop policy if exists "admin gestiona perfiles" on public.perfiles;
drop policy if exists "usuario edita su perfil" on public.perfiles;
create policy "usuario edita su perfil"
  on public.perfiles for update
  to authenticated
  using (id = auth.uid() or public.es_admin())
  with check (id = auth.uid() or public.es_admin());

-- Impide que un usuario normal se auto-asigne es_admin=true, se
-- desbloquee, se autoapruebe la verificación o marque su propio
-- depósito como pagado; solo el admin (o las funciones
-- revisar_deposito/revisar_verificacion) pueden cambiar esas
-- columnas.
create or replace function public.proteger_columnas_perfil()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.es_admin() then
    new.es_admin := old.es_admin;
    new.bloqueado := old.bloqueado;
    new.estado_verificacion := old.estado_verificacion;
    new.motivo_rechazo := old.motivo_rechazo;
    new.deposito_pagado := old.deposito_pagado;
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
-- pero la única forma de INSERTAR es a través de las funciones
-- hacer_puja() / hacer_puja_fisica() de arriba (nadie tiene
-- permiso de insert directo).
drop policy if exists "publico lee pujas" on public.pujas;
create policy "publico lee pujas"
  on public.pujas for select
  using (true);

drop policy if exists "admin borra pujas" on public.pujas;
create policy "admin borra pujas"
  on public.pujas for delete
  to authenticated using (public.es_admin());

-- Vendedores externos: público solo ve los aprobados; el admin
-- ve y gestiona todos (alta, aprobación, edición).
drop policy if exists "publico lee vendedores aprobados" on public.vendedores;
create policy "publico lee vendedores aprobados"
  on public.vendedores for select
  using (estado = 'aprobado');

drop policy if exists "admin gestiona vendedores" on public.vendedores;
create policy "admin gestiona vendedores"
  on public.vendedores for all
  to authenticated using (public.es_admin()) with check (public.es_admin());

-- Reseñas de vendedores: públicas de leer; solo un comprador ya
-- aprobado puede dejar (o editar) su propia reseña.
drop policy if exists "publico lee resenas" on public.resenas_vendedor;
create policy "publico lee resenas"
  on public.resenas_vendedor for select
  using (true);

drop policy if exists "comprador aprobado deja resena" on public.resenas_vendedor;
create policy "comprador aprobado deja resena"
  on public.resenas_vendedor for insert
  to authenticated with check (
    comprador_id = auth.uid()
    and exists (select 1 from public.perfiles where id = auth.uid() and estado_verificacion = 'aprobado')
  );

drop policy if exists "comprador edita su resena" on public.resenas_vendedor;
create policy "comprador edita su resena"
  on public.resenas_vendedor for update
  to authenticated using (comprador_id = auth.uid()) with check (comprador_id = auth.uid());

drop policy if exists "admin borra resenas" on public.resenas_vendedor;
create policy "admin borra resenas"
  on public.resenas_vendedor for delete
  to authenticated using (public.es_admin());

-- Depósitos: el comprador ve y sube el suyo; solo el admin (vía
-- revisar_deposito) lo aprueba o rechaza.
drop policy if exists "comprador ve sus depositos" on public.depositos;
create policy "comprador ve sus depositos"
  on public.depositos for select
  to authenticated using (comprador_id = auth.uid() or public.es_admin());

drop policy if exists "comprador sube su deposito" on public.depositos;
create policy "comprador sube su deposito"
  on public.depositos for insert
  to authenticated with check (comprador_id = auth.uid());

-- Facturas: el comprador ve las suyas; el admin las ve y las crea.
drop policy if exists "comprador ve su factura" on public.facturas;
create policy "comprador ve su factura"
  on public.facturas for select
  to authenticated using (comprador_id = auth.uid() or public.es_admin());

drop policy if exists "admin gestiona facturas" on public.facturas;
create policy "admin gestiona facturas"
  on public.facturas for all
  to authenticated using (public.es_admin()) with check (public.es_admin());

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

-- 11) Buckets de archivos
-- Fotos de ganado: público (se ven en el catálogo).
insert into storage.buckets (id, name, public)
values ('ganado-fotos', 'ganado-fotos', true)
on conflict (id) do nothing;

-- Fotos de identidad y comprobantes de depósito: PRIVADOS. Solo
-- el propio comprador y el administrador pueden verlos.
insert into storage.buckets (id, name, public)
values ('kyc-documentos', 'kyc-documentos', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('comprobantes-deposito', 'comprobantes-deposito', false)
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

-- kyc-documentos: cada comprador sube sus fotos en la carpeta
-- <su-user-id>/... y solo él mismo o el admin las pueden ver.
drop policy if exists "usuario sube su id" on storage.objects;
create policy "usuario sube su id"
  on storage.objects for insert
  to authenticated with check (bucket_id = 'kyc-documentos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "usuario ve su id" on storage.objects;
create policy "usuario ve su id"
  on storage.objects for select
  to authenticated using (bucket_id = 'kyc-documentos' and ((storage.foldername(name))[1] = auth.uid()::text or public.es_admin()));

drop policy if exists "usuario actualiza su id" on storage.objects;
create policy "usuario actualiza su id"
  on storage.objects for update
  to authenticated using (bucket_id = 'kyc-documentos' and (storage.foldername(name))[1] = auth.uid()::text);

-- comprobantes-deposito: mismo patrón que kyc-documentos.
drop policy if exists "usuario sube su comprobante" on storage.objects;
create policy "usuario sube su comprobante"
  on storage.objects for insert
  to authenticated with check (bucket_id = 'comprobantes-deposito' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "usuario y admin ven comprobante" on storage.objects;
create policy "usuario y admin ven comprobante"
  on storage.objects for select
  to authenticated using (bucket_id = 'comprobantes-deposito' and ((storage.foldername(name))[1] = auth.uid()::text or public.es_admin()));

-- ============================================================
-- IMPORTANTE — DOS PASOS MANUALES DESPUÉS DE CORRER ESTE SCRIPT:
--
-- 1) Cree su usuario administrador en
--    Supabase → Authentication → Users → Add user
--    (su correo + una contraseña fuerte).
--
-- 2) Vuelva a este SQL Editor y ejecute (con SU correo):
--
--    update public.perfiles set es_admin = true, estado_verificacion = 'aprobado'
--    where id = (select id from auth.users where email = 'su-correo@ejemplo.com');
--
--    Sin este paso, ese usuario entra a admin.html pero no podrá
--    escribir nada (por seguridad, así protegemos también a los
--    compradores que se registren solos para pujar).
-- ============================================================
