# Guía de Pruebas de Calidad (QA), Privacidad y CI/CD

Este documento describe el procedimiento estándar para ejecutar la suite completa de pruebas del proyecto Comunidad USAC (Base de Datos PostgreSQL con pgTAP, Backend Edge Functions y Frontend Flutter).

## Comandos Oficiales de Verificación

Para ejecutar la verificación completa localmente:

```bash
# 1. Reset e inicialización de la base de datos local
supabase db reset

# 2. Ejecutar suite de marketplace pgTAP de forma aislada / bloqueante (100% verde)
./scripts/db/run_pgtap.sh --file supabase/tests/database/marketplace_ux_test.sql

# 3. Ejecutar toda la suite pgTAP de base de datos
supabase test db

# 4. Verificación estática y suite Flutter
cd comunidad_universitaria
flutter analyze --no-pub
flutter test --no-pub

# 5. Validación de Edge Functions
cd ..
deno check supabase/functions/moderation-worker/index.ts
```

## Estructura de Suites de Pruebas

### 1. Suite de Marketplace UX y Privacidad (`supabase/tests/database/marketplace_ux_test.sql`)
Suite integral de 97 pruebas automatizadas que valida:
- **Planes normativos y cuotas:** Límites estrictos para planes `free` (3 activas, 2 fotos), `pro_student` (20 activas, 6 fotos, video) y `business_local` (catálogo ilimitado, carrusel VIP).
- **Vigencia y reconciliación:** Expiración a 14 días para plan free, degradación de planes de pago y mantenimiento vía `pause_expired_marketplace_items()`.
- **Privacidad y Anti-Doxxing:**
  - Vistas seguras (`safe_marketplace_items`, `safe_seller_profiles`) que omiten completamente `user_id`.
  - RPCs de feed (`get_marketplace_feed`, `get_marketplace_item_detail`, `get_seller_catalog`, `get_related_marketplace_items`) sin exposición de `user_id`.
  - `get_marketplace_metrics()` sin exponer la identidad de visitantes (`viewer_id`).
  - Inmutabilidad del autor: el `author_alias` es asignado determinísticamente desde el generador anónimo y nunca filtra el nombre real ni el carné institucional.
- **Custodia legal y soft delete:** Protección contra purgas (`purge_expired_soft_deletes()`) e inmutabilidad estricta (Art. 3) de elementos con `is_legal_hold = true`.
- **Compatibilidad legacy de vendedores:** Aceptación bidireccional de `profiles.seller_verification_status = 'verified'` e `is_verified = true`.
- **Blindaje RLS y Anti-escalada:** Bloqueo de DELETE físico para autores, validación de que solicitudes de patrocinio (`sponsor_requests`) en UPDATE por no-admin fallan con código de error `42501`, e imposibilidad de suplantar identidades en la creación de solicitudes.

### 2. Base de Datos y Suite Legal (`supabase/tests/`)
- Suite de hardening legal y retención de evidencia: `supabase/tests/database/full_system_and_legal_test.sql`.
- Pruebas adicionales de catálogos, contadores, comentarios y permisos RLS.

### 3. Frontend Flutter (`comunidad_universitaria/`)
- `flutter analyze --no-pub`: Análisis estático de código sin advertencias ni errores (0 issues).
- `flutter test --no-pub`: Suite de pruebas unitarias, modelos, privacidad, servicios y widgets.
- Nuevas pruebas de guardia y privacidad añadidas para Marketplace UX:
  - `test/widgets/create_listing_alias_privacy_test.dart`: Garantiza que al publicar un anuncio, aun si el perfil cuenta con `studentName` y `carne` verificados, el `authorAlias` enviado es el alias anónimo y nunca los datos personales reales.
  - `test/widgets/marketplace_plans_sheet_test.dart`: Verifica que en caso de error o respuesta vacía de `fetchPlans()`, se muestra el estado de error con reintento y no aparecen precios inventados (RN-MKT-04).
  - `test/services/marketplace_static_privacy_test.dart`: Guardia estática que inspecciona el código fuente de `MarketplaceService` y falla si contiene `.select(` con `user_id` o `SELECT *` sobre `marketplace_items`.
  - `test/models/marketplace_item_model_test.dart`: Valida el contrato estricto de `MarketplaceItem.fromJson` (omisión de `user_id`) y `toInsertMap()` (sin exposición de claves de identidad ni campos internos de moderación de staff).

---

## Fallos Legacy Preexistentes Conocidos

### Base de Datos (`supabase test db`)
Al ejecutar `supabase test db`, la suite nueva de marketplace (`marketplace_ux_test.sql`) y suites centrales (`full_system_and_legal_test.sql`, `groups_marketplace_rls_test.sql`, `comments_rls_test.sql`, etc.) pasan al 100%. Existen 4 archivos de prueba legacy que fallan por expectativas desactualizadas previas a las migraciones de endurecimiento:

1. **`supabase/tests/anonymous_read_only_test.sql`** (1 fallo):
   - *Causa:* El test espera el mensaje de error `Debes iniciar sesión con una cuenta para reportar` al invocar `report_marketplace_item`. La base de datos moderna activa la validación AAL2 (`AAL2 authentication is required to report content`), arrojando el mismo código SQLSTATE (`42501`) pero con el mensaje actualizado de segundo factor.
2. **`supabase/tests/authenticated_writes_without_otp_test.sql`** (5 fallos):
   - *Causa:* Las pruebas asumen que sesiones con nivel AAL1 pueden insertar y actualizar contenido autenticado sin segundo factor OTP. La migración `20261004000000_require_aal2_and_verified_sellers.sql` implementó la obligatoriedad estricta de AAL2 para toda mutación.
3. **`supabase/tests/rpc_moderation_test.sql`** (3 fallos):
   - *Causa:* Expectativas sobre el conteo de reportes y umbrales de auto-moderación que cambiaron durante la unificación de tablas y procedimientos de moderación legal.
4. **`supabase/tests/seller_verification_rls_test.sql`** (1 fallo):
   - *Causa:* El helper legacy `tests.authenticate_as_admin` realiza inserciones en `public.user_roles` sin elevar previamente la sesión a nivel AAL2, siendo rechazado por el trigger `require_aal2_for_authenticated_write`.

### Frontend Flutter (`flutter test --no-pub`)
Existen 23 fallos preexistentes documentados en suites fuera del dominio del Marketplace (`app_shell_test`, `discord_forum_test`, `forum_test`, `profile_screen_test`, `groups_screen_test`, `alias_modal_test`, `report_dialog_test`, `empty_state_test`, `create_post_dialog_test`). Las 340+ pruebas restantes, incluyendo todos los modelos, servicios y pantallas del Marketplace, pasan al 100% de forma reproducible.
