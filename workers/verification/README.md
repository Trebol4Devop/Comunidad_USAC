# Worker de Verificación de Documentos USAC (`comunidad-usac-verification`)

Cloudflare Worker (TypeScript) para la validación y verificación de documentos de estudiantes y comerciantes de la Universidad de San Carlos de Guatemala (USAC), con almacenamiento temporal de evidencias en Cloudflare R2 y persistencia en Supabase.

Implementa estrictamente los contratos normativos:
- Fase 1: Verificación Estudiantil (`docs/verification/contract.md`) y migración `20261116120000_student_verification.sql`.
- Fase 2: Verificación de Comerciantes (`docs/verification/merchant-contract.md`) y migración `20261116150000_merchant_verification.sql`.

---

## 1. Principios de Seguridad y Diseño

1. **Hash de credenciales exclusivo en PostgreSQL**: El Worker **nunca** calcula ni recibe peppers o hashes de carnés, CUI o DPI. El cómputo criptográfico HMAC-SHA256 (`private.hash_credential`) es responsabilidad única de la base de datos dentro del schema `private`.
2. **Detección real de tipo MIME**: No se confía en extensiones de archivo ni en headers `Content-Type` enviados por clientes. Se analizan **magic bytes** reales (JPEG `FF D8 FF`, PNG `89 50 4E 47 0D 0A 1A 0A`, WebP `RIFF` + `WEBP`).
3. **Validación estricta de dominios QR**: Solo se permiten URLs HTTPS cuyo hostname sea exactamente `usac.edu.gt` o termine en `.usac.edu.gt`.
4. **Política de retención mínima en R2**:
   - En **aprobación automática de estudiantes**, el documento **no se sube a R2**.
   - En **revisión manual de estudiantes**, el archivo se almacena temporalmente bajo la clave `pending/${userId}/${requestId}.${ext}`.
   - En **verificación de comerciantes**, **nunca se auto-aprueba**; siempre pasa a revisión manual. Las 3 evidencias (`dpi_front`, `dpi_back`, `establishment`) se suben bajo `pending/merchant/${userId}/${requestId}/...`.
   - Tras la resolución administrativa (`approved` o `rejected`), el Worker elimina inmediatamente los objetos de R2 y nulea las referencias mediante `admin_clear_merchant_keys`.
   - Un cron job (`0 */6 * * *`) limpia periódicamente documentos de solicitudes resueltas, huérfanas (`user_id IS NULL`) o expiradas (> 24 h).
5. **Sin logging de PII**: Nunca se loguean tokens JWT, carnés, CUI, DPI, claves de almacenamiento completas, correos electrónicos ni texto OCR completo.

---

## 2. Endpoints

Base: `/api/v1`

### 2.1 Verificación Estudiantil (Fase 1)

#### `POST /api/v1/verify-document`
- **Autenticación**: `Authorization: Bearer <JWT Supabase>` (cuenta real, no anónima).
- **Content-Type**: `multipart/form-data`
- **Campos**: `file` (File), `carne` (string 9 dígitos), `document_type` (`constancia_inscripcion` | `carne_fisico` | `boleta_asignacion`), `cui` (string 13 dígitos opcional), `client_ocr_text` (opcional), `qr_url` (opcional).
- **Respuestas**:
  - `200 { "status": "verified", "request_id": "uuid" }` (auto-aprobado)
  - `200 { "status": "manual_review", "request_id": "uuid" }` (revisión manual)

#### `POST /api/v1/admin/review-verification`
- **Autenticación**: `Authorization: Bearer <JWT Supabase>` (rol `admin` o `moderator` en `user_roles`).
- **Content-Type**: `application/json`
- **Payload**: `{ "request_id": "<uuid>", "decision": "approved" | "rejected", "reason": "opcional" }`
- **Respuestas**:
  - `200 { "status": "approved" | "rejected", "request_id": "<uuid>" }`
  - `502 r2_delete_failed`: Si falla el borrado en R2 (el cron reintenta).

