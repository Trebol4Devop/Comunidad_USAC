# Informe de Auditoría de Seguridad, Privacidad y Cumplimiento Legal (Red Team)

**Fecha de emisión:** 10 de noviembre de 2026  
**Auditor:** Agente 4 — Auditor de Seguridad, Privacidad y Cumplimiento Legal (Red Team)  
**Repositorio:** `/home/carlos/Escritorio/Comunidad_USAC`  
**Rama:** `feature/legal-hardening-audit`  
**Alcance evaluado:** Trabajo de Agente 1 (Esquema PostgreSQL, RLS y Migraciones), Agente 2 (Worker de Moderación Deno y Heurísticas) y Agente 3 (Frontend Flutter `comunidad_universitaria`).  
**Estado:** **RECHAZADO — DEVOLVER A AGENTE 1 Y AGENTE 3**

---

## 1. Resumen Ejecutivo y Alcance

La presente auditoría de Red Team evalúa las medidas de endurecimiento técnico y legal implementadas en la plataforma universitaria PEMTREE / Comunidad USAC, en cumplimiento de los estándares de anonimato, preservación de evidencia (90 días), puerto seguro de intermediarios (Art. 3) y tipificación de delitos informáticos (Art. 12, 13, 14, 16, 20 y 21).

### Balance General
- **Avances sobresalientes:**
  - El mecanismo de cálculo de `author_hash` por hilo mediante HMAC-SHA256 con sal secreta interna y ligadura estricta al `post_id` funciona correctamente en la inserción: el OP conserva su hash idéntico en comentarios del mismo hilo, usuarios distintos tienen hashes distintos, y el mismo usuario tiene hashes diferentes en distintos posts.
  - La neutralización de datos sensibles (`cui` y `carne`) en `public.profiles` es total: el trigger `handle_profile_sensitive_data` convierte los valores a hashes HMAC-SHA256 de 64 caracteres hex y fuerza las columnas a `NULL`, respaldado por el constraint ineludible `CHECK (cui IS NULL AND carne IS NULL)`.
  - La auto-cuarentena de 3 reportes comunitarios de riesgo (`COMMUNITY_AUTO_QUARANTINE`) actúa inmediatamente fijando `moderation_status = 1`, `is_legal_hold = true`, encolando un trabajo con prioridad 10 y asentando la auditoría con `is_automated = true`.
  - Las funciones de auto-limpieza (`purge_expired_soft_deletes()`) y el trigger sobre `auth.users` (`protect_authorship_on_user_delete()`) preservan adecuadamente la evidencia de cuentas y contenidos bajo retención legal, evitando la destrucción de pruebas de cara a investigaciones judiciales.
  - El motor de moderación en Edge Function (`moderation-worker`) compila limpiamente bajo Deno, opera en dos capas, aplica umbrales precisos (0.50 / 0.80), preserva el contenido sin modificarlo y asegura su endpoint con fallo cerrado (`fail-closed`).

- **Vulnerabilidades Críticas Encontradas (Bloqueantes de Producción):**
  1. **Destrucción masiva de tablas por permiso `TRUNCATE` activo:** El privilegio `TRUNCATE` fue revocado únicamente en 4 tablas, quedando activo para el rol `authenticated` en tablas críticas del sistema (`moderation_audit_log`, `user_roles`, `profiles`, `seccion_reviews`, `moderation_jobs`, `alias_nouns`, etc.). Dado que `TRUNCATE` no respeta Row-Level Security (RLS) en PostgreSQL, cualquier usuario registrado puede vaciar la bitácora legal, eliminar administradores o resetear perfiles.
  2. **Suplantación de identidad (Spoofing de OP) y manipulación de métricas en UPDATE:** Las columnas del sistema (`is_op`, `author_hash`, `user_id`, `created_at`, `likes`, `hot_score`, `comments_count`) tienen permiso de `UPDATE` concedido a `authenticated`, y el trigger de inmutabilidad no las protege cuando quien edita es el autor del registro. Un usuario comentarista puede editar su comentario y fijar `is_op = true` y el hash del OP para suplantarlo, o un creador de post puede forjar su `hot_score` a 999,999 o reasignar el `user_id` a otra cuenta.
  3. **Fuga de privacidad de `user_id` en Grupos Estudiantiles y Marketplace:** A diferencia del foro y las reseñas de secciones, las tablas `student_groups` y `marketplace_items` otorgan permiso `SELECT (user_id)` al rol público y anónimo. El frontend ejecuta `.select('*')` en ambos servicios y los modelos parsean el `user_id`, permitiendo a scrapers o actores maliciosos correlacionar actividades y desanonimizar usuarios que compartan su WhatsApp o redes sociales.

