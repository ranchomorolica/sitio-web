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
alter table public.config_sitio add column if not exists comision_marketplace_pct numeric not null default 5;

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

-- 5) Vendedores: esta tabla YA EXISTÍA de su software de subasta
--    (id_vendedor serial, nombre_vendedor, comision_pactada,
--    identidad, telefono, procedencia). NO la volvemos a crear —
--    solo le agregamos las columnas que necesita el sitio web para
--    mostrar cada finca públicamente con su reseña.
alter table public.vendedores add column if not exists correo text;
alter table public.vendedores add column if not exists nombre_finca text;
alter table public.vendedores add column if not exists ubicacion_finca text;
alter table public.vendedores add column if not exists descripcion text;
alter table public.vendedores add column if not exists estado text not null default 'aprobado';
alter table public.vendedores add column if not exists alias_publico text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'vendedores_estado_check') then
    alter table public.vendedores add constraint vendedores_estado_check
      check (estado in ('pendiente','aprobado','rechazado'));
  end if;
end $$;
-- Los vendedores que ya existían quedan aprobados y usan su nombre
-- real como nombre de finca hasta que el admin lo edite.
update public.vendedores set nombre_finca = nombre_vendedor where nombre_finca is null;

-- Apodo público (estilo eBay: nunca el nombre real de identidad).
-- A los que ya existían se les genera un apodo razonable — nombre
-- de pila + inicial del apellido — que el admin puede cambiar por
-- cualquier otro alias desde el panel cuando quiera.
update public.vendedores
set alias_publico = coalesce(alias_publico, nullif(trim(
  split_part(trim(nombre_vendedor), ' ', 1) ||
  case when split_part(trim(nombre_vendedor), ' ', 2) <> ''
       then ' ' || left(split_part(trim(nombre_vendedor), ' ', 2), 1) || '.'
       else '' end
), ''), 'Vendedor #' || id_vendedor)
where alias_publico is null;

-- Vista pública y segura: solo el apodo y la ubicación/descripción
-- general de la finca — NUNCA el nombre real, identidad, teléfono,
-- correo ni comisión pactada, que quedan solo para el admin.
-- Se borra y se vuelve a crear (en vez de "or replace") porque
-- Postgres no permite quitarle columnas a una vista existente con
-- "or replace" — y esta versión le quita nombre_vendedor/nombre_finca
-- a propósito, por privacidad.
drop view if exists public.vendedores_publico;
create view public.vendedores_publico as
select id_vendedor as id, coalesce(alias_publico, 'Vendedor #' || id_vendedor) as alias_publico,
       ubicacion_finca, descripcion
from public.vendedores
where coalesce(estado, 'aprobado') = 'aprobado';
grant select on public.vendedores_publico to anon, authenticated;

