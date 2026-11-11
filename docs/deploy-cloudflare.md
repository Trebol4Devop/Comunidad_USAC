# Despliegue web en Cloudflare Pages

El sitio se publica en **https://zanate.pages.dev** mediante *Direct Upload*: el
build de Flutter se hace en GitHub Actions y a Cloudflare solo se suben los
archivos ya compilados.

## Archivos relevantes

- `.github/workflows/deploy-cloudflare-pages.yml`: build + deploy.
- `wrangler.toml`: nombre del proyecto (`zanate`) y carpeta de salida
  (`comunidad_universitaria/build/web`).

El workflow corre con `push` a `main` y con `workflow_dispatch`. `develop` y los
PRs **no** despliegan; para publicar hay que integrar los cambios en `main`.

## Secrets requeridos en GitHub

Settings → Secrets and variables → Actions → Secrets:

| Nombre | Valor |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | Token con permiso *Account → Cloudflare Pages → Edit* |
| `CLOUDFLARE_ACCOUNT_ID` | `51f5709e5722058f9415fece11735834` |

Crear el token en <https://dash.cloudflare.com/?to=/:account/api-tokens> →
*Create Token* → *Custom token* → permiso **Account / Cloudflare Pages / Edit**.

## Variables opcionales

Settings → Secrets and variables → Actions → Variables:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` (clave pública de cliente; nunca `service_role`)

Si no existen, el build usa los valores por defecto de
`comunidad_universitaria/lib/core/config/supabase_config.dart`.

## Deploy manual (opcional)

Desde la raíz del repositorio, con credenciales de Wrangler:

```sh
cd comunidad_universitaria
flutter build web --release
cd ..
npx wrangler@4 pages deploy comunidad_universitaria/build/web --project-name=zanate
```

La primera vez, `wrangler login` abre el navegador para autorizar la cuenta.

## Notas

- Las URLs `*.pages.dev` no tienen cache de borde agresivo; no hace falta purgar
  tras un deploy.
- El proyecto no tiene dominio propio todavía. Para usar uno, agregarlo en
  Cloudflare Pages → `zanate` → *Custom domains*.
- Si se agrega `usePathUrlStrategy` a la app, también hay que agregar un archivo
  `_redirects` con `/* /index.html 200` en `comunidad_universitaria/web/`.