---

## 2. Metodología y Comandos Ejecutados

La auditoría se realizó mediante pruebas dinámicas adversariales contra la base de datos local y análisis estático del código fuente de TypeScript y Dart.

### Resumen de Pruebas de Línea de Comandos

| Comando | Resultado | Diagnóstico |
| :--- | :---: | :--- |
| `supabase db reset` | **OK (Exit 0)** | Migraciones aplicadas en orden (`20261110000000`, `20261110000100`, `20261110000200`) y seed completado. |
| `deno check supabase/functions/moderation-worker/index.ts` | **OK (Exit 0)** | Validación de tipos y dependencias de la Edge Function superada sin advertencias. |
| `supabase test db` | **FAIL (Exit 1)** | **Deuda de pruebas**: 9 archivos legacy fallan porque insertaban aliases prohibidos (`'Visitante'`, `'Alias A'`) o ejecutaban `DELETE` físico revocado. |
| `cd comunidad_universitaria && flutter analyze` | **WARN (Exit 1)** | 1 advertencia de variable local `appBar` no utilizada (`profile_screen.dart:330`) y 1 info de estilo (`popular_servers_sidebar.dart:124`). |
| `cd comunidad_universitaria && flutter test` | **FAIL (Exit 1)** | 289 pruebas pasadas, 6 fallos atribuibles a **deuda de pruebas** (adaptación a vistas seguras, soft-delete y mock keys). |

---

## 3. Hallazgos de Seguridad, Privacidad y Cumplimiento

### [BLOQUEANTE - CRÍTICO]

