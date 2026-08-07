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

## Se unificó con su programa de subasta (Panel de Control / Proyector)

Su tabla real de `vendedores` (la de su programa de ruedo) ahora es la misma que usa la página web — ya no hay dos por separado. Además, se le puso el candado de seguridad a las 6 tablas de ese programa que estaban completamente públicas (`clientes`, `compradores`, `lotes`, `historial_ventas`, `subasta_en_vivo`, `subastas_archivadas`): antes cualquiera en internet podía leerlas y modificarlas; ahora solo funcionan si inició sesión con su cuenta de administrador.

Dos pasos para que esto quede funcionando:

1. **Corra el `setup.sql` nuevo** en Supabase (el de siempre — SQL Editor → pegar todo → Run). Agrega las columnas que faltan en `vendedores` (correo, nombre de finca, etc.) y pone el candado en las 6 tablas.
2. **Reemplace el `App.js`** de su programa del ruedo por el que le mandé — ahora pide el mismo correo y contraseña de `admin.html` en vez de la contraseña compartida de antes. Sin este paso, el programa del ruedo deja de poder leer/escribir esas tablas (por el candado nuevo) hasta que inicie sesión de verdad.

## Maquinaria, silobolsa y pacas de heno

En `/admin.html` → **"Maquinaria y suministros"**: agregue cada artículo con su categoría (Maquinaria, Silobolsa, o Pacas de heno), foto, precio, y si quiere, marca/modelo/año/horas de uso (para maquinaria) o cantidad/unidad (para silobolsa y pacas). Aparecen en su propia sección "Maquinaria y suministros" de la página pública, separado del ganado.

## Modos de precio: directo u oferta (estilo eBay)

Al agregar o editar un animal o un artículo, en **"Modo de venta"** elija:

- **Precio directo** (como siempre): el comprador escribe por WhatsApp al precio publicado.
- **Permitir que el comprador haga una oferta**: en la página aparece un botón "Hacer una oferta" donde el comprador (ya registrado) propone un monto. Le llega a `/admin.html` → **"Ofertas recibidas"**, donde puede:
  - **Aceptar** → se marca vendido y genera la factura sola.
  - **Rechazar**.
  - **Contraofertar** → le pide otro monto; al comprador le aparece esa contraoferta en su propia página (arriba del catálogo) para aceptar o rechazar.

La subasta en vivo sigue siendo su propio modo aparte (con pujas en tiempo real), no cambia con esto.

## Publicaciones de usuarios: la gente publica desde su casa

Ya no depende solo de usted para subir cada animal o artículo. Un comprador con su identidad ya verificada (el mismo proceso de KYC de las subastas en línea) puede publicar su propio ganado o su maquinaria/silobolsa/pacas directo desde la página, sin tocar `/admin.html`:

1. En la página pública, sección **"Vende con nosotros"** → **"Publique usted mismo desde casa"**. Si no ha iniciado sesión o no tiene su identidad aprobada, la página le explica qué falta (crear cuenta o completar la verificación en "Subastas en línea").
2. Una vez aprobado, llena el formulario (tipo de artículo, categoría, precio, foto, modo de venta) y publica. **Queda "en revisión" y NO aparece en el catálogo público todavía** — así evitamos anuncios falsos o de mala fe.
3. A usted le llega a `/admin.html` → nueva sección **"Publicaciones de usuarios"**, con **Aprobar**/**Rechazar** (si rechaza, puede escribir el motivo y se lo muestra al usuario en su propia lista "Mis publicaciones").
4. Una vez aprobada, aparece igual que cualquier otro animal/artículo del catálogo — con la ventaja de que el usuario mismo puede editar precio/foto o marcarla vendida desde su "Mis publicaciones", sin escribirle a usted. Al marcarla vendida, se genera sola la factura con la **comisión de mercado** (configurable en `/admin.html` → "Configuración del sitio", campo "Comisión de mercado (%)" — es distinta de la comisión de los vendedores consignatarios).
5. El comprador nunca puede tocar el estado de aprobación, el vendedor asignado, ni publicar a nombre de otro — eso solo lo cambia usted.

⚠️ Esta factura de comisión queda **registrada**, pero el **cobro real de esa comisión todavía no está conectado a nada** — ver la sección de abajo sobre PixelPay.

## Cobro real de la comisión (PixelPay u otra pasarela) — qué falta

Ahora mismo, cuando alguien marca su propio artículo como vendido, el sistema calcula y registra cuánto le debe al rancho por comisión, pero no se lo cobra automáticamente — es un número en la factura, nada más. Para que el cobro sea real hay dos caminos, y le recomiendo el primero por ser mucho más simple y no requerir licencias:

- **Cobrar solo la comisión** (recomendado): el comprador y el vendedor arreglan el pago del animal/artículo entre ellos (transferencia, efectivo, como ya hacen), y la página le cobra al vendedor SOLO su comisión con tarjeta a través de PixelPay, como un cobro normal de comercio. Esto no requiere que el rancho maneje ni retenga el dinero de la venta completa.
- Manejar el dinero completo de la venta (dinero del comprador pasa por el rancho y luego se le entrega al vendedor) es "escrow" — legalmente se acerca a ser un transmisor de dinero, con requisitos regulatorios en Honduras que no vale la pena asumir solo para esto.

**Lo que necesito de usted para conectarlo de verdad (no de mentiras):**
1. Cree una cuenta de comercio (merchant account) en **PixelPay** (pixelpay.co) — es la pasarela hondureña más usada. Con eso le dan sus credenciales de API (llave pública y llave privada/secreta).
2. Me pasa esas credenciales (o las carga usted mismo como variable de entorno en Vercel, mejor aún — así ni yo las veo).
3. Con eso conecto un botón real de "Pagar mi comisión" en la factura del vendedor, que cobra la tarjeta a través de PixelPay y marca la factura como pagada solo cuando el banco confirma el cobro.

## Boletines y promociones automáticas — qué falta

Ya se recopilan los datos de compradores y vendedores (nombre, teléfono, correo) en los directorios de `/admin.html`, exportables en CSV. Para que el envío de boletines sea automático (no manual, uno por uno) hace falta un servicio de correo masivo — Gmail/Outlook normales bloquean el envío masivo y lo marcan como spam.

**Lo que necesito de usted:**
1. Cree una cuenta en un servicio de correo masivo — le recomiendo **Brevo** (antes Sendinblue, tiene plan gratis hasta 300 correos/día y es fácil de usar en español) o Mailchimp.
2. Me pasa su API key de ese servicio (o la carga usted mismo en Vercel como variable de entorno).
3. Con eso conecto: (a) que cada nuevo comprador/vendedor se agregue solo a su lista de contactos ahí, y (b) un botón en `/admin.html` para mandar un boletín/promoción a toda su lista (o segmentada, ej. solo vendedores, o solo compradores de cierta zona) sin salir de su panel.

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
- ~~Fase 4: publicaciones de usuarios (marketplace) con moderación~~ — ya está integrada arriba.
- **Fase 5**: cobro real de la comisión de mercado con PixelPay, y boletines/promociones automáticas por correo — ambas listas para conectar en cuanto usted tenga las cuentas (ver secciones de arriba); app instalable (PWA) para notificaciones cuando empieza un lote nuevo.

Soli Deo Gloria 🐂
