# Informe de Re-Auditoría de Seguridad, Privacidad y Cumplimiento Legal (Red Team V2)

**Fecha de emisión:** 10 de noviembre de 2026  
**Auditor:** Agente 4-V2 — Re-auditoría Red Team de Bloqueantes Corregidos  
**Repositorio:** `/home/carlos/Escritorio/Comunidad_USAC`  
**Rama:** `feature/legal-hardening-audit-v2` (integrando `fix/legal-hardening-audit-blockers`)  
**Migración evaluada:** `supabase/migrations/20261110000300_audit_blockers_hardening.sql` y componentes Flutter  
**Estado:** **RECHAZADO — DEVOLVER A AGENTE 1 (DB)**

---

## 1. Resumen Ejecutivo y Alcance

La presente re-auditoría adversarial (Red Team V2) evalúa la efectividad de las correcciones aplicadas a los tres bloqueantes de producción identificados en el informe anterior (`docs/audits/2026-11-10-legal-hardening-audit.md`):
- **B-01**: Concesión involuntaria de privilegios `TRUNCATE` a `authenticated` sobre tablas estructurales y de auditoría.
- **B-02**: Suplantación de OP (`is_op`, `author_hash`), reasignación de autoría (`user_id`) y alteración arbitraria de métricas (`hot_score`, `likes`) mediante `UPDATE` e `INSERT`.
- **B-03**: Fuga de privacidad horizontal de `user_id` en `student_groups` y `marketplace_items`.

Adicionalmente, se auditaron las advertencias de retención en `seccion_reviews`, las restricciones de edición en `profiles`, la suite completa de pruebas y el impacto de los cambios sobre el flujo funcional normal.

### Balance de la Re-Auditoría
1. **Bloqueantes Previos Cerrados Exitosamente:**
   - **B-01 CERRADO:** El privilegio `TRUNCATE` fue revocado en su totalidad en el esquema `public` para roles `anon` y `authenticated`. Todo intento de vaciado masivo es repelido por el motor de PostgreSQL con error `42501 (permission denied)`.
   - **B-02 CERRADO:** Se restringieron los permisos de `UPDATE` a nivel de columna y se robusteció el trigger `enforce_content_immutability_and_legal_hold()` junto al trigger preventivo de inserción `enforce_system_defaults_on_insert()`. Ni el autor ni moderadores pueden manipular métricas, hashes o identidad. Los autores sí pueden editar su propio contenido legítimamente.
   - **B-03 CERRADO:** El privilegio `SELECT (user_id)` fue revocado en `student_groups` y `marketplace_items`. Las vistas seguras `safe_student_groups` y `safe_marketplace_items` no proyectan `user_id` y proveen la bandera computada `is_mine`. Los servicios y modelos de Flutter no leen ni parsean `user_id` en flujos públicos.
   - **Retención y Perfiles Endurecidos:** `seccion_reviews` cuenta con política restrictiva y revocación total de `DELETE`, y `profiles` limita `UPDATE` únicamente a `full_name`, `carrera` y términos.

2. **Nuevo Bloqueante Detectado (Regresión Funcional Crítica):**
   - **B-04 [BLOQUEANTE]: Regresión en creación de grupos estudiantiles (`student_groups`).**  
     Al revocar el privilegio `SELECT (user_id)` en `public.student_groups` para mitigar B-03, el trigger preexistente `trg_check_whatsapp_groups_limit` —que invoca la función `public.check_whatsapp_groups_limit()` definida **sin** `SECURITY DEFINER`— ejecuta `SELECT COUNT(*) FROM public.student_groups WHERE user_id = v_target_user`. Dado que el rol `authenticated` ya no tiene permiso de lectura sobre `user_id`, **cualquier intento de un estudiante común de publicar un grupo de estudio falla inmediatamente con error `42501 (permission denied for table student_groups)`**, rompiendo una funcionalidad troncal del sistema.

Por esta razón, el pase a QA debe ser **RECHAZADO** hasta que el Agente 1 ajuste la función con `SECURITY DEFINER`.

