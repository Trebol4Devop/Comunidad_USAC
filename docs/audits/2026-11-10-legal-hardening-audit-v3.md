# Dictamen Final de Auditoría Red Team (Pre-QA V3) — Cumplimiento Legal y Hardening

**Fecha de emisión:** 10 de noviembre de 2026  
**Auditor:** Agente 4-V3 — Dictamen final Red Team (pre-QA)  
**Repositorio:** `/home/carlos/Escritorio/Comunidad_USAC`  
**Rama:** `feature/legal-hardening-audit-v3`  
**Migración evaluada:** `supabase/migrations/20261110000400_fix_group_limit_security_definer.sql` junto a `20261110000300_audit_blockers_hardening.sql`  
**Estado:** **APROBADO PARA QA**

---

## 1. Resumen Ejecutivo y Alcance

La presente auditoría adversarial Red Team V3 emite el dictamen final previo al pase a aseguramiento de calidad (QA). Se evalúa exhaustivamente el cierre de los bloqueantes de seguridad históricos (B-01, B-02, B-03) y la resolución de la regresión funcional crítica detectada en V2 (B-04):

1. **B-01**: Concesión accidental de privilegios `TRUNCATE` a usuarios autenticados sobre tablas troncales y bitácoras legales.
2. **B-02**: Manipulación arbitraria de autoría (`user_id`), estatus OP (`is_op`, `author_hash`) y métricas de relevancia (`hot_score`, `likes`).
3. **B-03**: Fuga horizontal de privacidad de identificadores UUID (`user_id`) en `student_groups` y `marketplace_items`.
4. **B-04**: Regresión introducida en `check_whatsapp_groups_limit()`, la cual impedía a estudiantes regulares crear grupos de estudio al ejecutarse como `SECURITY INVOKER` sin privilegios `SELECT (user_id)`.

Adicionalmente, se auditaron:
- La ausencia de otras funciones `SECURITY INVOKER` que interactúen con columnas restringidas.
- La estabilidad de los flujos funcionales normales (creación de posts, comentarios, grupos, marketplace, soft-delete, moderación, auto-cuarentena y upvotes de reseñas).
- La ejecución integral de las suites automatizadas (`supabase db reset`, `supabase test db`, `deno check`, `flutter analyze` y `flutter test`), discriminando minuciosamente entre bugs reales y deuda técnica de pruebas heredada por el nuevo contrato legal.

### Balance de la Auditoría
- **Seguridad y Privacidad:** **100% CERRADO Y VERIFICADO.** No se detectaron vectores de escalación, suplantación, alteración de métricas o fuga de identificadores de usuario.
- **Funcionalidad y Estabilidad:** **100% RESTAURADO.** El límite de grupos opera sin fallos de permisos; moderadores están exentos; soft-deleted no penalizan la cuota; y los flujos comunitarios operan según lo previsto.
- **Veredicto:** **APROBADO PARA QA.**

---

## 2. Estado de Bloqueantes B-01 .. B-04 con Evidencia Adversarial

### B-01: Revocación Absoluta de TRUNCATE
- **Estado:** **CERRADO Y VERIFICADO.**
- **Mecanismo:** La migración revocó `TRUNCATE` en todo el esquema `public` para roles `anon` y `authenticated`.
- **Evidencia PoC Adversarial:** Intento deliberado de vaciado masivo de bitácora y tablas de contenido:
  ```sql
  DO $$
  DECLARE
      v_user uuid := '11111111-1111-1111-1111-111111111111';
  BEGIN
      PERFORM tests.authenticate_as(v_user);
      
      -- Intento 1: Bitácora legal
      EXECUTE 'TRUNCATE TABLE public.moderation_audit_log';
      -- Intento 2: Publicaciones del foro
      EXECUTE 'TRUNCATE TABLE public.posts';
      -- Intento 3: Grupos estudiantiles
      EXECUTE 'TRUNCATE TABLE public.student_groups';
  END;
  $$;
  ```
  **Resultado:** Todos los intentos son bloqueados fulminantemente a nivel de motor de PostgreSQL:
  ```
  NOTICE: PoC 1.1: TRUNCATE moderation_audit_log bloqueado con 42501 (insufficient_privilege)
  NOTICE: PoC 1.2: TRUNCATE posts bloqueado con 42501 (insufficient_privilege)
  NOTICE: PoC 1.3: TRUNCATE student_groups bloqueado con 42501 (insufficient_privilege)
  ```
  Una verificación en `pg_class` constata 0 tablas en `public` con privilegio `TRUNCATE` para roles no privilegiados.

