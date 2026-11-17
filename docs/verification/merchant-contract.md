# Contrato — Acceso inicial y verificación de comerciante

> **Actualización Zero-PII (2026-11-17):** este documento conserva el contrato histórico.
> Desde la migración `20261117120000_zero_pii_hardening.sql` rigen los cambios descritos en
> `docs/verification/zero-pii.md`: no se solicitan ni almacenan DPI, fotos de identidad civil
> ni número de DPI. El comerciante se identifica por `contact_phone_hash` y una única foto
> del establecimiento (`establishment_key`).

> Normativo para los 4 entregables de la Fase 2. Versión 1.0 — 2026-11-16.
> Cualquier divergencia es un bug. La Fase 1 (verificación estudiantil) no se modifica.

## 1. Producto

### 1.1 Arranque

- Si hay **sesión real** (usuario no anónimo): entrar directo a `AppShell`.
- Si el flag local `usac_guest_mode = true` y no hay sesión real: entrar a
  `AppShell` en **modo invitado solo lectura**.
- En cualquier otro caso: `WelcomeScreen` con:
  - **Iniciar sesión** → `AuthGatewayScreen`.
  - **Continuar como anónimo** → marca `usac_guest_mode = true` y entra a
    `AppShell` (solo lectura).
- Cerrar sesión elimina `usac_guest_mode` y vuelve a `WelcomeScreen`.
- La ruta `/auth/authorize` (SSO) se resuelve **antes** del gate.

### 1.2 Login

- Único método de cuenta real: **Google OAuth**.
- Tras autenticar:
  - Dominio institucional (`usac.edu.gt`, `*.usac.edu.gt` o
    `facultades.allowed_domains`): Camino A de la Fase 1 (carné + carrera) si el
    perfil no está verificado; si ya lo está, a la app.
  - Dominio personal: pantalla **"Tu correo no es institucional"** con dos
    tarjetas separadas:
    - **Estudiante** → Camino B existente (constancia/carné/boleta, OCR o
      revisión manual).
    - **Comerciante** → flujo nuevo de esta fase (DPI frente, DPI reverso, foto
      del establecimiento, revisión manual).
- `AuthModal.show` (12 usos contextuales) debe abrir el mismo gateway y llamar
  `onAuthenticated` al completar una sesión real. No ofrece "anónimo".

### 1.3 Comerciante

- Requiere sesión real (JWT no anónimo).
- Formulario: `business_name` (2–80), `dpi_number` (13 dígitos),
  `establishment_note` opcional, y **3 fotos obligatorias**:
  `dpi_front`, `dpi_back`, `establishment`.
- **Nunca se auto-aprueba.** Toda solicitud entra a revisión manual.
- OCR móvil opcional solo para prellenar `dpi_number`; no decide nada.
- Al aprobar: se crea/actualiza `seller_profiles` como `local_business`
  aprobado y el usuario puede publicar de inmediato.
- Aprobar/rechazar comerciante **no** altera la verificación de estudiante.

## 2. Base de datos

### 2.1 Tabla `public.merchant_verification_requests`

```sql
id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
business_name text NOT NULL,
dpi_hash text NOT NULL,
dpi_front_key text,
dpi_back_key text,
establishment_key text,
establishment_note text,
status text NOT NULL DEFAULT 'pending'
  CHECK (status IN ('pending','approved','rejected')),
rejection_reason text,
reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
reviewed_at timestamptz,
expires_at timestamptz NOT NULL DEFAULT (now() + interval '24 hours'),
created_at timestamptz NOT NULL DEFAULT now(),
updated_at timestamptz NOT NULL DEFAULT now()
```

- `business_name`: CHECK `char_length BETWEEN 2 AND 80`.
- `establishment_note`: CHECK `char_length <= 160` si no es null.
- `user_id` nullable a propósito: al borrar la cuenta las claves quedan
  referenciadas para que el cron purgue R2.
- Índices: `(user_id, created_at DESC)`, `(status, expires_at)`,
  `(dpi_hash)`, parcial `(id) WHERE dpi_front_key IS NOT NULL OR ...`.
