# Auditoría Migraciones SQL y Drift de Base de Datos — Comunidad_USAC

## Resumen
Se ha auditado la totalidad de las migraciones SQL del repositorio (`supabase/migrations/*.sql`, 18 archivos), su histórico (`supabase/migrations_historical/*.sql`), la configuración del entorno (`supabase/config.toml`), las pruebas automatizadas (`supabase/tests/**`) y se contrastaron minuciosamente contra el estado real de la base de datos en producción documentado en `/tmp/opencode/audit/EVIDENCIA-BD.md`.
El repositorio exhibe un **drift crítico y estructural**: las migraciones no reproducen el estado real de la base de datos (faltan políticas, funciones y existen colisiones que impiden ejecutar `supabase db reset`), las vistas `safe_*` presentan una contradicción fundamental con las políticas RLS que oculta el contenido aprobado por moderación, las políticas `UPDATE` carecen de cláusula `WITH CHECK` y otorgan permisos a `authenticated` sobre `moderation_status`, existen tablas con inserción pública abierta sin validación (`sponsor_requests`, `post_polls`), funciones `SECURITY DEFINER` con `search_path=public` o sin validación de roles, grants de perfiles insuficientes para verificación y parámetros de autenticación altamente permisivos en `config.toml`.

## Hallazgos

### H-1: Drift severo: Políticas y funciones en BD real inexistentes en las migraciones del repositorio
- Severidad: CRÍTICA
- Tipo: ESQUEMA / RLS
- Ubicación: `supabase/migrations/` (ausencia total de migraciones para estos objetos)
- Evidencia:
  - En `EVIDENCIA-BD.md:291-294`:
    ```markdown
    ### `profiles` — Moderators can read profiles
    - cmd: `SELECT` · roles: `{authenticated}`
    - USING: `is_pemtree_moderator(( SELECT auth.uid() AS uid))`
    ```
  - En `EVIDENCIA-BD.md:386-390`:
    ```markdown
    ### `user_roles` — Admins can manage user_roles
    - cmd: `ALL` · roles: `{authenticated}`
    - USING: `is_pemtree_admin(( SELECT auth.uid() AS uid))`
    - WITH CHECK: `is_pemtree_admin(( SELECT auth.uid() AS uid))`
    ```
  - En `EVIDENCIA-BD.md:646, 658, 659, 660, 662, 664`:
    Funciones reales en BD sin archivo de migración en `supabase/migrations/`:
    `count_total_profiles()`, `get_admin_dashboard_stats()`, `get_admin_users_summary()`, `get_posts_with_comment_counts()`, `get_user_activity_admin(uuid)`, `get_verification_stats()`.
  - En el código Flutter (`comunidad_universitaria/lib/core/services/moderation_service.dart:45, 61, 77`): la aplicación móvil invoca directamente mediante RPC `get_admin_dashboard_stats`, `get_admin_users_summary` y `get_verification_stats`.
- Impacto: Imposibilidad total de reconstruir el entorno desde cero (`disaster recovery` o desarrollo local reproducible). Un despliegue limpio carecerá de las políticas de lectura de moderadores sobre perfiles y administración de roles, y las pantallas de moderación y métricas de la aplicación Flutter fallarán inmediatamente por inexistencia de los procedimientos RPC en la base de datos.
- Corrección propuesta: Crear una migración formal que consolide y cree con exactitud las políticas de `profiles` (`Moderators can read profiles`) y `user_roles` (`Admins can manage user_roles`), así como las 6 funciones RPC administrativas huérfanas presentes en producción, versionándolas bajo el control de código fuente del repositorio.

---

### H-2: Incompatibilidad semántica de `moderation_status`: Vistas `safe_*` filtran `= 0` mientras RLS y moderación usan `1`
- Severidad: CRÍTICA
- Tipo: LÓGICA / RLS
- Ubicación:
  - Nacimiento en vistas: `supabase/migrations/20261110000000_unified_core_and_legal_hardening.sql:1169-1171, 1199-1200`
  - Reafirmación en: `supabase/migrations/20261110000600_align_legacy_approved_content.sql:4-8, 164-165, 180-182`
  - RLS divergente: `supabase/migrations/20261001000000_adopt_remote_schema.sql:3871, 3978, 4034`
