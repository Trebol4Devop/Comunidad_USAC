# Guía de Pruebas de Calidad (QA), Privacidad y CI/CD

Este documento describe el procedimiento estándar para ejecutar la suite completa de pruebas del proyecto Comunidad USAC (Base de Datos, Backend Edge Functions y Frontend Flutter).

## Comandos Oficiales de Verificación

Para ejecutar la verificación completa localmente:

```bash
supabase db reset
supabase test db
cd comunidad_universitaria && flutter analyze && flutter test
deno check supabase/functions/moderation-worker/index.ts
```

## Estructura de Suites de Pruebas

### 1. Base de Datos y Suite Legal (`supabase/tests/`)
- La suite integral de hardening legal y retención de evidencia se encuentra ubicada en:
  `supabase/tests/database/full_system_and_legal_test.sql`
- Ejecuta pruebas pgTAP para verificar:
  - RLS (Row Level Security) en perfiles, publicaciones, comentarios, grupos y marketplace.
  - Vistas seguras (`safe_posts_feed`, `safe_comments_feed`, etc.) que omiten `user_id`.
  - Mecanismos de retención legal (`is_legal_hold`) y soft delete (`deleted_at`).
  - Triggers y funciones criptográficas deterministas (`author_hash`).

### 2. Frontend Flutter (`comunidad_universitaria/`)
- `flutter analyze`: Análisis estático de código sin advertencias ni errores (0 issues).
- `flutter test`: Suite de pruebas unitarias, modelos, privacidad, servicios y widgets (300+ pruebas).
- `test/models_and_privacy_test.dart`: Suite dedicada a la privacidad y modelos:
  - Consumo seguro de vistas sin exposición de `user_id`.
  - Color determinista basado en `author_hash` (sin generadores pseudoaleatorios en UI).
  - Badges contextuales de privacidad (`OP`, `Tú`).
  - Generador de alias cerrado (`AnonymousAliasGenerator`).
  - Separación entre escritura (`toInsertMap`) y lectura pública (`fromMap`).

### 3. Edge Functions (`supabase/functions/`)
- `deno check supabase/functions/moderation-worker/index.ts`: Validación de tipos TypeScript y compatibilidad de runtime para las funciones serverless de moderación.
