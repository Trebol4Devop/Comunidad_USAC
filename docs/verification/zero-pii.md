# Arquitectura de Verificación Zero-PII — Comunidad USAC

## 1. Principios y Objetivos

El modelo **Zero-PII** (Zero Personally Identifiable Information) garantiza que la base de datos de Comunidad USAC no almacene, procese en texto plano ni retenga datos personales directos o identificadores estatales de los usuarios.

### Pilares del Endurecimiento Zero-PII:
1. **Sin Nombres Reales:** Se elimina `full_name` de `public.profiles`. El alta de usuario no guarda nombres de metadatos OAuth.
2. **Sin CUI / DPI:** Se eliminan permanentemente las columnas `cui`, `cui_hash` en perfiles y solicitudes, así como `dpi_hash`, `dpi_front_key` y `dpi_back_key` en comercios.
3. **Sin OCR en Texto Claro:** Se elimina la persistencia de texto extraído (`extracted_ocr_text`). La validación se expresa exclusivamente mediante tres indicadores booleanos:
   - `matched_keywords`
   - `matched_carne`
   - `matched_current_year`
4. **Hashes Unidireccionales con Sal Secreta:** Los identificadores estudiantiles (`carne_hash`) y teléfonos comerciales (`contact_phone_hash`) se computan en PostgreSQL con HMAC-SHA256 (`private.hash_credential`), blindados contra lectura no autorizada.

---

## 2. Invariantes del Esquema de Base de Datos

### 2.1 `public.profiles`
- **Identificador de Carné Único:** `profiles_carne_hash_unique` garantiza que un mismo carné estudiantil no pueda vincularse a más de un perfil activo.
- **Permisos Restringidos (`authenticated`):** Solo se permite `UPDATE` sobre `carrera`, `accepted_terms_version` y `accepted_terms_at`. Las columnas sensibles no poseen permisos directos de escritura.
- **Creación de Perfiles:** El trigger `trg_on_auth_user_created` (`public.handle_new_user_profile()`) solo inicializa `(id)`, sin capturar `full_name`.

### 2.2 `public.verification_requests` (Estudiantes)
- Contiene: `carne_hash NOT NULL`, `document_type`, `r2_object_key`, `qr_url`, `matched_keywords`, `matched_carne`, `matched_current_year`, `ocr_source`, `status`, `expires_at`.
- Si `p_auto_approved = true`, `r2_object_key` se fuerza a `NULL` inmediatamente para no retener imágenes innecesarias.

### 2.3 `public.merchant_verification_requests` (Comerciantes)
- Contiene: `contact_phone_hash NOT NULL`, `establishment_key`, `establishment_note`, `campus_zone`, `business_name`, `status`.
- **Índice Único Parcial:**
  ```sql
  CREATE UNIQUE INDEX idx_merchant_unique_active_phone_hash
    ON public.merchant_verification_requests (contact_phone_hash)
    WHERE status IN ('pending', 'approved');
  ```
  Permite que un comerciante cuya solicitud previa haya sido rechazada (`rejected`) pueda volver a postularse con el mismo número telefónico tras corregir su documentación.

---

## 3. Catálogo de RPCs Autorizados

| Función | Rol Autorizado | Entradas | Salida / Efecto |
|---|---|---|---|
| `claim_student_credentials(p_carne text)` | `authenticated`, `service_role` | `p_carne` (9 dígitos, año 1980–actual) | Computa `carne_hash`, valida unicidad y actualiza el perfil del invocador (`auth.uid()`). |
| `admin_create_verification_request(...)` | `service_role`, `postgres` | `p_user_id`, `p_carne`, `p_document_type`, flags booleanas | Registra solicitud estudiantil, evalúa rate limit (3/24h) y actualiza estado de perfil / moderación. |
| `admin_create_merchant_verification_request(...)` | `service_role`, `postgres` | `p_request_id`, `p_user_id`, `p_business_name`, `p_contact_phone`, `p_establishment_key`, `p_establishment_note` | Normaliza teléfono guatemalteco (`^[2-7][0-9]{7}$`), valida prefijo R2, rate limit (2/24h) y encola en `moderation_jobs`. |
| `admin_clear_merchant_keys(p_request_id uuid)` | `service_role`, `postgres` | `p_request_id` | Establece `establishment_key = NULL` tras la purga del archivo en R2. |
| `admin_review_verification(...)` | `service_role`, `postgres` | `p_reviewer_id`, `p_request_id`, `p_decision`, `p_reason` | Aprueba o rechaza solicitud estudiantil, asignando `carne_hash` sin manipular CUI. |
| `admin_review_merchant_verification(...)` | `service_role`, `postgres` | `p_reviewer_id`, `p_request_id`, `p_decision`, `p_reason` | Aprueba o rechaza comerciante local, creando `seller_profiles` en caso afirmativo. |

---

## 4. Pasos Operativos de Migración

1. **Exportar Claves R2:**
   Ejecutar `scripts/zero-pii/00_export_r2_keys.sql` para generar la lista de objetos multimedia existentes.
2. **Purgar R2:**
   Seguir la guía en `scripts/zero-pii/README.md` utilizando `npx wrangler r2 object delete`.
3. **Aplicar Migración SQL:**
   Ejecutar `supabase/migrations/20261117120000_zero_pii_hardening.sql`. La migración es completamente idempotente y purga de forma segura las filas legacy de prueba en `verification_requests` y `merchant_verification_requests`.
4. **Verificación:**
   Ejecutar la suite de pruebas automatizadas:
   ```bash
   supabase test db
   ```