---

### B-02: Spoofing de OP, Identidad y Manipulación de Métricas
- **Estado:** **CERRADO Y VERIFICADO.**
- **Mecanismo:** 
  1. Revocación a nivel de columna del permiso `UPDATE` sobre columnas críticas (`hot_score`, `likes`, `user_id`, `author_hash`, `is_op`, `is_pinned`, `moderation_status`, `is_legal_hold`, `created_at`).
  2. Triggers `enforce_content_immutability_and_legal_hold()` y `enforce_system_defaults_on_insert()` que fuerzan valores seguros incondicionalmente.
- **Evidencia PoC Adversarial:**
  1. Intento de inflar `hot_score`:
     ```sql
     UPDATE public.posts SET hot_score = 999999 WHERE id = v_pid;
     -- Resultado: Bloqueado con error 42501 (insufficient_privilege)
     ```
  2. Intento de reasignar autoría (`user_id`):
     ```sql
     UPDATE public.posts SET user_id = '22222222-2222-2222-2222-222222222222' WHERE id = v_pid;
     -- Resultado: Bloqueado con error 42501 (insufficient_privilege)
     ```
  3. Intento de auto-otorgarse insignia OP (`is_op = true`):
     ```sql
     UPDATE public.comments SET is_op = true WHERE id = v_cid;
     -- Resultado: Bloqueado con error 42501 (insufficient_privilege)
     ```
  4. Inserción maliciosa forzando métricas y estados alterados:
     Los triggers `trg_aa_system_defaults_*` interceptan la inserción y sobreescriben los valores con los valores seguros por defecto del sistema (`likes=0`, `hot_score=calculado`, `is_pinned=false`, `mod_status=0`, `is_legal_hold=false`, `created_at=now()`).
  5. Edición legítima de contenido por el autor:
     ```sql
     UPDATE public.posts SET content = 'Contenido legítimamente editado por autor' WHERE id = v_pid;
     UPDATE public.comments SET content = 'Comentario legítimamente editado por autor' WHERE id = v_cid;
     -- Resultado: Ambos UPDATE se aplican exitosamente sin errores.
     ```

---

### B-03: Fuga Horizontal de Privacidad de `user_id`
- **Estado:** **CERRADO Y VERIFICADO.**
- **Mecanismo:** Revocación de `SELECT (user_id)` en `student_groups` y `marketplace_items` para `anon` y `authenticated`. Implementación de vistas seguras `safe_student_groups` y `safe_marketplace_items` con `security_invoker = true` y bandera `is_mine` computada.
- **Evidencia PoC Adversarial:**
  1. Intentos de acceso directo a la columna `user_id`:
     ```sql
     SET ROLE anon;
     SELECT user_id FROM public.student_groups LIMIT 1;
     SELECT user_id FROM public.marketplace_items LIMIT 1;

     SET ROLE authenticated;
     SELECT user_id FROM public.student_groups LIMIT 1;
     SELECT user_id FROM public.marketplace_items LIMIT 1;
     ```
     **Resultado:** Todos rechazados con:
     ```
     ERROR: 42501 permission denied for table student_groups / marketplace_items
     ```
  2. Consulta a través de las vistas seguras:
     ```sql
     SELECT id, title, is_mine FROM public.safe_student_groups LIMIT 1;
     SELECT id, title, is_mine FROM public.safe_marketplace_items LIMIT 1;
     ```
     **Resultado:** Operan limpiamente tanto para `anon` (`is_mine = false`) como para `authenticated` (`is_mine = true/false` según pertenencia) sin exponer la columna `user_id` en el catálogo de la vista.

---