- Trigger `updated_at` con `_triggers.set_updated_at()`.
- `moderation_jobs.entity_table` añade `'merchant_verification_requests'`.
- `dpi_hash` = `private.hash_credential(dpi_number)` (HMAC-SHA256). **Nunca**
  se guarda el DPI en claro.

### 2.2 RLS

```sql
ALTER TABLE public.merchant_verification_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.merchant_verification_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.merchant_verification_requests TO authenticated;
GRANT ALL ON TABLE public.merchant_verification_requests TO service_role, postgres;
```

- Política SELECT: `user_id = auth.uid()` o
  `is_pemtree_admin(auth.uid())` o `is_pemtree_moderator(auth.uid())`.
- Sin políticas INSERT/UPDATE/DELETE para `authenticated`.

### 2.3 RPC `public.admin_create_merchant_verification_request`

Solo `service_role` (`REVOKE` de `PUBLIC, anon, authenticated`).

```sql
(
  p_request_id uuid,
  p_user_id uuid,
  p_business_name text,
  p_dpi_number text,
  p_dpi_front_key text,
  p_dpi_back_key text,
  p_establishment_key text,
  p_establishment_note text DEFAULT NULL
) RETURNS jsonb
```

Reglas:

1. `auth.role() = 'service_role'` (o `current_user` interno postgres).
2. `p_request_id` y `p_user_id` no nulos.
3. `business_name` con `btrim`, 2–80 caracteres.
4. `dpi_number` con `btrim` y regex `^[0-9]{9}(0[1-9]|1[0-9]|2[0-2])[0-9]{2}$`.
5. Las 3 claves no nulas, distintas entre sí, y cada una debe empezar con
   `pending/merchant/<p_user_id>/<p_request_id>/`.
6. **Rate limit:** `>= 2` solicitudes del usuario en las últimas 24 h →
   `{"ok": false, "code": "rate_limited"}`.
7. **DPI duplicado:** misma `dpi_hash` en otra cuenta con estado
   `pending`/`approved` → `{"ok": false, "code": "credential_unavailable"}`.
8. Insertar fila con `status='pending'`, `expires_at = now() + 24h`.
9. `INSERT INTO public.profiles (id) ... ON CONFLICT DO NOTHING` y luego
   `profiles.seller_verification_status = 'pending'` (no toca `is_verified`).
10. Insertar `moderation_jobs`: `entity_table='merchant_verification_requests'`,
    `entity_id=p_request_id`, `content_hash='merchant_request:' || p_request_id`,
    `has_image=true`, `priority=40`, `status='pending'`.
11. Devolver:

```json
{ "ok": true, "status": "manual_review", "request_id": "uuid" }
{ "ok": false, "code": "not_authorized" | "invalid_business_name" |
  "invalid_dpi" | "invalid_keys" | "rate_limited" | "credential_unavailable" }
```

### 2.4 RPC `public.admin_review_merchant_verification`

```sql
(p_reviewer_id uuid, p_request_id uuid, p_decision text, p_reason text DEFAULT NULL)
RETURNS jsonb
```

- Solo `service_role`.
- Valida que `p_reviewer_id` tenga rol `admin`/`moderator` en `user_roles`.
- `p_decision in ('approved','rejected')`; fila bloqueada `FOR UPDATE`.
- **Aprobado:**
  - solicitud `approved`, `reviewed_by`, `reviewed_at`;
  - upsert `seller_profiles`:
    `seller_type='local_business'`, `verification_status='approved'`,
    `business_name = solicitud.business_name` (conserva `plan_id`);
  - `profiles.seller_verification_status='verified'`,
    `seller_verified_at=now()`, `seller_verified_by=p_reviewer_id`;
  - job `done`.
- **Rechazado:**
  - solicitud `rejected` + `rejection_reason`;
  - `seller_profiles.verification_status='rejected'` si existe;
  - `profiles.seller_verification_status='rejected'`, `seller_verified_at=NULL`;
  - job `done`.
- **No** borra las claves R2 ni las nula.
- Devuelve `{ "ok": true, "status": "approved|rejected", "request_id": "..." }`.
- Errores: `not_authorized`, `not_found`, `invalid_decision`.

### 2.5 RPC `public.admin_clear_merchant_keys`

`(p_request_id uuid) RETURNS void`, solo `service_role`.
Pone las 3 claves a `NULL` y `updated_at = now()`.

