# Contrato — Verificación estudiantil USAC

> Documento normativo para los tres entregables (base de datos, Worker, Flutter).
> Cualquier divergencia con este documento es un bug. Versión 1.0 — 2026-11-16.

## 1. Alcance

Tres niveles de verificación:

| Nivel | Método | Resultado |
|---|---|---|
| 1 | Correo institucional (`.usac.edu.gt`, `usac.edu.gt` o dominio en `facultades.allowed_domains`) | `verified` automático |
| 2 | Documento (constancia, carné físico, boleta) + OCR/QR | `verified` automático si pasa las reglas |
| 3 | Revisión manual por staff | `verified` o `rejected` |

Regla de producto:

- Sin cuenta (`anon`): solo lectura en toda la app.
- Autenticado **no verificado**: foro, grupos, mapa, reseñas y lectura del Marketplace. **No puede publicar** en Marketplace.
- Autenticado **verificado**: publica en Marketplace.
- `pending_review`: mismas capacidades que no verificado + banner informativo.
- `rejected`: mismas capacidades que no verificado + CTA para reintentar.

El Marketplace **sigue visible** para todos; solo se bloquea la publicación.

## 2. Modelo de datos

### 2.1 `public.facultades`

```sql
allowed_domains text[] NOT NULL DEFAULT '{}'::text[]
```

IDs reales (no usar nombres): `'todas'`, `'01'` Agronomía, `'02'` Arquitectura,
`'03'` Económicas, `'04'` Derecho, `'05'` Medicina, `'06'` Farmacia,
`'07'` Humanidades, `'08'` Ingeniería, `'09'` Odontología, `'10'` Veterinaria.

Población inicial:

| id | allowed_domains |
|---|---|
| `08` | `ingenieria.usac.edu.gt`, `ecys.org` |
| `05` | `medicina.usac.edu.gt` |
| `04` | `derecho.usac.edu.gt` |
| `03` | `economicas.usac.edu.gt` |
| `06` | `farusac.edu.gt` |
| `01` | `fausac.gt` |

### 2.2 `public.profiles`

Columnas nuevas (idempotentes):

```sql
verification_method text CHECK (verification_method = ANY (ARRAY[
  'institutional_email','ocr_document','qr_code','manual_review'])),
verification_status text NOT NULL DEFAULT 'unverified' CHECK (verification_status = ANY (ARRAY[
  'unverified','pending_review','verified','rejected'])),
institutional_email_domain text
```

`is_verified` y `verified_at` ya existen y se mantienen como fuente de verdad
para `public.is_verified_seller()` (Marketplace). Invariante:

```
verification_status = 'verified'  <=>  is_verified = true
```

`cui_hash` y `carne_hash` ya existen con índice único
(`profiles_cui_hash_key`, `profiles_carne_hash_key`). **No crear constraints
duplicados**: usar un bloque `DO` que solo agregue si falta.

### 2.3 `public.verification_requests`

```sql
id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
carne_hash text NOT NULL,
cui_hash text,
document_type text NOT NULL CHECK (document_type = ANY (ARRAY[
  'constancia_inscripcion','carne_fisico','boleta_asignacion'])),
r2_object_key text,
extracted_ocr_text text,
qr_url text,
ocr_confidence double precision,
ocr_source text NOT NULL DEFAULT 'client' CHECK (ocr_source = ANY (ARRAY['client','server'])),
status text NOT NULL DEFAULT 'pending' CHECK (status = ANY (ARRAY[
  'pending','approved','manual_review','rejected'])),
rejection_reason text,
reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
reviewed_at timestamptz,
expires_at timestamptz NOT NULL DEFAULT (now() + interval '24 hours'),
created_at timestamptz NOT NULL DEFAULT now(),
updated_at timestamptz NOT NULL DEFAULT now()
```

Índices:

- `(user_id, created_at DESC)`
- `(status, expires_at)`
- parcial `(id) WHERE r2_object_key IS NOT NULL`
- `(reviewed_by)` si no existe