-- Un ranchero externo se registra solo como vendedor consignatario
-- desde la página ("Vende con nosotros"), sin necesitar que usted
-- lo teclee a mano en admin.html. Queda "pendiente" — no aparece
-- en el directorio público ni se le puede asignar ningún animal
-- hasta que usted lo revise y lo apruebe. La comisión pactada la
-- decide siempre el rancho (queda en 4% por defecto, ajustable al
-- aprobar), nunca el propio vendedor.
create or replace function public.registrar_vendedor(
  p_nombre text, p_telefono text, p_correo text default null, p_identidad text default null,
  p_procedencia text default null, p_nombre_finca text default null, p_ubicacion_finca text default null,
  p_descripcion text default null, p_alias_publico text default null
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if coalesce(trim(p_nombre), '') = '' or coalesce(trim(p_telefono), '') = '' then
    raise exception 'Nombre y teléfono son obligatorios.';
  end if;
  insert into public.vendedores (
    nombre_vendedor, telefono, correo, identidad, procedencia,
    nombre_finca, ubicacion_finca, descripcion, alias_publico,
    comision_pactada, estado
  ) values (
    trim(p_nombre), trim(p_telefono), nullif(trim(p_correo), ''), nullif(trim(p_identidad), ''),
    nullif(trim(p_procedencia), ''), coalesce(nullif(trim(p_nombre_finca), ''), trim(p_nombre)),
    nullif(trim(p_ubicacion_finca), ''), nullif(trim(p_descripcion), ''),
    coalesce(nullif(trim(p_alias_publico), ''), split_part(trim(p_nombre), ' ', 1)),
    4, 'pendiente'
  );
end;
$$;

grant execute on function public.registrar_vendedor(text,text,text,text,text,text,text,text,text) to anon, authenticated;

-- Reseñas y ranking de esos vendedores, dejadas por compradores
-- ya verificados. vendedor_id es integer porque así es la llave
-- real de la tabla vendedores (id_vendedor serial), no uuid.
create table if not exists public.resenas_vendedor (
  id uuid primary key default gen_random_uuid(),
  vendedor_id integer not null references public.vendedores(id_vendedor) on delete cascade,
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
alter table public.subasta_lotes add column if not exists vendedor_id integer references public.vendedores(id_vendedor);
alter table public.ganado_web add column if not exists vendedor_id integer references public.vendedores(id_vendedor);

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
  vendedor_id integer references public.vendedores(id_vendedor),
  monto_lps numeric not null,
  comision_pct numeric not null default 0,
  comision_lps numeric not null default 0,
  created_at timestamptz default now()
);

-- 9b) Artículos: maquinaria agrícola, silobolsa y pacas de heno —
--     todo lo que no es ganado pero se vende igual desde el catálogo.
create table if not exists public.articulos_web (
  id uuid primary key default gen_random_uuid(),
  categoria text not null check (categoria in ('Maquinaria','Silobolsa','Pacas de heno')),
  nombre text not null,
  descripcion text,
  marca text,
  modelo text,
  anio int,
  horas_uso numeric,
  cantidad numeric,
  unidad text,
  precio_lps numeric,
  foto_url text,
  vendedor_id integer references public.vendedores(id_vendedor),
  publicado boolean default true,
  vendido boolean default false,
  created_at timestamptz default now()
);
alter table public.facturas add column if not exists articulo_id uuid references public.articulos_web(id);

