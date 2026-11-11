# Worker de imágenes (R2) — caché CDN

Este directorio no contiene el código del Worker desplegado (vive en Cloudflare,
por eso `worker/src` está vacío). Este documento deja el snippet y los pasos para
servir las imágenes con caché agresiva.

Contexto actual:

- Worker: `https://comunidad-usac-storage.carlosdelcidramirez.workers.dev`
- Escritura: `POST /upload` (presigned PUT) y luego `PUT` directo a R2.
- Lectura: `GET /images/<folder>/<filename>`.
- Las claves son inmutables por diseño: `<userId>_<timestamp>_<nombre>`.
  Un mismo objeto nunca se sobreescribe con contenido nuevo, por lo que se puede
  usar `immutable` con seguridad.

## 1. Snippet: `Cache-Control` en `/images/*`

En el handler del Worker, para la ruta de lectura de imágenes:

```js
export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname.startsWith('/images/')) {
      const key = url.pathname.slice('/images/'.length);
      const object = await env.R2_BUCKET.get(key); // ajusta el nombre del binding

      if (object === null) {
        return new Response('Not found', { status: 404 });
      }

      const headers = new Headers();
      object.writeHttpMetadata(headers); // conserva Content-Type original
      headers.set('etag', object.httpEtag);
      headers.set('Access-Control-Allow-Origin', '*');

      // URLs inmutables: cachear 1 año en navegador y CDN.
      headers.set('Cache-Control', 'public, max-age=31536000, immutable');

      return new Response(object.body, { headers });
    }

    // ... resto de rutas existentes (/upload, etc.)
  },
};
```

Notas:

- `Content-Type` sale de la metadata que R2 guardó en el `PUT`; no hay que
  fijarlo a mano.
- Si el Worker ya arma `Headers` en esa rama, basta con agregar el `headers.set`
  de `Cache-Control`; no cambies nada más.
- `max-age` aplica al navegador; el cache de borde de Cloudflare para
  `*.workers.dev` es limitado, de ahí la opción de dominio propio + Cache Rule.

## 2. Dominio propio `img.<dominio>` + Cache Rule

1. En Cloudflare Dashboard → **R2** → bucket de imágenes → **Settings** →
   **Public access** → **Custom Domains** → **Connect Domain**.
2. Usa `img.<tudominio>` (el dominio debe estar en la misma cuenta Cloudflare).
   Cloudflare crea el registro DNS automáticamente y lo deja proxied.
3. Verifica que R2 ya sirve el objeto:

   ```sh
   curl -I https://img.<tudominio>/images/forum/123_1700000000_foto.jpg
   ```

   Si el objeto no trae `Cache-Control` propio, la respuesta puede no incluirlo;
   la Cache Rule de abajo lo fuerza de todas formas.
4. Cache Rule: Dashboard → **Caching** → **Cache Rules** → **Create rule**:
   - **Nombre**: `R2 images immutable`
   - **When incoming requests match**: `starts_with(http.request.uri.path, "/images/")`
     (o `http.host eq "img.<tudominio>"` si prefieres por host).
   - **Cache eligibility**: `Eligible for cache`.
   - **Edge TTL**: `Ignore cache-control header and use this TTL` →
     `31536000` segundos (1 año).
   - **Browser TTL**: `Override origin` → `31536000` segundos.
5. Guarda y prueba de nuevo con `curl -I`: deben aparecer
   `cache-control: public, max-age=31536000, immutable` y, en una segunda
   petición, `cf-cache-status: HIT`.

Detalles importantes:

- Cloudflare solo cachea por defecto ciertas extensiones (las imágenes ya están
  en la lista), pero la Cache Rule garantiza el TTL largo y cubre cualquier ruta
  bajo `/images/`.
- Opcional: activar **Smart Tiered Cache** para que el upper tier quede cerca
  del bucket R2.
- Como las claves son inmutables, no hace falta purgar al subir una imagen
  nueva. Solo purgaría si se sobreescribe una clave existente (no es el caso).
- Si el Worker sigue siendo el que responde `/images/*` en `workers.dev`, el
  navegador cachea 1 año, pero el borde de Cloudflare no; para cache de borde
  hay que servir por el dominio propio del bucket (o por una ruta/dominio del
  Worker, donde sí aplica la Cache Rule).

## 3. Pendiente conocido (no tocar todavía)

`comunidad_universitaria/lib/core/services/storage_service.dart` todavía tiene
`convertSupabaseUrlToR2`, pensado para migrar URLs viejas de Supabase Storage a
R2. Hoy no se llama desde ningún lado del código Flutter (búsqueda en `lib/` sin
resultados), pero se deja como está: no eliminarlo en esta tarea.
