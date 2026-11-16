import type { DocumentType, ImageTypeResult } from './types';

const VALID_DOCUMENT_TYPES: readonly DocumentType[] = [
  'constancia_inscripcion',
  'carne_fisico',
  'boleta_asignacion',
];

const REQUIRED_KEYWORDS = [
  'UNIVERSIDAD DE SAN CARLOS',
  'REGISTRO Y ESTADISTICA',
  'USAC TRICENTENARIA',
  'ESTUDIANTE UNIVERSITARIO',
] as const;

/**
 * Valida formato del carné USAC: 9 dígitos, año entre 1980 y el año actual.
 * Regex canónico: ^(19[8-9][0-9]|20[0-9][0-9])[0-9]{5}$
 */
export function validateCarne(carne: string, maxYear?: number): boolean {
  if (!carne || typeof carne !== 'string') return false;
  const trimmed = carne.trim();
  const carneRegex = /^(19[8-9][0-9]|20[0-9][0-9])[0-9]{5}$/;
  if (!carneRegex.test(trimmed)) {
    return false;
  }
  const year = parseInt(trimmed.slice(0, 4), 10);
  const currentYear = maxYear ?? new Date().getUTCFullYear();
  return year >= 1980 && year <= currentYear;
}

/**
 * Valida formato del CUI de Guatemala: 13 dígitos.
 * 9 dígitos correlativos + 2 dígitos departamento (01-22) + 2 dígitos municipio.
 * Regex canónico: ^[0-9]{9}(0[1-9]|1[0-9]|2[0-2])[0-9]{2}$
 */
export function validateCui(cui: string): boolean {
  if (!cui || typeof cui !== 'string') return false;
  const trimmed = cui.trim();
  const cuiRegex = /^[0-9]{9}(0[1-9]|1[0-9]|2[0-2])[0-9]{2}$/;
  return cuiRegex.test(trimmed);
}

/**
 * Valida que el tipo de documento pertenezca al enum permitido.
 */
export function validateDocumentType(type: string): type is DocumentType {
  return VALID_DOCUMENT_TYPES.includes(type as DocumentType);
}

/**
 * Valida que la URL de QR sea https y pertenezca al dominio usac.edu.gt o subdominio.
 */
export function validateQrUrl(urlStr: string): boolean {
  if (!urlStr || typeof urlStr !== 'string') return false;
  try {
    const parsed = new URL(urlStr);
    if (parsed.protocol !== 'https:') {
      return false;
    }
    const host = parsed.hostname.replace(/\.$/, '').toLowerCase();
    return host === 'usac.edu.gt' || host.endsWith('.usac.edu.gt');
  } catch {
    return false;
  }
}

/**
 * Detecta tipo MIME real por magic bytes sin confiar en extensiones ni headers.
 * - JPEG: FF D8 FF
 * - PNG: 89 50 4E 47 0D 0A 1A 0A
 * - WebP: 52 49 46 46 + bytes 8-11: 57 45 42 50 (WEBP)
 */
export function detectImageType(bytes: Uint8Array): ImageTypeResult | null {
  if (!bytes || bytes.length < 3) return null;

  // JPEG: FF D8 FF
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return { mime: 'image/jpeg', ext: 'jpg' };
  }

  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a
  ) {
    return { mime: 'image/png', ext: 'png' };
  }

  // WebP: RIFF (52 49 46 46) ... WEBP (57 45 42 50) en offset 8-11
  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return { mime: 'image/webp', ext: 'webp' };
  }

  return null;
}

/**
 * Normaliza texto de OCR:
 * NFD, elimina marcas diacríticas (\p{M}), a mayúsculas y colapsa espacios.
 */
export function normalizeOcrText(text: string): string {
  if (!text || typeof text !== 'string') return '';
  return text
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toUpperCase()
    .replace(/\s+/g, ' ')
    .trim();
}

export interface ApprovalEvaluationParams {
  ocrText?: string | null;
  carne: string;
  documentType: DocumentType;
  currentYear?: number;
  qrUrl?: string | null;
}

/**
 * Evalúa reglas obligatorias de aprobación automática (§6.1):
 * a) contiene UNIVERSIDAD DE SAN CARLOS | REGISTRO Y ESTADISTICA | USAC TRICENTENARIA | ESTUDIANTE UNIVERSITARIO
 * b) contiene el carné exacto
 * c) si es constancia_inscripcion o boleta_asignacion, contiene el año actual
 * d) si viene qr_url, debe pasar la validación de host
 */
export function evaluateApproval(params: ApprovalEvaluationParams): boolean {
  if (!params.ocrText || typeof params.ocrText !== 'string') {
    return false;
  }

  // d) Si viene qr_url, validar host
  if (params.qrUrl != null && params.qrUrl.trim() !== '') {
    if (!validateQrUrl(params.qrUrl)) {
      return false;
    }
  }

  const norm = normalizeOcrText(params.ocrText);
  if (!norm) return false;

  // a) Contiene al menos una de las palabras clave institucionales
  const hasKeyword = REQUIRED_KEYWORDS.some((kw) => norm.includes(kw));
  if (!hasKeyword) {
    return false;
  }

  // b) Contiene el carné exacto
  const cleanCarne = params.carne.trim();
  if (!cleanCarne || !norm.includes(cleanCarne)) {
    return false;
  }

  // c) Si document_type es constancia_inscripcion o boleta_asignacion, contiene el año actual
  if (
    params.documentType === 'constancia_inscripcion' ||
    params.documentType === 'boleta_asignacion'
  ) {
    const year = params.currentYear ?? new Date().getUTCFullYear();
    if (!norm.includes(String(year))) {
      return false;
    }
  }

  return true;
}