-- 9c) Modo de venta: precio fijo directo (como hasta ahora), o que
--     el comprador pueda "Hacer oferta" (estilo eBay). La subasta
--     en vivo ya es su propio modo, separado (subasta_lotes).
alter table public.ganado_web add column if not exists modo_venta text not null default 'directo';
alter table public.articulos_web add column if not exists modo_venta text not null default 'directo';
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'ganado_web_modo_venta_check') then
    alter table public.ganado_web add constraint ganado_web_modo_venta_check check (modo_venta in ('directo','oferta'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'articulos_web_modo_venta_check') then
    alter table public.articulos_web add constraint articulos_web_modo_venta_check check (modo_venta in ('directo','oferta'));
  end if;
end $$;

-- 9d) Publicaciones de usuarios: cualquier comprador ya verificado
--     (KYC aprobado) puede publicar su propio animal o artículo
--     desde la página, sin pasar por admin.html. Queda "pendiente"
--     hasta que usted lo apruebe — así evitamos anuncios falsos.
--     Lo que YA existía (creado_por vacío) se considera suyo,
--     siempre aprobado, para no afectar su catálogo actual.
alter table public.ganado_web add column if not exists creado_por uuid references auth.users(id);
alter table public.ganado_web add column if not exists estado_publicacion text not null default 'aprobado';
alter table public.ganado_web add column if not exists motivo_rechazo_publicacion text;
alter table public.articulos_web add column if not exists creado_por uuid references auth.users(id);
alter table public.articulos_web add column if not exists estado_publicacion text not null default 'aprobado';
alter table public.articulos_web add column if not exists motivo_rechazo_publicacion text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'ganado_web_estado_publicacion_check') then
    alter table public.ganado_web add constraint ganado_web_estado_publicacion_check check (estado_publicacion in ('pendiente','aprobado','rechazado'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'articulos_web_estado_publicacion_check') then
    alter table public.articulos_web add constraint articulos_web_estado_publicacion_check check (estado_publicacion in ('pendiente','aprobado','rechazado'));
  end if;
end $$;

-- Impide que un usuario normal se autoapruebe la publicación, se
-- adjudique un vendedor de consignación, o edite algo de otro. El
-- propio dueño sí puede editar su descripción/precio/fotos y
-- marcarla vendida; solo el admin cambia estado_publicacion,
-- motivo_rechazo_publicacion o vendedor_id.
create or replace function public.proteger_columnas_listado()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.es_admin() then
    new.estado_publicacion := old.estado_publicacion;
    new.motivo_rechazo_publicacion := old.motivo_rechazo_publicacion;
    new.vendedor_id := old.vendedor_id;
    new.creado_por := old.creado_por;
  end if;
  return new;
end;
$$;

drop trigger if exists antes_actualizar_ganado on public.ganado_web;
create trigger antes_actualizar_ganado
  before update on public.ganado_web
  for each row execute function public.proteger_columnas_listado();

drop trigger if exists antes_actualizar_articulo on public.articulos_web;
create trigger antes_actualizar_articulo
  before update on public.articulos_web
  for each row execute function public.proteger_columnas_listado();

-- Función para que el admin apruebe/rechace una publicación.
create or replace function public.revisar_publicacion(p_origen text, p_item_id uuid, p_aprobado boolean, p_motivo text default null)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede revisar publicaciones.';
  end if;
  if p_origen = 'ganado' then
    update public.ganado_web
      set estado_publicacion = case when p_aprobado then 'aprobado' else 'rechazado' end,
          motivo_rechazo_publicacion = p_motivo
      where id = p_item_id;
  elsif p_origen = 'articulo' then
    update public.articulos_web
      set estado_publicacion = case when p_aprobado then 'aprobado' else 'rechazado' end,
          motivo_rechazo_publicacion = p_motivo
      where id = p_item_id;
  else
    raise exception 'Origen inválido.';
  end if;
end;
$$;

grant execute on function public.revisar_publicacion(text, uuid, boolean, text) to authenticated;

-- El propio vendedor marca su publicación como vendida: guarda
-- vendido=true y genera la factura con la comisión de mercado
-- (config_sitio.comision_marketplace_pct) ya calculada, para que
-- quede registrado cuánto le debe al rancho por esa venta. El
-- cobro real de esa comisión (con PixelPay u otro) es un paso
-- aparte que todavía no está conectado.
create or replace function public.marcar_vendido_propio(p_origen text, p_item_id uuid, p_comprador_nombre text, p_comprador_telefono text default null)
returns public.facturas
language plpgsql
security definer set search_path = public
as $$
declare
  v_precio numeric;
  v_pct numeric;
  v_com numeric;
  v_factura public.facturas;
begin
  select comision_marketplace_pct into v_pct from public.config_sitio where id = true;
  v_pct := coalesce(v_pct, 0);

  if p_origen = 'ganado' then
    select precio_lps into v_precio from public.ganado_web where id = p_item_id and creado_por = auth.uid();
    if not found then
      raise exception 'Publicación no encontrada o no le pertenece.';
    end if;
    update public.ganado_web set vendido = true where id = p_item_id;
  elsif p_origen = 'articulo' then
    select precio_lps into v_precio from public.articulos_web where id = p_item_id and creado_por = auth.uid();
    if not found then
      raise exception 'Publicación no encontrada o no le pertenece.';
    end if;
    update public.articulos_web set vendido = true where id = p_item_id;
  else
    raise exception 'Origen inválido.';
  end if;

  v_precio := coalesce(v_precio, 0);
  v_com := round(v_precio * v_pct) / 100;

  insert into public.facturas (origen, ganado_id, articulo_id, comprador_id, comprador_nombre, comprador_telefono, monto_lps, comision_pct, comision_lps)
  values (
    'catalogo',
    case when p_origen = 'ganado' then p_item_id else null end,
    case when p_origen = 'articulo' then p_item_id else null end,
    null, coalesce(nullif(trim(p_comprador_nombre), ''), 'Comprador'), p_comprador_telefono,
    v_precio, v_pct, v_com
  )
  returning * into v_factura;

  return v_factura;
end;
$$;

grant execute on function public.marcar_vendido_propio(text, uuid, text, text) to authenticated;

-- Ofertas de compradores registrados (no requiere el KYC completo
-- de la subasta en vivo — solo tener una cuenta — porque aquí no
-- hay dinero de garantía de por medio, es solo una propuesta).
create table if not exists public.ofertas (
  id uuid primary key default gen_random_uuid(),
  origen text not null check (origen in ('ganado','articulo')),
  ganado_id uuid references public.ganado_web(id) on delete cascade,
  articulo_id uuid references public.articulos_web(id) on delete cascade,
  comprador_id uuid not null references auth.users(id) on delete cascade,
  monto_ofrecido numeric not null,
  mensaje text,
  monto_contraoferta numeric,
  estado text not null default 'pendiente' check (estado in ('pendiente','aceptada','rechazada','contraoferta')),
  created_at timestamptz default now(),
  actualizado_at timestamptz default now()
);

-- Función única para que el admin responda una oferta: aceptar
-- (marca vendido y genera la factura sola), rechazar, o
-- contraofertar con otro monto.
create or replace function public.responder_oferta(p_oferta_id uuid, p_accion text, p_monto_contraoferta numeric default null)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_of public.ofertas;
  v_nombre text;
  v_tel text;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede responder ofertas.';
  end if;
  select * into v_of from public.ofertas where id = p_oferta_id;
  if not found then
    raise exception 'Oferta no encontrada.';
  end if;

  if p_accion = 'aceptar' then
    select nombre, telefono into v_nombre, v_tel from public.perfiles where id = v_of.comprador_id;
    if v_of.origen = 'ganado' then
      update public.ganado_web set vendido = true where id = v_of.ganado_id;
      insert into public.facturas (origen, ganado_id, comprador_id, comprador_nombre, comprador_telefono, monto_lps)
        values ('catalogo', v_of.ganado_id, v_of.comprador_id, coalesce(nullif(trim(v_nombre),''),'Comprador'), v_tel, v_of.monto_ofrecido);
    else
      update public.articulos_web set vendido = true where id = v_of.articulo_id;
      insert into public.facturas (origen, articulo_id, comprador_id, comprador_nombre, comprador_telefono, monto_lps)
        values ('catalogo', v_of.articulo_id, v_of.comprador_id, coalesce(nullif(trim(v_nombre),''),'Comprador'), v_tel, v_of.monto_ofrecido);
    end if;
    update public.ofertas set estado = 'aceptada', actualizado_at = now() where id = p_oferta_id;
  elsif p_accion = 'rechazar' then
    update public.ofertas set estado = 'rechazada', actualizado_at = now() where id = p_oferta_id;
  elsif p_accion = 'contraofertar' then
    if p_monto_contraoferta is null then
      raise exception 'Falta el monto de la contraoferta.';
    end if;
    update public.ofertas set estado = 'contraoferta', monto_contraoferta = p_monto_contraoferta, actualizado_at = now() where id = p_oferta_id;
  else
    raise exception 'Acción inválida.';
  end if;
end;
$$;

grant execute on function public.responder_oferta(uuid, text, numeric) to authenticated;

-- Función para que el comprador acepte o rechace una contraoferta
-- (la única forma de responder, para que no pueda cambiar el monto).
create or replace function public.responder_contraoferta(p_oferta_id uuid, p_aceptar boolean)
returns void
language plpgsql
security definer set search_path = public
as $$
declare v_of public.ofertas;
begin
  select * into v_of from public.ofertas where id = p_oferta_id and comprador_id = auth.uid();
  if not found then
    raise exception 'Oferta no encontrada.';
  end if;
  if v_of.estado <> 'contraoferta' then
    raise exception 'Esta oferta no tiene una contraoferta pendiente.';
  end if;
  if p_aceptar then
    update public.ganado_web set vendido = true where id = v_of.ganado_id and v_of.origen = 'ganado';
    update public.articulos_web set vendido = true where id = v_of.articulo_id and v_of.origen = 'articulo';
    insert into public.facturas (origen, ganado_id, articulo_id, comprador_id, comprador_nombre, monto_lps)
      values ('catalogo',
        case when v_of.origen = 'ganado' then v_of.ganado_id else null end,
        case when v_of.origen = 'articulo' then v_of.articulo_id else null end,
        v_of.comprador_id,
        coalesce((select nombre from public.perfiles where id = v_of.comprador_id), 'Comprador'),
        v_of.monto_contraoferta);
    update public.ofertas set estado = 'aceptada', actualizado_at = now() where id = p_oferta_id;
  else
    update public.ofertas set estado = 'rechazada', actualizado_at = now() where id = p_oferta_id;
  end if;
end;
$$;

grant execute on function public.responder_contraoferta(uuid, boolean) to authenticated;

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
alter table public.articulos_web enable row level security;
alter table public.ofertas enable row level security;

-- Estas 6 tablas son del software de subasta (ruedo/proyector) y
-- tenían RLS desactivado — es decir, cualquiera en internet con la
-- llave pública podía leerlas y modificarlas. Les ponemos el mismo
-- candado: solo su cuenta de administrador puede usarlas. El
-- programa del ruedo debe iniciar sesión con esa cuenta (ver
-- App.js actualizado) para seguir funcionando.
alter table public.clientes enable row level security;
alter table public.compradores enable row level security;
alter table public.lotes enable row level security;
alter table public.historial_ventas enable row level security;
alter table public.subasta_en_vivo enable row level security;
alter table public.subastas_archivadas enable row level security;

-- Ganado
drop policy if exists "publico lee ganado publicado" on public.ganado_web;
create policy "publico lee ganado publicado"
  on public.ganado_web for select
  using (publicado = true and coalesce(estado_publicacion, 'aprobado') = 'aprobado');

-- Un comprador ya verificado puede publicar su propio animal, ver
-- sus propias publicaciones (aunque estén pendientes de revisión o
-- rechazadas), editarlas o borrarlas.
drop policy if exists "usuario ve sus publicaciones ganado" on public.ganado_web;
create policy "usuario ve sus publicaciones ganado"
  on public.ganado_web for select
  to authenticated using (creado_por = auth.uid());

drop policy if exists "usuario aprobado publica ganado" on public.ganado_web;
create policy "usuario aprobado publica ganado"
  on public.ganado_web for insert
  to authenticated with check (
    creado_por = auth.uid()
    and exists (select 1 from public.perfiles where id = auth.uid() and estado_verificacion = 'aprobado' and not bloqueado)
  );

drop policy if exists "usuario edita su publicacion ganado" on public.ganado_web;
create policy "usuario edita su publicacion ganado"
  on public.ganado_web for update
  to authenticated using (creado_por = auth.uid()) with check (creado_por = auth.uid());

drop policy if exists "usuario borra su publicacion ganado" on public.ganado_web;
create policy "usuario borra su publicacion ganado"
  on public.ganado_web for delete
  to authenticated using (creado_por = auth.uid());

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

-- Vendedores: la tabla real queda solo para el admin (tiene
-- identidad, teléfono, comisión pactada). El público ve el
-- directorio a través de la vista vendedores_publico de arriba,
-- que no requiere permiso porque ya filtra las columnas sensibles.
drop policy if exists "publico lee vendedores aprobados" on public.vendedores;
drop policy if exists "admin gestiona vendedores" on public.vendedores;
create policy "admin gestiona vendedores"
  on public.vendedores for all
  to authenticated using (public.es_admin()) with check (public.es_admin());

-- Candado total para las 6 tablas del software de subasta: solo
-- funcionan con la cuenta de administrador (autenticada).
drop policy if exists "admin gestiona clientes" on public.clientes;
create policy "admin gestiona clientes"
  on public.clientes for all
  to authenticated using (public.es_admin()) with check (public.es_admin());

drop policy if exists "admin gestiona compradores" on public.compradores;
create policy "admin gestiona compradores"
  on public.compradores for all
  to authenticated using (public.es_admin()) with check (public.es_admin());

drop policy if exists "admin gestiona lotes" on public.lotes;
create policy "admin gestiona lotes"
  on public.lotes for all
  to authenticated using (public.es_admin()) with check (public.es_admin());

drop policy if exists "admin gestiona historial ventas" on public.historial_ventas;
create policy "admin gestiona historial ventas"
  on public.historial_ventas for all
  to authenticated using (public.es_admin()) with check (public.es_admin());

drop policy if exists "admin gestiona subasta en vivo" on public.subasta_en_vivo;
create policy "admin gestiona subasta en vivo"
  on public.subasta_en_vivo for all
  to authenticated using (public.es_admin()) with check (public.es_admin());

drop policy if exists "admin gestiona subastas archivadas" on public.subastas_archivadas;
create policy "admin gestiona subastas archivadas"
  on public.subastas_archivadas for all
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

-- Artículos (maquinaria, silobolsa, pacas de heno): mismo patrón
-- que el catálogo de ganado.
drop policy if exists "publico lee articulos publicados" on public.articulos_web;
create policy "publico lee articulos publicados"
  on public.articulos_web for select
  using (publicado = true and coalesce(estado_publicacion, 'aprobado') = 'aprobado');

drop policy if exists "usuario ve sus publicaciones articulos" on public.articulos_web;
create policy "usuario ve sus publicaciones articulos"
  on public.articulos_web for select
  to authenticated using (creado_por = auth.uid());

drop policy if exists "usuario aprobado publica articulo" on public.articulos_web;
create policy "usuario aprobado publica articulo"
  on public.articulos_web for insert
  to authenticated with check (
    creado_por = auth.uid()
    and exists (select 1 from public.perfiles where id = auth.uid() and estado_verificacion = 'aprobado' and not bloqueado)
  );

drop policy if exists "usuario edita su publicacion articulo" on public.articulos_web;
create policy "usuario edita su publicacion articulo"
  on public.articulos_web for update
  to authenticated using (creado_por = auth.uid()) with check (creado_por = auth.uid());

drop policy if exists "usuario borra su publicacion articulo" on public.articulos_web;
create policy "usuario borra su publicacion articulo"
  on public.articulos_web for delete
  to authenticated using (creado_por = auth.uid());

drop policy if exists "admin lee todos los articulos" on public.articulos_web;
create policy "admin lee todos los articulos"
  on public.articulos_web for select
  to authenticated using (public.es_admin());

drop policy if exists "admin escribe articulos" on public.articulos_web;
create policy "admin escribe articulos"
  on public.articulos_web for all
  to authenticated using (public.es_admin()) with check (public.es_admin());

-- Ofertas: el comprador ve y crea las suyas (y responde
-- contraofertas solo con la función de arriba); el admin las ve y
-- responde todas.
drop policy if exists "comprador ve sus ofertas" on public.ofertas;
create policy "comprador ve sus ofertas"
  on public.ofertas for select
  to authenticated using (comprador_id = auth.uid() or public.es_admin());

drop policy if exists "comprador hace oferta" on public.ofertas;
create policy "comprador hace oferta"
  on public.ofertas for insert
  to authenticated with check (comprador_id = auth.uid());

drop policy if exists "admin gestiona ofertas" on public.ofertas;
create policy "admin gestiona ofertas"
  on public.ofertas for all
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
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='subasta_en_vivo') then
    alter publication supabase_realtime add table public.subasta_en_vivo;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='historial_ventas') then
    alter publication supabase_realtime add table public.historial_ventas;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='lotes') then
    alter publication supabase_realtime add table public.lotes;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='clientes') then
    alter publication supabase_realtime add table public.clientes;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='vendedores') then
    alter publication supabase_realtime add table public.vendedores;
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

-- Un comprador verificado también puede subir fotos de SU PROPIA
-- publicación, siempre dentro de su propia carpeta <su-user-id>/…
drop policy if exists "usuario sube foto de su publicacion" on storage.objects;
create policy "usuario sube foto de su publicacion"
  on storage.objects for insert
  to authenticated with check (bucket_id = 'ganado-fotos' and (storage.foldername(name))[1] = auth.uid()::text);

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