Trigger `updated_at` reutilizando la función existente del proyecto
(`_triggers.set_updated_at` o equivalente disponible; si no existe, crear
`public.tg_set_updated_at()`).

### 2.4 `public.moderation_jobs`

Reemplazar el CHECK de `entity_table` para incluir `'verification_requests'`
conservando los valores actuales. `content_hash` es `NOT NULL`: para solicitudes
de verificación usar `content_hash = 'verification_request:' || request_id::text`.

## 3. Hash de credenciales

**Única fuente de verdad: Postgres.** El Worker y Flutter nunca calculan ni
reciben el hash.

```sql
private.hash_credential(p_value text) RETURNS text
```

- `encode(extensions.hmac(btrim(p_value), private.get_secret_salt(), 'sha256'), 'hex')`
- `REVOKE ALL ... FROM PUBLIC, anon, authenticated`.
- No se expone por PostgREST (schema `private` no está expuesto).

Normalización: `btrim` únicamente. El carné es solo dígitos; el CUI es solo
dígitos (se almacena como texto).

## 4. Funciones SQL

Todas son `SECURITY DEFINER`, `SET search_path = ''` y con nombres
completamente calificados. Devuelven `jsonb`; **no lanzan excepciones para
errores de negocio** (para no filtrar información por mensajes de error).

### 4.1 `public.is_user_verified() RETURNS boolean`

- `STABLE`.
- `EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_verified = true)`.
- `GRANT EXECUTE TO authenticated, service_role`.
- `REVOKE FROM PUBLIC, anon`.

### 4.2 `public.claim_student_credentials(p_carne text, p_cui text DEFAULT NULL) RETURNS jsonb`

Llamable por `authenticated` (usa `auth.uid()`).

Validaciones:

- `auth.uid()` no nulo.
- Carné: `^[0-9]{9}$` y año (primeros 4) entre 1980 y `EXTRACT(YEAR FROM now())`.
  Formato canónico del proyecto: `^(19[8-9][0-9]|20[0-9][0-9])[0-9]{5}$`.
- CUI (si viene): `^[0-9]{9}(0[1-9]|1[0-9]|2[0-2])[0-9]{2}$`.

Respuestas:

```json
{ "ok": true,  "verification_status": "verified|unverified|pending_review",
  "is_verified": true }
{ "ok": false, "code": "invalid_carne" | "invalid_cui" | "credential_unavailable" | "not_authenticated" }
```

Reglas:

- Calcula hashes con `private.hash_credential`.
- Si otro perfil (`id <> auth.uid()`) tiene el mismo `carne_hash` o `cui_hash`:
  `{"ok": false, "code": "credential_unavailable"}` (mensaje genérico, no
  confirma existencia).
- Actualiza `profiles.carne_hash`, `cui_hash` (si viene) y `updated_at`.
- **No** cambia `is_verified`: eso lo hace el trigger de correo o el OCR.
- Si el perfil ya está verificado con otro método, no lo degrada.

### 4.3 `public.admin_create_verification_request(...) RETURNS jsonb`

Solo `service_role`. La llama el Worker en una sola transacción.

```sql
public.admin_create_verification_request(
  p_user_id uuid,
  p_carne text,
  p_cui text DEFAULT NULL,
  p_document_type text DEFAULT 'constancia_inscripcion',
  p_r2_object_key text DEFAULT NULL,
  p_ocr_text text DEFAULT NULL,
  p_qr_url text DEFAULT NULL,
  p_ocr_confidence double precision DEFAULT NULL,
  p_auto_approved boolean DEFAULT false
) RETURNS jsonb
```

Comportamiento:

1. Verifica `auth.role() = 'service_role'` o `current_user IN ('postgres','supabase_admin')`.
2. Valida carné/CUI y `document_type` con las mismas reglas que 4.2.
3. **Rate limit:** si el usuario tiene `>= 3` filas en `verification_requests`
   con `created_at > now() - interval '24 hours'`, responde
   `{"ok": false, "code": "rate_limited"}`.