---

### 2.2 Verificación de Comerciantes (Fase 2)

#### `POST /api/v1/verify-merchant`
- **Autenticación**: `Authorization: Bearer <JWT Supabase>` (sesión real, usuarios anónimos retornan 403 `anonymous_not_allowed`).
- **Content-Type**: `multipart/form-data`

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `dpi_front` | `File` | Sí | Foto frontal del DPI (JPEG, PNG, WebP máx. 10 MB). |
| `dpi_back` | `File` | Sí | Foto posterior del DPI (JPEG, PNG, WebP máx. 10 MB). |
| `establishment` | `File` | Sí | Foto del establecimiento comercial (JPEG, PNG, WebP máx. 10 MB). |
| `business_name` | `string` | Sí | Nombre comercial del negocio (2 a 80 caracteres). |
| `dpi_number` | `string` | Sí | Número de DPI de 13 dígitos (departamentos válidos 01–22). |
| `establishment_note` | `string` | No | Nota opcional de ubicación (máx. 160 caracteres). |

##### Flujo:
1. Valida JWT no anónimo (`auth.getUser`).
2. Valida presencia de los 5 campos obligatorios y formato de cada uno.
3. Valida tamaño y magic bytes de las 3 imágenes.
4. Genera UUID de solicitud y construye las claves:
   - `pending/merchant/${userId}/${requestId}/dpi_front.${ext}`
   - `pending/merchant/${userId}/${requestId}/dpi_back.${ext}`
   - `pending/merchant/${userId}/${requestId}/establishment.${ext}`
5. Sube las 3 imágenes a R2 con compensación (borrado atómico si alguna falla).
6. Ejecuta `admin_create_merchant_verification_request` con `service_role`.
7. Si la base de datos rechaza la creación, purga inmediatamente las 3 imágenes de R2.
8. Retorna siempre `manual_review` (nunca se auto-aprueba).

##### Respuestas:
- **200 OK**:
  ```json
  { "status": "manual_review", "request_id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11" }
  ```
- **Errores**:
  - `401 unauthorized`: JWT ausente, expirado o malformado.
  - `403 anonymous_not_allowed`: Sesión anónima (se exige cuenta real).
  - `409 credential_unavailable`: DPI duplicado en otra solicitud pending/approved.
  - `413 file_too_large`: Algún archivo supera `MAX_FILE_BYTES`.
  - `415 unsupported_media_type`: Magic bytes no corresponden a JPEG, PNG o WebP.
  - `422 missing_fields`: Faltan campos requeridos.
  - `422 invalid_business_name`: Nombre fuera del rango 2–80 caracteres.
  - `422 invalid_dpi`: DPI no cumple formato guatemalteco de 13 dígitos y depto 01–22.
  - `429 rate_limited`: Más de 2 solicitudes en una ventana móvil de 24 horas.
  - `500 upload_failed`: Fallo en subida a R2 con compensación ejecutada.

---

#### `POST /api/v1/admin/review-merchant`
- **Autenticación**: `Authorization: Bearer <JWT Supabase>` (usuario con rol `admin` o `moderator` en `user_roles`).
- **Content-Type**: `application/json`

##### Payload:
```json
{
  "request_id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
  "decision": "approved",
  "reason": "Opcional: motivo en caso de rechazo"
}
```

##### Flujo:
1. Valida que el llamador tenga rol de staff (`admin` o `moderator`).
2. Ejecuta `admin_review_merchant_verification` en PostgreSQL con `service_role`.
3. Consulta las 3 claves de R2 de la solicitud.
4. Elimina las 3 imágenes de R2.
5. Solo si **todas** las eliminaciones en R2 tienen éxito, invoca `admin_clear_merchant_keys`.
6. Si alguna eliminación falla, preserva las referencias en BD y responde `502 r2_delete_failed` (el cron reintentará).

