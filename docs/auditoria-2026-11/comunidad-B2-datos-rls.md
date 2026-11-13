# Auditoría Servicios de Datos vs. RLS/Grants — Comunidad_USAC

## Resumen
Se auditó la capa de acceso a datos de la aplicación Flutter (`comunidad_universitaria`) contrastando cada llamada `.from()`, `.rpc()`, `.insert()`, `.update()` y `.delete()` contra el catálogo y permisos reales de Supabase documentados en `EVIDENCIA-BD.md`.
Se identificaron 10 hallazgos críticos y altos: las vistas `safe_*` invierten la lógica de moderación mostrando solo contenido pendiente (0) y ocultando lo aprobado (1); tablas y funciones cartográficas inexistentes (`campus_reviews`, `campus_rating_aggregates`) rompen las reseñas del mapa; columnas inexistentes en `profiles` y `notification_preferences` inutilizan la creación de anuncios en el Marketplace y el guardado de preferencias; grants faltantes en `shares_count` y `profiles` bloquean actualizaciones; la política `WITH CHECK true` en `sponsor_requests` permite spam y suplantación sin rate-limit; y errores 42501/42703 son silenciados sistemáticamente con `catch (_) {}`.

---

## Hallazgos

### H-1: Vistas `safe_*` filtran contenido pendiente (`moderation_status = 0`) y ocultan todo el contenido aprobado
- Severidad: ALTA
- Tipo: LÓGICA
- Ubicación:
  - `lib/core/services/forum_service.dart:115, 158` (`safe_posts_feed`)
  - `lib/core/services/forum_service.dart:698` (`safe_comments`)
  - `lib/core/services/marketplace_service.dart:85, 219` (`safe_marketplace_items`)
  - `lib/core/services/groups_service.dart:81` (`safe_student_groups`)
  - `lib/core/services/profile_service.dart:93, 162, 189`
- Evidencia:
  - En `EVIDENCIA-BD.md` §5 (L761, L801, L835, L883):
    - `safe_posts_feed`: `WHERE ((deleted_at IS NULL) AND (moderation_status = 0) AND ((expires_at IS NULL) OR (expires_at > now())))`
    - `safe_comments`: `WHERE ((deleted_at IS NULL) AND (moderation_status = 0))`
    - `safe_marketplace_items`: `WHERE ((deleted_at IS NULL) AND ((moderation_status = 0) OR is_my_marketplace_item(id)) ...)`
    - `safe_student_groups`: `WHERE ((deleted_at IS NULL) AND ((moderation_status = 0) OR is_my_group(id)))`
  - En `EVIDENCIA-BD.md` §9 (L1075-1081): la semántica es `0 = pendiente` (forzado en INSERT), `1 = aprobado`, `2 = oculto`, `3 = error`. Las políticas RLS usan `moderation_status IS DISTINCT FROM 2`.
  - En `EVIDENCIA-BD.md` §7 (L1039-1041) y §8 (L1062, L1067): `select count(*) from posts` devuelve 8 filas aprobadas, mientras que `safe_posts_feed` devuelve **0 filas**.
- Impacto:
  - En `ForumScreen`, `MarketplaceScreen`, `GroupsScreen`, `PostDetailScreen` y `ProfileScreen`, en cuanto un elemento es revisado y aprobado (`moderation_status = 1`), desaparece inmediatamente del feed para todos los usuarios.
  - La aplicación muestra únicamente contenido no revisado (pendiente).
  - El fallback a las tablas base (`posts`, `comments`) implementado en `forum_service.dart:207, 748` nunca se dispara porque Supabase responde HTTP 200 con array vacío `[]` (no genera excepción PostgrestException 42501 ni 42P01). Los feeds quedan desiertos permanentemente.
- Corrección propuesta:
  - Modificar en la base de datos la definición de las vistas `safe_*` para que filtren por `moderation_status = 1 OR is_my_post(id)` (o `moderation_status IS DISTINCT FROM 2` para coincidir con la política RLS).

---