4. Hash de carné/CUI y detección de duplicado (excluyendo `p_user_id`).
5. Inserta `verification_requests`:
   - `status = 'approved'` y `reviewed_at = now()` si `p_auto_approved`.
   - `status = 'manual_review'` en caso contrario.
   - `expires_at = now() + interval '24 hours'`.
   - `ocr_source = 'client'`.
6. Si `p_auto_approved`:
   - `profiles`: `is_verified = true`, `verified_at = now()`,
     `verification_status = 'verified'`, `verification_method = 'ocr_document'`,
     `carne_hash`, `cui_hash` (si viene).
   - `r2_object_key` debe ser `NULL`.
7. Si no:
   - `profiles.verification_status = 'pending_review'` (no toca `is_verified`).
   - Inserta en `moderation_jobs` (`entity_table = 'verification_requests'`,
     `entity_id = request_id`, `has_image = (p_r2_object_key IS NOT NULL)`,
     `content_hash = 'verification_request:' || request_id::text`, `priority = 50`).
8. Devuelve:

```json
{ "ok": true, "status": "verified" | "manual_review", "request_id": "uuid" }
{ "ok": false, "code": "invalid_carne" | "invalid_cui" | "invalid_document_type"
  | "credential_unavailable" | "rate_limited" | "not_authorized" }
```

### 4.4 `public.admin_review_verification(...) RETURNS jsonb`

Solo `service_role`.

```sql
public.admin_review_verification(
  p_reviewer_id uuid,
  p_request_id uuid,
  p_decision text,          -- 'approved' | 'rejected'
  p_reason text DEFAULT NULL
) RETURNS jsonb
```

- Valida que `p_reviewer_id` tenga rol `admin` o `moderator` en
  `public.user_roles`. Si no: `{"ok": false, "code": "not_authorized"}`.
- Bloquea la solicitud con `FOR UPDATE`.
- `approved`: solicitud `approved`, `reviewed_by`, `reviewed_at`; perfil
  `is_verified = true`, `verification_status = 'verified'`,
  `verification_method = 'manual_review'`, `verified_at = now()`, hashes.
- `rejected`: solicitud `rejected` + `rejection_reason`; perfil
  `verification_status = 'rejected'` e `is_verified = false` **solo si** el
  método vigente es `ocr_document` o `manual_review`. Nunca degrada una
  verificación por correo institucional.
- **No** limpia `r2_object_key`: lo hace el Worker tras borrar el objeto en R2.

```json
{ "ok": true, "status": "approved" | "rejected", "request_id": "uuid" }
{ "ok": false, "code": "not_authorized" | "not_found" | "invalid_decision" }
```

### 4.5 Trigger de correo institucional

`public.handle_institutional_email_verification()` — `SECURITY DEFINER`,
`SET search_path = ''`.

Disparador:

```sql
CREATE TRIGGER trg_on_auth_user_email_verified
AFTER INSERT OR UPDATE OF email, email_confirmed_at ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_institutional_email_verification();
```

Reglas:

1. Solo actúa si `NEW.email_confirmed_at IS NOT NULL` y `NEW.email` contiene `@`.
2. `v_domain := lower(split_part(NEW.email, '@', 2))`.
3. `INSERT INTO public.profiles (id) VALUES (NEW.id) ON CONFLICT (id) DO NOTHING`
   antes del `UPDATE` (tolera el orden de `trg_on_auth_user_created`).
4. Dominio permitido si:
   - `v_domain = 'usac.edu.gt'`, o
   - `v_domain LIKE '%.usac.edu.gt'`, o
   - `v_domain = ANY (SELECT unnest(f.allowed_domains) FROM public.facultades f)`.
5. Si está permitido, actualiza `is_verified = true`,
   `verification_status = 'verified'`, `verification_method = 'institutional_email'`,
   `verified_at = COALESCE(verified_at, now())`,
   `institutional_email_domain = v_domain`, `updated_at = now()`.
6. **Nunca degrada** un perfil ya verificado por OCR/manual.

## 5. RLS

### 5.1 `public.verification_requests`

```sql
ALTER TABLE public.verification_requests ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.verification_requests TO authenticated;
REVOKE ALL ON public.verification_requests FROM anon;
```

