import { describe, it, expect } from 'vitest';
import { evaluateApproval, isAutoApproved } from '../src/validators';
import { mapRpcErrorCode } from '../src/handlers/verify-document';

describe('evaluateApproval', () => {
  const currentYear = new Date().getUTCFullYear();
  const carne = '201912345';

  it('approves complete valid constancia_inscripcion with keyword, carne, year, and qr_url', () => {
    const text = `
      UNIVERSIDAD DE SAN CARLOS DE GUATEMALA
      DEPARTAMENTO DE REGISTRO Y ESTADISTICA
      CONSTANCIA DE INSCRIPCION CICLO ${currentYear}
      CARNE: ${carne}
      ESTUDIANTE REGULAR
    `;
    const qrUrl = 'https://registro.usac.edu.gt/verificar?id=abc';

    const result = evaluateApproval({
      ocrText: text,
      carne,
      documentType: 'constancia_inscripcion',
      currentYear,
      qrUrl,
    });

    expect(result.approved).toBe(true);
    expect(result.matched_keywords).toBe(true);
    expect(result.matched_carne).toBe(true);
    expect(result.matched_current_year).toBe(true);
    expect(isAutoApproved({
      ocrText: text,
      carne,
      documentType: 'constancia_inscripcion',
      currentYear,
      qrUrl,
    })).toBe(true);
  });

  it('approves with any of the 4 valid keywords', () => {
    const keywords = [
      'UNIVERSIDAD DE SAN CARLOS',
      'REGISTRO Y ESTADÍSTICA', // will be normalized without accent
      'USAC TRICENTENARIA',
      'ESTUDIANTE UNIVERSITARIO',
    ];

    for (const kw of keywords) {
      const text = `${kw} CARNE: ${carne} ANO: ${currentYear}`;
      const result = evaluateApproval({
        ocrText: text,
        carne,
        documentType: 'constancia_inscripcion',
        currentYear,
      });
      expect(result.approved).toBe(true);
      expect(result.matched_keywords).toBe(true);
      expect(result.matched_carne).toBe(true);
      expect(result.matched_current_year).toBe(true);
    }
  });

  it('rejects if institutional keyword is missing', () => {
    const text = `DOCUMENTO PRIVADO COLEGIO PRIVADO CARNE: ${carne} ANO: ${currentYear}`;
    const result = evaluateApproval({
      ocrText: text,
      carne,
      documentType: 'constancia_inscripcion',
      currentYear,
    });
    expect(result.approved).toBe(false);
    expect(result.matched_keywords).toBe(false);
    expect(result.matched_carne).toBe(true);
    expect(result.matched_current_year).toBe(true);
  });

  it('rejects if carne does not match', () => {
    const text = `UNIVERSIDAD DE SAN CARLOS CARNE: 202099999 ANO: ${currentYear}`;
    const result = evaluateApproval({
      ocrText: text,
      carne,
      documentType: 'constancia_inscripcion',
      currentYear,
    });
    expect(result.approved).toBe(false);
    expect(result.matched_keywords).toBe(true);
    expect(result.matched_carne).toBe(false);
    expect(result.matched_current_year).toBe(true);
  });

  it('rejects if current year is missing in constancia_inscripcion', () => {
    const text = `UNIVERSIDAD DE SAN CARLOS CONSTANCIA DE INSCRIPCION CARNE: ${carne} ANO: 2010`;
    const result = evaluateApproval({
      ocrText: text,
      carne,
      documentType: 'constancia_inscripcion',
      currentYear,
    });
    expect(result.approved).toBe(false);
    expect(result.matched_keywords).toBe(true);
    expect(result.matched_carne).toBe(true);
    expect(result.matched_current_year).toBe(false);
  });

  it('rejects if current year is missing in boleta_asignacion', () => {
    const text = `UNIVERSIDAD DE SAN CARLOS BOLETA DE ASIGNACION CARNE: ${carne} CICLO 2015`;
    const result = evaluateApproval({
      ocrText: text,
      carne,
      documentType: 'boleta_asignacion',
      currentYear,
    });
    expect(result.approved).toBe(false);
    expect(result.matched_keywords).toBe(true);
    expect(result.matched_carne).toBe(true);
    expect(result.matched_current_year).toBe(false);
  });

  it('allows carne_fisico even if current year is not present', () => {
    const text = `UNIVERSIDAD DE SAN CARLOS CARNE FISICO DE ESTUDIANTE: ${carne}`;
    const result = evaluateApproval({
      ocrText: text,
      carne,
      documentType: 'carne_fisico',
      currentYear,
    });
    expect(result.approved).toBe(true);
    expect(result.matched_keywords).toBe(true);
    expect(result.matched_carne).toBe(true);
    expect(result.matched_current_year).toBe(false); // carne_fisico sets matched_current_year to false
  });

  it('rejects if qr_url has an invalid or spoofed host', () => {
    const text = `UNIVERSIDAD DE SAN CARLOS CARNE: ${carne} ANO: ${currentYear}`;
    const evilQr = 'https://usac.edu.gt.evil.com/phish';

    const result = evaluateApproval({
      ocrText: text,
      carne,
      documentType: 'constancia_inscripcion',
      currentYear,
      qrUrl: evilQr,
    });
    expect(result.approved).toBe(false);
  });

  it('rejects if ocrText is empty or null', () => {
    const resNull = evaluateApproval({
      ocrText: null,
      carne,
      documentType: 'constancia_inscripcion',
    });
    expect(resNull.approved).toBe(false);
    expect(resNull.matched_keywords).toBe(false);
    expect(resNull.matched_carne).toBe(false);
    expect(resNull.matched_current_year).toBe(false);

    const resEmpty = evaluateApproval({
      ocrText: '   ',
      carne,
      documentType: 'constancia_inscripcion',
    });
    expect(resEmpty.approved).toBe(false);
    expect(resEmpty.matched_keywords).toBe(false);
    expect(resEmpty.matched_carne).toBe(false);
    expect(resEmpty.matched_current_year).toBe(false);
  });
});