---

## 2. Metodología y Comandos Ejecutados

Se ejecutaron pruebas automatizadas y dinámicas en el entorno local de desarrollo:

| Comando | Resultado | Diagnóstico |
| :--- | :---: | :--- |
| `supabase db reset` | **OK (Exit 0)** | Esquema recreado, migraciones aplicadas secuencialmente hasta `20261110000300_audit_blockers_hardening.sql` y seed completado sin errores. |
| `deno check supabase/functions/moderation-worker/index.ts` | **OK (Exit 0)** | Edge Function de moderación compila limpiamente sin discrepancias de tipos. |
| `supabase test db` | **FAIL (Exit 1)** | **Deuda de pruebas heredada**: 9 archivos legacy fallan por el rechazo legítimo de alias no curados (Art. 12) y revocación de `DELETE` físico (Art. 20/21). `profiles_rls_test.sql` pasa al 100%. |
| `cd comunidad_universitaria && flutter analyze` | **WARN (Exit 1)** | 1 warning de variable local no utilizada (`appBar` en `profile_screen.dart:330`) y 1 info de estilo en `popular_servers_sidebar.dart:124`. |
| `cd comunidad_universitaria && flutter test` | **FAIL (Exit 1)** | 289 pruebas unitarias exitosas, 6 fallos atribuibles a **deuda de pruebas** (adaptación a vistas seguras, soft-delete y mock keys). |

---

## 3. Evidencia Adversarial de Bloqueantes Corregidos

### Verificación B-01: Revocación Absoluta de TRUNCATE

Se verificó el privilegio `TRUNCATE` en el catálogo de PostgreSQL para todos los roles no administrativos:

```sql
SELECT 
    relname AS table_name,
    has_table_privilege('authenticated', c.oid, 'TRUNCATE') AS auth_can_truncate,
    has_table_privilege('anon', c.oid, 'TRUNCATE') AS anon_can_truncate,
    has_table_privilege('authenticated', c.oid, 'TRIGGER') AS auth_can_trigger,
    has_table_privilege('authenticated', c.oid, 'REFERENCES') AS auth_can_references
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND relname IN (
    'moderation_audit_log', 'user_roles', 'profiles', 'moderation_jobs', 'alias_nouns',
    'seccion_reviews', 'posts', 'comments', 'student_groups', 'marketplace_items'
  )
ORDER BY relname;
```

**Salida Obtenida:**
```
      table_name      | auth_can_truncate | anon_can_truncate | auth_can_trigger | auth_can_references 
----------------------+-------------------+-------------------+------------------+---------------------
 alias_nouns          | f                 | f                 | f                | f
 comments             | f                 | f                 | f                | f
 marketplace_items    | f                 | f                 | f                | f
 moderation_audit_log | f                 | f                 | f                | f
 moderation_jobs      | f                 | f                 | f                | f
 posts                | f                 | f                 | f                | f
 profiles             | f                 | f                 | f                | f
 seccion_reviews      | f                 | f                 | f                | f
 student_groups       | f                 | f                 | f                | f
 user_roles           | f                 | f                 | f                | f
(10 filas)
```

**Comprobación Global:** Se consultó si alguna tabla en `public` concede `TRUNCATE` a `authenticated`:
```sql
SELECT relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r' AND has_table_privilege('authenticated', c.oid, 'TRUNCATE') = true;
-- Resultado: 0 filas.
```

**PoC Adversarial:** Intento de sabotaje y destrucción de bitácora legal por un usuario autenticado:
```sql
SET ROLE authenticated;
TRUNCATE TABLE public.moderation_audit_log;
```
**Resultado:**
```
ERROR: permission denied for table moderation_audit_log
```
> **Conclusión B-01:** **CERRADO Y VERIFICADO.** No existe riesgo de sabotaje masivo vía TRUNCATE.

---

### Verificación B-02: Spoofing de OP y Manipulación de Métricas

