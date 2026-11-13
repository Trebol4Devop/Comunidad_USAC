# Correcciones aplicadas — Comunidad_USAC

**Fecha:** 13 de noviembre de 2026
**Base:** `feature/auditoria-supabase-rls` → `develop`
**Restricción respetada:** no se modificó nada en Supabase (ni DDL, ni políticas, ni buckets, ni funciones). Todo el trabajo adapta la app y su tooling al esquema y a las políticas existentes.
**Informe de hallazgos:** `AUDITORIA-SUPABASE-2026-11-13.md`

---

## 1. El cambio de fondo: dejar de leer las vistas `safe_*`

Las vistas `safe_posts_feed`, `safe_comments`, `safe_marketplace_items` y `safe_student_groups` filtran `moderation_status = 0` (pendiente) mientras que RLS usa `IS DISTINCT FROM 2`. Como no se puede tocar la base, el feed y los listados pasan a consultar la tabla canónica con lista explícita de columnas (las que tienen `GRANT SELECT`) y filtro `.neq('moderation_status', 2)`, que es exactamente el criterio de RLS.

| Archivo | Cambio |
|---|---|
| `lib/core/services/forum_service.dart` | `safe_posts_feed` → `posts` + `_postFallbackColumns` + `.neq('moderation_status', 2)` en el feed, en los posts guardados y en los posts citados. `safe_comments` → `comments` + `_commentFallbackColumns` + mismo filtro. |
| `lib/core/services/marketplace_service.dart` | Nueva constante `_marketColumns`; `safe_marketplace_items` → `marketplace_items` en el listado y en los patrocinados. |
| `lib/core/services/groups_service.dart` | Nueva constante `_groupColumns`; `safe_student_groups` → `student_groups` en el listado. |
| `lib/core/services/profile_service.dart` | El listado de publicaciones del perfil usa `posts` con columnas explícitas y `.neq('moderation_status', 2)`. |

> Se conservan las vistas `safe_*` únicamente en las consultas "mis elementos" (`fetchUserGroups`, `fetchUserMarketplaceItems`), porque su `WHERE (status = 0 OR is_mine(...))` sí las hace funcionar para el propio autor.

---

## 2. Resto de correcciones por archivo

### `lib/core/services/marketplace_service.dart`
- **`canCreateListing()`**: se elimina la consulta a `profiles.seller_verification_status` (columna inexistente que hacía que la función devolviera siempre `false`) y se exige únicamente sesión autenticada no anónima. La base no tiene forma de acreditar vendedores, así que el gate no puede depender de esa columna.
- **`moderateListing()`**: se elimina el `catchError` que intentaba un `update({moderation_status})` directo (rechazado por RLS y por los disparadores). Queda solo la RPC `moderate_marketplace_item`, que valida el rol y audita.

### `lib/core/models/notification_item.dart`
`toMap()` ya no envía la clave `carreras`, que no existe en `notification_preferences`.

### `lib/core/services/notification_service.dart`
Las carreras se persisten en la tabla real `notification_preference_carreras` (con RLS de "solo mis filas"):
- `_fetchCareerPreferences(uid)` las lee al cargar las preferencias.
- `_saveCareerPreferences(uid, carreras)` reemplaza las filas al guardar.
Resultado: los toggles y la selección de carreras se guardan de verdad.

### `lib/core/services/share_count_service.dart`
Se elimina el `update({shares_count})` que siempre fallaba con `42501` (la columna no está en el `GRANT UPDATE`). El contador queda local, que es el único comportamiento posible sin cambios de backend. La firma pasa de `incrementShare(id, {table})` a `incrementShare(id)`; se actualizaron los 3 llamadores (`forum_screen`, `post_detail_screen`, `marketplace_screen`).

### `lib/features/map/services/campus_community_supabase_service.dart`
Se elimina la consulta a `profiles.alias` (columna inexistente → `42703`) y se usa el alias recibido por parámetro.

### `lib/features/sso/screens/sso_authorize_screen.dart`
El `debugPrint` de error ya no interpola la excepción (que contenía la URL con `access_token` y `refresh_token`); solo registra el tipo.

### `supabase/functions/moderation-worker/index.ts` + `README.md`
Corregida la asignación de estados para que coincida con la semántica real de la base:

| Veredicto | Antes | Ahora |
|---|---|---|
| `SAFE_CAMPUS_HUMOR` | `0` (pendiente) | `1` (aprobado) |
| Riesgo con `0.50 ≤ conf < 0.80` | `1` (aprobado, se publicaba) | `3` (cola de revisión humana) |
| Riesgo con `conf ≥ 0.80` | `2` (oculto) | `2` (oculto, sin cambios) |

### `.github/workflows/deploy-cloudflare-pages.yml`
Antes de compilar y desplegar se ejecutan ahora `flutter analyze --no-fatal-infos` y `flutter test --no-pub`. Un fallo de análisis o de pruebas detiene el despliegue.

### `.github/workflows/flutter-tests.yml`
Se añade `permissions: contents: read`.

### `supabase/config.toml`
`minimum_password_length` 6 → 12 y `password_requirements = "lower_upper_letters_digits"`.

### Pruebas
Se actualizaron los mocks de `forum_service_test`, `groups_service_test`, `marketplace_service_test` y `profile_service_test` para apuntar a los endpoints canónicos (`/rest/v1/comments`, `/rest/v1/student_groups`, `/rest/v1/marketplace_items`, `/rest/v1/posts`). En `marketplace_service_test` se reemplazó la prueba del gate de verificación (que ya no existe) por una de `canCreateListing`.

---

## 3. Cómo verificar

```bash
cd comunidad_universitaria
flutter pub get
flutter analyze --no-pub     # No issues found!
flutter test --no-pub        # servicios: 66/66 OK
flutter run -d chrome
```

Comprobaciones funcionales:
1. **Foro**: un post aprobado (`moderation_status = 1`) debe seguir visible en el feed (antes desaparecía).
2. **Marketplace**: "Publicar anuncio" debe estar disponible para un usuario autenticado.
3. **Ajustes → Notificaciones**: los cambios deben persistir tras cerrar y reabrir.
4. **Perfil**: debe listar las publicaciones propias, incluidas las aprobadas.
5. **Compartir**: el contador sube localmente y ya no genera peticiones fallidas.
6. **Foro del campus (mapa)**: comentar ya no intenta leer `profiles.alias`.

---

## 4. Requiere despliegue o DDL (no aplicado)

```bash
# 1. Desplegar el worker corregido
supabase functions deploy moderation-worker --project-ref hfvsstkfqszpjrsrwhql

# 2. Programar la ejecución del worker (pg_cron + pg_net)
select cron.schedule('moderation-worker', '*/2 * * * *', $$
  select net.http_post(
    url := 'https://hfvsstkfqszpjrsrwhql.supabase.co/functions/v1/moderation-worker',
    headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.worker_secret'))
  );
$$);
```

DDL sugerido para los pendientes:

```sql
-- Vistas safe_* alineadas con RLS (0 = pendiente, 1 = aprobado, 2 = oculto)
CREATE OR REPLACE VIEW public.safe_posts_feed
WITH (security_invoker = true) AS
SELECT ... FROM public.posts p
WHERE p.deleted_at IS NULL
  AND p.moderation_status IN (0, 1)
  AND (p.expires_at IS NULL OR p.expires_at > now());
-- (idéntico criterio para safe_comments, safe_marketplace_items y safe_student_groups)

-- solicitudes de patrocinio legibles y gestionables por staff
CREATE POLICY "Staff reads sponsor_requests" ON public.sponsor_requests
  FOR SELECT TO authenticated
  USING (public.is_pemtree_admin((SELECT auth.uid())) OR public.is_pemtree_moderator((SELECT auth.uid())));
```

Para restaurar las reseñas del campus habría que aplicar `auditoria-sql/04` corregida (la función `get_target_reviews_with_authors` referencia `profiles.alias`, que no existe) o retirar la pantalla.

---

## 5. No corregido (fuera de alcance)

| Tema | Motivo |
|---|---|
| Vistas `safe_*` | Requiere DDL; el cliente ya no depende de ellas en los feeds |
| Reseñas de campus | Requiere tablas y RPC inexistentes |
| `TotpSessionGuard` sin montar y sin `aal` en RLS | Decisión de producto + cambios de políticas |
| Carné/nombre en `SharedPreferences` | Requiere añadir `flutter_secure_storage` y migrar datos |
| Drift de migraciones (`db reset` imposible) | Reorganización de todo el historial SQL |
| SSO con `refresh_token` en la URL | Rediseño a *authorization code* + PKCE en ambas apps |
| 29 pruebas de widgets que ya fallaban | Preexistentes, ajenas a Supabase |
