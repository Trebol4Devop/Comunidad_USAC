import { describe, it, expect } from 'vitest';
import {
  validateCarne,
  validateCui,
  validateDocumentType,
  validateQrUrl,
  detectImageType,
  normalizeOcrText,
} from '../src/validators';

describe('Validators: validateCarne', () => {
  it('accepts valid historical and recent carnes', () => {
    expect(validateCarne('198012345')).toBe(true);
    expect(validateCarne('201912345')).toBe(true);
    expect(validateCarne('202412345')).toBe(true);
  });

  it('rejects carnes with year before 1980', () => {
    expect(validateCarne('197912345')).toBe(false);
    expect(validateCarne('190012345')).toBe(false);
  });

  it('rejects carnes with future years', () => {
    const currentYear = new Date().getUTCFullYear();
    const futureCarne = `${currentYear + 1}12345`;
    expect(validateCarne(futureCarne)).toBe(false);
    expect(validateCarne('209912345')).toBe(false);
  });

  it('rejects carnes by length', () => {
    expect(validateCarne('20191234')).toBe(false); // 8 digits
    expect(validateCarne('2019123456')).toBe(false); // 10 digits
    expect(validateCarne('')).toBe(false);
  });

  it('rejects carnes containing letters or special characters', () => {
    expect(validateCarne('2019A2345')).toBe(false);
    expect(validateCarne('2019-12345')).toBe(false);
    expect(validateCarne('2019 12345')).toBe(false);
  });
});

describe('Validators: validateCui', () => {
  it('accepts valid 13-digit CUI with departments 01 to 22', () => {
    // Guatemala (01)
    expect(validateCui('1234567890101')).toBe(true);
    // Jalapa (21), Jutiapa (22)
    expect(validateCui('9876543212101')).toBe(true);
    expect(validateCui('9876543212201')).toBe(true);
  });

  it('rejects CUI with department 00 or 23+', () => {
    expect(validateCui('1234567890001')).toBe(false); // 00 invalid
    expect(validateCui('1234567892301')).toBe(false); // 23 invalid
    expect(validateCui('1234567899901')).toBe(false); // 99 invalid
  });

  it('rejects CUI with invalid lengths or non-numeric characters', () => {
    expect(validateCui('123456789010')).toBe(false); // 12 digits
    expect(validateCui('12345678901011')).toBe(false); // 14 digits
    expect(validateCui('12345678901A1')).toBe(false);
    expect(validateCui('')).toBe(false);
  });
});

describe('Validators: validateQrUrl', () => {
  it('accepts valid https URLs from usac.edu.gt and subdomains', () => {
    expect(validateQrUrl('https://registro.usac.edu.gt/verificar?id=123')).toBe(true);
    expect(validateQrUrl('https://usac.edu.gt/constancias/validar')).toBe(true);
    expect(validateQrUrl('https://ingenieria.usac.edu.gt/doc.pdf')).toBe(true);
    expect(validateQrUrl('https://registro.usac.edu.gt.')).toBe(true); // Trailing dot
  });

  it('rejects non-https URLs', () => {
    expect(validateQrUrl('http://registro.usac.edu.gt/verificar')).toBe(false);
    expect(validateQrUrl('ftp://registro.usac.edu.gt/verificar')).toBe(false);
  });

  it('rejects non-USAC hostnames and spoofing attempts', () => {
    expect(validateQrUrl('https://evil.com')).toBe(false);
    expect(validateQrUrl('https://usac.edu.gt.evil.com/fake')).toBe(false);
    expect(validateQrUrl('https://evil.com/?x=usac.edu.gt')).toBe(false);
    expect(validateQrUrl('https://evil.com#registro.usac.edu.gt')).toBe(false);
    expect(validateQrUrl('https://notusac.edu.gt')).toBe(false);
    expect(validateQrUrl('invalid-url')).toBe(false);
  });
});

describe('Validators: detectImageType', () => {
  it('detects JPEG from magic bytes FF D8 FF', () => {
    const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
    const result = detectImageType(bytes);
    expect(result).toEqual({ mime: 'image/jpeg', ext: 'jpg' });
  });

  it('detects PNG from magic bytes 89 50 4E 47 0D 0A 1A 0A', () => {
    const bytes = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00]);
    const result = detectImageType(bytes);
    expect(result).toEqual({ mime: 'image/png', ext: 'png' });
  });

  it('detects WebP from RIFF ... WEBP magic bytes', () => {
    const bytes = new Uint8Array([
      0x52, 0x49, 0x46, 0x46, // RIFF
      0x24, 0x00, 0x00, 0x00, // file size
      0x57, 0x45, 0x42, 0x50, // WEBP
      0x56, 0x50, 0x38, 0x20, // VP8
    ]);
    const result = detectImageType(bytes);
    expect(result).toEqual({ mime: 'image/webp', ext: 'webp' });
  });

  it('rejects PDF and garbage bytes', () => {
    // PDF: %PDF
    const pdfBytes = new Uint8Array([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x34]);
    expect(detectImageType(pdfBytes)).toBeNull();

    // Garbage / text / empty
    expect(detectImageType(new Uint8Array([0x00, 0x01, 0x02]))).toBeNull();
    expect(detectImageType(new Uint8Array([0x48, 0x65, 0x6c, 0x6c, 0x6f]))).toBeNull();
    expect(detectImageType(new Uint8Array([]))).toBeNull();
  });
});

describe('Validators: normalizeOcrText', () => {
  it('normalizes diacritics, casing, and collapses whitespace', () => {
    const raw = '  Universidad   de   San   Carlos  \n  de   Guatemala   ';
    expect(normalizeOcrText(raw)).toBe('UNIVERSIDAD DE SAN CARLOS DE GUATEMALA');

    const withAccents = 'Registro y Estadística Tricentenaria Constancia Inscripción';
    expect(normalizeOcrText(withAccents)).toBe(
      'REGISTRO Y ESTADISTICA TRICENTENARIA CONSTANCIA INSCRIPCION'
    );
  });

  it('handles empty or null inputs', () => {
    expect(normalizeOcrText('')).toBe('');
  });
});

describe('Validators: validateDocumentType', () => {
  it('accepts only allowed document types', () => {
    expect(validateDocumentType('constancia_inscripcion')).toBe(true);
    expect(validateDocumentType('carne_fisico')).toBe(true);
    expect(validateDocumentType('boleta_asignacion')).toBe(true);

    expect(validateDocumentType('pasaporte')).toBe(false);
    expect(validateDocumentType('dpi')).toBe(false);
    expect(validateDocumentType('')).toBe(false);
  });
});