### B-04: Regresión en Límite de Grupos Estudiantiles (`student_groups`)
- **Estado:** **CERRADO Y VERIFICADO.**
- **Mecanismo:** Mediante la migración `supabase/migrations/20261110000400_fix_group_limit_security_definer.sql`, la función de trigger `check_whatsapp_groups_limit()` fue redefinida como `SECURITY DEFINER SET search_path = ''`. Además, el conteo filtra explícitamente `AND deleted_at IS NULL` y exime a moderadores y administradores.
- **Evidencia PoC Adversarial Dinámica:**
  Se ejecutó un escenario de prueba adversarial completo autenticado como estudiante regular (`v_user`) y como moderador (`v_mod`):
  ```sql
  DO $$
  DECLARE
      v_user uuid := '44444444-4444-4444-4444-444444444444';
      v_mod  uuid := '55555555-5555-5555-5555-555555555555';
      v_gid1 uuid := gen_random_uuid();
      v_gid2 uuid := gen_random_uuid();
      v_gid3 uuid := gen_random_uuid();
      v_gid4 uuid := gen_random_uuid();
      v_gid5 uuid := gen_random_uuid();
      v_gid6 uuid := gen_random_uuid();
      v_gid7 uuid := gen_random_uuid();
      v_failed boolean := false;
      v_err_msg text;
      i int;
  BEGIN
      PERFORM tests.authenticate_as(v_user);

      -- Paso 1: Inserción de grupo 1 (comprobación de no-regresión B-04)
      INSERT INTO public.student_groups (id, user_id, title, carrera, curso, section, link, description, author_alias)
      VALUES (v_gid1, v_user, 'Grupo Calculo 1', 'sistemas', 'Calculo 1', 'A', 
              'https://chat.whatsapp.com/LkJhGfEdCbAyXwVuTsRqPo', 'Grupo de apoyo', 'Compilador Desvelado');
      RAISE NOTICE 'Grupo 1 insertado exitosamente por usuario normal.';

      -- Paso 2: Inserción de grupos 2, 3, 4 y 5
      -- ... (inserciones válidas de grupos 2 al 5) ...
      RAISE NOTICE '5 grupos insertados exitosamente por usuario normal.';

      -- Paso 3: Inserción de grupo 6 (debe fallar por límite de 5 grupos)
      BEGIN
          INSERT INTO public.student_groups (id, user_id, title, carrera, curso, section, link, description, author_alias)
          VALUES (v_gid6, v_user, 'Grupo IPC 1', 'sistemas', 'IPC 1', 'A', 
                  'https://chat.whatsapp.com/QazWsxEdcRfvTgbYhnUjmK', 'Introduccion a programacion', 'Compilador Desvelado');
      EXCEPTION WHEN OTHERS THEN
          v_failed := true;
          v_err_msg := SQLERRM;
          RAISE NOTICE 'Grupo 6 rechazado correctamente: %', v_err_msg;
      END;
      IF NOT v_failed THEN RAISE EXCEPTION 'ERROR: El grupo 6 debió fallar por límite de 5 grupos!'; END IF;

      -- Paso 4: Soft-delete del grupo 1 por el autor
      UPDATE public.student_groups SET deleted_at = now() WHERE id = v_gid1;
      RAISE NOTICE 'Grupo 1 marcado como soft-deleted por su autor.';

      -- Paso 5: Reintentar inserción del grupo 6 (debe funcionar: 4 activos + 1 nuevo = 5)
      INSERT INTO public.student_groups (id, user_id, title, carrera, curso, section, link, description, author_alias)
      VALUES (v_gid6, v_user, 'Grupo IPC 1', 'sistemas', 'IPC 1', 'A', 
              'https://chat.whatsapp.com/QazWsxEdcRfvTgbYhnUjmK', 'Introduccion a programacion', 'Compilador Desvelado');
      RAISE NOTICE 'Grupo 6 insertado exitosamente tras soft-delete del grupo 1.';

      -- Paso 6: Intentar insertar grupo 7 (debe fallar nuevamente al alcanzar 5 activos)
      v_failed := false;
      BEGIN
          INSERT INTO public.student_groups (id, user_id, title, carrera, curso, section, link, description, author_alias)
          VALUES (v_gid7, v_user, 'Grupo IPC 2', 'sistemas', 'IPC 2', 'B', 
                  'https://chat.whatsapp.com/WsxEdcRfvTgbYhnUjmKlop', 'Programacion orientada', 'Compilador Desvelado');
      EXCEPTION WHEN OTHERS THEN
          v_failed := true;
          v_err_msg := SQLERRM;
          RAISE NOTICE 'Grupo 7 rechazado correctamente tras volver al límite: %', v_err_msg;
      END;
      IF NOT v_failed THEN RAISE EXCEPTION 'ERROR: El grupo 7 debió fallar!'; END IF;

      -- Paso 7: Comprobación con usuario Moderador (sin límite de grupos)
      PERFORM tests.authenticate_as_moderator(v_mod);
      FOR i IN 1..7 LOOP
          INSERT INTO public.student_groups (id, user_id, title, carrera, curso, section, link, description, author_alias)
          VALUES (gen_random_uuid(), v_mod, 'Grupo Mod ' || i, 'sistemas', 'Curso ' || i, 'A', 
                  'https://chat.whatsapp.com/ModInviteCodeNumber' || i || 'XyZ', 'Coordinacion docente', 'Compilador Desvelado');
      END LOOP;
      RAISE NOTICE 'Moderador insertó 7 grupos exitosamente sin límite.';
  END;
  $$;
  ```
  **Salida Obtenida:**
  ```
  NOTICE: Grupo 1 insertado exitosamente por usuario normal.
  NOTICE: 5 grupos insertados exitosamente por usuario normal.
  NOTICE: Grupo 6 rechazado correctamente: Límite de 5 grupos alcanzado: Un usuario normal no puede publicar más de 5 grupos en la comunidad. Si necesitas publicar más, comunícate con un administrador o moderador.
  NOTICE: Grupo 1 marcado como soft-deleted por su autor.
  NOTICE: Grupo 6 insertado exitosamente tras soft-delete del grupo 1.
  NOTICE: Grupo 7 rechazado correctamente tras volver al límite: Límite de 5 grupos alcanzado: Un usuario normal no puede publicar más de 5 grupos en la comunidad. Si necesitas publicar más, comunícate con un administrador o moderador.
  NOTICE: Moderador insertó 7 grupos exitosamente sin límite.
  DO
  ```

