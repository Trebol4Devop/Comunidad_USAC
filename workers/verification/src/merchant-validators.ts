/**
 * Validadores puros para el flujo de verificación de comerciantes (Zero-PII).
 */

const DPI_REGEX = /^[0-9]{9}(0[1-9]|1[0-9]|2[0-2])[0-9]{2}$/;

/**
 * Valida formato de DPI de Guatemala (mantenido para utilidades internas o pruebas):
 * 13 dígitos numéricos con código de departamento 01-22.
 */
export function validateDpi(dpi: string | null | undefined): boolean {
  if (!dpi || typeof dpi !== 'string') return false;
  const trimmed = dpi.trim();
  return DPI_REGEX.test(trimmed);
}

/**
 * Valida nombre del negocio / comerciante:
 * - Cadena de texto requerida
 * - Longitud entre 2 y 80 caracteres tras trim()
 */
export function validateBusinessName(name: string | null | undefined): boolean {
  if (!name || typeof name !== 'string') return false;
  const trimmed = name.trim();
  return trimmed.length >= 2 && trimmed.length <= 80;
}

/**
 * Normaliza número de teléfono de contacto de Guatemala:
 * - Elimina espacios, guiones, puntos y paréntesis
 * - Remueve prefijo internacional '+502' o '502' cuando corresponda
 */
export function normalizeContactPhone(phone: string | null | undefined): string {
  if (!phone || typeof phone !== 'string') return '';
  let cleaned = phone.trim().replace(/[\s\-\(\)\.]/g, '');
  if (cleaned.startsWith('+502')) {
    cleaned = cleaned.slice(4);
  } else if (cleaned.startsWith('502') && cleaned.length === 11) {
    cleaned = cleaned.slice(3);
  }
  return cleaned;
}

/**
 * Valida que el teléfono de contacto de Guatemala sea de 8 dígitos tras normalizar.
 */
export function validateContactPhone(phone: string | null | undefined): boolean {
  const normalized = normalizeContactPhone(phone);
  return /^[2-7][0-9]{7}$/.test(normalized);
}

/**
 * Valida nota opcional del establecimiento: máximo 160 caracteres.
 */
export function validateEstablishmentNote(note: string | null | undefined): boolean {
  if (note == null) return true;
  if (typeof note !== 'string') return false;
  return note.trim().length <= 160;
}

/**
 * Valida que la clave R2 para la foto del establecimiento cumpla:
 * - Comience con 'pending/merchant/<userId>/<requestId>/establishment.'
 * - Tenga extensión tras el prefijo
 */
export function validateEstablishmentKey(
  key: string | null | undefined,
  userId: string,
  requestId: string
): boolean {
  if (!userId || !requestId || !key || typeof key !== 'string') return false;
  const prefix = `pending/merchant/${userId}/${requestId}/establishment.`;
  return key.startsWith(prefix) && key.length > prefix.length;
}

export interface MerchantKeys {
  dpiFrontKey?: string | null;
  dpiBackKey?: string | null;
  establishmentKey: string | null | undefined;
}

/**
 * Validador de claves para compatibilidad histórica con suites de pruebas.
 */
export function validateMerchantKeys(
  keys: MerchantKeys,
  userId: string,
  requestId: string
): boolean {
  if (!userId || !requestId) return false;
  const prefix = `pending/merchant/${userId}/${requestId}/`;

  const { dpiFrontKey, dpiBackKey, establishmentKey } = keys;
  if (!establishmentKey || typeof establishmentKey !== 'string') return false;

  if (dpiFrontKey && dpiBackKey) {
    if (
      dpiFrontKey === dpiBackKey ||
      dpiFrontKey === establishmentKey ||
      dpiBackKey === establishmentKey
    ) {
      return false;
    }
    if (!dpiFrontKey.startsWith(prefix) || !dpiBackKey.startsWith(prefix)) {
      return false;
    }
  }

  return establishmentKey.startsWith(prefix) && establishmentKey.length > prefix.length;
}

/**
 * Valida el parámetro doc del endpoint GET /admin/merchant-document
 * En Zero-PII sólo se sirve la foto del establecimiento ('establishment').
 */
export function validateMerchantDoc(doc: unknown): doc is 'establishment' {
  return doc === 'establishment';
}
