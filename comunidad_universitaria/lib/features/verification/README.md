# Módulo de Verificación Estudiantil y Comerciante USAC (`features/verification`)

Este módulo implementa el flujo normativo de verificación de identidad para la comunidad universitaria de la USAC, de acuerdo con el contrato técnico `docs/verification/contract.md` y la política **Zero-PII** (sin CUI/DPI ni fotos de documentos de identidad civil).

## Arquitectura y Flujos

### Verificación automática: Correo Institucional + Carné (Zero-PII)
- **Identidad**: Validación mediante cuenta oficial de Google Workspace o mediante código OTP enviado al correo institucional del estudiante.
- **Fotos del carné + verificación local (Android/iOS)**:
  - El estudiante adjunta el **frente** y el **reverso** de su carné con cámara o galería.
  - **Frente** (Facultad, Carrera, Foto, Carné, "Departamento de Registro y Estadística", "En caso de emergencia marca 1592", código de barras):
    - el número de carné escrito aparece en la foto (bloqueante);
    - se detecta una leyenda institucional USAC (bloqueante);
    - la facultad y la carrera seleccionadas aparecen en el texto (advertencia);
    - se detecta la leyenda "En caso de emergencia marca 1592" (advertencia);
    - el código de barras del frente se acepta como código detectado (advertencia si falta).
    - cualquier CUI detectado por OCR es ignorado y nunca se persiste.
  - **Reverso** (Nombre completo, "USAC TRICENTENARIA", "ESTUDIANTE UNIVERSITARIO", QR de Registro y Estadística):
    - se detectan las leyendas "USAC TRICENTENARIA" y "ESTUDIANTE UNIVERSITARIO" (bloqueante si no hay ninguna);
    - el QR debe ser una URL de `usac.edu.gt` (bloqueante si falta o es de otro dominio);
    - si el QR contiene el carné, se refuerza la coherencia entre ambas caras; si no, se valida el dominio (advertencia).
  - La app ejecuta OCR y detección de QR/código de barras **en el dispositivo** y no habilita el correo institucional hasta que ambas caras pasan.
  - Las fotos **no se suben ni se persisten**: viven en memoria y se descartan al cerrar el flujo.
  - En **web/desktop** no hay OCR nativo: se muestra un aviso y se mantiene el correo institucional como prueba principal.
- **Sin solicitud de CUI**: Solo se solicita carné universitario (9 dígitos) y carrera. Se incluye aviso de privacidad visible sobre el cifrado irreversible.
- **Dominios permitidos**: `@usac.edu.gt`, `@*.usac.edu.gt` (ej. `@ingenieria.usac.edu.gt`, `@medicina.usac.edu.gt`, `@derecho.usac.edu.gt`, `@economicas.usac.edu.gt`), y autorizados en facultades (`@fausac.gt`, `@ecys.org`).
- **Asociación**: Se ejecuta la función RPC `claim_student_credentials(p_carne)`. Si el dominio es institucional, el trigger de base de datos activa automáticamente `is_verified = true` y `verification_status = 'verified'`. Si no es institucional, permanece `unverified` y se le ofrece contactar con soporte.

### Contactar con soporte
- Alternativa cuando la verificación automática no funciona o el estudiante no tiene correo institucional.
- La pantalla solicita:
  1. Motivo de contacto.
  2. Detalle opcional (máx. 500 caracteres).
  3. Carné USAC opcional (9 dígitos).
- El botón **“Enviar correo a soporte”** abre el cliente de correo del usuario con `mailto:trebol4devop@proton.me`, asunto y cuerpo prellenados.
- La app no guarda el mensaje ni el carné; solo se incluyen en el correo que el usuario decide enviar.
- Si no hay cliente de correo disponible, se copia la dirección de soporte al portapapeles.

### Verificación de Comerciantes (Zero-PII)
- Requiere sesión Google real (no anónima).
- Datos solicitados:
  1. Nombre del negocio (2-80 caracteres).
  2. Teléfono comercial / WhatsApp (8 dígitos de Guatemala; normalizado).
  3. Nota de ubicación en el campus (opcional, máx. 160 caracteres).
  4. Una sola fotografía obligatoria del puesto o local físico en el campus USAC.
- No se solicitan fotos ni números de DPI.
- Envío: `POST /api/v1/verify-merchant` con `business_name`, `contact_phone`, `establishment_note`, `establishment_photo`.
- Toda solicitud entra a revisión manual (`manual_review`).

## Privacidad y Seguridad (Zero-PII & Anti-doxxing)
- El carné universitario **nunca** se persiste en `shared_preferences` ni en texto plano en almacenamiento local.
- Solo reside temporalmente en memoria durante la sesión del flujo.
- En la interfaz de usuario se muestra enmascarado (`2019****5`).
- En la base de datos se almacena encriptado/hasheado con HMAC-SHA256 (`private.hash_credential`).
- No se recopilan CUI, DPI ni fotos de documentos de identidad civil.
