# Rancho Morolica — Sitio web oficial
## Guía de instalación (30–45 minutos, se puede hacer desde el teléfono)

## Qué incluye este paquete

| Archivo | Qué es |
|---|---|
| `index.html` | La página pública: catálogo, subastas en línea, registro de compradores, WhatsApp, SEO |
| `admin.html` | Su panel privado: animales, subastas, verificación de compradores, depósitos, vendedores, facturas |
| `ruedo.html` | Panel simple para el rematador: registra las pujas físicas del ruedo |
| `factura.html` | Comprobante de compra imprimible (se abre solo, no lo edite) |
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

⚠️ **Si su proyecto ya tenía una versión anterior de `setup.sql` corrida** (de una vez anterior), no hay problema: vuelva a correr el `setup.sql` nuevo completo, es seguro — agrega las tablas y columnas nuevas sin borrar nada de lo que ya tenía.

## PASO 2 — Configurar los archivos (5 min)

Abra `index.html` y `admin.html` y busque la sección `CONFIG` (está al inicio del código JavaScript, claramente marcada). Cambie:

- `SUPABASE_ANON_KEY`: pegue la anon key que copió (en los DOS archivos).
- `WHATSAPP`: su número en formato `504XXXXXXXX` (504 + los 8 dígitos, sin espacios ni guiones). Solo en `index.html`.
- `WHATSAPP_MOSTRAR`: cómo quiere que se vea, ej. `9999-9999`.

⚠️ La anon key es pública por diseño (va en el navegador). La seguridad real está en las políticas RLS del `setup.sql`: nadie puede escribir en su base sin su usuario y contraseña.

## PASO 3 — Subir a GitHub y Vercel (10 min)

1. En **github.com/ranchomorolica** cree un repositorio nuevo llamado `sitio-web` (público o privado).
2. Suba todos los archivos de este paquete (botón "Add file → Upload files").
3. En **vercel.com** → **Add New → Project** → importe el repo `sitio-web` → **Deploy** (sin cambiar nada).
4. En 1 minuto tendrá su sitio en `sitio-web-xxxx.vercel.app`. Pruébelo.
5. El panel queda en `su-dominio/admin.html` — entre con el correo y contraseña del Paso 1 y suba su primer animal.

💡 Para evitar el problema de despliegue que tuvo antes: cada vez que cambie un archivo en GitHub, verifique en Vercel → Deployments que aparezca un deployment nuevo con la hora correcta. Si no aparece, en Vercel → Settings → Git reconecte el repositorio.

## PASO 4 — Dominio ✅ (ya hecho)

Se compró **ranchomorolica.com** en Namecheap y quedó conectado en Vercel → Settings → Domains (registro A en `@` apuntando a `216.198.79.1`). Si más adelante también quiere `ranchomorolica.hn` como respaldo, es opcional — no es necesario para que la página funcione.

## PASO 5 — Aparecer en Google (10 min)

1. Entre a **search.google.com/search-console** con su cuenta de Google.
2. Agregue su dominio y verifíquelo (Vercel facilita la verificación por DNS).
3. En **Sitemaps**, envíe: `https://ranchomorolica.com/sitemap.xml`
4. En **Inspección de URLs**, pegue su página principal y toque **Solicitar indexación**.
5. Refuerzo gratis y potente: cree el perfil de **Google Business Profile** (business.google.com) de Rancho Morolica con la ubicación Km 177, fotos del ruedo y el link a la página. Eso lo pone en Google Maps y en las búsquedas locales de inmediato.
6. Ponga el link de la página en la bio de TikTok, Facebook e Instagram, y menciónelo en sus videos: los clics desde redes le dicen a Google que la página es real y activa.

## Uso diario

- **Agregar animal**: entre a `/admin.html` desde el teléfono → llene lote, categoría, peso, precio → tome la foto ahí mismo → Guardar. Aparece al instante en la página.
- **Se vendió**: Editar → marque "Vendido" (sale con sello VENDIDO) o desmarque "Publicado" (desaparece).
- **Subasta en línea**: en el panel, sección "Próxima subasta": ponga nombre, fecha y el link del Facebook Live. La página muestra automáticamente la cuenta regresiva.

## Cómo funciona la subasta EN VIVO con pujas reales

Esto reemplaza la puja por WhatsApp: los compradores pujan directo en la página y el precio sube solo, en tiempo real, para todos los que estén viendo — y se combina con las pujas físicas del ruedo (ver más abajo), así que hay un solo precio verdadero en todo momento.

1. **Antes del día**: en `/admin.html`, guarde la subasta (nombre, fecha, descripción, y si quiere, el link del video en vivo). Luego, en "Lotes de la subasta en vivo", agregue cada animal que va a rematar, en orden, con su precio de salida, el incremento mínimo de puja (ej. L 500) y, si el animal es de un vendedor externo, selecciónelo ahí mismo.
2. **El día de la subasta**: cuando va a rematar un animal, presione **"Poner en vivo"** en ese lote. Automáticamente aparece en la página principal con foto, precio, video y un botón para pujar — solo puede haber un lote en vivo a la vez.
3. **Los compradores**: entran a la página, crean su cuenta (nombre, WhatsApp, correo, contraseña) y luego pasan por el proceso de verificación y depósito descrito abajo. Una vez aprobados, pujan con un botón; el precio y quién va ganando se actualizan solos, para todos, sin recargar la página.
4. **Cuando se cierra la puja**: presione **"Vendido"** — esto guarda el comprador ganador y el monto final, y genera automáticamente la factura/comprobante (se abre solo en una pestaña nueva, lista para imprimir o guardar como PDF). O presione **"Cerrar sin venta"** si no hubo comprador. Pase al siguiente lote.