##### Respuestas:
- **200 OK**:
  ```json
  { "status": "approved", "request_id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11" }
  ```
- **Errores**:
  - `401 unauthorized`: Sesión inválida.
  - `403 not_authorized`: No es admin ni moderador.
  - `404 not_found`: Solicitud no encontrada.
  - `422 invalid_payload` / `invalid_decision`.
  - `502 r2_delete_failed`: Fallo al purgar imágenes en R2.

---

#### `GET /api/v1/admin/merchant-document`
- **Autenticación**: `Authorization: Bearer <JWT Supabase>` (rol staff `admin` o `moderator`).
- **Parámetros de consulta (Query params)**:
  - `request_id=<uuid>`: Identificador de la solicitud.
  - `doc=front|back|establishment`: Documento a consultar.

##### Flujo:
1. Valida privilegios de staff.
2. Lee la columna correspondiente (`dpi_front_key`, `dpi_back_key`, `establishment_key`).
3. Recupera el objeto desde R2 con `bucket.get(key)`. Si no existe o ya fue purgado -> 404 `not_found`.
4. Devuelve el flujo de bytes con `Content-Type` extraído de `httpMetadata` y encabezado `Cache-Control: no-store`.
5. Sin logs con claves completas ni contenido.

---

### 2.3 Scheduled Task (Cron cada 6 horas)

- Cron: `0 */6 * * *`
- Handler: `runCleanup(bucket, supabase)` en `src/handlers/cleanup.ts`.
- **Estudiantes (`verification_requests`)**:
  - Busca hasta 100 filas con `r2_object_key IS NOT NULL` y (`status IN ('approved','rejected')` o `expires_at < now()`).
  - Borra en R2 y nulea `r2_object_key`.
- **Comerciantes (`merchant_verification_requests`)**:
  - Busca hasta 100 filas con alguna clave no nula y (`status IN ('approved','rejected')` o `expires_at < now()` o `user_id IS NULL`).
  - **Expiración de pendientes**: Si la fila sigue en `status = 'pending'` y `expires_at < now()`, la actualiza a `status = 'rejected'`, `rejection_reason = 'expired'`, pasa el `moderation_jobs` a `done`, y si `profiles.seller_verification_status` sigue en `'pending'`, lo actualiza a `'rejected'` (sin alterar jamás `is_verified` de estudiante).
  - Borra las 3 claves de R2.
  - Si todas las operaciones de borrado tienen éxito, ejecuta `admin_clear_merchant_keys`. Si alguna falla, no limpia para reintentar en el próximo ciclo.
- Procesa en lotes concurrentes de 5 elementos (`Promise.allSettled`).
- Idempotente y tolerante a fallos individuales.

---

## 3. Variables de Entorno y Configuración

Configuración en `wrangler.toml`:

```toml
name = "comunidad-usac-verification"
main = "src/index.ts"
compatibility_date = "2026-11-10"
compatibility_flags = ["nodejs_compat"]

[[r2_buckets]]
binding = "VERIFICATION_BUCKET"
bucket_name = "comunidad-usac-verification"

[triggers]
crons = ["0 */6 * * *"]

[vars]
MAX_FILE_BYTES = "10485760"
ALLOWED_ORIGINS = "*"
```

### Secretos requeridos (`.dev.vars` / Cloudflare Secrets):

```bash
SUPABASE_URL="https://<project-ref>.supabase.co"
SUPABASE_ANON_KEY="<public-anon-key>"
SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"
```

---

## 4. Scripts de Desarrollo y Verificación

```bash
cd workers/verification

# Instalar dependencias
npm install

# Verificación de tipos estricta (TypeScript)
npm run typecheck

# Ejecutar suite de pruebas unitarias (Vitest)
npm run test

# Dry-run de compilación y empaquetado Wrangler
npx wrangler deploy --dry-run --outdir dist
```
