# Rancho Morolica — Sitio web oficial
## Guía de instalación (30–45 minutos, se puede hacer desde el teléfono)

## Qué incluye este paquete

| Archivo | Qué es |
|---|---|
| `index.html` | La página pública: catálogo, subastas en línea, WhatsApp, SEO |
| `admin.html` | Su panel privado: agregar animales con foto desde el teléfono |
| `setup.sql` | Script que crea las tablas y la seguridad en Supabase |
| `robots.txt` / `sitemap.xml` | Para que Google indexe la página |
| `vercel.json` | Configuración de despliegue |

---

## PASO 1 — Preparar Supabase (10 min)

1. Entre a **supabase.com** → su proyecto (kjcvlgfgqvwfjgcsqbhu).
2. Menú **SQL Editor** → **New query** → pegue TODO el contenido de `setup.sql` → **Run**. Debe decir "Success".
3. Menú **Authentication → Users → Add user**: cree su usuario admin con su correo y una contraseña fuerte (guárdela en Apple Passwords). Con ese correo entrará al panel.
4. Vuelva al **SQL Editor** y ejecute esto (cambiando el correo por el suyo), para marcarlo como administrador:
   ```sql
   update public.perfiles set es_admin = true
   where id = (select id from auth.users where email = 'su-correo@ejemplo.com');
   ```
   ⚠️ Sin este paso su usuario entra a `admin.html` pero no puede guardar nada — es la protección que impide que un comprador que se registre solo desde la página termine con permisos de administrador.
5. Menú **Authentication → Settings**: si quiere que los compradores puedan pujar inmediatamente después de registrarse (recomendado para el día de la subasta), desactive "Confirm email". Si lo deja activado, cada comprador debe confirmar su correo antes de poder pujar.
6. Menú **Settings → API**: copie la **anon public key** (una clave larga que empieza con `eyJ...`).

## PASO 2 — Configurar los archivos (5 min)

Abra `index.html` y `admin.html` y busque la sección `CONFIG` (está al inicio del código JavaScript, claramente marcada). Cambie:

- `SUPABASE_ANON_KEY`: pegue la anon key que copió (en los DOS archivos).
- `WHATSAPP`: su número en formato `504XXXXXXXX` (504 + los 8 dígitos, sin espacios ni guiones). Solo en `index.html`.
- `WHATSAPP_MOSTRAR`: cómo quiere que se vea, ej. `9999-9999`.

⚠️ La anon key es pública por diseño (va en el navegador). La seguridad real está en las políticas RLS del `setup.sql`: nadie puede escribir en su base sin su usuario y contraseña.

## PASO 3 — Subir a GitHub y Vercel (10 min)

1. En **github.com/ranchomorolica** cree un repositorio nuevo llamado `sitio-web` (público o privado).
2. Suba los 6 archivos (botón "Add file → Upload files").
3. En **vercel.com** → **Add New → Project** → importe el repo `sitio-web` → **Deploy** (sin cambiar nada).
4. En 1 minuto tendrá su sitio en `sitio-web-xxxx.vercel.app`. Pruébelo.
5. El panel queda en `su-dominio/admin.html` — entre con el correo y contraseña del Paso 1 y suba su primer animal.

💡 Para evitar el problema de despliegue que tuvo antes: cada vez que cambie un archivo en GitHub, verifique en Vercel → Deployments que aparezca un deployment nuevo con la hora correcta. Si no aparece, en Vercel → Settings → Git reconecte el repositorio.

## PASO 4 — Dominio (15 min + espera)

1. **ranchomorolica.com**: cómprelo en Namecheap (~$12/año). **ranchomorolica.hn**: se registra en **nic.hn** (Registro de Dominios de Honduras, ~$50/año).
2. En Vercel → su proyecto → **Settings → Domains** → agregue el dominio. Vercel le indica los registros DNS (un registro A y un CNAME) que debe poner donde compró el dominio.
3. Configure el `.com` para redirigir al `.hn` (o al revés — lo importante es tener los dos).

## PASO 5 — Aparecer en Google (10 min)

1. Entre a **search.google.com/search-console** con su cuenta de Google.
2. Agregue su dominio y verifíquelo (Vercel facilita la verificación por DNS).
3. En **Sitemaps**, envíe: `https://ranchomorolica.hn/sitemap.xml`
4. En **Inspección de URLs**, pegue su página principal y toque **Solicitar indexación**.
5. Refuerzo gratis y potente: cree el perfil de **Google Business Profile** (business.google.com) de Rancho Morolica con la ubicación Km 177, fotos del ruedo y el link a la página. Eso lo pone en Google Maps y en las búsquedas locales de inmediato.
6. Ponga el link de la página en la bio de TikTok, Facebook e Instagram, y menciónelo en sus videos: los clics desde redes le dicen a Google que la página es real y activa.

## Uso diario

- **Agregar animal**: entre a `/admin.html` desde el teléfono → llene lote, categoría, peso, precio → tome la foto ahí mismo → Guardar. Aparece al instante en la página.
- **Se vendió**: Editar → marque "Vendido" (sale con sello VENDIDO) o desmarque "Publicado" (desaparece).
- **Subasta en línea**: en el panel, sección "Próxima subasta": ponga nombre, fecha y el link del Facebook Live. La página muestra automáticamente la cuenta regresiva.

## Cómo funciona la subasta EN VIVO con pujas reales

Esto reemplaza la puja por WhatsApp: los compradores pujan directo en la página y el precio sube solo, en tiempo real, para todos los que estén viendo.

1. **Antes del día**: en `/admin.html`, guarde la subasta (nombre, fecha, descripción). Luego, en "Lotes de la subasta en vivo", agregue cada animal que va a rematar, en orden, con su precio de salida y el incremento mínimo de puja (ej. L 500).
2. **El día de la subasta**: cuando va a rematar un animal, presione **"Poner en vivo"** en ese lote. Automáticamente aparece en la página principal con foto, precio y un botón para pujar — solo puede haber un lote en vivo a la vez.
3. **Los compradores**: entran a la página, se registran una sola vez (nombre, WhatsApp, correo, contraseña) y ya pueden pujar con un botón. El precio y quién va ganando se actualizan solos, para todos, sin recargar la página.
4. **Cuando se cierra la puja**: presione **"Vendido"** (queda registrado el comprador ganador y el monto final) o **"Cerrar sin venta"** si no hubo comprador. Pase al siguiente lote.
5. **Compradores registrados**: en el panel, sección "Compradores registrados", puede ver a todos los que se han registrado y **bloquear** a alguien si es necesario (por ejemplo, pujas de broma) — un comprador bloqueado no puede pujar más.

La transmisión de Facebook Live sigue siendo importante: la gente ve el animal en persona, en báscula, y puja aquí mientras lo ve.

## Pendiente: el dominio

Esto quedó fuera de este cambio porque comprar un dominio requiere su tarjeta y sus datos personales en el registrador — no es algo que se pueda automatizar. Cuando esté listo, siga el **Paso 4** de este documento (comprar en Namecheap / nic.hn y conectarlo en Vercel → Settings → Domains).

## Fases siguientes

- **Fase 2**: registro de vendedores terceros con su comisión del 4% — se agrega un formulario de vendedor y aprobación desde su panel.
- ~~Fase 3: pujas en tiempo real~~ — ya está integrada arriba.
- **Fase 4**: app instalable (PWA) para que los compradores reciban notificación cuando empieza un lote nuevo.

Soli Deo Gloria 🐂