## Verificar compradores antes de admitirlos (KYC)

Cuando alguien crea su cuenta en la página para pujar, no puede pujar de inmediato: primero debe completar sus datos (número de identidad, dirección, estado civil) y subir fotos de su identidad (frente y dorso). Esto queda pendiente hasta que usted lo revise:

1. En `/admin.html`, sección **"Verificación de compradores"**, vea la lista de quienes están esperando aprobación.
2. Presione **"Ver ID"** para abrir las fotos de su identidad (se abren en pestañas nuevas; solo usted puede verlas, están guardadas en un espacio privado).
3. Presione **"Aprobar"** o **"Rechazar"** (si rechaza, puede escribir el motivo — se lo mostramos al comprador en la página, y él puede escribirle por WhatsApp para corregir).
4. Un comprador aprobado todavía no puede pujar hasta pagar su depósito de garantía (siguiente sección).

## Depósito de garantía antes de pujar

Después de ser aprobado, la página le muestra al comprador el monto del depósito (L10,000 por defecto) y sus datos bancarios, y le pide subir una foto del comprobante de la transferencia/depósito:

1. Configure sus datos bancarios una sola vez en `/admin.html` → **"Configuración del sitio"** (también ahí se ajusta el monto del depósito y el tipo de cambio para mostrar precios en dólares).
2. Cuando un comprador suba su comprobante, aparecerá en `/admin.html` → **"Depósitos de garantía"**. Verifique que el dinero llegó a su cuenta y presione **"Ver comprobante"** para confirmar el monto.
3. Presione **"Aprobar"** — recién ahí ese comprador puede pujar. Si algo no cuadra, presione **"Rechazar"** con el motivo.

## Vendedores externos (consignatarios) y sus reseñas

Para ranchos ajenos que consignan ganado con usted:

1. En `/admin.html` → **"Vendedores externos"**, dé de alta la finca (nombre de contacto, teléfono, nombre y ubicación de la finca, y su % de comisión).
2. Al registrar un animal (o un lote de subasta), selecciónelo en el campo **"Vendedor"** — si lo deja en "Rancho Morolica (propio)", es un animal suyo, sin comisión.
3. Los compradores ya aprobados pueden dejar una reseña de 1 a 5 estrellas de cada vendedor desde la sección "Vendedores" de la página pública; el promedio y la cantidad de reseñas se muestran ahí y también junto al animal en el catálogo.
4. Cada venta genera su factura automáticamente con el desglose de la comisión de ese vendedor.

## Precio también en dólares

Se calcula solo a partir del tipo de cambio que usted pone en `/admin.html` → "Configuración del sitio". Actualícelo cuando cambie el valor del dólar; no se conecta a ningún servicio externo.

## El video en vivo dentro de la página

En `/admin.html` → "Próxima subasta en línea", pegue el link de su transmisión de Facebook Live (o YouTube) en el campo "Link del video en vivo" y guarde. Aparece incrustado automáticamente arriba de la puja en línea — el comprador ve el remate y puja sin salir de la página.

## Pujas físicas del ruedo (coordinadas con las de la página)

Abra `ruedo.html` desde un teléfono o tablet en el ruedo (hay un link directo en `/admin.html` → "Configuración del sitio"). Inicie sesión con su misma cuenta de administrador. Mientras un lote está "en vivo":

- Vea el precio actual, grande, igual que en la página.
- Cuando alguien ofrezca presencialmente, escriba el monto (o use el mínimo que ya viene sugerido) y el número/nombre del comprador presencial, y presione **"Registrar puja física"**.
- Esa puja se suma exactamente a la misma cadena de pujas que ven los compradores en línea — el precio del ruedo y el de internet son siempre el mismo, en tiempo real.

## Pendiente: el dominio

Esto quedó fuera de este cambio porque comprar un dominio requiere su tarjeta y sus datos personales en el registrador — no es algo que se pueda automatizar. Cuando esté listo, siga el **Paso 4** de este documento (comprar en Namecheap / nic.hn y conectarlo en Vercel → Settings → Domains).

## Fases siguientes

- ~~Fase 2: registro de vendedores terceros~~ — ya está integrada arriba.
- ~~Fase 3: pujas en tiempo real~~ — ya está integrada arriba.
- **Fase 4**: app instalable (PWA) para que los compradores reciban notificación cuando empieza un lote nuevo; y, si más adelante quiere cobrar el depósito con tarjeta en línea en vez de transferencia manual, contratar una pasarela de pago (Stripe u otra que opere en Honduras).

Soli Deo Gloria 🐂