### H-2: Inoperabilidad del sistema de reseñas del mapa por tablas y funciones inexistentes en Supabase
- Severidad: ALTA
- Tipo: ESQUEMA
- Ubicación:
  - `lib/features/map/services/campus_community_supabase_service.dart:32, 54, 92`
  - `lib/features/map/services/supabase_campus_community_repository.dart:138, 141, 203`
  - `lib/features/map/screens/campus_map_screen.dart:135, 164`
- Evidencia:
  - `campus_community_supabase_service.dart:32`: `client.from('campus_rating_aggregates').select(...)`
  - `campus_community_supabase_service.dart:54`: `client.rpc('get_target_reviews_with_authors', ...)`
  - `campus_community_supabase_service.dart:92`: `client.from('campus_reviews').upsert(...)`
  - En `EVIDENCIA-BD.md` §1 (L7-54) y §4 (L631-714): los objetos `campus_reviews`, `campus_rating_aggregates` y la función `get_target_reviews_with_authors` **no existen** en el catálogo de Supabase.
- Impacto:
  - Al abrir los detalles de un edificio o POI en `CampusMapScreen`, `fetchTargetAggregate` falla con PostgrestException `42P01` (relation does not exist) y `loadTargetReviews` falla con `42883` (function does not exist).
  - Al emitir una reseña o calificación de sanitarios/instalaciones, `submitReview` falla con `42P01`.
  - Toda la funcionalidad comunitaria del mapa queda degradada a memoria local volátil; ninguna reseña estudiantil se sincroniza con otros estudiantes ni se persiste en la nube.
- Corrección propuesta:
  - Crear la migración SQL que defina `campus_reviews`, `campus_rating_aggregates` y la función RPC `get_target_reviews_with_authors` con RLS habilitada y grants para `anon` y `authenticated`.

---

### H-3: Bloqueo permanente de creación de anuncios en Marketplace por consulta a columna inexistente `profiles.seller_verification_status`
- Severidad: ALTA
- Tipo: ESQUEMA
- Ubicación:
  - `lib/core/services/marketplace_service.dart:248, 297`
  - `lib/features/marketplace/screens/marketplace_screen.dart`
- Evidencia:
  - `marketplace_service.dart:247-251`:
    ```dart
    final profile = await SupabaseService.client
        .from('profiles')
        .select('seller_verification_status')
        .eq('id', userId)
        .maybeSingle();
    return profile?['seller_verification_status'] == 'verified';
    ```
  - `marketplace_service.dart:297-302`:
    ```dart
    if (!await canCreateListing()) {
      throw StateError(
        'Publicar requiere que el equipo autorizado verifique tu identidad. '
        'La verificación institucional todavía no está disponible, así que tu anuncio no se guardó.',
      );
    }
    ```
  - En `EVIDENCIA-BD.md` §3 (L517-521): las columnas reales de `profiles` son `accepted_terms_at, accepted_terms_version, carne, carne_hash, carrera, created_at, cui, cui_hash, full_name, id, is_verified, reputation_score, updated_at, verified_at`. No existe `seller_verification_status`.
- Impacto:
  - La consulta a `profiles` falla con código PostgREST `42703` (column profiles.seller_verification_status does not exist).
  - El bloque `catch (e)` en L252 silencia el error y retorna `false`.
  - Como consecuencia, `canCreateListing()` siempre devuelve `false`, y `createListing()` arroja `StateError` para el 100% de los usuarios. Ningún estudiante puede crear publicaciones en el Marketplace.
- Corrección propuesta:
  - Modificar `canCreateListing()` para evaluar la columna real `is_verified == true`, o aplicar una migración que agregue formalmente la columna `seller_verification_status` a `profiles`.

---

### H-4: Error 42703 y fallo al guardar preferencias de notificación por mapeo de columna inexistente `notification_preferences.carreras`
- Severidad: MEDIA
- Tipo: ESQUEMA
- Ubicación:
  - `lib/core/services/notification_service.dart:115, 132`
  - `lib/core/models/notification_item.dart:149`