- Evidencia:
  - En `20261110000000_unified_core_and_legal_hardening.sql:1169-1171` (`safe_posts_feed`):
    ```sql
    WHERE p.deleted_at IS NULL
      AND p.moderation_status = 0
      AND (p.expires_at IS NULL OR p.expires_at > now());
    ```
  - En `20261110000000_unified_core_and_legal_hardening.sql:1199-1200` (`safe_comments`):
    ```sql
    WHERE c.deleted_at IS NULL
      AND c.moderation_status = 0;
    ```
  - En `20261110000600_align_legacy_approved_content.sql:4-6`:
    ```sql
    -- PEMTREE usaba moderation_status = 1 como "visible bajo revisión". El nuevo
    -- contrato legal usa 1 = oculto/en revisión y 0 = visible.
    ```
  - En `20260818161514_replica_pemtree_functions.sql:175, 350-385`:
    La función `enforce_system_defaults_on_insert()` establece por defecto `NEW.moderation_status := 0` (pendiente), mientras que `apply_moderation_batch()` asigna `1` cuando la etiqueta es `'appropriate'` (aprobado).
  - En `EVIDENCIA-BD.md:281-284`:
    La política RLS de lectura pública en `posts` exige:
    `USING (moderation_status IS DISTINCT FROM 2)`
  - En `EVIDENCIA-BD.md:1039-1041, 1067-1068`:
    Prueba empírica real en BD:
    `anon` → `select count(*) from posts` = **8 filas** (vistas por RLS directo).
    `anon` → `select count(*) from safe_posts_feed` = **0 filas**.
    `anon` → `select count(*) from v_public_posts` = **0 filas**.
- Impacto: Contradicción total del modelo de datos. Las publicaciones y comentarios aprobados legítimamente por el flujo de moderación automática o manual (`moderation_status = 1`) desaparecen completamente de las vistas públicas `safe_*` y del feed de los usuarios, mientras que el contenido pendiente de moderación (`status = 0`) es el único expuesto en dichas vistas. Al mismo tiempo, las consultas directas sobre las tablas base exponen contenido no moderado porque la RLS permite cualquier estado distinto de 2.
- Corrección propuesta: Unificar el contrato semántico en todo el sistema:
  1. Definir formalmente `0 = pending`, `1 = approved/appropriate`, `2 = inappropriate/hidden`, `3 = error`.
  2. Modificar las vistas `safe_posts_feed`, `safe_comments`, `safe_student_groups` y `safe_marketplace_items` para que filtren `moderation_status = 1` para visitantes generales (o permitan `status = 0` únicamente al autor del contenido mediante `is_my_*`).
  3. Alinear las políticas RLS de `posts`, `comments`, `student_groups` y `marketplace_items` para que la lectura pública (`anon`) exija estrictamente `moderation_status = 1`.

---

### H-3: Políticas UPDATE sin `WITH CHECK` y `GRANT UPDATE (moderation_status)` permiten autoaprobación de contenido
- Severidad: CRÍTICA
- Tipo: RLS / GRANTS
- Ubicación:
  - `supabase/migrations/20261110000000_unified_core_and_legal_hardening.sql:631-654`
  - `supabase/migrations/20261001000000_adopt_remote_schema.sql:4025-4030`
  - `supabase/migrations/20261110000300_audit_blockers_hardening.sql:100-108`
- Evidencia:
  - En `20261110000000_unified_core_and_legal_hardening.sql:631-636`:
    ```sql
    CREATE POLICY "Actualizar propias publicaciones o moderador" ON public.posts
        FOR UPDATE TO authenticated
        USING (
            (auth.uid() IS NOT NULL AND (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.post_authors WHERE post_id = posts.id AND user_id = auth.uid())))
            OR public.is_pemtree_moderator(auth.uid())
        );
    ```
    (Omite por completo la cláusula `WITH CHECK`).
  - Idéntica omisión para `comments` (línea 640), `marketplace_items` (línea 649) y `student_groups` (`20261001000000:4025`).
  - En `EVIDENCIA-BD.md:433, 449, 516, 584` (Grants de columna en la BD real):
    `comments` | `authenticated` | `UPDATE` incluye `moderation_status`.
    `marketplace_items` | `authenticated` | `UPDATE` incluye `moderation_status`.
    `posts` | `authenticated` | `UPDATE` incluye `moderation_status`.
    `student_groups` | `authenticated` | `UPDATE` incluye `moderation_status`.
  - En `comunidad_universitaria/lib/core/services/marketplace_service.dart:427-432`:
    El código cliente explota activamente esta permisividad:
    ```dart
    await SupabaseService.client
        .from('marketplace_items')
        .update({'moderation_status': newStatus})
        .eq('id', itemId);
    ```
