/**
 * Validadores puros para el flujo de verificación de comerciantes (§3 del contrato).
 */

const DPI_REGEX = /^[0-9]{9}(0[1-9]|1[0-9]|2[0-2])[0-9]{2}$/;

/**
 * Valida formato de DPI de Guatemala:
 * 13 dígitos numéricos:
 * - 9 dígitos correlativos
 * - 2 dígitos de código de departamento (01 a 22)
 * - 2 dígitos de código de municipio (00 a 99)
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

export interface MerchantKeys {
  dpiFrontKey: string | null | undefined;
  dpiBackKey: string | null | undefined;
  establishmentKey: string | null | undefined;
}

/**
 * Valida que las 3 claves de R2 para comerciante cumplan:
 * - No nulas ni vacías
 * - Distintas entre sí
 * - Comiencen estrictamente con 'pending/merchant/<userId>/<requestId>/'
 * - Tengan nombre/extensión tras el prefijo
 */
export function validateMerchantKeys(
  keys: MerchantKeys,
  userId: string,
  requestId: string
): boolean {
  if (!userId || !requestId) return false;
  const prefix = `pending/merchant/${userId}/${requestId}/`;

  const { dpiFrontKey, dpiBackKey, establishmentKey } = keys;

  if (
    !dpiFrontKey ||
    typeof dpiFrontKey !== 'string' ||
    !dpiBackKey ||
    typeof dpiBackKey !== 'string' ||
    !establishmentKey ||
    typeof establishmentKey !== 'string'
  ) {
    return false;
  }

  // Deben ser distintas entre sí
  if (
    dpiFrontKey === dpiBackKey ||
    dpiFrontKey === establishmentKey ||
    dpiBackKey === establishmentKey
  ) {
    return false;
  }

  // Deben empezar con el prefijo normativo y ser más largas que el prefijo
  if (
    !dpiFrontKey.startsWith(prefix) ||
    !dpiBackKey.startsWith(prefix) ||
    !establishmentKey.startsWith(prefix)
  ) {
    return false;
  }

  if (
    dpiFrontKey.length <= prefix.length ||
    dpiBackKey.length <= prefix.length ||
    establishmentKey.length <= prefix.length
  ) {
    return false;
  }

  return true;
}

export type MerchantDocType = 'front' | 'back' | 'establishment';

/**
 * Valida el parámetro doc del endpoint GET /admin/merchant-document
 */
export function validateMerchantDoc(doc: unknown): doc is MerchantDocType {
  return doc === 'front' || doc === 'back' || doc === 'establishment';
}

/**
 * Valida nota opcional del establecimiento: máximo 160 caracteres.
 */
export function validateEstablishmentNote(note: string | null | undefined): boolean {
  if (note == null) return true;
  if (typeof note !== 'string') return false;
  return note.trim().length <= 160;
}
