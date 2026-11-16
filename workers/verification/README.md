# Worker de Verificación de Documentos USAC (`comunidad-usac-verification`)

Cloudflare Worker (TypeScript) para la validación y verificación de documentos de estudiantes de la Universidad de San Carlos de Guatemala (USAC), con almacenamiento temporal de evidencias en Cloudflare R2 y persistencia en Supabase.

Implementa estrictamente el contrato normativo (`docs/verification/contract.md`) y la migración `20261116120000_student_verification.sql`.

---

## 1. Principios de Seguridad y Diseño

1. **Hash de credenciales exclusivo en PostgreSQL**: El Worker **nunca** calcula ni recibe peppers o hashes de carnés/CUI. El cómputo criptográfico HMAC-SHA256 (`private.hash_credential`) es responsabilidad única de la base de datos dentro del schema `private`.
2. **Detección real de tipo MIME**: No se confía en extensiones de archivo ni en headers `Content-Type` enviados por clientes. Se analizan **magic bytes** reales (JPEG `FF D8 FF`, PNG `89 50 4E 47 0D 0A 1A 0A`, WebP `RIFF` + `WEBP`).
3. **Validación estricta de dominios QR**: Solo se permiten URLs HTTPS cuyo hostname sea exactamente `usac.edu.gt` o termine en `.usac.edu.gt`.
4. **Política de retención mínima en R2**:
   - En **aprobación automática**, el documento **no se sube a R2**.
   - En **revisión manual**, el archivo se almacena temporalmente bajo la clave `pending/${userId}/${requestId}.${ext}`.
   - Tras la revisión por personal administrativo (`approved` o `rejected`), el Worker elimina inmediatamente el objeto de R2.
   - Un cron job (`0 */6 * * *`) limpia periódicamente documentos de solicitudes resueltas o expiradas (> 24 h).
5. **Sin logging de PII**: Nunca se loguean tokens JWT, carnés, CUI, correos electrónicos ni texto OCR completo.

---

## 2. Endpoints

Base: `/api/v1`

### 2.1 `POST /api/v1/verify-document`

- **Autenticación**: `Authorization: Bearer <JWT Supabase>`
- **Content-Type**: `multipart/form-data`

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `file` | `File` | Sí | Imagen del documento (JPEG, PNG, WebP máx. 10 MB). |
| `carne` | `string` | Sí | Carné USAC (9 dígitos, año 1980 hasta año actual). |
| `document_type` | `string` | Sí | `constancia_inscripcion`, `carne_fisico`, o `boleta_asignacion`. |
| `cui` | `string` | No | CUI de Guatemala (13 dígitos, depto 01-22). |
| `client_ocr_text` | `string` | No | Texto extraído por OCR en el cliente. |
| `qr_url` | `string` | No | URL decodificada de código QR institucional. |

#### Respuestas:

- **200 OK (Aprobación Automática)**:
  ```json
  { "status": "verified", "request_id": "uuid" }
  ```
- **200 OK (Enviado a Revisión Manual)**:
  ```json
  { "status": "manual_review", "request_id": "uuid" }
  ```
- **Errores Uniformes**:
  ```json
  { "status": "error", "code": "invalid_carne", "message": "..." }
  ```
  - `401 unauthorized`: JWT ausente, inválido o expirado.
  - `413 file_too_large`: Archivo supera `MAX_FILE_BYTES`.
  - `415 unsupported_media_type`: Magic bytes no corresponden a JPEG, PNG ni WebP.
  - `422 missing_fields`: Falta `file`, `carne` o `document_type`.
  - `422 invalid_carne`: Carné no cumple regex o año fuera de rango.
  - `422 invalid_cui`: CUI no cumple 13 dígitos o código de departamento inválido.
  - `422 invalid_document_type`: Tipo de documento no permitido.
  - `422 invalid_qr_host`: Host de QR no pertenece a `usac.edu.gt`.
  - `409 credential_unavailable`: Carné o CUI ya tomado por otro perfil.
  - `429 rate_limited`: Más de 3 intentos en las últimas 24 horas.

---

### 2.2 `POST /api/v1/admin/review-verification`

- **Autenticación**: `Authorization: Bearer <JWT Supabase>` (usuario con rol `admin` o `moderator` en `user_roles`)
- **Content-Type**: `application/json`

#### Payload:
```json
{
  "request_id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
  "decision": "approved",
  "reason": "Opcional: motivo en caso de rechazo"
}
```

#### Flujo:
1. Valida que el llamador tenga rol `admin` o `moderator`.
2. Ejecuta `admin_review_verification` en PostgreSQL.
3. Si el registro tenía documento en R2, elimina el archivo del bucket.
4. Solo tras confirmar la eliminación en R2, actualiza `r2_object_key = NULL`. Si R2 falla, devuelve `502 r2_delete_failed` y preserva la clave para reintento por el cron.

#### Respuestas:
- **200 OK**:
  ```json
  { "status": "approved", "request_id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11" }
  ```
- **Errores**:
  - `401 unauthorized`: Sesión inválida.
  - `403 not_authorized`: Usuario no es admin ni moderador.
  - `404 not_found`: Solicitud no encontrada.
  - `422 invalid_payload` / `invalid_decision`.
  - `502 r2_delete_failed`: Fallo en Cloudflare R2 al purgar el archivo.

---

### 2.3 Scheduled Task (Cron cada 6 horas)

- Cron: `0 */6 * * *`
- Handler: `runCleanup(bucket, supabase)` en `src/handlers/cleanup.ts`.
- Busca hasta 100 solicitudes donde `r2_object_key IS NOT NULL` y (`status IN ('approved','rejected')` o `expires_at < now()`).
- Procesa en lotes concurrentes de 5 elementos (`Promise.allSettled`).
- Borra cada objeto en R2 y actualiza `r2_object_key = NULL`.
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

# Ejecutar suite de pruebas unitarias
npm run test

# Dry-run de compilación y empaquetado Wrangler
npx wrangler deploy --dry-run --outdir dist
```
