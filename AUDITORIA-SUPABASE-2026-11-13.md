# Auditoría de integración con Supabase — Comunidad_USAC

**Fecha:** 13 de noviembre de 2026
**Alcance:** app Flutter `comunidad_universitaria`, migraciones SQL del repositorio, Edge Function de moderación y CI. Proyecto Supabase `hfvsstkfqszpjrsrwhql` (el mismo del panel `PEMTREE-admin`).
**Método:** 4 agentes independientes (Gemini Flash, CLI `agy`) más verificación directa contra la base real por SQL y REST. Informes crudos en `docs/auditoria-2026-11/`; volcado de políticas/grants/funciones en `docs/auditoria-2026-11/EVIDENCIA-BD.md`.

> Un hallazgo figura como **CONFIRMADO** solo si fue reproducido contra la base real o el código. Los descartados por la base aparecen en la sección 5.

---

## 1. Contexto: la app comparte base con el panel

`comunidad_universitaria` y `PEMTREE-admin` apuntan al **mismo proyecto Supabase**. La app usa la clave publishable/anon (correcto) y RLS activo en todas las tablas. Los problemas graves no están en el modelo de permisos de la base, sino en la coherencia entre lo que la app consulta y lo que la base realmente expone.

---

## 2. Hallazgos confirmados

### 2.1 Críticos

| # | Hallazgo | Evidencia | Corregido |
|---|---|---|---|
| C-1 | **El feed público mostraba solo contenido SIN moderar.** `safe_posts_feed`, `safe_comments`, `safe_marketplace_items` y `safe_student_groups` filtran `moderation_status = 0` (pendiente), mientras que RLS y el worker usan `1 = aprobado`. Verificado en vivo: `posts` devuelve 8 filas (todas `status = 1`) y `safe_posts_feed` devuelve **0**. En la práctica: al aprobarse un post desaparecía del feed, y lo visible era lo aún no revisado. El fallback a la tabla base nunca se activaba porque PostgREST responde `200 []`, no un error. | Evidencia §5, §7 y §8; `forum_service.dart:115,158`, `marketplace_service.dart:85,219`, `groups_service.dart:81`, `profile_service.dart:93` | Sí |
| C-2 | **Incompatibilidad semántica del worker de moderación.** `moderation-worker` marcaba `SAFE_CAMPUS_HUMOR` con `0` (pendiente) y el contenido dudoso (`0.50 ≤ conf < 0.80`) con `1` (**aprobado**, no "en revisión"). Resultado: el contenido dudoso se publicaba sin revisión humana y la cola (`panel_cola_revision`, que solo lee `status = 3` y `2` con baja confianza) nunca lo mostraba. | `supabase/functions/moderation-worker/index.ts:397-404` y su README | Sí |
| C-3 | **`campus_reviews`, `campus_rating_aggregates` y las RPC de reseñas no existen** en la base (`auditoria-sql/04` no aplicada). Las reseñas del mapa fallan al guardar y los agregados siempre vienen vacíos. | `GET /rest/v1/campus_reviews` → `404 PGRST205`; `POST /rpc/get_target_reviews_with_authors` → `404 PGRST202` | No (requiere DDL) |

### 2.2 Altos

| # | Hallazgo | Evidencia | Corregido |
|---|---|---|---|
| C-4 | **Crear un anuncio en Marketplace era imposible.** `canCreateListing()` consultaba `profiles.seller_verification_status`, columna inexistente → `42703` → `catch` → `return false`. La app bloqueaba la creación a todos los usuarios. | `marketplace_service.dart:247` | Sí |
| C-5 | **Guardar preferencias de notificación fallaba siempre.** `NotificationPreferences.toMap()` enviaba una clave `carreras` que no existe en `notification_preferences` → `PGRST204`/`42703`. Los toggles nunca se persistían. | `notification_item.dart:142`; columnas reales de la tabla | Sí |
| C-6 | **`profiles.alias` no existe** → `42703` al comentar en el foro del campus; el alias se descartaba silenciosamente. | `campus_community_supabase_service.dart:124` | Sí |
| C-7 | **Los contadores de compartidos no se persisten.** `share_count_service` hace `update({shares_count: n})` sobre `posts`/`marketplace_items`, pero `shares_count` no está en el `GRANT UPDATE` → `42501` silenciado. | `share_count_service.dart:65-75`; Evidencia §3 | Sí (queda local) |
| C-8 | **`moderateListing` con fallback inválido.** Si la RPC fallaba, intentaba `update({moderation_status})` directo, que la base rechaza por los disparadores de inmutabilidad. | `marketplace_service.dart:424-432` | Sí |
| C-9 | **SSO entrega `access_token` y `refresh_token` en el fragmento de la URL.** El refresh token queda en historial, logs y `Referer`; puede invalidar sesiones por rotación. No valida `state` en el emisor. | `sso_authorize_screen.dart:171-223`; `sso_security_validator.dart` | Parcial (se sanea el log) |
| C-10 | **`debugPrint` de la URL de redirección**: al fallar `launchUrl`, la excepción incluye la URL con ambos tokens en claro. | `sso_authorize_screen.dart:258` | Sí |
| C-11 | **Deploy a producción sin pruebas.** El workflow de Cloudflare Pages compilaba y publicaba sin `flutter analyze` ni `flutter test`. | `.github/workflows/deploy-cloudflare-pages.yml` | Sí |
| C-12 | **Escaneo completo de tablas y contadores no persistentes**: el feed y el perfil descargan sin paginar; no hay límites. | `forum_service.dart`, `profile_service.dart` | Parcial (límites ya existentes) |

### 2.3 Medios