- Impacto: En PostgreSQL, si una política `UPDATE` no define `WITH CHECK`, el motor reutiliza la expresión de `USING` como `WITH CHECK`. Dado que la condición `USING` solo comprueba `auth.uid() = user_id`, cualquier fila resultante donde el autor siga siendo el usuario autenticado es admitida por RLS. Aunque el trigger procedural `enforce_content_immutability_and_legal_hold()` intenta restringir cambios a moderadores, la ausencia de defensa en profundidad en RLS y la concesión explícita de `GRANT UPDATE` sobre la columna `moderation_status` a `authenticated` permite que fallas en el trigger, anidamientos (`pg_trigger_depth() > 1`) o llamadas directas permitan a un usuario autoaprobarse contenido oculto o rechazado.
- Corrección propuesta:
  1. Revocar el permiso `UPDATE` sobre las columnas `moderation_status`, `moderation_label`, `moderation_confidence`, `moderation_reason`, `moderated_at`, `moderated_by` e `is_legal_hold` para el rol `authenticated` en todas las tablas de contenido.
  2. Agregar cláusula `WITH CHECK` explícita en las políticas de actualización asegurando que las columnas de moderación no puedan ser modificadas por usuarios estándar.
  3. Eliminar el fallback en el cliente Flutter (`marketplace_service.dart:427-432`) que intenta actualizar `moderation_status` directamente sin pasar por RPC autorizada.

---

### H-4: Políticas de `post_polls` y `post_poll_options` con `WITH CHECK true` permiten secuestro y manipulación de encuestas ajenas
- Severidad: ALTA
- Tipo: RLS
- Ubicación: `supabase/migrations/20261001000000_adopt_remote_schema.sql:3936-3939, 3961-3964`
- Evidencia:
  - En `20261001000000_adopt_remote_schema.sql:3961-3964`:
    ```sql
    CREATE POLICY "Crear encuestas autenticados" ON "public"."post_polls"
      FOR INSERT
      TO "authenticated"
      WITH CHECK (true);
    ```
  - En `20261001000000_adopt_remote_schema.sql:3936-3939`:
    ```sql
    CREATE POLICY "Crear opciones autenticados" ON "public"."post_poll_options"
      FOR INSERT
      TO "authenticated"
      WITH CHECK (true);
    ```
  - En `EVIDENCIA-BD.md:237-241, 259-263`: Confirmado que el catálogo de PostgreSQL tiene `WITH CHECK: true` para ambos objetos.
- Impacto: Cualquier usuario autenticado puede asociar una encuesta arbitraria a un post creado por otra persona (sin comprobar si es el autor de dicho post). Asimismo, cualquier usuario autenticado puede insertar opciones de encuesta maliciosas, vulgares o alteradas en encuestas creadas por otros usuarios, alterando votaciones comunitarias.
- Corrección propuesta:
  1. En `post_polls`, restringir el `WITH CHECK` a:
     ```sql
     WITH CHECK (
       EXISTS (
         SELECT 1 FROM public.posts p
         WHERE p.id = post_id AND p.user_id = auth.uid()
       )
     );
     ```
  2. En `post_poll_options`, restringir el `WITH CHECK` a:
     ```sql
     WITH CHECK (
       EXISTS (
         SELECT 1 FROM public.post_polls pp
         JOIN public.posts p ON p.id = pp.post_id
         WHERE pp.id = poll_id AND p.user_id = auth.uid()
       )
     );
     ```

---

### H-5: Inserción pública irrestricta en `sponsor_requests` permite spam, autoaprobación y suplantación de `user_id` por visitantes anónimos
- Severidad: ALTA
- Tipo: RLS / PRIVACIDAD
- Ubicación: `supabase/migrations/20261001000000_adopt_remote_schema.sql:3994-3997`
- Evidencia:
  - En `20261001000000_adopt_remote_schema.sql:3994-3997`:
    ```sql
    CREATE POLICY "Anyone can insert sponsor requests" ON "public"."sponsor_requests"
      FOR INSERT
      TO PUBLIC
      WITH CHECK (true);
    ```
  - En `EVIDENCIA-BD.md:335-339`:
    `sponsor_requests` — `Anyone can insert sponsor requests` (cmd: `INSERT` · roles: `{public}` · WITH CHECK: `true`).
  - En `EVIDENCIA-BD.md:565-570` (Grants de columna):
    El rol `anon` posee permisos `INSERT` sobre las columnas `brand_name,contact_name,contact_phone,created_at,email,expected_placement,id,proposal_details,status,user_id`.
  - En `EVIDENCIA-BD.md:1047, 1053` (Pruebas empíricas con rol `anon` y `authenticated`):
    `anon` → `INSERT INTO sponsor_requests(...)` | **ÉXITO** (sin rate-limit / captcha).
    `authenticated` → `INSERT INTO sponsor_requests(user_id=<otro uuid>)` | No bloqueado por RLS, solo limitado por integridad referencial.