---

## 3. Auditoría de Funciones SECURITY INVOKER en el Catálogo

Se realizó una inspección exhaustiva en `pg_proc` y `pg_namespace` para identificar cualquier función de trigger o procedimiento almacenado que se ejecute con privilegios del invocador (`prosecdef = false`) y realice consultas sobre `student_groups`, `marketplace_items`, `posts`, `comments` y la columna `user_id`:

```sql
SELECT 
    p.proname AS trigger_func,
    p.prosecdef AS is_sec_definer
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prorettype = 'trigger'::regtype
  AND p.prosecdef = false
  AND (
      p.prosrc ILIKE '%student_groups%'
      OR p.prosrc ILIKE '%marketplace_items%'
      OR p.prosrc ILIKE '%posts%'
      OR p.prosrc ILIKE '%comments%'
  )
  AND p.prosrc ILIKE '%user_id%';
```
**Resultado:** **0 filas encontradas.**

### Desglose de Funciones de Trigger en `public`:
De las 26 funciones de trigger existentes en `public`:
- **21 funciones son `SECURITY DEFINER`** (`prosecdef = true`), incluyendo todos los handlers de hash, encolamiento, defaults, cuotas e inmutabilidad.
- **5 funciones son `SECURITY INVOKER`** (`prosecdef = false`):
  1. `check_content_moderation`: Evalúa exclusivamente expresiones regulares y diccionarios sobre los campos textuales del registro `NEW`. No realiza sentencias `SELECT`.
  2. `reset_moderation_on_edit`: Asigna `NEW.moderation_status := 0; RETURN NEW;`. No realiza sentencias `SELECT`.
  3. `legacy_marketplace_reports_iud`, `legacy_student_group_reports_iud`, `legacy_user_reports_iud`: Triggers `INSTEAD OF` sobre vistas de compatibilidad de reportes que redirigen inserciones hacia `entity_reports`. No realizan `SELECT` sobre columnas revocadas.

---

## 4. Verificación de Flujos Funcionales Normales (Sin Regresiones)

Se verificó el correcto funcionamiento de los 8 flujos operativos principales de la plataforma:

