# Módulo de Verificación Estudiantil USAC (`features/verification`)

Este módulo implementa el flujo normativo de verificación de identidad estudiantil para la comunidad universitaria de la USAC, de acuerdo con el contrato técnico `docs/verification/contract.md`.

## Arquitectura y Flujos

### Camino A: Correo Institucional + Carné
- **Identidad**: Validación mediante cuenta oficial de Google Workspace o mediante código OTP enviado al correo del estudiante.
- **Foto del carné + verificación local (Android/iOS)**:
  - El estudiante adjunta una foto del frente de su carné con cámara o galería.
  - La app ejecuta OCR y detección de QR/código de barras **en el dispositivo**, y comprueba coherencia antes de habilitar el correo institucional:
    - el número de carné escrito aparece en la foto (bloqueante);
    - se detecta una leyenda institucional USAC (bloqueante);
    - la facultad y la carrera seleccionadas aparecen en el texto (advertencia);
    - si hay QR, pertenece a `usac.edu.gt` o a un subdominio (bloqueante si es un dominio ajeno);
    - el código de barras del frente se acepta como código detectado.
  - La foto **no se sube ni se persiste**: vive en memoria y se descarta al cerrar el flujo.
  - En **web/desktop** no hay OCR nativo: se muestra un aviso y se mantiene el correo institucional como prueba principal.
- **Dominios permitidos**: `@usac.edu.gt`, `@*.usac.edu.gt` (ej. `@ingenieria.usac.edu.gt`, `@medicina.usac.edu.gt`, `@derecho.usac.edu.gt`, `@economicas.usac.edu.gt`), y autorizados en facultades (`@fausac.gt`, `@ecys.org`).
- **Requisito en Supabase Auth**:
  > **IMPORTANTE**: La plantilla de correo de confirmación y OTP de Supabase debe contener explícitamente el tag `{{ .Token }}` para que el usuario reciba el código de 6 dígitos en su bandeja de entrada.
- **Asociación**: Se ejecuta la función RPC `claim_student_credentials(p_carne, p_cui)`. Si el dominio es institucional, el trigger de base de datos activa automáticamente `is_verified = true` y `verification_status = 'verified'`. Si no es institucional, permanece `unverified` y se le ofrece el Camino B.

### Camino B: Documento Estudiantil + OCR / QR
- **Tipos de documento admitidos**:
  1. `constancia_inscripcion`: Constancia de inscripción oficial.
  2. `carne_fisico`: Carné físico universitario (frente y reverso).
  3. `boleta_asignacion`: Boleta de asignación de cursos.
- **Procesamiento de OCR/QR**:
  - En **móvil** (Android/iOS): Se realiza análisis local mediante `google_mlkit_text_recognition` (script latino) y `mobile_scanner` (análisis de imagen) para extraer texto y código QR antes de enviar.
  - En **web y desktop**: No se ejecutan bibliotecas nativas de OCR móvil (`ocr_service_stub.dart`). Se muestra un aviso informativo y el documento se envía directamente para revisión manual sin bloquear al usuario.
- **Worker**: Se envía vía `multipart/form-data` al endpoint seguro `POST /api/v1/verify-document` del Cloudflare Worker con el Bearer token de Supabase.
- **Estados resultantes**:
  - `verified`: Aprobación automática.
  - `manual_review` / `pending_review`: Pasa a moderación del equipo.
  - Errores de credencial duplicada (`credential_unavailable` / 409): Muestra un mensaje estrictamente genérico sin confirmar la existencia previa del carné para prevenir ataques de enumeración.

## Privacidad y Seguridad (Anti-doxxing)
- El carné universitario **nunca** se persiste en `shared_preferences` ni en texto plano en almacenamiento local.
- Solo reside temporalmente en memoria durante la sesión del flujo.
- En la interfaz de usuario se muestra enmascarado (`2019****5`).
- En la base de datos se almacena encriptado/hasheado con HMAC-SHA256 (`private.hash_credential`).
