# Login compartido entre Zanate y PEMTREE

Arquitectura elegida: **un solo backend de identidad** y **SSO con Zanate como
emisor**.

- Proyecto Supabase (identidad única): `hfvsstkfqszpjrsrwhql` (nombre en el
  dashboard: *PEMTREE*).
- Zanate (Flutter web, `https://zanate.pages.dev`): pantalla de login y
  consentimiento en `/auth/authorize`.
- PEMTREE (React, `https://pemtree.netlify.app`): cliente SSO. Redirige a
  Zanate y recibe la sesión en `/auth/callback`.

El proyecto `jsdshvnkbrkwobfhdysh` (*Comunidad_USAC*) **no** se usa para login.
Sus migraciones y usuarios no están conectados a ninguna de las dos apps.

## Flujo

1. PEMTREE abre
   `https://zanate.pages.dev/auth/authorize?client_id=pemtree&redirect_uri=https%3A%2F%2Fpemtree.netlify.app%2Fauth%2Fcallback&state=...`.
2. Zanate valida `client_id`, `redirect_uri` y, si no hay sesión, ofrece
   únicamente iniciar sesión con Google.
3. Tras el consentimiento, Zanate redirige al `redirect_uri` con
   `access_token`, `refresh_token` y `state` en el fragmento.
4. PEMTREE valida el `state`, crea la sesión con `setSession`, limpia la URL y
   vuelve a la ruta original.

## Configuración de Supabase Auth

Dashboard → proyecto **PEMTREE** → *Authentication* → *URL Configuration*:

- **Site URL**: `https://zanate.pages.dev`
- **Redirect URLs**:
  - `https://zanate.pages.dev/**`
  - `https://pemtree.netlify.app/**`
  - `https://*--pemtree.netlify.app/**` (previews de Netlify)
  - `http://localhost:3000/**` (Zanate local)
  - `http://localhost:5173/**` (PEMTREE local)
  - `comunidadusac://login-callback/` (app nativa)

Proveedores → *Google*: ya está habilitado. El callback registrado en Google
Cloud debe ser exactamente
`https://hfvsstkfqszpjrsrwhql.supabase.co/auth/v1/callback`.

El flujo actual de Zanate/PEMTREE usa únicamente Google para autenticarse.
La configuración de confirmación de Email en Supabase no altera ese flujo; no se
ofrece registro por correo/contraseña ni se envían códigos de confirmación.

> El MCP de Supabase disponible en este entorno solo expone herramientas de
> base de datos (SQL, migraciones, ramas, logs). No permite leer ni escribir la
> configuración de Auth; eso se hace en el dashboard o con la Management API
> usando un personal access token.

### Aplicarlo con la Management API

Con un token de <https://supabase.com/dashboard/account/tokens>:

```sh
SUPABASE_ACCESS_TOKEN=sbp_xxx ./scripts/configure-auth.sh --show   # ver actual
SUPABASE_ACCESS_TOKEN=sbp_xxx ./scripts/configure-auth.sh          # aplicar
```

El script fija `site_url`, `uri_allow_list` y no toca proveedores ni plantillas.
También acepta `SUPABASE_PROJECT_REF` si algún día cambia el proyecto.

## Variables de entorno

PEMTREE (Netlify → *Site configuration* → *Environment variables*):

- `VITE_COMMUNITY_AUTH_URL=https://zanate.pages.dev`
- `VITE_SUPABASE_URL=https://hfvsstkfqszpjrsrwhql.supabase.co`
- `VITE_SUPABASE_ANON_KEY=<anon key>`

Sin `VITE_COMMUNITY_AUTH_URL`, el build de producción usa
`https://zanate.pages.dev` y el de desarrollo `http://localhost:3000`
(ver `pemtree-react/src/lib/communityAuth.js`).

## Seguridad

- `redirect_uri` solo se acepta en `pemtree.netlify.app` (y subdominios de
  preview), `pemtree.com`, `pemtree.app`, `pemtree.org`, siempre sobre HTTPS y
  con ruta `/auth/callback`. Antes se aceptaba cualquier `*.netlify.app`.
- El `state` generado por PEMTREE es obligatorio en la vuelta.
- Zanate ya no emite tokens falsos: si no hay sesión real, bloquea la
  autorización (salvo builds de depuración sin Supabase configurado).

## Verificación

1. En Zanate, abrir
   `https://zanate.pages.dev/auth/authorize?client_id=pemtree` sin sesión:
   debe mostrar el formulario de login, no un error de redirect.
2. Iniciar sesión con Google y aceptar: debe volver a PEMTREE en
   `/auth/callback` y terminar en la ruta de origen.
3. En PEMTREE, `supabase.auth.getSession()` debe devolver el usuario.
4. Probar un `redirect_uri` ajeno
   (`https://evil.netlify.app/auth/callback`): Zanate debe rechazarlo.