- Evidencia:
  - `notification_item.dart:149`: `NotificationPreferences.toMap()` incluye `'carreras': carreras`.
  - `notification_service.dart:132`: `await SupabaseService.client.from('notification_preferences').upsert(prefs.toMap());`.
  - En `EVIDENCIA-BD.md` §3 (L472-477): la tabla `notification_preferences` solo tiene las columnas `comment_enabled, created_at, like_enabled, new_post_enabled, reply_enabled, updated_at, user_id`.
  - Las suscripciones por carrera se gestionan en una tabla relacional independiente: `notification_preference_carreras` (`carrera_id, created_at, user_id`, §1 L23 y §3 L466-471).
- Impacto:
  - Toda llamada a `savePreferences()` falla con error PostgREST `42703` (`column "carreras" of relation "notification_preferences" does not exist`).
  - El error es atrapado en L134 retornando `false`. Los usuarios no pueden actualizar sus preferencias de notificación de forma persistente.
  - `getPreferences()` en L115 falla al intentar insertar las preferencias por defecto y retorna valores en memoria no sincronizados.
- Corrección propuesta:
  - Separar en `NotificationService` la actualización de booleanos en `notification_preferences` de la inserción/eliminación de carreras en `notification_preference_carreras`.

---

### H-5: Error 42501 al consultar la vista `whatsapp_groups` por falta de grant SELECT sobre `student_groups.user_id`
- Severidad: MEDIA
- Tipo: GRANTS
- Ubicación:
  - `lib/core/services/moderation_service.dart:111`
  - Vista `whatsapp_groups` en `EVIDENCIA-BD.md` §5 L995-1018
- Evidencia:
  - Definición de la vista: `SELECT id, title, carrera, curso, section, link, description, user_id, author_alias, ... FROM student_groups;`.
  - En `EVIDENCIA-BD.md` §3 L581-583: `student_groups` no otorga privilegio `SELECT` sobre `user_id` ni a `anon` ni a `authenticated`.
  - En `EVIDENCIA-BD.md` §7 L1046 y §8 L1069:
    - `anon → select count(*) from whatsapp_groups` → `ERR 42501 permission denied for table student_groups`.
    - `GET /rest/v1/whatsapp_groups` con anon key devuelve HTTP 401/403 con error 42501.
- Impacto:
  - La vista `whatsapp_groups` no puede ser leída por ningún cliente estándar.
  - En `ModerationService`, si un moderador ejecuta acciones pasando la tabla `'whatsapp_groups'` (mencionada explícitamente en el comentario de L111), la operación fallará con 42501.
- Corrección propuesta:
  - Recrear la vista `whatsapp_groups` eliminando la proyección de `student_groups.user_id`, o utilizar `safe_student_groups` como fuente de datos autorizada.

---

### H-6: Fallo en incremento de contadores de compartidos (`shares_count`) por falta de GRANT UPDATE y violación de RLS
- Severidad: MEDIA
- Tipo: GRANTS
- Ubicación:
  - `lib/core/services/share_count_service.dart:66-73`
- Evidencia:
  - `share_count_service.dart:66-70`:
    ```dart
    await SupabaseService.client
        .from(table)
        .update({'shares_count': nextCount})
        .eq('id', id);
    ```
  - En `EVIDENCIA-BD.md` §3 L516: el rol `authenticated` tiene UPDATE en `posts` únicamente sobre: `author_alias, carrera, category, content, deleted_at, expires_at, gif_url, image_url, is_legal_hold, is_pinned, moderated_at, moderated_by, moderation_confidence, moderation_label, moderation_reason, moderation_status, quoted_post_id, title`. **No incluye `shares_count`**.
  - En `EVIDENCIA-BD.md` §3 L449: `marketplace_items` tampoco incluye `shares_count` para UPDATE.
  - En `EVIDENCIA-BD.md` §2 L285: la política RLS de `posts` para UPDATE exige `auth.uid() = user_id OR is_pemtree_moderator(auth.uid())`. Un usuario que comparte el post de otro no es el autor.
- Impacto:
  - La actualización falla con PostgrestException 42501.
  - El bloque `catch (_) {}` en L71 silencia el error. El contador se incrementa solo en el almacenamiento local (`SharedPreferences`) del usuario que compartió, pero nunca se actualiza en la base de datos de Supabase para el resto de la comunidad.