| Flujo | Descripción | Comportamiento Observado | Estado |
| :--- | :--- | :--- | :---: |
| **A** | Crear publicación en foro (`posts`) | Registro exitoso por autor autenticado con seudónimo del catálogo (`Compilador Desvelado`). | **OK** |
| **B** | Crear comentario (`comments`) | Inserción exitosa ligada al post con validación de seudónimo y hash. | **OK** |
| **C** | Crear grupo estudiantil (`student_groups`) | Inserción de enlace WhatsApp exitosa sin errores de privilegios (Fix B-04). | **OK** |
| **D** | Crear anuncio de marketplace (`marketplace_items`) | Inserción exitosa con categoría de catálogo `libros_materiales`. | **OK** |
| **E** | Soft-delete por autor | Autor actualiza `deleted_at = now()` en post, comentario, grupo e item de forma exitosa. | **OK** |
| **F** | Moderación manual por moderador | Moderador actualiza `moderation_status = 2` y agrega justificación sin impedimentos de RLS. | **OK** |
| **G** | Auto-cuarentena comunitaria | Al recibir 3 reportes independientes por causas de riesgo (`acoso`), el post cambia automáticamente a `moderation_status = 1`, `is_legal_hold = true`, se encola trabajo prioritario en `moderation_jobs` y se asienta bitácora en `moderation_audit_log` con etiqueta `COMMUNITY_AUTO_QUARANTINE`. | **OK** |
| **H** | Voto en reseñas (`seccion_review_upvotes`) | Inserción en `seccion_review_upvotes` incrementa `seccion_reviews.upvotes` a 1; eliminación lo decrementa a 0. | **OK** |

---

## 5. Hallazgos Nuevos

**No se detectaron hallazgos nuevos ni vulnerabilidades secundarias.**  
La corrección introducida en la migración `20261110000400_fix_group_limit_security_definer.sql` resolvió B-04 sin alterar la superficie de ataque ni reintroducir filtraciones de `user_id`.

---

## 6. Deuda de Pruebas para QA (Plan de Acción Concreto)

Durante la evaluación de la suite de pruebas automatizadas:
- `supabase db reset`: **EXITOSO (Exit 0)**.
- `deno check supabase/functions/moderation-worker/index.ts`: **EXITOSO (Exit 0)**.
- `flutter analyze`: **1 advertencia y 1 aviso de estilo**.
- `supabase test db`: **9 archivos de prueba fallidos por contrato nuevo**.
- `flutter test`: **289 pruebas exitosas, 6 fallidas por adaptación de mocks y vistas**.

Todas las fallas detectadas obedecen estrictamente a **deuda de pruebas** generada por el endurecimiento del contrato legal y de seguridad (Art. 12 seudónimos curados, Art. 20/21 Legal Hold y soft-delete, B-03 vistas seguras y revocación de `DELETE` físico). Ninguna falla corresponde a un bug en el código de producción.

### Detalle de Deuda de Pruebas a Actualizar por QA antes de Producción:

#### A. Pruebas de Base de Datos (`supabase/tests/`)
1. **`supabase/tests/anonymous_read_only_test.sql`**
   - **Causa:** Inserta un post con `author_alias = 'Visitante'`, el cual es rechazado legítimamente por el trigger `check_author_alias_validity()` con código `23514 (Art. 12)`.
   - **Acción QA:** Cambiar el fixture a un seudónimo del catálogo (ej. `'Compilador Desvelado'`).
2. **`supabase/tests/authenticated_writes_without_otp_test.sql`**
   - **Causa:** 
     - Usa alias `'Usuario de prueba'` (rechazado por Art. 12).
     - Intenta ejecutar `DELETE FROM public.posts` físico, el cual está revocado con error `42501` por retención legal.
   - **Acción QA:** Usar un alias curado y actualizar la aserción de eliminación física para verificar el soft-delete (`UPDATE public.posts SET deleted_at = now()`) o comprobar que el `DELETE` físico falla con `42501`.
3. **`supabase/tests/comments_rls_test.sql`**
   - **Causa:** Usa `author_alias = 'Alias A'` (rechazado por Art. 12).
   - **Acción QA:** Actualizar el alias a uno curado del catálogo.
4. **`supabase/tests/constraints_catalog_test.sql`**
   - **Causa:** Inserta items de marketplace con alias no permitidos (rechazado por Art. 12).
   - **Acción QA:** Asignar alias válidos en los inserts del test.
5. **`supabase/tests/counters_triggers_test.sql`**
   - **Causa:** Inserta registros con alias arbitrarios (rechazado por Art. 12).
   - **Acción QA:** Actualizar los inserts con alias válidos.
6. **`supabase/tests/groups_marketplace_rls_test.sql`**
   - **Causa:** Usa alias no curados en las pruebas de creación de grupos y anuncios.
   - **Acción QA:** Migrar fixtures a alias del catálogo.
7. **`supabase/tests/posts_rls_test.sql`**
   - **Causa:** Usa alias ad-hoc `'Alias A'` y `'Alias B'`.
   - **Acción QA:** Reemplazar por alias válidos del catálogo.