- Impacto: Cualquier bot o actor malicioso en Internet puede inundar la base de datos de solicitudes de patrocinio fraudulentas sin autenticación previa, asignarles arbitrariamente `status = 'approved'`, o asociar el patrocinio al `user_id` de otro estudiante.
- Corrección propuesta:
  1. Revocar permisos de `INSERT` sobre `sponsor_requests` al rol `anon`.
  2. Exigir autenticación para enviar solicitudes de patrocinio (`TO authenticated`) y validar `WITH CHECK (user_id = auth.uid() AND status = 'pending')`.
  3. Utilizar un trigger `BEFORE INSERT` que fuerce `NEW.status := 'pending'` y `NEW.user_id := auth.uid()`.

---

### H-6: Funciones `SECURITY DEFINER` con `search_path=public` y oráculos de enumeración de usuarios sin control de rol
- Severidad: ALTA
- Tipo: PRIVACIDAD / AUTH
- Ubicación:
  - `supabase/migrations/20261001000000_adopt_remote_schema.sql:1490, 1504, 1560, 1820, 2033, 2073, 2113, 2260`
  - `EVIDENCIA-BD.md:655, 657, 667, 685, 698, 699, 700, 711`
- Evidencia:
  - 7 funciones `SECURITY DEFINER` fijan explícitamente `search_path=public` en lugar de `search_path=""` o `pg_catalog`:
    1. `force_marketplace_item_owner()`
    2. `generate_author_hash(p_user_id uuid, p_salt text)`
    3. `handle_new_user_profile()`
    4. `moderate_marketplace_item(uuid, integer, text, double precision, text)`
    5. `report_forum_comment(uuid, text, text)`
    6. `report_forum_post(uuid, text, text)`
    7. `report_marketplace_item(uuid, text, uuid, text)`
  - Función `user_exists(p_user_id uuid)` (`20261001000000:2260`):
    ```sql
    CREATE OR REPLACE FUNCTION public.user_exists (p_user_id uuid)
    RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
    AS $function$ select exists (select 1 from auth.users u where u.id = p_user_id) $function$;
    ```
    Posee `GRANT EXECUTE TO authenticated` sin verificar si el invocador es administrador.
  - Función `count_total_profiles()` (`EVIDENCIA-BD.md:646`): Posee `GRANT EXECUTE TO anon, authenticated` y salta RLS sin validación.
  - Función `generate_author_hash(p_user_id uuid, p_salt text)` (`EVIDENCIA-BD.md:657`): Ejecutable por `anon` y `authenticated` con `search_path=public`.
- Impacto:
  - `search_path=public` en funciones `SECURITY DEFINER` (que corren como superusuario `postgres`) incumple las recomendaciones de seguridad de PostgreSQL y Supabase, exponiendo las rutinas a riesgos de secuestro de resolución de operadores o funciones auxiliares.
  - `user_exists` actúa como un oráculo directo que permite a cualquier usuario registrado enumerar y verificar si un UUID cualquiera pertenece a una cuenta registrada en `auth.users`.
- Corrección propuesta:
  1. Modificar todas las funciones `SECURITY DEFINER` para fijar `SET search_path = ''` y referenciar explícitamente `public.<tabla>` y `pg_catalog.<funcion>`.
  2. Revocar `EXECUTE ON FUNCTION user_exists` a `authenticated` y restringirlo exclusivamente a roles administrativos o `service_role`.

---

### H-7: Falta de `GRANT UPDATE` en columnas de verificación de `profiles` bloquea la verificación estudiantil
- Severidad: ALTA
- Tipo: GRANTS / AUTH
- Ubicación:
  - `supabase/migrations/20261110000300_audit_blockers_hardening.sql:116-119`
  - `EVIDENCIA-BD.md:521, 1049`