- Corrección propuesta:
  - Crear una función RPC `SECURITY DEFINER` (ej. `increment_share_count(p_table text, p_id uuid)`) con rate-limiting en PostgreSQL para actualizar el contador sin requerir permisos de UPDATE directo sobre la fila ajena.

---

### H-7: Mass Assignment y escalada de privilegios publicitarios en INSERT de `marketplace_items` y `student_groups`
- Severidad: ALTA
- Tipo: RLS
- Ubicación:
  - `lib/core/services/marketplace_service.dart:332, 349-352`
  - `lib/core/services/groups_service.dart:294, 304-307`
- Evidencia:
  - `marketplace_service.dart:305-339` envía `upvotes: 1`, `reported_count: 0`, `is_sponsored: false`, `sponsor_badge_text: null`, `moderation_status: 0`.
  - En `EVIDENCIA-BD.md` §3 L447: `authenticated` tiene **GRANT INSERT** concedido sobre `is_sponsored, sponsor_badge_text, upvotes, reported_count, shares_count, moderation_status`.
  - En `EVIDENCIA-BD.md` §2 L130-134: la política RLS `Authenticated users can insert own marketplace items` únicamente comprueba `WITH CHECK ((auth.uid() IS NOT NULL) AND (auth.uid() = user_id))`.
  - En `EVIDENCIA-BD.md` §2 L357-361: la política de `student_groups` comprueba únicamente `auth.uid() = user_id`.
- Impacto:
  - Un usuario autenticado que invoque la API REST directamente puede enviar `'is_sponsored': true`, `'sponsor_badge_text': 'Verificado'`, `'upvotes': 999999` y `'moderation_status': 1`.
  - La RLS no valida el valor de estas columnas y los grants de columna permiten su inserción directa, permitiendo forjar anuncios patrocinados y alterar la clasificación sin control ni pago administrativo.
- Corrección propuesta:
  - Modificar las políticas RLS `WITH CHECK` para restringir valores fijos:
    `WITH CHECK (auth.uid() = user_id AND (is_sponsored IS NOT TRUE) AND (sponsor_badge_text IS NULL) AND (upvotes <= 1) AND (moderation_status = 0))`.
  - Alternativamente, revocar el GRANT INSERT a `authenticated` sobre columnas administrativas y de contadores.

---

### H-8: Vulnerabilidad de spam y suplantación de identidad en `sponsor_requests` por política RLS permisiva `WITH CHECK (true)`
- Severidad: ALTA
- Tipo: RLS
- Ubicación:
  - `lib/core/services/marketplace_service.dart:481-490`
  - `lib/features/marketplace/widgets/sponsor_request_dialog.dart:65-75, 185-210`
- Evidencia:
  - En `EVIDENCIA-BD.md` §2 L335-339:
    ```
    ### `sponsor_requests` — Anyone can insert sponsor requests
    - Roles: {anon, authenticated}
    - Permiso: INSERT
    - WITH CHECK: true
    ```
  - En `EVIDENCIA-BD.md` §7 L1047 y L1053:
    - `anon → INSERT INTO sponsor_requests(...)` → ÉXITO (sin captcha ni rate-limit).
    - `authenticated → INSERT INTO sponsor_requests(user_id=<otro uuid>)` → permitido; solo valida la foreign key a `auth.users`, pero RLS no comprueba que `auth.uid() = user_id`.
  - `sponsor_request_dialog.dart` solo tiene validaciones visuales en cliente (campos no vacíos, teléfono 8 dígitos); no valida formato de correo ni autenticación.
- Impacto:
  - Actores maliciosos pueden spamear masivamente la tabla `sponsor_requests` usando la anon key pública hasta agotar la base de datos (DoS).
  - Permite suplantar a cualquier estudiante adjuntando su `user_id` en solicitudes fraudulentas.
- Corrección propuesta:
  - Cambiar la política RLS a:
    `WITH CHECK ((user_id IS NULL AND auth.uid() IS NULL) OR (auth.uid() = user_id))`.
  - Implementar rate-limiting o captchas (Turnstile) antes de autorizar inserciones anónimas.

---

