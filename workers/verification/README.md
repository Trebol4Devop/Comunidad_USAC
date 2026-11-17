# Worker de Verificación — administración histórica y limpieza

Cloudflare Worker (TypeScript) que conserva la revisión de solicitudes históricas de
estudiantes y comerciantes, la entrega de documentos legacy y el cron de limpieza de R2.

La app ya no crea solicitudes nuevas:
- Estudiantes: **Verificación automática** o **Contactar con soporte** por correo.
- Comerciantes: **Contactar con soporte** por correo; soporte da de alta el comercio
  manualmente en `seller_profiles`.

El Worker se mantiene para resolver solicitudes creadas antes del cambio y para purgar
los objetos temporales que aún existan en R2.

---

## 1. Principios

1. **Hashes solo en PostgreSQL**: el Worker nunca calcula hashes de carné, teléfono o DPI.
2. **Sin PII en logs**: no se registran teléfonos, carnés, tokens, claves R2 completas
   ni URLs firmadas.
3. **Retención mínima**: los objetos legacy se borran al resolver la solicitud o desde
   el cron cada 6 horas.

---

## 2. Endpoints

Base: `/api/v1`

### `POST /admin/review-verification` (legado)

- Solo staff (`admin` o `moderator`).
- Payload: `{ "request_id": "uuid", "decision": "approved|rejected", "reason": "..." }`
- Revisa solicitudes históricas de `verification_requests` y borra el objeto R2 asociado.

### `POST /admin/review-merchant` (legado)

- Solo staff.
- Payload: `{ "request_id": "uuid", "decision": "approved|rejected", "reason": "..." }`
- Ejecuta `admin_review_merchant_verification`, borra `establishment_key` de R2 y limpia
  la columna. Si R2 falla, la revisión ya aplicada no se revierte y el cron reintenta.

### `GET /admin/merchant-document?request_id=<uuid>` (legado)

- Solo staff. Sirve únicamente la foto del establecimiento (`establishment_key`).
- Cualquier `doc` distinto de `establishment` responde 422.

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