#### 1. Intento de autor de alterar métricas (`hot_score = 999999`):
```sql
-- Ejecutado como autor del post
UPDATE public.posts SET hot_score = 999999 WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0001';
```
**Resultado:**
```
ERROR: permission denied for table posts
SUGERENCIA: Grant the required privileges to the current role with: GRANT UPDATE ON public.posts TO authenticated;
```
*Bloqueado a nivel de columna (privilegio revocado).*

#### 2. Intento de reasignar autoría (`user_id = '<otro>'`):
```sql
-- Ejecutado como autor del post
UPDATE public.posts SET user_id = '22222222-2222-2222-2222-222222222222' WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0001';
```
**Resultado:**
```
ERROR: permission denied for table posts
```
*Bloqueado por privilegios de columna y respaldado por trigger inmutable.*

#### 3. Actualización legítima de contenido por el autor:
```sql
-- Ejecutado como autor del post
UPDATE public.posts SET content = 'Contenido Actualizado por el Autor' WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0001';
```
**Resultado:**
```
NOTICE: Contenido actualizado exitosamente: Contenido Actualizado por el Autor
DO
```
*Funciona correctamente sin bloqueos espurios.*

#### 4. Operaciones de Moderador vs. Contenido Ajeno:
- **Moderador actualiza estado de moderación:**
  ```sql
  -- Autenticado como moderador
  UPDATE public.posts SET moderation_status = 1 WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0001';
  ```
  **Resultado:** `NOTICE: Moderador actualizó moderation_status a 1 con éxito.` (OK).
- **Moderador intenta editar contenido de publicación ajena:**
  ```sql
  -- Autenticado como moderador
  UPDATE public.posts SET content = 'Contenido alterado por moderador' WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0001';
  ```
  **Resultado:**
  ```
  ERROR: Only the original author can edit content
  CONTEXTO: PL/pgSQL function public.enforce_content_immutability_and_legal_hold() line 183 at RAISE
  ```
  *Puerto seguro del Art. 3 blindado.*

#### 5. Suplantación de OP por comentarista (`is_op = true`, `author_hash = 'x'`):
```sql
-- Ejecutado como usuario comentarista (no OP)
UPDATE public.comments SET is_op = true WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccc0002';
UPDATE public.comments SET author_hash = 'x' WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccc0002';
```
**Resultado:**
```
ERROR: permission denied for table comments
SUGERENCIA: Grant the required privileges to the current role with: GRANT UPDATE ON public.comments TO authenticated;
```
*Columnas del sistema protegidas contra modificación.*

#### 6. Regresión en Comentarios: Edición legítima de `content`:
```sql
-- Ejecutado por el autor del comentario
UPDATE public.comments SET content = 'Comentario Editado Legítimamente' WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccc0002';
```
**Resultado:**
```
NOTICE: Comentario editado con éxito: Comentario Editado Legítimamente
DO
```
*Verificado: El guard en `enforce_content_immutability_and_legal_hold()` únicamente evalúa columnas existentes (`content`, `gif_url`, `parent_id`).*

#### 7. Inserción maliciosa forzando valores de métricas e identidad:
Se ejecutó un `INSERT` intentando registrar:
- En `posts`: `likes=999`, `hot_score=999999`, `is_pinned=true`, `moderation_status=2`, `is_legal_hold=true`, `created_at='2000-01-01'`.
- En `comments`: `likes_count=999`, `is_op=true`, `moderation_status=2`, `created_at='2000-01-01'`.
- En `marketplace_items`: `upvotes=999`, `reported_count=999`, `is_sponsored=true`.
- En `seccion_reviews`: `upvotes=999`, `created_at='2000-01-01'`.

