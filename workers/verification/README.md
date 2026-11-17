# Worker de Verificación (`comunidad-usac-verification`)

Cloudflare Worker (TypeScript) para la verificación de comerciantes del campus USAC,
con almacenamiento temporal de la foto del establecimiento en Cloudflare R2 y
persistencia en Supabase.

El flujo estudiantil de documentos fue retirado de la app. La alternativa al flujo
automático es **Contactar con soporte** mediante `mailto:` desde Flutter. El Worker
conserva el endpoint de revisión de solicitudes históricas y el cron de limpieza.

Implementa:
- Verificación de comerciantes (`docs/verification/merchant-contract.md`).
- Revisión de solicitudes históricas de estudiantes (`verification_requests`).
- Limpieza periódica de objetos temporales en R2.

---

## 1. Principios de seguridad

1. **Hashes solo en PostgreSQL**: el Worker nunca calcula hashes de carné, teléfono
   o DPI. Usa `private.hash_credential` mediante RPC.
2. **Magic bytes reales**: no se confía en extensiones ni `Content-Type`; se validan
   JPEG (`FF D8 FF`), PNG (`89 50 4E 47...`) y WebP (`RIFF...WEBP`).
3. **Retención mínima en R2**:
   - Solo se sube la foto del establecimiento, en
     `pending/merchant/${userId}/${requestId}/establishment.${ext}`.
   - Al aprobar o rechazar, el Worker borra el objeto y limpia `establishment_key`.
   - El cron cada 6 horas purga solicitudes resueltas, expiradas o huérfanas.
4. **Sin PII en logs**: no se registran teléfonos, carné, tokens, claves R2 completas
   ni URLs firmadas.

---

## 2. Endpoints

Base: `/api/v1`

### `POST /verify-merchant`

- **Autenticación**: `Authorization: Bearer <JWT Supabase>` (cuenta real; anónimos 403).
- **Content-Type**: `multipart/form-data`
- **Campos**:

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `business_name` | string | Sí | 2–80 caracteres |
| `contact_phone` | string | Sí | 8 dígitos de Guatemala (`+502` opcional) |
| `establishment_note` | string | No | Máx. 160 caracteres |
| `establishment_photo` | File | Sí | JPEG/PNG/WebP, máx. 10 MB |

- **Flujo**:
  1. Valida JWT no anónimo.
  2. Valida campos y magic bytes.
  3. Sube la foto a R2 con compensación si falla.
  4. Ejecuta `admin_create_merchant_verification_request` con `service_role`.
  5. Si el RPC falla, borra el objeto recién subido.
  6. Responde siempre `manual_review`.
- **Respuestas**: `200 manual_review`, `401`, `403`, `409 credential_unavailable`,
  `413`, `415`, `422`, `429 rate_limited`, `500 upload_failed`.

### `POST /admin/review-merchant`

- **Autenticación**: staff (`admin` o `moderator`).
- **Payload**: `{ "request_id": "uuid", "decision": "approved|rejected", "reason": "..." }`
- Ejecuta `admin_review_merchant_verification`, borra `establishment_key` de R2 y
  limpia la columna. Si R2 falla, la revisión ya aplicada no se revierte y el cron
  reintenta.

### `GET /admin/merchant-document?request_id=<uuid>`

- Solo staff. Sirve únicamente la foto del establecimiento (`establishment_key`).
- `doc` es opcional; cualquier valor distinto de `establishment` responde 422.

### `POST /admin/review-verification` (legado)

- Solo staff. Revisa solicitudes históricas de `verification_requests`.
- Se conserva para solicitudes creadas antes de retirar el flujo de documentos.
- Tras la decisión, borra el objeto R2 si existe.

### `GET /health`

Devuelve `{ "status": "ok" }`.

---

## 3. Cron

- `0 */6 * * *`
- Limpia `verification_requests` históricas con `r2_object_key`.
- Limpia `merchant_verification_requests` con `establishment_key`:
  - resueltas (`approved`/`rejected`), expiradas (>24 h) o huérfanas;
  - marca como `rejected`/`expired` las pendientes vencidas;
  - no altera `is_verified` estudiantil.

---

## 4. Variables de entorno

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

Secretos: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.

---

## 5. Desarrollo

```bash
cd workers/verification
npm install
npm run typecheck
npm test
npx wrangler deploy --dry-run --outdir dist
```