- `SELECT`: `user_id = auth.uid()` **o** `public.is_pemtree_admin(auth.uid())`
  **o** `public.is_pemtree_moderator(auth.uid())`.
- Sin políticas de `INSERT`/`UPDATE`/`DELETE` para `authenticated`
  (el Worker usa `service_role`, que ignora RLS).

### 5.2 Marketplace

El `INSERT` de `marketplace_items` ya exige `public.is_verified_seller(auth.uid())`
(`20261113120000_marketplace_ux_backend.sql`). Mantener esa política y
**verificar con un test** que:

- un autenticado no verificado **no** puede insertar;
- uno verificado por el flujo nuevo **sí** puede;
- lectura, upvotes y bookmarks siguen disponibles para no verificados.

No se agregan restricciones nuevas al foro, grupos, mapa ni reseñas.

### 5.3 Inmutabilidad de campos sensibles

`profiles.verification_status`, `verification_method`, `institutional_email_domain`,
`is_verified` y `verified_at` **no** deben poder modificarse desde el cliente.
El trigger existente `guard_seller_verification_fields` ya protege campos de
vendedor: extender el mismo patrón (o crear
`public.guard_verification_fields()`) para que solo `service_role`,
`postgres` o `supabase_admin` puedan cambiarlos. `claim_student_credentials`
y las funciones `admin_*` son `SECURITY DEFINER`, por lo que no se ven
afectadas.

## 6. API del Worker

Base: `https://<worker>/api/v1`.

### 6.1 `POST /verify-document`

`Authorization: Bearer <JWT Supabase>`, `Content-Type: multipart/form-data`.

| Campo | Tipo | Obligatorio |
|---|---|---|
| `file` | imagen JPEG/PNG/WebP | sí |
| `carne` | string 9 dígitos | sí |
| `document_type` | `constancia_inscripcion` \| `carne_fisico` \| `boleta_asignacion` | sí |
| `cui` | string 13 dígitos | no |
| `client_ocr_text` | string | no |
| `qr_url` | string | no |

Validaciones del servidor:

1. JWT válido (`auth.getUser`). 401 si no.
2. Archivo: máx. 10 MB; MIME real por magic bytes (`FF D8 FF`, `89 50 4E 47`,
   `52 49 46 46` + `WEBP`); extensión coherente.
3. `carne` con `^(19[8-9][0-9]|20[0-9]{2})[0-9]{5}$` y año <= año actual.
4. `document_type` dentro del enum.
5. Si viene `qr_url`: `hostname === 'usac.edu.gt'` o termina en `.usac.edu.gt`.
6. Normalización de texto: mayúsculas, sin tildes (`NFD` + quitar `\p{M}`),
   espacios colapsados.

Reglas de aprobación automática (todas obligatorias):

- **a)** El texto contiene `UNIVERSIDAD DE SAN CARLOS` **o**
  `REGISTRO Y ESTADISTICA` **o** `USAC TRICENTENARIA` **o**
  `ESTUDIANTE UNIVERSITARIO`.
- **b)** El texto contiene el carné exacto.
- **c)** Si `document_type` es `constancia_inscripcion` o `boleta_asignacion`,
  contiene el año vigente (calculado, no hardcodeado).
- **d)** Si viene `qr_url`, el hostname pasó la validación.

Referencia del carné físico USAC (para keywords del prompt de OCR):

- Frente: CUI, Facultad, Carrera, Foto, Carné,
  `DEPARTAMENTO DE REGISTRO Y ESTADISTICA`,
  `EN CASO DE EMERGENCIA MARQUE AL 1592`, código de barras.
- Reverso: nombre completo, `USAC TRICENTENARIA`,
  `ESTUDIANTE UNIVERSITARIO`, QR.

Flujo:

- **Aprobado:** llama a `admin_create_verification_request(..., p_auto_approved => true)`
  **sin subir a R2**. Responde `{"status":"verified","request_id":...}`.