**Salida Obtenida:**
```
NOTICE: Post forzado a: likes=0, hot_score=0.328603, is_pinned=f, mod_status=0, is_legal_hold=f, created_at=2026-11-10 22:34:35.559135+00
NOTICE: Comment Atacante B forzado a: likes_count=0, is_op=f, mod_status=0, is_legal_hold=f, created_at=2026-11-10 22:34:43.355234+00
NOTICE: Marketplace forzado a: upvotes=0, reported=0, mod_status=0, is_legal_hold=f, is_sponsored=f, created_at=2026-11-10 22:35:19.872352+00
NOTICE: Review forzado a: upvotes=0, created_at=2026-11-10 22:35:26.090052+00
```
> **Conclusión B-02:** **CERRADO Y VERIFICADO.** Los triggers `trg_aa_system_defaults_*` se disparan de primeros en orden alfabético y restablecen valores seguros incondicionalmente.

---

### Verificación B-03: Fuga de Privacidad Horizontal de `user_id`

#### 1. Consulta directa a tablas base por roles `anon` y `authenticated`:
```sql
DO $$
BEGIN
    SET ROLE anon;
    PERFORM user_id FROM public.student_groups LIMIT 1;
END;
$$;
```
**Salida Obtenida:**
```
ERROR: permission denied for table student_groups
SUGERENCIA: Grant the required privileges to the current role with: GRANT SELECT ON public.student_groups TO anon;
```
*(Idéntico error obtenido para `marketplace_items` y para el rol `authenticated`).*

#### 2. Consulta a Vistas Seguras (`safe_student_groups` y `safe_marketplace_items`):
```sql
SELECT column_name FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name IN ('safe_student_groups', 'safe_marketplace_items')
  AND column_name = 'user_id';
-- Resultado: 0 filas.

SELECT table_name, column_name FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name IN ('safe_student_groups', 'safe_marketplace_items')
  AND column_name = 'is_mine';
-- Resultado:
-- safe_marketplace_items | is_mine
-- safe_student_groups    | is_mine
```

