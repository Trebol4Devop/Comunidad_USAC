# Módulo de Verificación Estudiantil USAC (`features/verification`)

Este módulo implementa el flujo normativo de verificación de identidad estudiantil para la comunidad universitaria de la USAC, de acuerdo con el contrato técnico `docs/verification/contract.md`.

## Arquitectura y Flujos

### Camino A: Correo Institucional + Carné
- **Identidad**: Validación mediante cuenta oficial de Google Workspace o mediante código OTP enviado al correo del estudiante.
- **Fotos del carné + verificación local (Android/iOS)**:
  - El estudiante adjunta el **frente** y el **reverso** de su carné con cámara o galería.
  - **Frente** (CUI, Facultad, Carrera, Foto, Carné, "Departamento de Registro y Estadística", "En caso de emergencia marca 1592", código de barras):
    - el número de carné escrito aparece en la foto (bloqueante);
    - se detecta una leyenda institucional USAC (bloqueante);
    - el CUI escrito aparece en la foto (bloqueante si se proporcionó);
    - la facultad y la carrera seleccionadas aparecen en el texto (advertencia);
    - se detecta la leyenda "En caso de emergencia marca 1592" (advertencia);
    - el código de barras del frente se acepta como código detectado (advertencia si falta).
  - **Reverso** (Nombre completo, "USAC TRICENTENARIA", "ESTUDIANTE UNIVERSITARIO", QR de Registro y Estadística):
    - se detectan las leyendas "USAC TRICENTENARIA" y "ESTUDIANTE UNIVERSITARIO" (bloqueante si no hay ninguna);
    - el QR debe ser una URL de `usac.edu.gt` (bloqueante si falta o es de otro dominio);
    - si el QR contiene el carné o el CUI, se refuerza la coherencia entre ambas caras; si no, se valida el dominio (advertencia).
  - La app ejecuta OCR y detección de QR/código de barras **en el dispositivo** y no habilita el correo institucional hasta que ambas caras pasan.
  - Las fotos **no se suben ni se persisten**: viven en memoria y se descartan al cerrar el flujo.
  - En **web/desktop** no hay OCR nativo: se muestra un aviso y se mantiene el correo institucional como prueba principal.
- **CUI opcional**: el formulario acepta el CUI de 13 dígitos y lo pasa a `claim_student_credentials(p_carne, p_cui)`; también se usa para validar el frente y el QR del reverso.
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