- Evidencia:
  - En `20261110000300_audit_blockers_hardening.sql:116-119`:
    ```sql
    REVOKE UPDATE ON TABLE public.profiles FROM anon, authenticated;
    GRANT UPDATE (
        full_name, carrera, accepted_terms_version, accepted_terms_at
    ) ON TABLE public.profiles TO authenticated;
    ```
  - En `EVIDENCIA-BD.md:521`:
    `profiles` | `authenticated` | `UPDATE` | columnas permitidas: `accepted_terms_at,accepted_terms_version,carrera,full_name`.
  - En `EVIDENCIA-BD.md:1049`:
    Prueba empírica real: `authenticated` → `has_table_privilege(profiles,'UPDATE')` = **false**.
- Impacto: Las columnas `carne`, `carne_hash`, `cui`, `cui_hash`, `is_verified` y `verified_at` carecen por completo de `GRANT UPDATE` para el rol `authenticated`. Si la interfaz de usuario en Flutter o el flujo de verificación envía los datos de carné o CUI para que el trigger `handle_profile_sensitive_data()` genere los hashes, la consulta es abortada inmediatamente a nivel de motor por `permission denied for column carne / cui of relation profiles`.
- Corrección propuesta: Si la verificación se realiza por escritura directa en `profiles` protegida por el trigger `handle_profile_sensitive_data()`, conceder `GRANT UPDATE (carne, cui) ON TABLE public.profiles TO authenticated` (el trigger se encarga de calcular el hash y poner en NULL el valor en texto claro). Si la verificación debe ser server-authoritative, implementar una función RPC dedicada con `SECURITY DEFINER` (e.g. `submit_student_verification(carne, cui)`) y revocar cualquier intento de escritura directa sobre dichas columnas.

---

### H-8: Desalineación y fallas estructurales en la suite de pruebas pgTAP contra el estado real
- Severidad: MEDIA
- Tipo: RLS / ESQUEMA
- Ubicación:
  - `supabase/tests/seller_verification_rls_test.sql:26-48`
  - `supabase/tests/anonymous_read_only_test.sql:49-60`
  - `supabase/tests/views_public_test.sql:32-61`
- Evidencia:
  - En `seller_verification_rls_test.sql:42-46`:
    ```sql
    update public.profiles
       set seller_verification_status = 'verified',
           seller_verified_at = now(),
           seller_verified_by = '88888888-8888-8888-8888-888888888888'
     where id = '77777777-7777-7777-7777-777777777777'
    ```
    Falla contra la base de datos real: la columna `seller_verification_status` **no existe** en `public.profiles` (`EVIDENCIA-BD.md:520`). La migración `20261004000000_require_aal2_and_verified_sellers.sql` nunca fue aplicada en producción.
  - En `anonymous_read_only_test.sql:49-60`: Asume que la política restrictiva `deny_anonymous_auth_insert` rechaza inserciones de sesiones anónimas. En la BD real dicha política no existe y la inserción tendría éxito, haciendo fallar el test `throws_ok`.
  - En `views_public_test.sql:32-61`: Todos los fixtures preparan datos con `moderation_status = 0` bajo la premisa de que 0 es visible, ocultando el comportamiento de contenido aprobado (`status = 1`).
  - Cobertura deficiente: No existen pruebas de RLS para inserción en `sponsor_requests` por visitantes anónimos, inserciones no autorizadas en `post_polls`/`post_poll_options`, ni pruebas sobre las funciones RPC administrativas huérfanas.
- Impacto: La suite de pruebas no refleja la realidad del entorno de producción. Pruebas clave fallarían al ejecutarse contra la base de datos real, mientras que otras proporcionan una falsa sensación de seguridad al no verificar vectores reales de suplantación y desconfiguración.
- Corrección propuesta: Actualizar los tests de pgTAP para alinearlos con el esquema real o aplicar las migraciones faltantes en producción; parametrizar pruebas negativas para verificar que `anon` no pueda insertar en `sponsor_requests` y que usuarios ajenos no puedan crear encuestas en posts ajenos.

---

### H-9: Configuración insegura de autenticación en `supabase/config.toml`
- Severidad: ALTA
- Tipo: AUTH
- Ubicación: `supabase/config.toml:159, 176, 179, 207-211, 220, 222, 224`
- Evidencia:
  - Línea 176: `minimum_password_length = 6` (mínimo histórico inseguro; recomendado: >= 8).
  - Línea 179: `password_requirements = ""` (sin requisitos de complejidad: permite contraseñas como "123456").
  - Línea 207-211: Captcha desactivado / comentado (`[auth.captcha] enabled = true` está comentado).
  - Línea 220: `enable_confirmations = false` (`[auth.email]`).
  - Línea 222: `secure_password_change = false` (permite cambio de contraseña sin exigir reautenticación).
  - Línea 224: `max_frequency = "1s"` (frecuencia entre solicitudes de restablecimiento/confirmación fijada en solo 1 segundo).