## 3. Worker

Todas las rutas bajo `https://<worker>/api/v1`.

### 3.1 `POST /verify-merchant`

`Authorization: Bearer <JWT real>`, `multipart/form-data`:

| Campo | Tipo | Obligatorio |
|---|---|---|
| `dpi_front` | imagen JPEG/PNG/WebP | sí |
| `dpi_back` | imagen JPEG/PNG/WebP | sí |
| `establishment` | imagen JPEG/PNG/WebP | sí |
| `business_name` | string 2–80 | sí |
| `dpi_number` | 13 dígitos | sí |
| `establishment_note` | string ≤160 | no |

Flujo:

1. JWT válido y **no anónimo**; si no, 403 `unauthorized`.
2. Cada archivo: ≤ 10 MB, MIME real por magic bytes; 415/413 si falla.
3. `business_name` y DPI validados; 422 `invalid_business_name` / `invalid_dpi`.
4. `requestId = crypto.randomUUID()`.
5. Claves:
   `pending/merchant/<userId>/<requestId>/dpi_front.<ext>`,
   `.../dpi_back.<ext>`, `.../establishment.<ext>`.
6. Subir las 3 a R2. Si una falla, borrar las ya subidas y 500 `upload_failed`.
7. Llamar al RPC con las 3 claves.
8. Si el RPC devuelve `ok:false`, borrar las 3 y mapear:
   `credential_unavailable` → 409, `rate_limited` → 429,
   `invalid_*` → 422, `not_authorized` → 403.
9. 200 `{ "status": "manual_review", "request_id": "..." }`.

Códigos HTTP: 401 `unauthorized`, 403 `anonymous_not_allowed`,
413 `file_too_large`, 415 `unsupported_media_type`, 422, 409, 429, 500.

### 3.2 `POST /admin/review-merchant`

JSON `{ "request_id": "uuid", "decision": "approved|rejected", "reason": "..." }`.

1. JWT + rol `admin`/`moderator` (consulta `user_roles`).
2. Llamar `admin_review_merchant_verification`.
3. Si `ok`: leer las 3 claves; borrar cada objeto de R2. Si **todas** las
   operaciones tienen éxito, llamar `admin_clear_merchant_keys`.
   Si alguna falla, no limpiar y responder 502 `r2_delete_failed`
   (el cron reintenta; borrar un objeto inexistente es no-op).
4. 200 `{ "status": "approved|rejected", "request_id": "..." }`.

### 3.3 `GET /admin/merchant-document?request_id=<uuid>&doc=front|back|establishment`

- JWT + rol staff.
- Devuelve los bytes de la imagen con su `Content-Type`.
- 404 si la clave ya fue purgada.
- **No** loguear el contenido, el DPI ni claves completas.

### 3.4 Cron `scheduled` (cada 6 h)

Además de la limpieza de estudiantes ya existente:

- Filas de `merchant_verification_requests` con alguna clave no nula y
  (`status IN ('approved','rejected')` **o** `expires_at < now()` **o**
  `user_id IS NULL`), máximo 100.
- Borrar las 3 claves; si todas las operaciones OK, `admin_clear_merchant_keys`
  (o update directo con service_role).
- Idempotente, lotes de 5, sin PII en logs.

## 4. Flutter

### 4.1 Módulo `lib/features/onboarding/`

```
onboarding/
├── state/session_controller.dart      # ChangeNotifier inyectable
├── widgets/auth_gate.dart
├── screens/welcome_screen.dart
├── screens/auth_gateway_screen.dart
├── screens/no_institutional_email_screen.dart
└── screens/merchant_verification_screen.dart
```

`SessionController`:

```dart
enum SessionPhase { loading, authenticated, guest, unauthenticated }
```

- Métodos: `bootstrap()`, `signInWithGoogle()`, `continueAsGuest()`,
  `signOut()`, `setAuthenticated(User)`.
- Escucha `SupabaseService.client.auth.onAuthStateChange`.
- Persiste `usac_guest_mode` en `SharedPreferences` (clave
  `usac_guest_mode`; limpiar al autenticar y al cerrar sesión).
- Debe ser inyectable en tests (`SessionController({AuthApi? api, ...})`).