- **Dudoso (dos pasos, por ese orden):**
  1. Llama a `admin_create_verification_request(..., p_r2_object_key => NULL,
     p_auto_approved => false)` y obtiene `request_id`.
  2. Sube el archivo a R2 con la clave `pending/${userId}/${request_id}.${ext}`
     y luego actualiza con el cliente service_role
     `verification_requests.r2_object_key = key` y
     `moderation_jobs.has_image = true` (fila con
     `entity_id = request_id`).
  Si la subida falla, elimina la fila recién creada y responde
  `500 {"status":"error","code":"upload_failed"}`.
  Responde `{"status":"manual_review","request_id":...}`.

Errores:

| HTTP | code |
|---|---|
| 401 | `unauthorized` |
| 413 | `file_too_large` |
| 415 | `unsupported_media_type` |
| 422 | `invalid_carne`, `invalid_cui`, `invalid_document_type`, `invalid_qr_host`, `missing_fields` |
| 409 | `credential_unavailable` |
| 429 | `rate_limited` |

Cuerpo de error uniforme:

```json
{ "status": "error", "code": "invalid_carne", "message": "..." }
```

### 6.2 `POST /admin/review-verification`

`Authorization: Bearer <JWT>`, `application/json`:

```json
{ "request_id": "uuid", "decision": "approved|rejected", "reason": "opcional" }
```

1. Verifica el JWT y que el usuario tenga rol `admin`/`moderator`
   (`user_roles`), además de la validación dentro del RPC.
2. Llama a `admin_review_verification(reviewer_id, request_id, decision, reason)`.
3. Si `ok`, y existía `r2_object_key`: `await env.VERIFICATION_BUCKET.delete(key)`
   y luego `UPDATE verification_requests SET r2_object_key = NULL`.
   Si el borrado falla, **no** nulees la clave: el cron lo reintentará.
4. Responde `{"status":"approved|rejected","request_id":"uuid"}`.

### 6.3 Cron `scheduled` (cada 6 h)

Selecciona hasta 100 filas donde:

```sql
r2_object_key IS NOT NULL
AND (status IN ('approved','rejected') OR expires_at < now())
```

Por cada una: `bucket.delete(key)` → si OK, `r2_object_key = NULL`.
Si falla, registra y continúa. Idempotente.

## 7. Estados en Flutter

| `is_verified` | `verification_status` | UI |
|---|---|---|
| `true` | `verified` | App completa |
| `false` | `unverified` | Foro/grupos/mapa/reseñas + Marketplace **visible en solo lectura**; CTA "Verifica para publicar"; al abrir el flujo, onboarding en 2 pasos |
| `false` | `pending_review` | Igual + banner "Tu verificación está en revisión" |
| `false` | `rejected` | Igual + banner con motivo y CTA para reintentar |

- Invitado (`auth.currentUser == null` o sesión anónima): lectura en toda la app,
  sin acciones.
- El CTA de publicación en Marketplace abre el flujo de verificación, no el
  formulario de publicación.
- El carné **no** se persiste en `shared_preferences` ni en `UserProfile`:
  solo vive en memoria durante el flujo.

## 8. Criterios de aceptación

1. Migración aplicable dos veces seguidas sin errores.
2. `claim_student_credentials` no permite reclamar un carné/CUI ya tomado y no
   confirma si existe.
3. El trigger de correo verifica `@ingenieria.usac.edu.gt`, `@usac.edu.gt` y
   `@fausac.gt`; rechaza `@gmail.com`; no degrada a un verificado por OCR.
4. Un autenticado no verificado recibe error al insertar en `marketplace_items`;
   uno verificado puede.
5. `verification_requests`: el dueño ve solo las suyas; staff ve todas;
   `authenticated` no puede insertar ni actualizar directamente.
6. Worker: rechaza archivos falsos por magic bytes, JWT inválido, QR con host
   ajeno y carné fuera de rango.
7. Worker: en aprobación no escribe en R2; en revisión escribe con la clave
   `pending/<userId>/<requestId>.<ext>`; en revisión manual borra el objeto y
   nula la clave; el cron limpia expirados.
8. Flutter: `flutter analyze` y `flutter test` en verde; el plugin de OCR solo
   se importa en móvil (sin romper web/desktop).