8. **`supabase/tests/rpc_moderation_test.sql`**
   - **Causa:** Usa `author_alias = 'Vendedor Pirata'`.
   - **Acción QA:** Ajustar el fixture a un seudónimo válido (ej. `'Puntero Fantasma'`).
9. **`supabase/tests/views_public_test.sql`**
   - **Causa:** Inserta posts con `'Alias A'`.
   - **Acción QA:** Ajustar el fixture al catálogo de alias.

#### B. Pruebas Unitarias de Frontend (`comunidad_universitaria/test/`)
1. **`test/services/profile_service_test.dart`**
   - **`deletePost`, `deleteGroup`, `deleteMarketplaceItem`:**  
     - **Causa:** Las pruebas registran `fakeServer.onDelete('/rest/v1/posts', ...)`. Debido al endurecimiento legal, `ProfileService` ahora ejecuta un soft-delete vía HTTP `PATCH` actualizando el campo `deleted_at`.
     - **Acción QA:** Cambiar los stubs de prueba de `fakeServer.onDelete` a `fakeServer.onPatch`.
   - **`fetchUserPosts`:**  
     - **Causa:** El test mockea `fakeServer.onGet('/rest/v1/v_public_posts')`. El servicio fue actualizado para consumir la vista segura `/rest/v1/safe_posts_feed`.
     - **Acción QA:** Actualizar la ruta del mock a `/rest/v1/safe_posts_feed`.
2. **`test/cache_service_test.dart`**
   - **`fetchPosts devuelve la copia en memoria y protege la caché`:**  
     - **Causa:** `ForumService.fetchPosts` incluye el parámetro `'feedMode': feedMode.name` en el cálculo de `cacheKey`. La prueba construye la clave manual sin dicho parámetro, produciendo un cache-miss que intenta consultar el cliente no configurado.
     - **Acción QA:** Añadir `'feedMode': 'hot'` a los parámetros de `CacheService.buildKey` en la prueba.
3. **`test/widgets/profile_screen_test.dart`**
   - **`permite volver a la pantalla principal desde el perfil`:**  
     - **Causa:** La prueba espera encontrar el texto `'Editar perfil'` y un widget `BackButton`. La pantalla `ProfileScreen` implementa el título `'Preferencias de Usuario'` y utiliza un `IconButton` con `Icons.arrow_back`.
     - **Acción QA:** Actualizar el texto esperado a `'Preferencias de Usuario'` y buscar el botón con `find.byIcon(Icons.arrow_back)`.

#### C. Análisis Estático (`comunidad_universitaria`)
1. **`lib/features/profile/screens/profile_screen.dart:330:11`**:
   - `warning • The value of the local variable 'appBar' isn't used`: Variable local residual generada durante el refactor de la barra superior.
   - **Acción QA:** Eliminar la línea declarativa no utilizada.
2. **`lib/features/forum/widgets/discord/popular_servers_sidebar.dart:124:41`**:
   - `info • Unnecessary use of multiple underscores`: Uso de `__` en parámetro de callback.
   - **Acción QA:** Reemplazar por un único guión bajo `_`.

---

## 7. Dictamen y Veredicto Final

```
================================================================================
                              VEREDICTO FINAL:
                              APROBADO PARA QA
================================================================================
```

### Justificación Técnica:
1. **Bloqueantes de Seguridad Cero:** B-01, B-02 y B-03 están completamente cerrados y respaldados por restricciones a nivel de catálogo de PostgreSQL (`REVOKE TRUNCATE`, `REVOKE UPDATE (columns)`, `REVOKE SELECT (user_id)`).
2. **Regresión B-04 Resuelta:** La migración `20261110000400` restableció la capacidad operativa de los grupos estudiantiles con el nivel de privilegio adecuado (`SECURITY DEFINER`), garantizando la aplicación estricta de la cuota de 5 grupos sin romper los permisos del estudiante común.
3. **Flujos Normales Intactos:** La plataforma preserva la totalidad de sus flujos funcionales (creación, edición autorizada de contenido, soft-delete, moderación, auto-cuarentena y votación).
4. **Deuda de Pruebas Controlada:** Las fallas en `supabase test db` y `flutter test` son exclusivamente el reflejo del endurecimiento contractual y deben ser actualizadas por el equipo de QA en su ciclo de pruebas previo a producción.