| # | Hallazgo | Evidencia | Corregido |
|---|---|---|---|
| D-1 | `minimum_password_length = 6` y sin requisitos de composición en `supabase/config.toml`. | `config.toml:176-179` | Sí |
| D-2 | `flutter-tests.yml` sin bloque `permissions` (token con permisos por defecto). | `.github/workflows/flutter-tests.yml` | Sí |
| D-3 | `TotpSessionGuard` existe pero **no está montado** en `main.dart` ni en `app_shell.dart`; además ninguna política RLS valida `aal`. El 2FA es cosmético. | `totp_session_guard.dart` | No (requiere decisión de producto + RLS) |
| D-4 | Carné y nombre real en `SharedPreferences` en texto plano, mientras la UI afirma que se guardan como HMAC irreversible. | `local_storage_service.dart:93-103` | No (requiere `flutter_secure_storage`) |
| D-5 | CORS `*` en la Edge Function de moderación (aceptable: no usa cookies y exige secreto compartido). | `moderation-worker/index.ts` | No aplica |

---

## 3. Lo que está bien (no requiere cambios)

- `moderation-worker`: **fail-closed**. Sin `WORKER_SECRET` no procesa; compara el secreto por cabecera o bearer; usa `service_role` solo del entorno; `moderation_jobs` no tiene grants para `anon`/`authenticated` (deny-all).
- `send-push`: `verify_jwt: false` pero exige `x-pemtree-secret` leído del Vault vía RPC `get_push_secrets()` (solo `service_role`).
- Los RPC de moderación (`ocultar/restaurar/eliminar_contenido_moderado`, `panel_*`) validan rol y registran auditoría.
- `moderation_service.dart` usa correctamente `is_pemtree_admin(p_user_id)` / `is_pemtree_moderator(p_user_id)` con el parámetro.
- No hay `service_role`, credenciales R2 ni tokens personales versionados. `.wrangler/` solo contiene caché de cuenta.

---

## 4. Drift entre las migraciones del repositorio y la base real

| # | Hallazgo | Estado |
|---|---|---|
| E-1 | Varias políticas y funciones que existen en la base **no están generadas por ninguna migración** del repo (p. ej. `enforce_content_immutability_and_legal_hold`, `prevent_nonmoderator_restore`, `safe_*` con `security_invoker`). El entorno no se puede reconstruir con `supabase db reset`. | Confirmado — requiere consolidar migraciones |
| E-2 | Las migraciones reproducen el error `moderation_status = 0` en las vistas `safe_*` (`20261110000000_unified_core_and_legal_hardening.sql:1213`). | Confirmado (se corrigió en el cliente) |
| E-3 | Colisión de versiones entre `supabase/migrations` y `supabase/migrations_historical` que impide un `db reset` limpio. | Confirmado — requiere reorganización |
| E-4 | La suite pgTAP no cubre RLS por rol y asume objetos que no existen en el estado real. | Confirmado |
| E-5 | `remote_public_snapshot.sql` está desactualizado respecto de la base. | Confirmado |

---

## 5. Hallazgos reportados y REFUTADOS

| Reportado | Por qué es falso |
|---|---|
| "La aceptación de términos falla por falta de GRANT en `profiles`" (B1-H1) | `accepted_terms_at` y `accepted_terms_version` **sí** están concedidos por columna a `authenticated`; `has_table_privilege(...,'UPDATE')=false` solo indica ausencia de grant a nivel de tabla. |
| "Mass assignment de `is_sponsored`, `upvotes`, `moderation_status` en el INSERT de marketplace/grupos" (B2-H7) | El disparador `enforce_system_defaults_on_insert` fuerza esos campos a `false`/`0`/`NULL` en todo INSERT que no venga de `service_role`. |
| "Un autor puede cambiar `moderation_status` y autoaprobarse" (B3-H3, B2-H7) | `prevent_nonmoderator_restore` lanza `42501` ante cualquier cambio de `moderation_status` hecho por quien no sea staff, y `enforce_content_immutability_and_legal_hold` protege el resto de metadatos de moderación. |

---

## 6. Pendiente por decisión de alcance

Requieren cambios en la base o despliegues (no aplicados; instrucción de no modificar Supabase):

1. Vistas `safe_*`: cambiar el filtro a `moderation_status IN (0,1)` (o `IS DISTINCT FROM 2`) para alinear con RLS. Mientras tanto, el cliente ya no las usa en los feeds públicos.
2. Aplicar (corregidas) `auditoria-sql/04` y `05`, o retirar del producto las pantallas de reseñas de campus.
3. `sponsor_requests` sin políticas de lectura/gestión: la app puede crear solicitudes y nadie puede leerlas.
4. Desplegar el `moderation-worker` corregido (`supabase functions deploy moderation-worker`).
5. Definir un cron (`pg_cron + pg_net`) que invoque el worker; hoy la cola solo avanza si alguien llama al endpoint.
6. Montar `TotpSessionGuard` y, si el 2FA debe ser obligatorio, añadir `auth.jwt() ->> 'aal' = 'aal2'` en las políticas que se decidan.
7. Mover carné/nombre a `flutter_secure_storage`.
8. Consolidar migraciones para que `supabase db reset` reproduzca el entorno.

---

## 7. Estado de pruebas después de las correcciones

```
flutter analyze --no-pub   → No issues found!
flutter test  test/services → 66/66 OK
flutter test (suite completa) → 291 OK, 29 fallos
```

Los 29 fallos restantes son **preexistentes** en pruebas de widgets (`app_shell_test`, `discord_forum_test`, `forum_test`): se verificó que fallan igual en el árbol sin cambios (`git stash`). No están relacionados con la integración con Supabase.