#### 3. Auditoría de Código Frontend (Flutter):
- [`GroupsService.fetchGroups`](file:///home/carlos/Escritorio/Comunidad_USAC/comunidad_universitaria/lib/core/services/groups_service.dart#L81): Consume `safe_student_groups` con `.select('*')`.
- [`GroupsService.createGroup`](file:///home/carlos/Escritorio/Comunidad_USAC/comunidad_universitaria/lib/core/services/groups_service.dart#L292): Proyecta una lista explícita de columnas `explicitColumns` que excluye terminantemente `user_id`.
- [`MarketplaceService.fetchListings`](file:///home/carlos/Escritorio/Comunidad_USAC/comunidad_universitaria/lib/core/services/marketplace_service.dart#L85): Consume `safe_marketplace_items`.
- [`MarketplaceService.createListing`](file:///home/carlos/Escritorio/Comunidad_USAC/comunidad_universitaria/lib/core/services/marketplace_service.dart#L306): Proyecta columnas explícitas sin `user_id`.
- [`ProfileService.fetchUserGroups`](file:///home/carlos/Escritorio/Comunidad_USAC/comunidad_universitaria/lib/core/services/profile_service.dart#L161) y [`fetchUserMarketplaceItems`](file:///home/carlos/Escritorio/Comunidad_USAC/comunidad_universitaria/lib/core/services/profile_service.dart#L188): Consultan las vistas seguras con el filtro `.eq('is_mine', true)`.
- Modelos [`WhatsAppGroup`](file:///home/carlos/Escritorio/Comunidad_USAC/comunidad_universitaria/lib/core/models/whatsapp_group.dart#L139) y [`MarketplaceItem`](file:///home/carlos/Escritorio/Comunidad_USAC/comunidad_universitaria/lib/core/models/marketplace_item.dart#L287): Forzados a `userId: null` y deserializan `isMine: map['is_mine'] == true`.
> **Conclusión B-03:** **CERRADO Y VERIFICADO.** La desanonimización horizontal mediante scraping de `user_id` está totalmente neutralizada.

---

### Verificación de Retención y Perfiles

1. **Retención en `seccion_reviews`:**
   - La tabla ahora cuenta con `deleted_at timestamptz NULL` e `is_legal_hold boolean NOT NULL DEFAULT false`.
   - Se ejecutó `REVOKE DELETE ON public.seccion_reviews FROM anon, authenticated;`.
   - Se añadió la política restrictiva `deny_all_delete_seccion_reviews` (`USING (false)`).
   - Intento de `DELETE FROM public.seccion_reviews`: Arroja `ERROR: permission denied for table seccion_reviews`.
   - La vista `safe_seccion_reviews` aplica `WHERE deleted_at IS NULL` y `security_invoker = true`.
2. **Inmutabilidad de atributos protegidos en `profiles`:**
   - Permiso `UPDATE` otorgado a `authenticated` exclusivamente en: `full_name`, `carrera`, `accepted_terms_version`, `accepted_terms_at`.
   - Intentos de actualizar `is_verified`, `reputation_score`, `cui_hash` o `carne_hash`: Rechazados con error `42501 (insufficient_privilege)`.
   - Actualización de `full_name` y `carrera`: Exitosa.

---

## 4. Nuevos Hallazgos de Seguridad, Estabilidad y Cumplimiento

### [BLOQUEANTE]

#### HALLAZGO B-04: Regresión en creación de grupos estudiantiles (`student_groups`) por falta de `SECURITY DEFINER` en `check_whatsapp_groups_limit()`
- **Ubicación:**
  - Definición de función: `public.check_whatsapp_groups_limit()` ([`supabase/migrations/20261001000000_adopt_remote_schema.sql`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261001000000_adopt_remote_schema.sql#L1328-L1347))
  - Trigger asociado: `trg_check_whatsapp_groups_limit` BEFORE INSERT ON `public.student_groups`
  - Migración causante: [`supabase/migrations/20261110000300_audit_blockers_hardening.sql#L672-L678`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261110000300_audit_blockers_hardening.sql#L672-L678)
- **Descripción del Problema:**  
  Para resolver la fuga B-03, la migración `20261110000300` revocó el privilegio `SELECT` general en `public.student_groups` y concedió `GRANT SELECT (...)` exclusivamente sobre las columnas públicas, excluyendo deliberadamente a `user_id`.  
  Sin embargo, la función de trigger `check_whatsapp_groups_limit()`, encargada de validar que un estudiante no exceda el límite de 5 grupos, está declarada sin `SECURITY DEFINER` (actúa como `SECURITY INVOKER` con privilegios del llamante):
  ```sql
  CREATE OR REPLACE FUNCTION public.check_whatsapp_groups_limit()
  RETURNS trigger LANGUAGE plpgsql AS $$
  ...
      SELECT COUNT(*) INTO v_count
      FROM public.student_groups
      WHERE user_id = v_target_user;
  ...
  ```
  Al ser invocada durante un `INSERT` por un usuario autenticado normal (un estudiante no moderador), PostgreSQL evalúa la consulta interna con los privilegios del estudiante. Al no tener concedido `SELECT (user_id)` en la tabla `public.student_groups`, la transacción se aborta de manera fulminante.
- **Evidencia Adversarial (PoC de Regresión):**
  ```sql
  DO $$
  DECLARE
      v_user uuid := '44444444-4444-4444-4444-444444444444';
  BEGIN
      PERFORM tests.authenticate_as(v_user);

      -- Intento de inserción normal de grupo estudiantil:
      INSERT INTO public.student_groups (
          id, user_id, title, carrera, curso, section, link, description, author_alias
      ) VALUES (
          gen_random_uuid(), v_user, 'Grupo Calculo 1', 'sistemas', 'Calculo 1', 'A', 
          'https://chat.whatsapp.com/test1234', 'Grupo estudio', 'Compilador Desvelado'
      );
  END;
  $$;
  ```
  **Salida Obtenida:**
  ```
  ERROR:  permission denied for table student_groups
  SUGERENCIA:  Grant the required privileges to the current role with: GRANT SELECT ON public.student_groups TO authenticated;
  CONTEXTO:  SQL statement "SELECT COUNT(*) FROM public.student_groups WHERE user_id = v_target_user"
  PL/pgSQL function check_whatsapp_groups_limit() line 10 at SQL statement
  ```
- **Impacto:**  
  **Rotura total del flujo de inserción de grupos.** Ningún estudiante regular de la universidad puede compartir enlaces a grupos de WhatsApp/Telegram en la plataforma.
- **Corrección Obligatoria (Agente 1):**  
  Añadir a la migración de hardening la redefinición de `check_whatsapp_groups_limit()` con `SECURITY DEFINER SET search_path = ''`:
  ```sql
  CREATE OR REPLACE FUNCTION public.check_whatsapp_groups_limit()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = ''
  AS $$
  DECLARE
      v_count integer;
      v_target_user uuid := COALESCE(auth.uid(), NEW.user_id);
  BEGIN
      IF public.is_pemtree_admin(auth.uid()) OR public.is_pemtree_moderator(auth.uid()) THEN
          RETURN NEW;
      END IF;

      SELECT COUNT(*) INTO v_count
      FROM public.student_groups
      WHERE user_id = v_target_user;

      IF v_count >= 5 THEN
          RAISE EXCEPTION 'Límite de 5 grupos alcanzado: Un usuario normal no puede publicar más de 5 grupos en la comunidad. Si necesitas publicar más, comunícate con un administrador o moderador.';
      END IF;

      RETURN NEW;
  END;
  $$;
  ```

---

### [ADVERTENCIAS]

1. **Inoperancia de la vista legada `public.whatsapp_groups`:**  
   La vista `public.whatsapp_groups` fue creada con `security_invoker = true` proyectando `user_id FROM public.student_groups`. Al revocarse el privilegio `SELECT (user_id)` a nivel de tabla base, cualquier consulta a la vista por parte de roles `anon` o `authenticated` (`SELECT * FROM public.whatsapp_groups`) falla con `42501 (permission denied for table student_groups)`. Aunque esto protege la privacidad (falla cerrada), la vista ha quedado obsoleta e inservible. Se recomienda eliminarla o apuntarla a `safe_student_groups`.
2. **Variable no utilizada en `profile_screen.dart` (`flutter analyze`):**  
   [`comunidad_universitaria/lib/features/profile/screens/profile_screen.dart:330:11`](file:///home/carlos/Escritorio/Comunidad_USAC/comunidad_universitaria/lib/features/profile/screens/profile_screen.dart#L330): La variable `appBar` sigue declarada sin uso, arrojando advertencia en el análisis estático.

---

### [DEUDA DE PRUEBAS] (Legacy Test Debt a Ajustar en QA)

1. **Suites de Pruebas pgTAP (`supabase/tests/*.sql`):**
   - 9 archivos fallan debido a contratos anteriores:
     - Intentos de inserción con nombres no curados (`'Visitante'`, `'Alias A'`) rechazados por `check_author_alias_validity()` (Art. 12).
     - Intentos de `DELETE` físico revocados por cumplimiento de Art. 20/21.
2. **Pruebas Unitarias de Flutter (`comunidad_universitaria/test/`):**
   - 6 pruebas fallan por aserciones obsoletas (mocks interceptando endpoints viejos o esperando errores en soft-delete).

---

## 5. Verificación de Regresiones Funcionales y Flujo Normal

| Flujo Funcional Evaluado | Estado | Evidencia y Comportamiento Observado |
| :--- | :---: | :--- |
| **Insertar Post (Usuario Normal)** | **OK** | Inserción exitosa con alias del catálogo curado (`Compilador Desvelado`). |
| **Insertar Comentario (Usuario Normal)** | **OK** | Inserción exitosa enlazada al hilo del post. |
| **Insertar Marketplace Item (Usuario Normal)** | **OK** | Inserción exitosa en categoría válida (`otros_articulos`). |
| **Insertar Grupo Estudiantil (Usuario Normal)** | **FALLO (Bloqueante)** | **Rechazado con error 42501** por el trigger `check_whatsapp_groups_limit()` (Hallazgo B-04). |
| **Soft Delete por el Autor** | **OK** | Actualización de `deleted_at = now()` permitida en `posts`, `student_groups` y `marketplace_items`. |
| **Protección de Legal Hold en Soft Delete** | **OK** | Modificación de `deleted_at` bloqueada cuando `is_legal_hold = true` (`Content under legal hold cannot be deleted or restored (Art. 3)`). |
| **Moderador Actualiza Estado de Moderación** | **OK** | Moderador puede fijar `moderation_status`, `moderation_reason`, `is_legal_hold` y `is_pinned`. |
| **Auto-cuarentena Comunitaria (3 Reportes de Riesgo)** | **OK** | Al acumular 3 reportes únicos de riesgo, se asigna automáticamente `moderation_status = 1`, `is_legal_hold = true`, se encola trabajo con `priority = 10` y se asienta bitácora en `moderation_audit_log` con `is_automated = true`. |
| **Upvote / Downvote en Reseñas** | **OK** | Inserción y eliminación en `seccion_review_upvotes` actualiza el contador denormalizado de forma consistente (0 -> 1 -> 0). |

---

## 6. Tabla de Cumplimiento por Marco Legal

| Marco Normativo | Control Requerido | Estado | Detalle y Hallazgos V2 |
| :--- | :--- | :---: | :--- |
| **Art. 3** | Inmutabilidad de contenido de terceros y puerto seguro | **CUMPLIDO** | Moderadores no pueden alterar contenido ajeno (`Only the original author can edit content`). Comentaristas no pueden modificar `is_op` ni `author_hash`. B-02 cerrado. |
| **Art. 12** | Anonimato obligatorio y catálogo curado de seudónimos | **CUMPLIDO** | Validación estricta en inserción y actualización; spoofing bloqueado por inmutabilidad y permisos de columna. |
| **Art. 13 / 16** | Protección contra ciberdelitos y sabotaje | **CUMPLIDO** | Revocación total de `TRUNCATE`, `REFERENCES` y `TRIGGER` en todo el esquema público. B-01 cerrado. |
| **Art. 14** | Moderación comunitaria y cuarentena por reportes | **CUMPLIDO** | Auto-cuarentena verificada en posts y grupos con prioridad 10 y bitácora automatizada. |
| **Art. 20 / 21** | Retención de evidencia por 90 días | **CUMPLIDO** | `seccion_reviews` con `DELETE` físico bloqueado. Contenido bajo retención legal no puede ser ocultado ni borrado. B-01 y advertencia cerrados. |
| **Privacidad Horizontal** | Blindaje contra correlación de `user_id` | **CUMPLIDO** | Tablas `student_groups` y `marketplace_items` con `user_id` restringido; vistas seguras operativas sin identificadores personales. B-03 cerrado. |
| **Estabilidad Funcional** | Operación continua de funciones para estudiantes | **NO CONFORME** | La remediación introdujo una regresión crítica que impide publicar grupos de WhatsApp/Telegram a usuarios no moderadores (Hallazgo B-04). |

---

## 7. Veredicto Final

# **RECHAZADO — DEVOLVER A AGENTE 1 (DB)**

### Justificación:
Aunque los tres bloqueantes de seguridad y privacidad (**B-01**, **B-02**, **B-03**) han sido satisfactoriamente resueltos y no existe vía de spoofing, fuga de identidad ni destrucción de evidencia:
1. **Regresión Funcional Crítica (Hallazgo B-04):** La corrección de permisos rompió la función de trigger `check_whatsapp_groups_limit()`, impidiendo que los estudiantes publiquen grupos de estudio en `public.student_groups`.

### Pasos Requeridos para Aprobación Definitiva:
1. **Agente 1:** Agregar `SECURITY DEFINER SET search_path = ''` a `public.check_whatsapp_groups_limit()` en una nueva migración (o en la migración de hardening) y ejecutar `supabase db reset`.
2. Una vez corregido, se verificará la inserción de `student_groups` por un usuario regular para emitir el veredicto de `APROBADO PARA QA`.