### H-9: Errores de Supabase silenciados sistemáticamente que enmascaran fallos de esquema y permisos como "listas vacías"
- Severidad: MEDIA
- Tipo: LÓGICA
- Ubicación:
  - `lib/core/services/profile_service.dart:173, 200`
  - `lib/core/services/notification_service.dart:27, 47, 117, 134`
  - `lib/core/services/marketplace_service.dart:232, 252, 492`
  - `lib/core/services/share_count_service.dart:71`
  - `lib/features/map/services/campus_community_supabase_service.dart:38, 63, 131`
- Evidencia:
  - Patrón generalizado de captura indiscriminada:
    ```dart
    try {
      final res = await client.from('...').select(...);
      return res;
    } catch (e) {
      debugPrint('...');
      return []; // o return false / null
    }
    ```
  - En `campus_community_supabase_service.dart:131`, `client.from('profiles').select('alias')` falla con error 42703 (columna `alias` inexistente en `profiles`), pero se silencia con `catch (_) {}`.
  - En `profile_service.dart:173, 200`, si la consulta falla con 42501 (permiso denegado), devuelve lista vacía `[]`.
- Impacto:
  - Errores críticos de esquema (42703), de tabla inexistente (42P01) o de permisos (42501) no alertan al usuario ni a sistemas de monitoreo, aparentando que "no hay datos disponibles" cuando en realidad la consulta fue rechazada por la base de datos.
- Corrección propuesta:
  - Manejar específicamente `PostgrestException`; re-lanzar o mostrar alertas de error de conexión/permisos al usuario en lugar de retornar arrays vacíos que ocultan el fallo.

---

### H-10: Inconsistencia entre modelo de datos local y base de datos en `profiles.cui` y `profiles.carne`
- Severidad: MEDIA
- Tipo: PRIVACIDAD
- Ubicación:
  - `lib/core/models/user_profile.dart:15, 34, 95`
  - `lib/core/services/profile_service.dart:72`
- Evidencia:
  - En `EVIDENCIA-BD.md` §3 L518, L520: las columnas `cui` y `carne` figuran en `profiles`.
  - Sin embargo, en la migración `20261110000000_unified_core_and_legal_hardening.sql:92, 97`, el trigger `handle_profile_sensitive_data()` ejecuta:
    `NEW.cui_hash := encode(extensions.hmac(btrim(NEW.cui), ...), 'hex'); NEW.cui := NULL;`
    `NEW.carne_hash := encode(extensions.hmac(btrim(NEW.carne), ...), 'hex'); NEW.carne := NULL;`
    Acompañado del constraint `CHECK (cui IS NULL AND carne IS NULL)`.
  - `user_profile.dart` define `carne` como campo en texto plano y `profile_service.dart:72` solo puede consultar `cui_hash` y `carne_hash`.
  - En `EVIDENCIA-BD.md` §7 L1049: `authenticated → has_table_privilege(profiles,'UPDATE')` es `false`, estando restringido el UPDATE a nivel de columna exclusivamente a `accepted_terms_at, accepted_terms_version, carrera, full_name` (§3 L521).
- Impacto:
  - Cualquier valor de `cui` o `carne` enviado por la aplicación es destruido y fijado en `NULL` por el trigger del servidor.
  - La interfaz de perfil no puede recuperar el carné del usuario desde Supabase, dependiendo únicamente de la caché local `LocalStorageService`.
  - La falta de privilegio UPDATE a nivel de tabla puede provocar fallos al invocar `acceptTerms()` según el driver o versión de PostgREST.
- Corrección propuesta:
  - Reflejar en la arquitectura de la app que `cui` y `carne` son estrictamente confidenciales y que solo se preservan sus hashes HMAC en Supabase; validar que las mutaciones sobre `profiles` se limiten estrictamente a las cuatro columnas autorizadas.

---

## No verificado
- Se desconoce si existen Edge Functions o cron jobs externos que ejecuten periódicamente `purge_expired_soft_deletes()` o `recalcular_contadores()` fuera del entorno de pruebas directas.
- No se verificó el comportamiento exacto de los WebSockets de Supabase Realtime bajo canales privados con RLS en `campus_community_supabase_service.dart:178` debido a que el servidor de desarrollo local no mantiene una conexión activa a WebSockets de producción en este entorno.