`AuthGate`:

- `loading` → splash.
- `authenticated` → `AppShell`.
- `guest` → `AppShell`.
- `unauthenticated` → `WelcomeScreen`.
- No intercepta `/auth/authorize`.

`AuthGatewayScreen`:

- Botón **Continuar con Google** (mismo `SupabaseService.signInWithGoogle`).
- Enlace **¿No cuentas con correo institucional?** →
  `NoInstitutionalEmailScreen`.
- Mientras espera el deep link, mostrar estado "Completa el acceso en Google".
- Tras sesión real:
  - dominio institucional y perfil no verificado → abrir Camino A
    (`VerificationFlowScreen` en tab 0);
  - dominio personal → `NoInstitutionalEmailScreen`.
- No mostrar OTP ni correo/contraseña en este gateway.

`NoInstitutionalEmailScreen`:

- Dos tarjetas independientes:
  - **Estudiante** → `VerificationFlowScreen(initialTab: 1)`.
  - **Comerciante** → `MerchantVerificationScreen`.
- Si no hay sesión real, lanza Google primero y luego continúa al camino
  elegido.

`MerchantVerificationScreen`:

- Campos: nombre del negocio, número de DPI, nota de ubicación (opcional).
- 3 selectores de imagen con vista previa; no permitir enviar si falta una.
- Aviso: "Tus documentos se eliminan después de la revisión".
- Envío a `POST /verify-merchant` con Bearer token.
- Resultado `manual_review` → mensaje y estado pendiente.
- `rejected` → motivo + reintento.
- Error 409 → mensaje genérico de credencial no disponible.
- OCR móvil opcional para prellenar el DPI; nunca auto-aprobar.
- El carné/CUI no aplican aquí.

### 4.2 Cambios existentes

- `main.dart`: quitar `SupabaseService.ensureSession()` del arranque; montar
  `AuthGate`; conservar la ruta SSO.
- `auth_modal.dart`: delegar en `AuthGatewayScreen` y respetar
  `onAuthenticated`.
- `settings_bottom_sheet.dart` / `profile_screen.dart`: para invitados, CTA
  "Iniciar sesión"; para autenticados, "Quiero vender" (abre el flujo de
  comerciante si `seller_verification_status != verified`).
- `VerificationController`: añadir `sellerVerificationStatus` leído de
  `profiles.seller_verification_status`; exponer `isMerchantPending`,
  `isMerchantVerified`, `isMerchantRejected`.
- `VerificationBanner`: banner de comerciante pendiente/rechazado.
- Marketplace: si `seller_verification_status='pending'`, el CTA de publicar
  informa que la solicitud está en revisión; si `verified`, permite publicar
  (ya lo hace `is_verified_seller`).

## 5. Estados de UI

| Sesión | `seller_verification_status` | UI |
|---|---|---|
| Invitado | — | App solo lectura; CTA "Iniciar sesión" |
| Autenticado | `unverified` | Puede pedir verificación de comerciante |
| Autenticado | `pending` | Banner "Solicitud de comerciante en revisión"; sin publicar |
| Autenticado | `verified` | Puede publicar en Marketplace |
| Autenticado | `rejected` | Banner con motivo + reintento |

## 6. Criterios de aceptación

1. Primer arranque sin sesión muestra `WelcomeScreen`; "anónimo" entra en solo
   lectura y no vuelve a preguntar en el siguiente arranque.
2. "Iniciar sesión" con Google institucional completa Camino A.
3. Google personal muestra las dos tarjetas separadas (estudiante/comerciante).
4. Comerciante exige las 3 fotos y siempre queda en revisión manual.
5. Al aprobar, `seller_profiles` queda `local_business/approved` y puede
   publicar sin pasos extra.
6. Staff puede ver las 3 imágenes con el endpoint de documentos.
7. Las 3 claves se borran al resolver, al expirar y al eliminar la cuenta.
8. `AuthModal` contextual sigue funcionando en los 12 usos.
9. Sin regresiones: 0 fallos nuevos de Flutter frente a los 23 preexistentes;
   pgTAP global solo con los 4 fallos legacy.
10. No se guarda el DPI en claro ni el carné en `shared_preferences`.