describe('mapRpcErrorCode', () => {
  it('maps database and RPC codes correctly according to contract §6.1', () => {
    expect(mapRpcErrorCode('credential_unavailable')).toEqual({
      status: 409,
      message: 'Student credentials are unavailable or already claimed',
    });
    expect(mapRpcErrorCode('rate_limited')).toEqual({
      status: 429,
      message: 'Too many verification attempts in the last 24 hours. Please wait.',
    });
    expect(mapRpcErrorCode('invalid_carne').status).toBe(422);
    expect(mapRpcErrorCode('invalid_document_type').status).toBe(422);
    expect(mapRpcErrorCode('not_authorized').status).toBe(403);
    expect(mapRpcErrorCode('other_error').status).toBe(500);
  });
});

describe('CORS and Router helpers', () => {
  it('handles wildcard ALLOWED_ORIGINS correctly', async () => {
    const { getCorsHeaders } = await import('../src/index');
    const req = new Request('https://api.usac.edu.gt/api/v1/verify-document', {
      headers: { Origin: 'https://app.usac.edu.gt' },
    });
    const headers = getCorsHeaders(req, '*');
    expect(headers['Access-Control-Allow-Origin']).toBe('https://app.usac.edu.gt');
    expect(headers['Access-Control-Allow-Headers']).toBe('authorization, content-type');
  });

  it('restricts origins when ALLOWED_ORIGINS has a specific list', async () => {
    const { getCorsHeaders } = await import('../src/index');
    const reqAllowed = new Request('https://api.usac.edu.gt/test', {
      headers: { Origin: 'https://comunidadusac.com' },
    });
    const headersAllowed = getCorsHeaders(reqAllowed, 'https://comunidadusac.com, https://usac.edu.gt');
    expect(headersAllowed['Access-Control-Allow-Origin']).toBe('https://comunidadusac.com');

    const reqBlocked = new Request('https://api.usac.edu.gt/test', {
      headers: { Origin: 'https://evil.com' },
    });
    const headersBlocked = getCorsHeaders(reqBlocked, 'https://comunidadusac.com, https://usac.edu.gt');
    expect(headersBlocked['Access-Control-Allow-Origin']).toBeUndefined();
  });
});