#### HALLAZGO B-01: Privilegio `TRUNCATE` concedido a `authenticated` permite el borrado catastrófico de bitácoras de auditoría, roles y perfiles
- **Ubicación:**
  - [`supabase/migrations/20261001000000_adopt_remote_schema.sql`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261001000000_adopt_remote_schema.sql#L4931)
  - [`supabase/migrations/20261110000000_unified_core_and_legal_hardening.sql#L1308-L1312`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261110000000_unified_core_and_legal_hardening.sql#L1308-L1312)
- **Descripción del Riesgo:**  
  En PostgreSQL, la instrucción `TRUNCATE` **no está sujeta a políticas de Row-Level Security (RLS)**. En la migración inicial de adopción remota, se concedió `GRANT ALL` (incluyendo `TRUNCATE`, `TRIGGER`, `REFERENCES`) al rol `authenticated`.  
  La migración de hardening `20261110000000` ejecutó `REVOKE TRUNCATE` únicamente sobre `posts`, `comments`, `student_groups` y `marketplace_items`. Como resultado, cualquier atacante registrado con una cuenta legítima de estudiante puede conectarse y ejecutar `TRUNCATE` sobre tablas estructurales y de auditoría:
  - Destruir la bitácora legal `public.moderation_audit_log` (Art. 20/21).
  - Destruir la tabla `public.user_roles`, revocando de inmediato los permisos a todos los administradores y moderadores.
  - Destruir `public.profiles CASCADE`, borrando la base de datos de usuarios.
  - Destruir `public.seccion_reviews CASCADE`, borrando todas las reseñas y sus upvotes.
  - Destruir `public.alias_nouns` y `public.alias_adjectives`, rompiendo permanentemente la validación del Art. 12.
- **Evidencia Adversarial (PoC Ejecutada):**
  ```sql
  BEGIN;
  -- Simular sesión de usuario común autenticado
  SELECT tests.authenticate_as('11111111-1111-1111-1111-111111111111');
  
  -- Intento de sabotaje y destrucción de evidencia:
  TRUNCATE TABLE public.moderation_audit_log CASCADE;
  TRUNCATE TABLE public.user_roles CASCADE;
  TRUNCATE TABLE public.profiles CASCADE;
  TRUNCATE TABLE public.seccion_reviews CASCADE;
  
  -- Resultado: Comandos ejecutados con éxito (TRUNCATE TABLE), vaciando todas las tablas.
  ROLLBACK;
  ```
- **Corrección Obligatoria (Agente 1):**  
  Crear una nueva migración que revoque de forma absoluta `TRUNCATE`, `REFERENCES` y `TRIGGER` de todas las tablas públicas a `anon` y `authenticated`:
  ```sql
  REVOKE TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
  
  -- Asegurar de forma explícita las tablas del núcleo:
  REVOKE TRUNCATE, REFERENCES, TRIGGER ON TABLE 
      public.profiles,
      public.user_roles,
      public.moderation_jobs,
      public.moderation_audit_log,
      public.entity_reports,
      public.seccion_reviews,
      public.seccion_review_upvotes,
      public.post_polls,
      public.post_poll_options,
      public.post_poll_votes,
      public.post_likes,
      public.post_bookmarks,
      public.marketplace_upvotes,
      public.student_group_upvotes,
      public.alias_nouns,
      public.alias_adjectives,
      public.carreras,
      public.facultades,
      public.categorias_foro,
      public.categorias_marketplace
  FROM anon, authenticated;
  ```

---

#### HALLAZGO B-02: Suplantación de OP (Spoofing) y manipulación de contadores y hot score mediante `UPDATE`
- **Ubicación:**
  - [`supabase/migrations/20261110000000_unified_core_and_legal_hardening.sql#L452-L595`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261110000000_unified_core_and_legal_hardening.sql#L452-L595)
  - [`supabase/migrations/20261110000000_unified_core_and_legal_hardening.sql#L1271-L1300`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261110000000_unified_core_and_legal_hardening.sql#L1271-L1300)
- **Descripción del Riesgo:**  
  1. El trigger `handle_comment_author_hash` sólo está registrado `BEFORE INSERT`. No se ejecuta en `BEFORE UPDATE`.
  2. En `enforce_content_immutability_and_legal_hold`, cuando quien realiza la actualización es el autor del comentario (`v_is_author = true`), la función sólo valida cambios en `content`, `gif_url` o `parent_id` (para aplicar restricciones de retención legal).
  3. No existe ninguna cláusula que impida al autor modificar `is_op`, `author_hash`, `user_id`, `post_id`, `created_at` o `likes_count`.
  4. Del mismo modo, en `posts`, el autor tiene permiso de `UPDATE` sobre `author_hash`, `user_id`, `created_at`, `likes`, `reposts_count`, `comments_count` y `hot_score`.
  5. **Impacto Crítico:** Un usuario común puede comentar en un hilo ajeno, ejecutar un `UPDATE` en su propio comentario fijando `is_op = true` y copiando el `author_hash` del creador del post. En la vista `safe_comments`, dicho comentario se mostrará como si fuera del autor legítimo de la publicación, violando flagrantemente la integridad de la atribución y permitiendo ataques de ingeniería social y suplantación institucional. Además, un usuario puede inflar artificialmente su `hot_score` a 999,999 para posicionar permanentemente su contenido en la cima del feed.
- **Evidencia Adversarial (PoC Ejecutada):**
  ```sql
  BEGIN;
  -- 1. Usuario A crea publicación legítima
  SELECT tests.authenticate_as('11111111-1111-1111-1111-111111111111');
  INSERT INTO public.posts (id, user_id, title, content, category, carrera, author_alias)
  VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0001', '11111111-1111-1111-1111-111111111111', 'Post Original', 'Contenido Original', 'general', 'sistemas', 'Compilador Desvelado');
  -- Obtiene hash del OP: 'e6adf2b8'

  -- 2. Usuario B (atacante) comenta en el post
  SELECT tests.authenticate_as('22222222-2222-2222-2222-222222222222');
  INSERT INTO public.comments (id, post_id, user_id, content, author_alias)
  VALUES ('cccccccc-cccc-cccc-cccc-cccccccc0002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0001', '22222222-2222-2222-2222-222222222222', 'Comentario Atacante', 'Depurador Nocturno');

  -- 3. Atacante suplanta la identidad del OP en el hilo mediante UPDATE:
  UPDATE public.comments 
  SET is_op = true, author_hash = 'e6adf2b8' 
  WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccc0002';

  -- 4. Verificación en la vista pública:
  SELECT id, author_hash, is_op FROM public.safe_comments WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccc0002';
  -- Resultado: author_hash = 'e6adf2b8', is_op = true (SUPLANTACIÓN EXITOSA).
  ROLLBACK;
  ```
- **Corrección Obligatoria (Agente 1):**  
  1. Revocar permisos de `UPDATE` sobre columnas generadas por el sistema:
  ```sql
  REVOKE UPDATE (
      id, user_id, author_hash, created_at, likes, 
      reposts_count, comments_count, hot_score
  ) ON public.posts FROM authenticated;

  REVOKE UPDATE (
      id, post_id, user_id, author_hash, is_op, 
      created_at, likes_count
  ) ON public.comments FROM authenticated;

  REVOKE UPDATE (
      id, user_id, upvotes, reported_count, created_at
  ) ON public.student_groups, public.marketplace_items FROM authenticated;
  ```
  2. Endurecer el trigger `enforce_content_immutability_and_legal_hold` para abortar cualquier transacción que intente modificar campos de identidad o contadores denormalizados fuera de triggers de sistema:
  ```sql
  -- Agregar al inicio de enforce_content_immutability_and_legal_hold():
  IF (NEW.id IS DISTINCT FROM OLD.id)
     OR (NEW.user_id IS DISTINCT FROM OLD.user_id)
     OR (NEW.created_at IS DISTINCT FROM OLD.created_at)
     OR (TG_TABLE_NAME = 'posts' AND (
         NEW.author_hash IS DISTINCT FROM OLD.author_hash
         OR (pg_trigger_depth() <= 1 AND (
             NEW.likes IS DISTINCT FROM OLD.likes
             OR NEW.reposts_count IS DISTINCT FROM OLD.reposts_count
             OR NEW.comments_count IS DISTINCT FROM OLD.comments_count
             OR NEW.hot_score IS DISTINCT FROM OLD.hot_score
         ))
     ))
     OR (TG_TABLE_NAME = 'comments' AND (
         NEW.post_id IS DISTINCT FROM OLD.post_id
         OR NEW.author_hash IS DISTINCT FROM OLD.author_hash
         OR NEW.is_op IS DISTINCT FROM OLD.is_op
         OR (pg_trigger_depth() <= 1 AND NEW.likes_count IS DISTINCT FROM OLD.likes_count)
     ))
     OR (TG_TABLE_NAME IN ('student_groups', 'marketplace_items') AND (
         pg_trigger_depth() <= 1 AND (
             NEW.upvotes IS DISTINCT FROM OLD.upvotes
             OR NEW.reported_count IS DISTINCT FROM OLD.reported_count
         )
     )) THEN
      RAISE EXCEPTION 'Modificación no permitida en campos del sistema o métricas (Art. 3 / Art. 13)'
          USING ERRCODE = '42501';
  END IF;
  ```

---

#### HALLAZGO B-03: Fuga de privacidad horizontal de `user_id` en Grupos Estudiantiles y Marketplace
- **Ubicación:**
  - [`comunidad_universitaria/lib/core/services/groups_service.dart#L53`](file:///home/carlos/Escritorio/Comunidad_USAC/comunidad_universitaria/lib/core/services/groups_service.dart#L53)
  - [`comunidad_universitaria/lib/core/services/marketplace_service.dart#L79`](file:///home/carlos/Escritorio/Comunidad_USAC/comunidad_universitaria/lib/core/services/marketplace_service.dart#L79)
  - [`comunidad_universitaria/lib/core/models/whatsapp_group.dart#L137`](file:///home/carlos/Escritorio/Comunidad_USAC/comunidad_universitaria/lib/core/models/whatsapp_group.dart#L137)
  - [`comunidad_universitaria/lib/core/models/marketplace_item.dart#L271`](file:///home/carlos/Escritorio/Comunidad_USAC/comunidad_universitaria/lib/core/models/marketplace_item.dart#L271)
  - [`supabase/migrations/20261001000000_adopt_remote_schema.sql`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261001000000_adopt_remote_schema.sql)
- **Descripción del Riesgo:**  
  Mientras que para el foro y las reseñas se implementaron vistas de seguridad (`safe_posts_feed`, `safe_comments`, `safe_seccion_reviews`) y se revocó el privilegio `SELECT (user_id)`, en `student_groups` y `marketplace_items`:
  1. `anon` y `authenticated` tienen concedido `SELECT` a nivel de columna sobre `user_id`.
  2. Los servicios del cliente Flutter (`groups_service.dart` y `marketplace_service.dart`) realizan consultas directas con `.select('*')`.
  3. Los modelos correspondientes deserializan `user_id: map['user_id']?.toString()`.
  4. **Impacto de Privacidad:** Un usuario que publique una venta en el marketplace e incluya su número telefónico de WhatsApp personal expone su UUID persistente (`auth.users.id`). Un observador externo puede recolectar estos identificadores y correlacionar todas las ventas, grupos creados y actividad histórica del estudiante en la plataforma.
- **Evidencia Adversarial (PoC Ejecutada):**
  ```sql
  SET ROLE anon;
  -- Consulta anónima pública sin autenticación:
  SELECT user_id, title, contact_whatsapp FROM public.marketplace_items LIMIT 1;
  SELECT user_id, title, link FROM public.student_groups LIMIT 1;
  -- Resultado: Ejecución exitosa con código 0; el UUID del autor se entrega en claro.
  ```
- **Corrección Obligatoria (Agentes 1 y 3):**  
  1. En Base de Datos (Agente 1): Crear las vistas seguras `safe_student_groups` y `safe_marketplace_items` (con `security_invoker = true`), excluyendo la columna `user_id`, y revocar `SELECT (user_id)` en ambas tablas base para `anon` y `authenticated`.
  2. En Flutter (Agente 3): Actualizar `groups_service.dart` y `marketplace_service.dart` para consumir las nuevas vistas o explicitar columnas seguras sin `user_id`, y neutralizar la lectura en `whatsapp_group.dart` y `marketplace_item.dart` (estableciendo `userId: null` en lecturas públicas).

---

### [ADVERTENCIAS]

1. **Inconsistencia de retención en `seccion_reviews`:**  
   - [`comunidad_universitaria/lib/core/services/reviews_service.dart#L133-L136`](file:///home/carlos/Escritorio/Comunidad_USAC/comunidad_universitaria/lib/core/services/reviews_service.dart#L133-L136) documenta que el borrado físico está prohibido por retención de auditoría. Sin embargo, en la base de datos la política `El autor o admin pueden borrar la reseña de sección` permite al autor ejecutar `DELETE` físico (`DELETE 1`), destruyendo el registro de inmediato. Se recomienda migrar `seccion_reviews` a soft delete (`deleted_at`, `is_legal_hold`) o alinear la documentación.
2. **Posibilidad de soft delete en contenido bajo Legal Hold:**  
   - En `enforce_content_immutability_and_legal_hold`, la condición `v_content_changed` no incluye `deleted_at`. Aunque la evidencia física no se destruye (dado que `purge_expired_soft_deletes()` preserva las filas con `is_legal_hold = true` y `auth.users` bloquea el borrado de la cuenta), un autor bajo investigación podría ocultar su contenido del feed público vía PostgREST antes de la resolución del moderador. Se sugiere añadir `OR (OLD.is_legal_hold = true AND NEW.deleted_at IS DISTINCT FROM OLD.deleted_at)` para inmutabilidad completa del estado de borrado.
3. **Advertencia de compilación en Flutter:**  
   - [`comunidad_universitaria/lib/features/profile/screens/profile_screen.dart#L330`](file:///home/carlos/Escritorio/Comunidad_USAC/comunidad_universitaria/lib/features/profile/screens/profile_screen.dart#L330) define una variable local `final appBar = AppBar(title: const Text('Editar perfil'));` que no es utilizada, provocando una advertencia en `flutter analyze`. Se debe eliminar dicha línea.

---

### [DEUDA DE PRUEBAS] (Legacy Test Debt a Corregir en QA)

Los siguientes fallos en suites de pruebas corresponden a **comportamientos obsoletos de pruebas previas** que no se adaptaron a los nuevos requerimientos de seguridad:

1. **Pruebas de Base de Datos (`supabase/tests/*.sql`):**
   - `anonymous_read_only_test.sql`, `authenticated_writes_without_otp_test.sql`, `comments_rls_test.sql`, `constraints_catalog_test.sql`, `counters_triggers_test.sql`, `groups_marketplace_rls_test.sql`, `posts_rls_test.sql`, `rpc_moderation_test.sql`, `views_public_test.sql`.
   - **Motivo del fallo:** Las pruebas legacy insertan valores fijos como `'Visitante'`, `'Usuario de prueba'`, `'Alias A'`, `'Vendedor Pirata'`. El nuevo trigger `check_author_alias_validity()` (Art. 12) rechaza con razón cualquier alias que no pertenezca al catálogo curado (`alias_nouns` + `alias_adjectives`).
   - **Motivo adicional:** `authenticated_writes_without_otp_test.sql` ejecuta `DELETE FROM public.posts`, lo cual es rechazado con error `42501 (permission denied)` debido a la revocación legítima de borrado físico del Art. 20/21.
   - **Acción:** Actualizar los tests en QA para insertar `'Compilador Desvelado'` o `'Estudiante Anónimo'` y validar soft-delete mediante `UPDATE ... SET deleted_at = now()`.

2. **Pruebas Unitarias de Flutter (`comunidad_universitaria/test/`):**
   - `test/services/profile_service_test.dart`:
     - Las pruebas `deletePost`, `deleteGroup`, `deleteMarketplaceItem` configuran el mock con `fakeServer.onDelete(...)`, pero el servicio ahora ejecuta un `PATCH` con `deleted_at`.
     - La prueba `fetchUserPosts` intercepta `/rest/v1/v_public_posts`, pero el servicio ahora consume `/rest/v1/safe_posts_feed`.
   - `test/cache_service_test.dart`:
     - La prueba calcula manualmente la clave de caché sin incluir el nuevo campo requerido `'feedMode': 'hot'`.
   - `test/widgets/profile_screen_test.dart`:
     - La prueba busca el texto `'Editar perfil'` y el widget `BackButton`, pero el encabezado fue renombrado a `'Preferencias de Usuario'` y usa un `IconButton` con icono de flecha.

---

## 4. Tabla de Cumplimiento por Artículo Legal

| Marco Normativo | Control Requerido | Estado | Detalle y Hallazgos |
| :--- | :--- | :---: | :--- |
| **Art. 3** | Inmutabilidad de contenido de terceros y puerto seguro | **NO CONFORME** | Moderadores no pueden alterar contenido ajeno, pero **comentaristas pueden editar su registro para fijar `is_op = true` y falsificar el `author_hash`** (Hallazgo B-02). |
| **Art. 12** | Anonimato obligatorio y catálogo curado de seudónimos | **PARCIAL** | Catálogo curado (`alias_nouns` + `alias_adjectives`) y rechazo de nombres y carnés 100% verificado. Sin embargo, **el atacante puede alterar `author_hash` vía UPDATE** (Hallazgo B-02). |
| **Art. 13 / 16** | Protección contra ciberdelitos y sabotaje de sistemas | **NO CONFORME** | Motor de moderación Capa 1 y Capa 2 detecta credenciales y herramientas de hacking. Sin embargo, **`authenticated` puede ejecutar `TRUNCATE` en `moderation_audit_log` y `user_roles`** (Hallazgo B-01). |
| **Art. 14** | Moderación comunitaria y cuarentena por reportes | **CUMPLIDO** | Al alcanzar 3 reportes de riesgo únicos, se asigna `moderation_status = 1`, `is_legal_hold = true`, job de prioridad 10 y auditoría automatizada. Verificado con PoC. |
| **Art. 20 / 21** | Retención de evidencia por 90 días y trazabilidad | **NO CONFORME** | `purge_expired_soft_deletes()` y bloqueo de borrado de usuario en `auth.users` funcionan correctamente. Sin embargo, **la bitácora de auditoría legal puede ser destruida con `TRUNCATE`** (Hallazgo B-01). |
| **Privacidad Horizontal** | Blindaje contra correlación de `user_id` | **NO CONFORME** | Blindado con éxito en `posts`, `comments` y `seccion_reviews`. **Vulnerable en `student_groups` y `marketplace_items`** donde `user_id` sigue expuesto a consultas públicas (Hallazgo B-03). |

---

## 5. Veredicto Final

# **RECHAZADO — DEVOLVER A AGENTE 1 (DB) Y AGENTE 3 (FLUTTER)**

### Justificación:
Aunque el diseño general de arquitectura criptográfica y puerto seguro es sólido, la presencia de tres vulnerabilidades bloqueantes críticas impide autorizar el paso a QA o despliegue:
1. **Riesgo Crítico de Sabotaje (B-01):** Concesión involuntaria de `TRUNCATE` sobre tablas de auditoría legal, roles y perfiles.
2. **Riesgo Crítico de Suplantación (B-02):** Falta de inmutabilidad en sentencias `UPDATE` sobre `is_op`, `author_hash` y contadores de sistema.
3. **Fuga Crítica de Privacidad (B-03):** Exposición de `user_id` en las entidades de Grupos Estudiantiles y Marketplace.

Una vez que el Agente 1 aplique las revocaciones y refuerzos en los triggers, y el Agente 3 cierre la proyección de `user_id` en Flutter, se podrá proceder a la verificación de QA.
