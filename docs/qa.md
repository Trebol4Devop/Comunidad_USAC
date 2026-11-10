# Aseguramiento de Calidad (QA), Privacidad y CI/CD

Guía de referencia rápida para el equipo de desarrollo y CI/CD.

## Comandos de Verificación QA

```bash
supabase db reset
supabase test db
cd comunidad_universitaria && flutter analyze && flutter test
deno check supabase/functions/moderation-worker/index.ts
```

## Suites Relevantes

- **Suite Legal y Retención Judicial:** Ubicada en `supabase/tests/database/full_system_and_legal_test.sql`. Valida retención de registros bajo `is_legal_hold`, borrado lógico suave (`deleted_at`), inmutabilidad de logs y ofuscación de identidad con vistas seguras sin `user_id`.
- **Suite de Modelos y Privacidad Flutter:** Ubicada en `comunidad_universitaria/test/models_and_privacy_test.dart`. Valida anonimato, catálogo cerrado de alias, cálculo determinista de color para `author_hash` y encapsulamiento estricto de identificadores.
- **Flujo de Integración Continua (CI):** Definido en `.github/workflows/flutter-tests.yml`, configurado para ramas `main` y `develop` según el modelo Gitflow.
