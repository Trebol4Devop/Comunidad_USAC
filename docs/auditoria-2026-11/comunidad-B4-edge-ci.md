# Auditoría Edge Function de moderación, CI/CD, scripts y secretos — Comunidad_USAC

## Resumen
Se auditó la Edge Function de moderación (`moderation-worker`), los flujos de CI/CD en GitHub Actions, los scripts operativos y el manejo de credenciales/secretos en el repositorio `Comunidad_USAC`, contrastándolos con el volcado real de la base de datos (`EVIDENCIA-BD.md`). Se detectó un despliegue directo a producción en Cloudflare Pages sin validación previa de pruebas, una divergencia semántica crítica en `moderation_status` entre el worker (asume 0=aprobado y 1=revisión) y la base de datos/panel (0=pendiente, 1=aprobado, 3=revisión), una falla lógica en `ocultar_contenido_moderado` que permite a cualquier usuario autenticado ocultar contenido con autor nulo, y sobreescritura ciega por condición de carrera frente a moderadores humanos. No se detectaron credenciales productivas ni tokens de Cloudflare/R2 filtrados en Git.

---

## Respuestas Concretas a Preguntas de la Auditoría

### 1. Obtención de la `service_role` key por la Edge Function
- **Mecanismo de obtención**:
  - La función obtiene la clave en tiempo de ejecución a través de variables de entorno mediante `Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")` en [`supabase/functions/moderation-worker/index.ts:533`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/functions/moderation-worker/index.ts#L533).
  - Asimismo obtiene la URL del backend mediante `Deno.env.get("SUPABASE_URL")` ([`index.ts:532`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/functions/moderation-worker/index.ts#L532)).
- **¿Está en el repo, en `wrangler.toml`, en `.wrangler/` o en variables de entorno?**:
  - **En el repositorio**: NO está hardcodeada ninguna clave `service_role` productiva en los archivos versionados de Git.
  - **En `wrangler.toml`**: NO existe referencia a Supabase ni a claves; únicamente contiene metadatos de Cloudflare Pages (`name = "zanate"`, `pages_build_output_dir`, `compatibility_date`) ([`wrangler.toml:1-6`](file:///home/carlos/Escritorio/Comunidad_USAC/wrangler.toml#L1-L6)).
  - **En `.wrangler/`**: NO hay claves secretas. Solo contiene identificadores públicos de cuenta (`account_id: 51f5709e5722058f9415fece11735834`) y proyecto (`zanate`) en archivos locales de caché que están ignorados por `.gitignore` ([`.gitignore:11`](file:///home/carlos/Escritorio/Comunidad_USAC/.gitignore#L11)).
  - **En variables de entorno**: SÍ. En producción, Supabase Edge Runtime inyecta automáticamente `SUPABASE_SERVICE_ROLE_KEY` o se suministra mediante el gestor de secretos (`supabase secrets set`). En el entorno de desarrollo local con Docker, existe una clave demo estándar (`iss: "supabase-demo"`) ubicada en `supabase/.temp/start-secrets/.../docker.env`, la cual está correctamente ignorada por Git mediante [`supabase/.gitignore:3`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/.gitignore#L3).

### 2. Verificación de identidad e invocación de `moderation_jobs`
- **¿Verifica quién la invoca antes de moderar o tocar `moderation_jobs`?**:
  - SÍ. La verificación se realiza al inicio del manejador HTTP en [`supabase/functions/moderation-worker/index.ts:513-543`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/functions/moderation-worker/index.ts#L513-L543), **antes** de instanciar las llamadas a `claim_moderation_jobs` o interactuar con `moderation_jobs`.
- **¿Valida secreto compartido, firma o confía en la petición?**:
  - Valida un **secreto compartido estático**. Comprueba si el encabezado `Authorization: Bearer <token>` o `x-worker-secret: <token>` coincide con la variable de entorno `WORKER_SECRET` ([`index.ts:535-536`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/functions/moderation-worker/index.ts#L535-L536)), o bien si el `bearerToken` coincide con `SUPABASE_SERVICE_ROLE_KEY` ([`index.ts:537`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/functions/moderation-worker/index.ts#L537)).
  - Opera bajo el principio de **fallo cerrado (fail-closed)**: si `WORKER_SECRET` no está configurado en las variables de entorno, la función retorna inmediatamente HTTP 500 (`"WORKER_SECRET is not configured; worker disabled"`) ([`index.ts:524-529`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/functions/moderation-worker/index.ts#L524-L529)).
  - Si el token enviado no coincide, retorna HTTP 401 (`"Unauthorized"`) ([`index.ts:538-543`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/functions/moderation-worker/index.ts#L538-L543)).
  - **No valida firma criptográfica**: No utiliza HMAC con sellos de tiempo (timestamp) ni protección contra reenvío (anti-replay). Depende enteramente del secreto compartido.
- **¿Cómo se autentica el cron/worker?**:
  - Cualquier invocador automatizado (cron externo, Cloudflare Worker o webhook) debe proporcionar el encabezado `Authorization: Bearer <WORKER_SECRET>` o `x-worker-secret: <WORKER_SECRET>`.
  - **Ausencia de cron programado**: No existe ninguna tarea programada en `pg_cron` ni workflow de GitHub Actions que invoque periódicamente este endpoint. Los triggers de base de datos encolan tareas en `moderation_jobs` ([`20261001000000_adopt_remote_schema.sql:2664`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261001000000_adopt_remote_schema.sql#L2664)), pero la cola permanece estancada a menos que un servicio externo invoque la función.

### 3. CORS en la Edge Function
- **¿`Access-Control-Allow-Origin: *` con credenciales?**:
  - En la respuesta preflight `OPTIONS` ([`supabase/functions/moderation-worker/index.ts:504-510`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/functions/moderation-worker/index.ts#L504-L510)), se devuelve:
    - `"Access-Control-Allow-Origin": "*"`
    - `"Access-Control-Allow-Headers": "authorization, x-worker-secret, content-type"`
  - **NO** incluye el encabezado `Access-Control-Allow-Credentials: true`. (Por estándar de navegadores, el comodín `*` es incompatible con credenciales explícitas; al omitirse, las credenciales no son permitidas por el navegador).
- **¿Acepta cualquier origen?**:
  - El preflight `OPTIONS` acepta cualquier origen (`*`).
  - Sin embargo, las respuestas a peticiones reales (`POST`, `GET`, errores 401/500 y respuesta final 200 en [`index.ts:619-622`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/functions/moderation-worker/index.ts#L619-L622)) **no devuelven encabezados CORS**, limitándose a `Content-Type: application/json`.
  - Si un navegador web intentase consumir el endpoint vía AJAX/fetch, el preflight pasaría pero la respuesta real sería bloqueada por el navegador por falta de `Access-Control-Allow-Origin`. No obstante, al tratarse de un worker de backend con privilegios administrativos `service_role`, exponer `Access-Control-Allow-Origin: *` en preflight es un antipatrón arquitectónico, ya que este endpoint nunca debería ser llamado desde navegadores de clientes.

### 4. Inyección SQL en RPCs y Filtros
- **¿La Edge Function construye SQL por concatenación al llamar RPCs o filtros?**:
  - NO. En [`supabase/functions/moderation-worker/index.ts`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/functions/moderation-worker/index.ts), todas las operaciones de base de datos utilizan el cliente oficial de PostgREST (`supabase.from(job.entity_table).select(...)`, `.update(...)`, `.eq(...)`) y llamadas RPC parametrizadas (`supabase.rpc("claim_moderation_jobs", { p_worker_id, p_limit })`). No hay ensamblado de sentencias SQL en cadenas de texto en TypeScript.
- **Revisión de `apply_moderation_batch`**:
  - Definida en [`supabase/migrations/20261001000000_adopt_remote_schema.sql:960-1121`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261001000000_adopt_remote_schema.sql#L960-L1121). No utiliza SQL dinámico ni `EXECUTE`. Recorre el array JSON con `jsonb_array_elements` y ejecuta sentencias `UPDATE` estáticas ramificadas con `if v_table = 'posts' then ... elsif v_table = 'comments' then ...`. Tiene `SET search_path TO ''`.
- **Revisión de `enqueue_moderation`**:
  - Definida en [`supabase/migrations/20261001000000_adopt_remote_schema.sql:1426-1451`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261001000000_adopt_remote_schema.sql#L1426-L1451). Ejecuta un `INSERT INTO public.moderation_jobs ... ON CONFLICT ... DO UPDATE` puramente estático y parametrizado con `SET search_path TO ''`.
- **Revisión de `claim_moderation_job` / `claim_moderation_jobs`**:
  - Definidas en [`20261001000000_adopt_remote_schema.sql:1269`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261001000000_adopt_remote_schema.sql#L1269) y [`20261110000100_moderation_and_reports_hardening.sql:515-557`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261110000100_moderation_and_reports_hardening.sql#L515-L557). Ejecutan sentencias `UPDATE` y consultas CTE con `FOR UPDATE SKIP LOCKED` estáticas con parámetros fijados. No existe concatenación de cadenas SQL.

### 5. Validación del identificador `p_tabla` (entity_table)
- **¿Qué pasa si `p_tabla` viene del cliente? ¿La BD valida el identificador en `ocultar/restaurar/eliminar_contenido_moderado`?**:
  - SÍ, la base de datos valida estrictamente el identificador mediante listas blancas fijas en sentencias `IF / ELSIF / ELSE`:
    - En [`ocultar_contenido_moderado`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261001000000_adopt_remote_schema.sql#L1888-L1898): valida `'whatsapp_groups'`, `'posts'`, `'comments'`, `'marketplace_items'`. Cualquier otro valor dispara `RAISE EXCEPTION 'Tabla (%) no válida para moderación.', p_tabla;`.
    - En [`restaurar_contenido_moderado`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261001000000_adopt_remote_schema.sql#L2511-L2521): valida idéntica lista blanca; si no coincide, arroja excepción.
    - En [`eliminar_contenido_moderado`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261001000000_adopt_remote_schema.sql#L1353-L1363): valida idéntica lista blanca; si no coincide, arroja excepción.
  - No hay posibilidad de inyección de identificadores SQL ni acceso a tablas arbitrarias mediante `p_tabla`.
  - **Inconsistencia funcional detectada**: La tabla física es `student_groups` (`EVIDENCIA-BD.md:38`), mientras que `whatsapp_groups` es una vista (`EVIDENCIA-BD.md:54`). Si un cliente envía el nombre de tabla `student_groups`, las tres funciones lo rechazan como tabla inválida.
- **¿Y en `apply_moderation_batch`?**:
  - SÍ. En [`20261001000000_adopt_remote_schema.sql:1007-1102`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261001000000_adopt_remote_schema.sql#L1007-L1102), valida mediante `IF / ELSIF` contra `'posts'`, `'comments'`, `'student_groups'`, `'marketplace_items'`, `'whatsapp_groups'`, `'user_reports'`, `'whatsapp_group_reports'`. Si `v_table` no coincide con ninguna, entra a la rama `else`, invoca `fail_moderation_job(v_job_id, 'Tabla desconocida: ' || ...)` y salta el registro mediante `continue;`.

### 6. Seguridad en Workflows de GitHub Actions
- **¿Algún secret se imprime en logs?**:
  - NO. En [`.github/workflows/deploy-cloudflare-pages.yml`](file:///home/carlos/Escritorio/Comunidad_USAC/.github/workflows/deploy-cloudflare-pages.yml) y [`.github/workflows/flutter-tests.yml`](file:///home/carlos/Escritorio/Comunidad_USAC/.github/workflows/flutter-tests.yml), los secretos (`CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `SUPABASE_ANON_KEY`, `SUPABASE_URL`) son inyectados como variables de entorno o parámetros directos a acciones oficiales (`cloudflare/wrangler-action@v4`), las cuales son enmascaradas por GitHub Actions runner (`***`). No hay instrucciones `echo` ni `set -x` volcando secretos.
- **¿`pull_request_target` con checkout del PR?**:
  - NO. Ninguno de los dos workflows utiliza `pull_request_target`. En `flutter-tests.yml:8-11` se utiliza el evento seguro `pull_request`, el cual se ejecuta en el contexto del fork sin acceso a secretos del repositorio base.
- **¿Permisos del `GITHUB_TOKEN` demasiado amplios?**:
  - En `deploy-cloudflare-pages.yml:16-18` los permisos están adecuadamente acotados (`contents: read`, `deployments: write`).
  - En `flutter-tests.yml:1-163` **NO hay bloque `permissions:` declarado**. Hereda los privilegios por defecto del repositorio (que en organizaciones GitHub suele ser lectura/escritura completa para `GITHUB_TOKEN`).
- **¿Se despliega a producción sin tests?**:
  - **SÍ (HALLAZGO CRÍTICO)**. El workflow [`deploy-cloudflare-pages.yml`](file:///home/carlos/Escritorio/Comunidad_USAC/.github/workflows/deploy-cloudflare-pages.yml) se ejecuta ante cualquier `push` a `main` o `workflow_dispatch`. Realiza checkout, instala Flutter, compila la versión web (`flutter build web --release`) y la despliega directamente a Cloudflare Pages producción (`https://zanate.pages.dev`). **No ejecuta `flutter test` ni `flutter analyze`**, y no tiene dependencia (`needs` o `workflow_run`) sobre `flutter-tests.yml`. Si un commit rompe las pruebas, `deploy-cloudflare-pages.yml` compila y publica la versión rota en producción de forma simultánea.

### 7. Configuración de `scripts/configure-auth.sh`
- **¿Qué configura en Supabase Auth?**:
  - En [`scripts/configure-auth.sh:24-30`](file:///home/carlos/Escritorio/Comunidad_USAC/scripts/configure-auth.sh#L24-L30), envía un `PATCH` a `https://api.supabase.com/v1/projects/${REF}/config/auth` fijando exclusivamente:
    1. `"site_url": "https://zanate.pages.dev"`
    2. `"uri_allow_list": "https://zanate.pages.dev/**,https://*.zanate.pages.dev/**,https://pemtree.netlify.app/**,https://*--pemtree.netlify.app/**,http://localhost:3000/**,http://localhost:5173/**,http://127.0.0.1:3000/**,http://127.0.0.1:5173/**,comunidadusac://login-callback/"`
- **¿Habilita signup anónimo?**: NO. El payload no incluye la propiedad `anonymous_users_enabled`.
- **¿Desactiva confirmación de correo?**: NO. El payload no modifica `mailer_autoconfirm`.
- **¿Imprime secretos?**:
  - NO en condiciones normales. La respuesta completa del endpoint de gestión de Supabase (que incluye llaves SMTP y secretos de integración) es canalizada por tubería hacia un script inline de Python ([`configure-auth.sh:37`](file:///home/carlos/Escritorio/Comunidad_USAC/scripts/configure-auth.sh#L37)) que extrae y formatea únicamente los campos públicos (`site_url`, `uri_allow_list`, `external_google_enabled`, `mailer_autoconfirm`), previniendo la fuga de credenciales en la terminal.

### 8. Versionado de `.wrangler/` y `.env` (Credenciales Cloudflare/R2)
- **¿Están versionados en Git?**:
  - NO. `.gitignore` contiene explícitamente las reglas `.env`, `.env.*` y `.wrangler/` ([`.gitignore:2-3, 11`](file:///home/carlos/Escritorio/Comunidad_USAC/.gitignore#L2-L3)).
  - La inspección de Git (`git ls-files` y búsqueda histórica en todo el log con `git log --all --full-history`) confirma que ningún archivo `.env` ni `.wrangler` ha sido jamás confirmado (committed) en el repositorio.
- **¿Hay credenciales de Cloudflare/R2 en el repo?**:
  - En `.wrangler/cache/` (directorio local en disco, no versionado), únicamente residen `wrangler-account.json` y `pages.json`, los cuales almacenan el Account ID (`51f5709e5722058f9415fece11735834`) y el nombre de proyecto (`zanate`). No existen tokens de API ni claves secretas.
  - En `worker/` (`worker/README.md`), el subdirectorio `worker/src` está vacío y el README documenta un snippet de ejemplo con un worker público (`https://comunidad-usac-storage.carlosdelcidramirez.workers.dev`), sin claves privadas.
  - En `docs/deploy-cloudflare.md:23`, se documenta el Account ID para configuración de GitHub Secrets, pero no el token de acceso.
  - En `supabase/config.toml:385-387`, las credenciales de S3/R2 se obtienen estrictamente mediante variables de entorno `env(S3_ACCESS_KEY)` y `env(S3_SECRET_KEY)`.

---

## Hallazgos

### H-1: Despliegue continuo a producción sin ejecución de pruebas ni análisis estático
- Severidad: ALTA
- Tipo: LÓGICA
- Ubicación: [`.github/workflows/deploy-cloudflare-pages.yml:5-67`](file:///home/carlos/Escritorio/Comunidad_USAC/.github/workflows/deploy-cloudflare-pages.yml#L5-L67)
- Evidencia:
  ```yaml
  on:
    push:
      branches:
        - main
    workflow_dispatch:
  ...
  steps:
    - name: Checkout del repositorio
      uses: actions/checkout@v6
    - name: Configurar Flutter SDK
    ...
    - name: Compilar web (release)
      working-directory: comunidad_universitaria
      run: flutter build web --release "${defines[@]}"
    - name: Desplegar a Cloudflare Pages
      uses: cloudflare/wrangler-action@v4
      with:
        apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
        accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
        command: pages deploy comunidad_universitaria/build/web --project-name=zanate --branch=main
  ```
- Impacto: Todo push o merge hacia la rama `main` compila y publica inmediatamente el artefacto web en producción (`https://zanate.pages.dev`). El workflow no ejecuta `flutter test` ni `flutter analyze`, y corre en paralelo e independientemente de `flutter-tests.yml`. Cambios con pruebas fallidas o regresiones críticas de seguridad se publican en producción sin bloqueo.
- Corrección propuesta:
  Agregar un paso previo obligatorio en `deploy-cloudflare-pages.yml` que ejecute `flutter analyze` y `flutter test`, o condicionar el despliegue al éxito del workflow de pruebas mediante el evento `workflow_run`.

---

### H-2: Incompatibilidad semántica de `moderation_status` entre Edge Function y Base de Datos / Panel Admin
- Severidad: ALTA
- Tipo: LÓGICA
- Ubicación:
  - [`supabase/functions/moderation-worker/index.ts:397-408`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/functions/moderation-worker/index.ts#L397-L408)
  - [`supabase/functions/moderation-worker/README.md:24-28`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/functions/moderation-worker/README.md#L24-L28)
  - `EVIDENCIA-BD.md:17, 1073-1081`
  - [`supabase/migrations/20261001000000_adopt_remote_schema.sql:990-997, 1971, 2039`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261001000000_adopt_remote_schema.sql#L990-L997)
- Evidencia:
  En `moderation-worker/index.ts`:
  ```typescript
  if (verdict.label === "SAFE_CAMPUS_HUMOR") {
    newModerationStatus = 0; // Worker asume: 0 = Visible / Aprobado
  } else if (verdict.confidence >= 0.50 && verdict.confidence < 0.80) {
    newModerationStatus = 1; // Worker asume: 1 = En Revisión humana
  } else if (verdict.confidence >= 0.80) {
    newModerationStatus = 2; // Ocultado automático
  }
  ```
  Contraste con la semántica real en base de datos (`EVIDENCIA-BD.md` §9) y en funciones del panel (`20261001000000_adopt_remote_schema.sql`):
  - `0`: PENDIENTE (valor predeterminado de la columna en BD).
  - `1`: APROBADO / APROPIADO (asignado por `panel_aprobar`: `set moderation_status = 1, moderation_label = 'appropriate'` y `apply_moderation_batch`).
  - `2`: OCULTO / INAPROPIADO (`ocultar_contenido_moderado`, `panel_rechazar`).
  - `3`: ERROR / REVISIÓN MANUAL (consultado por `panel_cola_revision`: `where p.moderation_status = 3`).
- Impacto:
  1. Contenido catalogado como dudoso o con riesgo medio (`0.50 <= conf < 0.80`) es marcado por el worker con `moderation_status = 1`. En la base de datos, `1` significa contenido aprobado; las políticas RLS (`USING (moderation_status IS DISTINCT FROM 2)`) lo exponen inmediatamente a todos los usuarios autenticados y anónimos, y la cola de moderación humana (`panel_cola_revision`) nunca lo muestra porque filtra por estado `3`.
  2. Contenido seguro (`SAFE_CAMPUS_HUMOR`) es marcado como `0` (pendiente), manteniéndose indistinguible de publicaciones no procesadas.
- Corrección propuesta:
  Corregir la asignación de estados en `moderation-worker/index.ts`:
  - `SAFE_CAMPUS_HUMOR` debe asignar `moderation_status = 1`.
  - Contenido en revisión (`0.50 <= conf < 0.80`) debe asignar `moderation_status = 3` (o `2` si se desea ocultamiento preventivo durante la revisión humana).

---

### H-3: Condición de carrera con sobreescritura ciega de moderación humana por el Edge Function
- Severidad: MEDIA
- Tipo: LÓGICA
- Ubicación: [`supabase/functions/moderation-worker/index.ts:424-431`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/functions/moderation-worker/index.ts#L424-L431)
- Evidencia:
  En `moderation-worker/index.ts`:
  ```typescript
  const { error: updateEntityErr } = await supabase
    .from(job.entity_table)
    .update(updatePayload)
    .eq("id", job.entity_id);
  ```
  En contraste, la función SQL `apply_moderation_batch` implementaba protección contra sobreescrituras en [`20261001000000_adopt_remote_schema.sql:1016-1020`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261001000000_adopt_remote_schema.sql#L1016-L1020):
  ```sql
  and not exists (
    select 1 from public.moderation_audit_log a
     where a.entity_table = 'posts' and a.entity_id = v_id
       and a.is_automated = false and a.created_at > v_locked
  );
  ```
- Impacto: Si un moderador humano aprueba o rechaza una entidad desde el panel administrativo (`panel_aprobar` o `panel_rechazar`) mientras el worker asíncrono está procesando la llamada externa al LLM, el worker sobrescribe incondicionalmente el veredicto del moderador humano con su clasificación automatizada.
- Corrección propuesta:
  Incluir una cláusula de verificación en la llamada de actualización o utilizar una función RPC atómica que impida actualizar la entidad si existe un registro manual en `moderation_audit_log` con fecha posterior a `job.locked_at`.

---

### H-4: `ocultar_contenido_moderado` permite a cualquier usuario autenticado ocultar contenido de autores eliminados (`user_id IS NULL`)
- Severidad: ALTA
- Tipo: LÓGICA
- Ubicación: [`supabase/migrations/20261001000000_adopt_remote_schema.sql:1878, 1904`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261001000000_adopt_remote_schema.sql#L1878)
- Evidencia:
  En `public.ocultar_contenido_moderado`:
  ```sql
  1878:    v_user_id uuid := auth.uid();
  1879:    v_owner_id uuid;
  ...
  1904:    IF v_owner_id <> v_user_id AND NOT v_is_admin AND NOT v_is_mod THEN
  1905:        RAISE EXCEPTION 'Permiso denegado: No tienes autorización para ocultar este contenido.';
  1906:    END IF;
  ```
  En las tablas `comments` y `posts`, la clave foránea hacia `auth.users` está configurada como `ON DELETE SET NULL` ([`20260818161419_replica_pemtree_schema.sql:40`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20260818161419_replica_pemtree_schema.sql#L40)). Si la cuenta del creador original fue eliminada, `v_owner_id` es `NULL`.
  En SQL, la comparación `NULL <> v_user_id` evalúa a `NULL` (desconocido). En PL/pgSQL, una condición de bloque `IF` que evalúa a `NULL` no ejecuta el cuerpo del `THEN`.
- Impacto: Cualquier usuario normal autenticado (la función tiene permiso de ejecución público para `authenticated`, ver `EVIDENCIA-BD.md:686`) puede invocar con éxito `ocultar_contenido_moderado` sobre cualquier publicación o comentario cuyo autor haya sido eliminado, censurando contenido ajeno arbitrariamente.
- Corrección propuesta:
  Utilizar comparación segura contra nulos:
  `IF (v_owner_id IS DISTINCT FROM v_user_id) AND NOT v_is_admin AND NOT v_is_mod THEN`

---

### H-5: Inconsistencia de esquema en funciones de moderación manual: rechazo de la tabla `student_groups`
- Severidad: MEDIA
- Tipo: ESQUEMA
- Ubicación:
  - [`supabase/migrations/20261001000000_adopt_remote_schema.sql:1888-1898, 2511-2521, 1353-1363`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261001000000_adopt_remote_schema.sql#L1888-L1898)
  - [`supabase/functions/moderation-worker/index.ts:18, 347-361`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/functions/moderation-worker/index.ts#L18)
  - `EVIDENCIA-BD.md:38, 54`
- Evidencia:
  En `EVIDENCIA-BD.md`:
  `| student_groups | TABLE | True | 5 |`
  `| whatsapp_groups | VIEW | False | 0 |`
  En `ocultar_contenido_moderado`, `restaurar_contenido_moderado` y `eliminar_contenido_moderado`:
  ```sql
  IF p_tabla = 'whatsapp_groups' THEN ...
  ELSIF p_tabla = 'posts' THEN ...
  ELSIF p_tabla = 'comments' THEN ...
  ELSIF p_tabla = 'marketplace_items' THEN ...
  ELSE
      RAISE EXCEPTION 'Tabla (%) no válida para moderación.', p_tabla;
  END IF;
  ```
  En la Edge Function `moderation-worker/index.ts:18`:
  `entity_table: "posts" | "comments" | "student_groups" | "marketplace_items";`
- Impacto: Si el panel de moderación o la API envía el nombre real de la tabla subyacente (`student_groups`) para ocultar, restaurar o eliminar un grupo de estudio, las tres funciones PL/pgSQL fallan con error `Tabla (student_groups) no válida para moderación`.
- Corrección propuesta:
  Incorporar `'student_groups'` en la lista blanca de las funciones de moderación, actualizando y consultando la tabla física `public.student_groups`.

---

### H-6: Ausencia de bloque de permisos mínimos (`permissions`) en workflow `flutter-tests.yml`
- Severidad: MEDIA
- Tipo: AUTH
- Ubicación: [`.github/workflows/flutter-tests.yml:1-163`](file:///home/carlos/Escritorio/Comunidad_USAC/.github/workflows/flutter-tests.yml#L1-L163)
- Evidencia:
  A diferencia de `deploy-cloudflare-pages.yml:16-18` (que restringe explícitamente `contents: read`, `deployments: write`), `flutter-tests.yml` no define ninguna directiva `permissions:` en la raíz del archivo ni dentro de sus jobs (`flutter-test`, `supabase-db-tests`, `e2e-linux`).
- Impacto: El token implícito de ejecución `GITHUB_TOKEN` adquiere los permisos configurados por defecto en el repositorio o la organización. En repositorios donde no se ha restringido a solo lectura, scripts o acciones vulnerables ejecutadas en el runner de CI podrían realizar modificaciones no autorizadas en el repositorio (creación de releases, push a ramas, edición de issues).
- Corrección propuesta:
  Declarar de manera explícita en la cabecera de `flutter-tests.yml`:
  ```yaml
  permissions:
    contents: read
  ```

---

### H-7: Subdominios wildcard y esquemas inseguros HTTP localhost en lista blanca OAuth de producción
- Severidad: MEDIA
- Tipo: AUTH
- Ubicación:
  - [`scripts/configure-auth.sh:27`](file:///home/carlos/Escritorio/Comunidad_USAC/scripts/configure-auth.sh#L27)
  - [`docs/auth-sso.md:33-38`](file:///home/carlos/Escritorio/Comunidad_USAC/docs/auth-sso.md#L33-L38)
- Evidencia:
  `scripts/configure-auth.sh` fija en el proyecto Supabase de producción:
  ```json
  "uri_allow_list": "https://zanate.pages.dev/**,https://*.zanate.pages.dev/**,https://pemtree.netlify.app/**,https://*--pemtree.netlify.app/**,http://localhost:3000/**,http://localhost:5173/**,http://127.0.0.1:3000/**,http://127.0.0.1:5173/**,comunidadusac://login-callback/"
  ```
- Impacto:
  1. Los patrones comodín `https://*.zanate.pages.dev/**` y `https://*--pemtree.netlify.app/**` permiten que cualquier despliegue preview (por ejemplo, ramas creadas en un PR malicioso de Netlify o subdominios colisionados en Pages) sea reconocido como destino legítimo para recepción de tokens OAuth.
  2. Permitir permanentemente esquemas no cifrados `http://localhost:*` y `http://127.0.0.1:*` en la configuración del proyecto Supabase productivo abre vectores de intercepción local de credenciales si una víctima inicia sesión en una red compartida o máquina comprometida.
- Corrección propuesta:
  Remover los comodines de subdominios y las URLs `http://localhost` de la configuración de producción de Supabase Auth, manteniendo estrictamente los dominios finales conocidos en HTTPS. Las URLs de depuración local deben pertenecer exclusivamente a entornos o proyectos de desarrollo aislados.

---

### H-8: Peticiones HTTP no idempotentes (GET) desencadenan ejecución de la Edge Function
- Severidad: BAJA
- Tipo: LÓGICA
- Ubicación: [`supabase/functions/moderation-worker/index.ts:503, 560-569`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/functions/moderation-worker/index.ts#L503)
- Evidencia:
  El manejador `Deno.serve` solo inspecciona `req.method === "OPTIONS"` para responder el preflight y `req.method === "POST"` para parsear el cuerpo JSON. No restringe el método HTTP. Si un cliente autorizado envía un método `GET`, la función procede a reclamar concurrentemente 10 jobs de `moderation_jobs` y a procesar el lote con llamadas a BD y LLMs.
- Impacto: Violación de la semántica segura e idempotente del método HTTP GET (RFC 9110 §9.2.1). Monitores de salud (health checks), herramientas de escaneo o balanceadores de carga que envíen peticiones GET accidentales con encabezados autorizados alterarán el estado de la cola de moderación.
- Corrección propuesta:
  Validar el método al inicio del handler y rechazar cualquier petición distinta de `POST` (salvo `OPTIONS`) con código `405 Method Not Allowed`.

---

### H-9: Ausencia de invocador programado (cron) para vaciar la cola `moderation_jobs`
- Severidad: MEDIA
- Tipo: LÓGICA
- Ubicación:
  - [`supabase/functions/moderation-worker/`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/functions/moderation-worker/)
  - [`supabase/migrations/20261110000000_unified_core_and_legal_hardening.sql`](file:///home/carlos/Escritorio/Comunidad_USAC/supabase/migrations/20261110000000_unified_core_and_legal_hardening.sql)
- Evidencia:
  Los triggers en base de datos (`trg_enqueue_posts`, `trg_enqueue_comments`, `trg_enqueue_marketplace`, `trg_enqueue_student_groups`) insertan jobs en `public.moderation_jobs` en cada creación o edición. No obstante, en las migraciones de PostgreSQL (`pg_cron`) solo se programan tareas de purga suave (`purge-expired-soft-deletes`) y recálculo de hot score (`refresh-active-posts-hot-score`). No existe ningún cron job ni webhook programado que invoque `/functions/v1/moderation-worker`.
- Impacto: Las publicaciones y comentarios nuevos permanecen en estado pendiente y nunca son procesados por el worker determinista ni por el LLM, a menos que un operador invoque manualmente el endpoint vía `curl`.
- Corrección propuesta:
  Configurar una tarea de `pg_cron` combinada con `pg_net` (o un cron job externo en GitHub Actions / Cloudflare Worker) que ejecute periódicamente `POST /functions/v1/moderation-worker` con el header `Authorization: Bearer <WORKER_SECRET>`.

---

## No verificado
- Configuración activa de secretos en el dashboard remoto de Supabase (`WORKER_SECRET`, `MODERATION_LLM_URL`, `MODERATION_LLM_API_KEY`), por requerir credenciales de la consola web no presentes en el repositorio local.
- Configuración de Branch Protection Rules en el repositorio GitHub remoto para la rama `main` (para corroborar si se bloquea el push directo requiriendo la finalización exitosa de `flutter-tests.yml`).
- Comportamiento en tiempo de ejecución del endpoint OpenAI compatible configurado en `MODERATION_LLM_URL`.