- Impacto:
  - Al estar `enable_confirmations = false`, cualquier usuario puede registrarse con correos institucionales ajenos (e.g. `@ingenieria.usac.edu.gt`, `@usac.edu.gt`) sin demostrar posesión de la cuenta de correo, suplantando identidades estudiantiles inmediatamente.
  - La combinación de longitud de 6 caracteres sin requisitos de complejidad y sin captcha expone al endpoint de autenticación a ataques automatizados de fuerza bruta y creación masiva de cuentas títere (*sockpuppets*).
- Corrección propuesta:
  1. Habilitar `enable_confirmations = true` en `[auth.email]` para requerir validación de correo antes de iniciar sesión.
  2. Ajustar `minimum_password_length = 8` o superior y configurar `password_requirements = "lower_upper_letters_digits"`.
  3. Establecer `secure_password_change = true`.
  4. Configurar un proveedor de Captcha (Turnstile o hCaptcha) para el registro y elevar `max_frequency` a un valor más restrictivo (e.g. `"60s"`).

---

### H-10: Colisión estructural en migraciones impide reconstruir la BD con `supabase db reset`
- Severidad: CRÍTICA
- Tipo: ESQUEMA
- Ubicación:
  - `supabase/migrations/20260818161419_replica_pemtree_schema.sql:56, 76, 101, 111`
  - `supabase/migrations/20261001000000_adopt_remote_schema.sql:3297, 3318, 3340, 3352`
- Evidencia:
  - En `20260818161419_replica_pemtree_schema.sql`:
    Línea 56: `create table public.user_reports (`
    Línea 76: `create table public.whatsapp_groups (`
    Línea 101: `create table public.whatsapp_group_upvotes (`
    Línea 111: `create table public.whatsapp_group_reports (`
  - En `20261001000000_adopt_remote_schema.sql`:
    Línea 3297: `CREATE VIEW "public"."user_reports" WITH (security_invoker=true) AS ...`
    Línea 3318: `CREATE VIEW "public"."whatsapp_groups" WITH (security_invoker=true) AS ...`
    Línea 3340: `CREATE VIEW "public"."whatsapp_group_reports" WITH (security_invoker=true) AS ...`
    Línea 3352: `CREATE VIEW "public"."whatsapp_group_upvotes" WITH (security_invoker=true) AS ...`
  - No existe ninguna sentencia `DROP TABLE` intermedia entre ambas migraciones.
  - Además, `20260818161419_replica_pemtree_schema.sql:201, 215` crea las tablas `docentes` y `docente_reviews`, las cuales ya no existen en el esquema remoto adoptado ni en producción (`EVIDENCIA-BD.md`).
- Impacto: Al ejecutar `supabase db reset` en un entorno de desarrollo local o CI/CD, PostgreSQL falla con error fatal `ERROR: relation "whatsapp_groups" already exists` al llegar a la línea 3318 de `20261001000000_adopt_remote_schema.sql`. La secuencia de migraciones actual está rota y no puede ser aplicada secuencialmente en una base de datos limpia.
- Corrección propuesta:
  1. Eliminar o reestructurar las migraciones iniciales redundantes `20260818161401` a `20260818161532` para que `20261001000000_adopt_remote_schema.sql` (o un baseline limpio) actúe como punto de partida único y consistente.
  2. Alternativamente, intercalar una migración que realice `DROP TABLE IF EXISTS public.whatsapp_groups, public.whatsapp_group_upvotes, public.whatsapp_group_reports, public.user_reports, public.docentes, public.docente_reviews CASCADE;` antes de que se intente crear las vistas con los mismos nombres.

---

## No verificado
1. **Cuerpo PL/pgSQL completo de funciones remotas huérfanas**: No fue posible verificar la lógica interna exacta ni los triggers de `count_total_profiles()` y `get_posts_with_comment_counts()`, ya que no se encuentran en los archivos de migración del repositorio ni en las muestras disponibles en el directorio de evidencias.
2. **Impacto en producción de la migración no aplicada `20261004000000_require_aal2_and_verified_sellers.sql`**: No se pudo verificar si dicha migración fue descartada deliberadamente por problemas operativos con el flujo de doble factor (MFA/AAL2) en la app móvil, o si se encuentra pendiente de despliegue manual.
